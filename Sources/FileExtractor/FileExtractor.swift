// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import SwiftUI
import PDFKit

/// Служба для извлечения текста из файлов различных форматов
final class TextExtractionService: @unchecked Sendable {
    /// Синглтон для доступа к сервису
    static let shared = TextExtractionService()
    
    /// Настройки для OCR
    struct OCRSettings {
        /// Включить автоматическое применение OCR для изображений и PDF без текстового слоя
        var autoApplyOCR: Bool = UserDefaults.standard.bool(forKey: "auto_apply_on_text_extraction")
    }
    
    /// Результат извлечения текста
    struct ExtractionResult {
        let text: String?
        let method: String
        let error: Error?
        
        var isSuccess: Bool {
            // Текст должен быть не nil, не пустой, и ошибки не должно быть
            return text != nil && !text!.isEmpty && error == nil
        }
    }
    
    var settings = OCRSettings()
    
    private init() {
        // Следим за изменениями настроек
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateSettings),
            name: UserDefaults.didChangeNotification,
            object: nil
        )
    }
    
    @objc private func updateSettings() {
        settings.autoApplyOCR = UserDefaults.standard.bool(forKey: "auto_apply_on_text_extraction")
    }
    
    
    // Убрать
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    /// Извлекает текст из файла по URL
    /// - Parameters:
    ///   - fileURL: URL файла
    ///   - fileName: Имя файла (опционально, если отличается от последнего компонента URL)
    ///   - completion: Обработчик завершения с результатом
//    func extractText(from fileURL: URL, fileName: String? = nil, completion: @escaping (ExtractionResult) -> Void) {
//        Task {
//            let result = await extractTextAsync(from: fileURL, fileName: fileName)
//            DispatchQueue.main.async {
//                completion(result)
//            }
//        }
//    }
    // Переписал метод, требуется по-другому вызывать с помошью await
    public func extractText(from fileURL: URL, fileName: String? = nil) async {
        let result = await extractTextAsync(from: fileURL, fileName: fileName)
        print("📄 TextExtractionService: Результат извлечения текста: \(result)")
    }
    
    /// Асинхронная версия метода для извлечения текста
    /// - Parameters:
    ///   - fileURL: URL файла
    ///   - fileName: Имя файла (опционально, если отличается от последнего компонента URL)
    /// - Returns: Результат извлечения текста
    public func extractTextAsync(from fileURL: URL, fileName: String? = nil) async -> ExtractionResult {
        let name = fileName ?? fileURL.lastPathComponent
        let fileExtension = fileURL.pathExtension.lowercased()
        
        print("📄 TextExtractionService: Извлечение текста из файла \(name) (тип: \(fileExtension))")
        
        // Выбираем метод извлечения в зависимости от типа файла
        switch fileExtension {
            case "pdf":
                return await processPDF(fileURL: fileURL)
                
            case "txt", "md", "swift", "py", "js", "html", "css", "json":
                return await processPlainText(fileURL: fileURL)
                
            case "rtf":
                return await processRTF(fileURL: fileURL)
                
            case "doc", "docx":
                return await processDOCX(fileURL: fileURL)
                
            case "jpg", "jpeg", "png", "tiff", "tif", "gif", "bmp", "heic":
                return await processImage(fileURL: fileURL)
                
            default:
                return ExtractionResult(
                    text: nil,
                    method: "Unsupported",
                    error: NSError(
                        domain: "TextExtractionService",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Тип файла \(fileExtension) не поддерживается"]
                    )
                )
        }
    }
    
    /// Обрабатывает PDF-файл, проверяет наличие текстового слоя, при необходимости применяет OCR
    func processPDF(fileURL: URL) async -> ExtractionResult {
        guard let pdfDocument = PDFDocument(url: fileURL) else {
            return ExtractionResult(
                text: nil,
                method: "PDFKit",
                error: NSError(
                    domain: "TextExtractionService",
                    code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "Не удалось открыть PDF документ"]
                )
            )
        }
        
        // Пытаемся извлечь текст с помощью PDFKit
        var fullText = ""
        for i in 0..<pdfDocument.pageCount {
            if let page = pdfDocument.page(at: i), let pageText = page.string {
                fullText += pageText + "\n" // Добавляем перенос строки между страницами
            }
        }
        
        // Проверяем, есть ли текст
        if !fullText.isEmpty {
            return ExtractionResult(
                text: fullText.trimmingCharacters(in: .whitespacesAndNewlines),
                method: "PDFKit",
                error: nil
            )
        } else {
            // Если текстового слоя нет, применяем OCR при соответствующей настройке
            if settings.autoApplyOCR {
                print("📝 TextExtractionService: PDF не содержит текстового слоя, применяем OCR")
                return await processWithOCR(fileURL: fileURL)
            } else {
                print("⚠️ TextExtractionService: PDF не содержит текстового слоя, OCR отключен в настройках")
                return ExtractionResult(
                    text: nil,
                    method: "OCR отключен",
                    error: NSError(
                        domain: "TextExtractionService",
                        code: 3,
                        userInfo: [NSLocalizedDescriptionKey: "OCR отключен в настройках"]
                    )
                )
            }
        }
    }
    
    /// Обрабатывает обычный текстовый файл
    func processPlainText(fileURL: URL) async -> ExtractionResult {
        do {
            let text = try String(contentsOf: fileURL, encoding: .utf8)
            return ExtractionResult(
                text: text,
                method: "PlainText",
                error: nil
            )
        } catch {
            print("⚠️ TextExtractionService: Ошибка при чтении текстового файла: \(error)")
            return ExtractionResult(
                text: nil,
                method: "PlainText",
                error: error
            )
        }
    }
    
    /// Обрабатывает RTF-файл
    func processRTF(fileURL: URL) async -> ExtractionResult {
        do {
            let text = try extractTextFromRTF(fileURL: fileURL)
            return ExtractionResult(
                text: text,
                method: "NSAttributedString",
                error: nil
            )
        } catch {
            print("⚠️ TextExtractionService: Ошибка при обработке RTF файла: \(error)")
            return ExtractionResult(
                text: nil,
                method: "NSAttributedString",
                error: error
            )
        }
    }
    
    /// Извлекает текст из RTF файла
    func extractTextFromRTF(fileURL: URL) throws -> String {
        // Читаем данные из файла
        let rtfData = try Data(contentsOf: fileURL)
        
        // Создаем NSAttributedString из RTF данных
        if let attributedString = try? NSAttributedString(
            data: rtfData,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
        ) {
            // Получаем чистый текст без форматирования
            return attributedString.string
        } else {
            throw NSError(domain: "RTFExtraction", code: 1, userInfo: [NSLocalizedDescriptionKey: "Не удалось преобразовать RTF в текст"])
        }
    }
    
    /// Обрабатывает DOC/DOCX файл с помощью textutil
    func processDOCX(fileURL: URL) async -> ExtractionResult {
        do {
            let text = try await readDocxUsingTextUtil(filePath: fileURL.path)
            return ExtractionResult(
                text: text,
                method: "textutil",
                error: nil
            )
        } catch {
            print("⚠️ TextExtractionService: Ошибка при обработке DOCX файла: \(error)")
            return ExtractionResult(
                text: nil,
                method: "textutil",
                error: error
            )
        }
    }
    
    /// Чтение DOC/DOCX с помощью textutil
    func readDocxUsingTextUtil(filePath: String) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/textutil")
        process.arguments = ["-convert", "txt", "-encoding", "UTF-8", filePath, "-stdout"]
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw NSError(domain: "ProcessError", code: 0,
                          userInfo: [NSLocalizedDescriptionKey: "Не удалось запустить textutil: \(error.localizedDescription)"])
        }
        
        // Читаем данные из пайпов ПОСЛЕ завершения процесса
        let outputData = try? outputPipe.fileHandleForReading.readToEnd()
        let errorData = try? errorPipe.fileHandleForReading.readToEnd()
        
        // Проверяем статус завершения
        if process.terminationStatus != 0 {
            let errorString = String(data: errorData ?? Data(), encoding: .utf8) ?? "Unknown textutil error"
            throw NSError(domain: "TextUtilError", code: Int(process.terminationStatus),
                          userInfo: [NSLocalizedDescriptionKey: "Ошибка textutil: \(errorString)"])
        }
        
        // Проверяем наличие данных и декодируем
        guard let validOutputData = outputData, !validOutputData.isEmpty else {
            return "" // Возвращаем пустую строку, если файл пустой
        }
        
        guard let outputString = String(data: validOutputData, encoding: .utf8) else {
            throw NSError(domain: "TextUtilError", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Не удалось декодировать результат работы textutil"])
        }
        
        return outputString
    }
    
    /// Обрабатывает изображение с помощью OCR
    func processImage(fileURL: URL) async -> ExtractionResult {
        if settings.autoApplyOCR {
            print("📝 TextExtractionService: Применяем OCR для изображения \(fileURL.lastPathComponent)")
            return await processWithOCR(fileURL: fileURL)
        } else {
            print("⚠️ TextExtractionService: OCR отключен в настройках для изображений")
            return ExtractionResult(
                text: nil,
                method: "OCR отключен",
                error: NSError(
                    domain: "TextExtractionService",
                    code: 3,
                    userInfo: [NSLocalizedDescriptionKey: "OCR отключен в настройках"]
                )
            )
        }
    }
    
    /// Применяет OCR к файлу (изображению или PDF без текстового слоя)
    func processWithOCR(fileURL: URL) async -> ExtractionResult {
        if let extractedText = await MistralAPIManager.shared.extractTextUsingMistralOCR(filePath: fileURL.path) {
            print("✅ TextExtractionService: OCR успешно применен к \(fileURL.lastPathComponent)")
            return ExtractionResult(
                text: extractedText,
                method: "Mistral OCR",
                error: nil
            )
        } else {
            print("❌ TextExtractionService: Ошибка при применении OCR к \(fileURL.lastPathComponent)")
            return ExtractionResult(
                text: nil,
                method: "Mistral OCR",
                error: NSError(
                    domain: "TextExtractionService",
                    code: 4,
                    userInfo: [NSLocalizedDescriptionKey: "Ошибка при применении OCR"]
                )
            )
        }
    }
    
    /// Создает и сохраняет кэш-файл с извлеченными данными
    /// - Parameters:
    ///   - data: Извлеченные данные
    ///   - fileItem: Файл, из которого извлечены данные
    ///   - method: Метод извлечения текста
    /// - Returns: URL созданного кэш-файла или nil в случае ошибки
    public func saveCache(text: String, for fileItem: FileItem, extractionMethod: String) async -> URL? {
        // 1. Создаем структуру для кэширования
        let dataToCache = ExtractedData(
            extractedText: text,
            originalFileModificationDate: fileItem.modificationDate,
            originalFilePath: fileItem.path.path,
            extractionMethod: extractionMethod
        )
        
        // 2. Определяем путь к скрытому кэш-файлу
        let hiddenFileName = "." + fileItem.name + ".json"
        let hiddenPath = fileItem.path.deletingLastPathComponent().appendingPathComponent(hiddenFileName)
        
        // 3. Кодируем в JSON и сохраняем
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let jsonData = try encoder.encode(dataToCache)
            try jsonData.write(to: hiddenPath)
            print("✅ TextExtractionService: Кэш успешно сохранен в: \(hiddenPath.path)")
            return hiddenPath
        } catch {
            print("❌ TextExtractionService: Ошибка при сохранении кэша для \(fileItem.name): \(error)")
            return nil
        }
    }
    
    /// Извлекает и сохраняет текст из файла в кэш
    /// - Parameters:
    ///   - fileItem: Файл для обработки
    ///   - completion: Обработчик завершения с результатом и URL кэш-файла
//    func extractAndCacheData(for fileItem: FileItem, completion: @escaping (ExtractionResult, URL?) -> Void) {
//        Task {
//            // Извлекаем текст
//            let result = await extractTextAsync(from: fileItem.path)
//            
//            // Если текст успешно извлечен И не пустой, сохраняем в кэш
//            var cacheURL: URL? = nil
//            if let text = result.text, !text.isEmpty {
//                cacheURL = await saveCache(text: text, for: fileItem, extractionMethod: result.method)
//                
//                // Отправляем уведомление для обновления интерфейса только если был создан кэш
//                await MainActor.run {
//                    // Уведомление для обновления списка файлов
//                    NotificationCenter.default.post(
//                        name: Notification.Name("RefreshFiles"),
//                        object: nil
//                    )
//                }
//            } else {
//                print("❗ TextExtractionService: Текст не был извлечен или пустой, кэш-файл не создается")
//            }
//            
//            // Вызываем обработчик завершения
//            await MainActor.run {
//                completion(result, cacheURL)
//            }
//        }
//    }
    // Изменил метод, нужно вызывать через await
    public func extractAndCacheData(for fileItem: FileItem) async -> (ExtractionResult, URL?) {
        // Извлекаем текст
        let result = await extractTextAsync(from: fileItem.path)
        // Если текст успешно извлечен И не пустой, сохраняем в кэш
        var cacheURL: URL? = nil
        if let text = result.text, !text.isEmpty {
            cacheURL = await saveCache(text: text, for: fileItem, extractionMethod: result.method)
            
            // Отправляем уведомление для обновления интерфейса только если был создан кэш
            await MainActor.run {
                // Уведомление для обновления списка файлов
                NotificationCenter.default.post(
                    name: Notification.Name("RefreshFiles"),
                    object: nil
                )
            }
        } else {
            print("❗ TextExtractionService: Текст не был извлечен или пустой, кэш-файл не создается")
        }
        
        return (result, cacheURL)
    }
    
    
    
    /// Загружает извлеченные данные из кэш-файла
    /// - Parameter fileItem: Файл, для которого нужно загрузить данные
    /// - Returns: Извлеченные данные или nil в случае ошибки
    public func loadCachedData(for fileItem: FileItem) async -> ExtractedData? {
        guard !fileItem.isDirectory, fileItem.hasExtractedData else {
            return nil
        }
        
        // Определяем путь к кэш-файлу
        let hiddenFileName = "." + fileItem.name + ".json"
        let hiddenPath = fileItem.path.deletingLastPathComponent().appendingPathComponent(hiddenFileName)
        
        do {
            // Читаем и декодируем JSON
            let jsonData = try Data(contentsOf: hiddenPath)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let decodedData = try decoder.decode(ExtractedData.self, from: jsonData)
            return decodedData
        } catch {
            print("❌ TextExtractionService: Ошибка при чтении кэша для \(fileItem.name): \(error)")
            return nil
        }
    }
}
