import Foundation
import SwiftUI
import UniformTypeIdentifiers

final class MistralAPIManager: @unchecked Sendable {
    public static let shared = MistralAPIManager()
    
    // Флаг для отмены текущей обработки
     var isCancelled = false
    
     init() {}
    
    // Метод для отмены текущей обработки
    public func cancelProcessing() {
        isCancelled = true
    }
    
    // Получаем API ключ из настроек
    private var apiKey: String {
        UserDefaults.standard.string(forKey: "mistral_api_key") ?? ""
    }
    
    // Поддерживаемые типы файлов для OCR
    public enum OCRFileType {
        case pdf
        case image
        
        static func fromURL(_ url: URL) -> OCRFileType? {
            if url.pathExtension.lowercased() == "pdf" {
                return .pdf
            } else if ["jpg", "jpeg", "png", "tiff", "tif", "bmp", "gif"].contains(url.pathExtension.lowercased()) {
                return .image
            }
            return nil
        }
    }
    
    // Функция для обработки результатов OCR
    public func processOCRResult(_ extractedText: String, options: OCRProcessingOptions = OCRProcessingOptions()) -> String {
        // Если текст пустой, возвращаем пустую строку
        guard !extractedText.isEmpty else {
            return ""
        }
        
        var processedText = extractedText
        
        // Обрабатываем ссылки на изображения
        if options.handleImageLinks != .keep {
            // Регулярное выражение для поиска Markdown-ссылок на изображения
            let imagePattern = #"!\[(.*?)\]\((.*?)\)"#
            
            switch options.handleImageLinks {
            case .remove:
                // Удаляем все ссылки на изображения
                processedText = processedText.replacingOccurrences(
                    of: imagePattern,
                    with: "",
                    options: .regularExpression
                )
                
            case .replaceWithPlaceholder:
                // Заменяем ссылки на изображения на текстовое описание
                processedText = processedText.replacingOccurrences(
                    of: imagePattern,
                    with: options.imagePlaceholder,
                    options: .regularExpression
                )
                
            case .keep:
                // Оставляем как есть
                break
            }
        }
        
        // Удаляем пустые строки, если нужно
        if options.removeEmptyLines {
            processedText = processedText.replacingOccurrences(
                of: #"\n\s*\n+"#,
                with: "\n\n",
                options: .regularExpression
            )
        }
        
        // Удаляем лишние пробелы, если нужно
        if options.trimWhitespace {
            processedText = processedText.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        return processedText
    }
    
    // Универсальная функция для извлечения текста из PDF или изображения с опциями обработки
    public func extractTextUsingMistralOCR(filePath: String, processingOptions: OCRProcessingOptions = OCRProcessingOptions()) async -> String? {
        // Сбрасываем флаг отмены перед началом обработки
        isCancelled = false
        
        guard !apiKey.isEmpty else {
            print("⚠️ API ключ Mistral не указан")
            return nil
        }
        
        // Удаляем лишние пробелы и переносы строк
        let cleanedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let url = URL(string: "file://\(filePath)") else {
            print("⚠️ Неверный путь к файлу: \(filePath)")
            return nil
        }
        
        // Определяем тип файла
        guard let fileType = OCRFileType.fromURL(url) else {
            print("⚠️ Неподдерживаемый тип файла: \(url.pathExtension)")
            return nil
        }
        
        // Получаем имя файла для отображения
        let fileName = url.lastPathComponent
        
        do {
            // Проверяем отмену
            if isCancelled {
                print("🛑 Обработка отменена пользователем")
                return nil
            }
            
            // Проверяем размер файла перед обработкой
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: filePath)
            if let fileSize = fileAttributes[.size] as? Int {
                if fileSize > 50_000_000 { // 50 МБ (согласно документации)
                    print("⚠️ Файл слишком большой для OCR API: \(fileSize / 1_000_000) МБ (максимум 50 МБ)")
                    return nil
                }
                
                print("📄 Размер файла для OCR: \(fileSize / 1_000) КБ")
            }
            
            // Проверяем отмену
            if isCancelled {
                print("🛑 Обработка отменена пользователем")
                return nil
            }
            
            // Читаем данные файла
            let fileData = try Data(contentsOf: url)
            
            // ШАГ 1: Загружаем файл через /v1/files
            print("🔄 Загрузка файла в Mistral API...")
            
            // Создаем multipart запрос для загрузки файла
            let uploadURL = URL(string: "https://api.mistral.ai/v1/files")!
            var uploadRequest = URLRequest(url: uploadURL)
            uploadRequest.httpMethod = "POST"
            uploadRequest.addValue("Bearer \(cleanedKey)", forHTTPHeaderField: "Authorization")
            
            // Генерируем уникальную границу для multipart/form-data
            let boundary = UUID().uuidString
            uploadRequest.addValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            
            // Создаем тело multipart запроса
            var uploadBody = Data()
            
            // Добавляем поле purpose
            uploadBody.append("--\(boundary)\r\n".data(using: .utf8)!)
            uploadBody.append("Content-Disposition: form-data; name=\"purpose\"\r\n\r\n".data(using: .utf8)!)
            uploadBody.append("ocr\r\n".data(using: .utf8)!)
            
            // Добавляем файл
            uploadBody.append("--\(boundary)\r\n".data(using: .utf8)!)
            uploadBody.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
            
            // Устанавливаем правильный Content-Type в зависимости от типа файла
            let mimeType = fileType == .pdf ? "application/pdf" : "image/\(url.pathExtension.lowercased())"
            uploadBody.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
            uploadBody.append(fileData)
            uploadBody.append("\r\n".data(using: .utf8)!)
            
            // Завершаем multipart запрос
            uploadBody.append("--\(boundary)--\r\n".data(using: .utf8)!)
            
            uploadRequest.httpBody = uploadBody
            
            // Проверяем отмену
            if isCancelled {
                print("🛑 Обработка отменена пользователем")
                return nil
            }
            
            // Выполняем запрос на загрузку файла
            let (uploadData, uploadResponse) = try await URLSession.shared.data(for: uploadRequest)
            
            // Проверяем отмену
            if isCancelled {
                print("🛑 Обработка отменена пользователем")
                return nil
            }
            
            guard let httpUploadResponse = uploadResponse as? HTTPURLResponse else {
                print("⚠️ Неверный формат ответа от API при загрузке файла")
                return nil
            }
            
            // Получаем текст ответа для диагностики
            let uploadResponseText = String(data: uploadData, encoding: .utf8) ?? "Не удалось декодировать ответ"
            print("📝 Код ответа API при загрузке файла: \(httpUploadResponse.statusCode)")
            print("📝 Тело ответа: \(uploadResponseText)")
            
            if httpUploadResponse.statusCode != 200 {
                print("⚠️ Ошибка при загрузке файла: \(uploadResponseText)")
                return nil
            }
            
            // Извлекаем ID загруженного файла
            guard let uploadJson = try JSONSerialization.jsonObject(with: uploadData) as? [String: Any],
                  let fileId = uploadJson["id"] as? String else {
                print("⚠️ Не удалось получить ID загруженного файла")
                return nil
            }
            
            print("✅ Файл успешно загружен, ID: \(fileId)")
            
            // Проверяем отмену
            if isCancelled {
                print("🛑 Обработка отменена пользователем")
                return nil
            }
            
            // ШАГ 2: Используем полученный ID для OCR
            print("🔄 Отправка запроса в Mistral OCR API для обработки файла...")
            
            // Сначала получаем URL для загруженного файла
            let fileInfoURL = URL(string: "https://api.mistral.ai/v1/files/\(fileId)")!
            var fileInfoRequest = URLRequest(url: fileInfoURL)
            fileInfoRequest.httpMethod = "GET"
            fileInfoRequest.addValue("application/json", forHTTPHeaderField: "Accept")
            fileInfoRequest.addValue("Bearer \(cleanedKey)", forHTTPHeaderField: "Authorization")
            
            print("📝 Запрос информации о файле: \(fileInfoURL)")
            
            // Проверяем отмену
            if isCancelled {
                print("🛑 Обработка отменена пользователем")
                return nil
            }
            
            // Выполняем запрос для получения информации о файле
            let (fileInfoData, fileInfoResponse) = try await URLSession.shared.data(for: fileInfoRequest)
            
            // Проверяем отмену
            if isCancelled {
                print("🛑 Обработка отменена пользователем")
                return nil
            }
            
            guard let httpFileInfoResponse = fileInfoResponse as? HTTPURLResponse else {
                print("⚠️ Неверный формат ответа при запросе информации о файле")
                return nil
            }
            
            let fileInfoResponseText = String(data: fileInfoData, encoding: .utf8) ?? "Не удалось декодировать ответ"
            print("📝 Код ответа API информации о файле: \(httpFileInfoResponse.statusCode)")
            print("📝 Тело ответа: \(fileInfoResponseText)")
            
            if httpFileInfoResponse.statusCode != 200 {
                print("⚠️ Ошибка при получении информации о файле: \(fileInfoResponseText)")
                return nil
            }
            
            // Теперь получаем URL для доступа к файлу
            let fileURLRequest = URL(string: "https://api.mistral.ai/v1/files/\(fileId)/url?expiry=24")!
            var getURLRequest = URLRequest(url: fileURLRequest)
            getURLRequest.httpMethod = "GET"
            getURLRequest.addValue("application/json", forHTTPHeaderField: "Accept")
            getURLRequest.addValue("Bearer \(cleanedKey)", forHTTPHeaderField: "Authorization")
            
            print("📝 Запрос URL для файла: \(fileURLRequest)")
            
            // Проверяем отмену
            if isCancelled {
                print("🛑 Обработка отменена пользователем")
                return nil
            }
            
            // Выполняем запрос для получения URL файла
            let (urlData, urlResponse) = try await URLSession.shared.data(for: getURLRequest)
            
            // Проверяем отмену
            if isCancelled {
                print("🛑 Обработка отменена пользователем")
                return nil
            }
            
            guard let httpURLResponse = urlResponse as? HTTPURLResponse else {
                print("⚠️ Неверный формат ответа при запросе URL файла")
                return nil
            }
            
            let urlResponseText = String(data: urlData, encoding: .utf8) ?? "Не удалось декодировать ответ"
            print("📝 Код ответа API URL файла: \(httpURLResponse.statusCode)")
            print("📝 Тело ответа: \(urlResponseText)")
            
            if httpURLResponse.statusCode != 200 {
                print("⚠️ Ошибка при получении URL файла: \(urlResponseText)")
                return nil
            }
            
            // Извлекаем URL файла из ответа
            guard let urlJson = try JSONSerialization.jsonObject(with: urlData) as? [String: Any],
                  let fileURL = urlJson["url"] as? String else {
                print("⚠️ Не удалось получить URL файла из ответа")
                return nil
            }
            
            print("✅ Получен URL файла: \(fileURL)")
            
            // Проверяем отмену
            if isCancelled {
                print("🛑 Обработка отменена пользователем")
                return nil
            }
            
            // Теперь отправляем запрос OCR с полученным URL
            let ocrURL = URL(string: "https://api.mistral.ai/v1/ocr")!
            var ocrRequest = URLRequest(url: ocrURL)
            ocrRequest.httpMethod = "POST"
            ocrRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
            ocrRequest.addValue("Bearer \(cleanedKey)", forHTTPHeaderField: "Authorization")
            
            // Создаем тело запроса для OCR API с правильным URL и типом документа
            let ocrRequestBody: [String: Any]
            
            if fileType == .pdf {
                ocrRequestBody = [
                    "model": "mistral-ocr-latest",
                    "document": [
                        "type": "document_url",
                        "document_url": fileURL
                    ],
                    "include_image_base64": false
                ]
            } else { // Для изображений
                ocrRequestBody = [
                    "model": "mistral-ocr-latest",
                    "document": [
                        "type": "image_url",
                        "image_url": fileURL
                    ],
                    "include_image_base64": false
                ]
            }
            
            // Выводим информацию о запросе для диагностики
            print("📝 URL запроса OCR: \(ocrURL)")
            print("📝 Заголовки запроса: Content-Type: application/json, Authorization: Bearer \(cleanedKey.prefix(5))...\(cleanedKey.suffix(5))")
            print("📝 Модель: mistral-ocr-latest")
            print("📝 Тип документа: \(fileType == .pdf ? "document_url" : "image_url")")
            print("📝 URL файла для OCR: \(fileURL)")
            
            // Сериализуем тело запроса
            let ocrJsonData = try JSONSerialization.data(withJSONObject: ocrRequestBody)
            ocrRequest.httpBody = ocrJsonData
            
            // Создаем URLSession с настройками
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 120.0  // Увеличиваем таймаут, так как OCR может занять время
            config.timeoutIntervalForResource = 180.0
            let session = URLSession(configuration: config)
            
            // Проверяем отмену
            if isCancelled {
                print("🛑 Обработка отменена пользователем")
                return nil
            }
            
            // Выполняем запрос OCR
            let (ocrData, ocrResponse) = try await session.data(for: ocrRequest)
            
            // Проверяем отмену
            if isCancelled {
                print("🛑 Обработка отменена пользователем")
                return nil
            }
            
            // Проверяем ответ
            guard let httpOcrResponse = ocrResponse as? HTTPURLResponse else {
                print("⚠️ Неверный формат ответа от OCR API")
                return nil
            }
            
            // Получаем текст ответа для диагностики
            let ocrResponseText = String(data: ocrData, encoding: .utf8) ?? "Не удалось декодировать ответ"
            print("📝 Код ответа OCR API: \(httpOcrResponse.statusCode)")
            print("📝 Тело ответа OCR: \(ocrResponseText.prefix(200))...")
            
            switch httpOcrResponse.statusCode {
            case 200:
                // Парсим ответ
                if let json = try JSONSerialization.jsonObject(with: ocrData) as? [String: Any],
                   let pages = json["pages"] as? [[String: Any]] {
                    
                    var extractedText = ""
                    
                    // Извлекаем текст из каждой страницы
                    for (index, page) in pages.enumerated() {
                        if let markdown = page["markdown"] as? String {
                            extractedText += "Страница \(index + 1):\n\(markdown)\n\n"
                        }
                    }
                    
                    print("✅ Успешно получен ответ от Mistral OCR API")
                    
                    // Обрабатываем результат перед возвратом
                    if !extractedText.isEmpty {
                        return processOCRResult(extractedText, options: processingOptions)
                    }
                    return nil
                }
                
                print("⚠️ Не удалось извлечь текст из ответа OCR API")
                return nil
                
            case 401:
                print("⚠️ Ошибка OCR API (код 401): Недействительный API ключ")
                print("📝 Полный ответ: \(ocrResponseText)")
                return nil
                
            case 422:
                print("⚠️ Ошибка OCR API (код 422): Неверный формат запроса")
                print("📝 Полный ответ: \(ocrResponseText)")
                return nil
                
            case 429:
                print("⚠️ Ошибка OCR API (код 429): Превышен лимит запросов")
                return nil
                
            case 520:
                print("⚠️ Ошибка OCR API (код 520): Сервер Mistral временно недоступен")
                print("⚠️ Ответ сервера: \(ocrResponseText)")
                return nil
                
            default:
                print("⚠️ Ошибка OCR API (код \(httpOcrResponse.statusCode)): \(ocrResponseText)")
                return nil
            }
        } catch let error as NSError {
            print("⚠️ Ошибка при использовании Mistral API: \(error.localizedDescription)")
            if error.domain == NSURLErrorDomain {
                switch error.code {
                case NSURLErrorTimedOut:
                    print("⚠️ Превышено время ожидания ответа от API")
                case NSURLErrorNetworkConnectionLost:
                    print("⚠️ Соединение с API было прервано")
                case NSURLErrorNotConnectedToInternet:
                    print("⚠️ Отсутствует подключение к интернету")
                default:
                    print("⚠️ Сетевая ошибка: \(error.code)")
                }
            }
            return nil
        } catch {
            print("⚠️ Неизвестная ошибка при использовании Mistral API: \(error)")
            return nil
        }
    }
    
    // Для обратной совместимости
    public func extractTextFromPDFUsingMistralOCR(pdfPath: String, processingOptions: OCRProcessingOptions = OCRProcessingOptions()) async -> String? {
        return await extractTextUsingMistralOCR(filePath: pdfPath, processingOptions: processingOptions)
    }
    
    // Добавляем функцию для получения только текста (без изображений)
    public func extractTextOnlyUsingMistralOCR(filePath: String) async -> String? {
        var options = OCRProcessingOptions()
        options.handleImageLinks = .remove
        return await extractTextUsingMistralOCR(filePath: filePath, processingOptions: options)
    }
    
    // Опции для обработки результатов OCR
    struct OCRProcessingOptions {
        enum ImageLinkHandling {
            case keep                 // Оставить ссылки на изображения как есть
            case remove               // Удалить все ссылки на изображения
            case replaceWithPlaceholder // Заменить ссылки на изображения текстовым описанием
        }
        
        var handleImageLinks: ImageLinkHandling = .replaceWithPlaceholder
        var imagePlaceholder: String = "[Изображение]"
        var removeEmptyLines: Bool = true
        var trimWhitespace: Bool = true
    }
    

}
