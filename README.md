# FileExtractor

Библиотека Swift для извлечения и обработки текста из файлов различных форматов. 

## Описание

FileExtractor - это Swift-библиотека для извлечения текстового содержимого из различных типов файлов. Библиотека поддерживает работу с PDF, изображениями, текстовыми файлами, RTF-документами и другими форматами. Основная цель - предоставить простой и унифицированный интерфейс для извлечения текста независимо от исходного формата файла.

## Особенности

- 📄 Извлечение текста из различных форматов файлов:
  - PDF-документы (с текстовым слоем или через OCR)
  - Изображения (JPG, PNG, TIFF, GIF и др.)
  - Текстовые файлы (TXT, MD, Swift, JS, HTML и др.)
  - RTF-документы
  - Word-документы (DOC, DOCX)
  
- 🔍 Интеграция с OCR через Mistral API для распознавания текста на изображениях и сканах
- 📋 Структурированное представление извлеченных данных
- 🗄️ Управление файлами и поддержка метаданных
- 📂 Работа с файловой системой

## Подробное описание функциональности

### Методы извлечения текста

FileExtractor поддерживает различные методы извлечения текста в зависимости от формата файла:

#### Текстовые файлы
- Прямое чтение для форматов: TXT, MD, Swift, PY, JS, HTML, CSS, JSON
- Метод: `processPlainText`
- Кодировка: UTF-8

#### PDF-документы
- Извлечение текстового слоя через PDFKit
- Распознавание текста через OCR при отсутствии текстового слоя
- Методы: `processPDF` и `processWithOCR`
- Поддержка многостраничных документов

#### RTF-документы
- Извлечение через NSAttributedString
- Метод: `processRTF`
- Сохранение структуры текста

#### Word-документы (DOC, DOCX)
- Извлечение через системные методы обработки
- Метод: `processDOCX`

#### Изображения
- Поддержка форматов: JPG, JPEG, PNG, TIFF, TIF, GIF, BMP, HEIC
- OCR через интеграцию с Mistral API
- Метод: `processImage`

### OCR-функциональность

Библиотека интегрирована с Mistral API для OCR-распознавания текста на изображениях и в PDF без текстового слоя:

- Автоматическое применение OCR (настраивается)
- Загрузка файлов на сервер Mistral API
- Обработка результатов распознавания
- Возможность отмены текущей OCR-обработки
- Ограничение по размеру файла: до 50 МБ

### Настройки OCR-обработки

```swift
// Доступные настройки для обработки результатов OCR
struct OCRProcessingOptions {
    // Обработка ссылок на изображения: удаление, замена на заполнитель или сохранение
    enum ImageLinkHandling {
        case remove
        case replaceWithPlaceholder
        case keep
    }
    
    var handleImageLinks: ImageLinkHandling = .keep
    var imagePlaceholder: String = "[изображение]"
    var removeEmptyLines: Bool = true
    var trimWhitespace: Bool = true
}
```

### Управление файлами

Библиотека предоставляет структуру `FileItem` для работы с файлами:

- Информация о файле (имя, путь, размер, дата изменения)
- Определение типа файла и соответствующей иконки
- Форматирование размера файла и даты
- Поддержка тегов цвета файлов macOS
- Поддержка перетаскивания (Transferable)

### Хранение извлеченных данных

Структура `ExtractedData` для кэширования и хранения извлеченных данных:

- Извлеченный текст
- Дата извлечения
- Дата модификации оригинального файла
- Путь к оригинальному файлу
- Метод извлечения

## Требования

- macOS 15.0+ или iOS 15.0+
- Swift 6.1+

## Установка

### Swift Package Manager

Добавьте FileExtractor в зависимости вашего проекта в Package.swift:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/FileExtractor.git", from: "1.0.0")
]
```

## Использование

### Извлечение текста из файла

```swift
import FileExtractor

// Асинхронное извлечение текста из файла
Task {
    let fileURL = URL(fileURLWithPath: "/path/to/file.pdf")
    let result = await TextExtractionService.shared.extractTextAsync(from: fileURL)
    
    if result.isSuccess, let text = result.text {
        print("Успешно извлечен текст с помощью метода: \(result.method)")
        print("Содержимое: \(text)")
    } else if let error = result.error {
        print("Ошибка при извлечении текста: \(error.localizedDescription)")
    }
}
```

### Использование OCR для изображений или сканов PDF

```swift
import FileExtractor

// Настройка автоматического применения OCR
TextExtractionService.shared.settings.autoApplyOCR = true

// Извлечение текста из изображения или скана PDF
Task {
    let fileURL = URL(fileURLWithPath: "/path/to/scan.jpg")
    let result = await TextExtractionService.shared.extractTextAsync(from: fileURL)
    
    if result.isSuccess, let text = result.text {
        print("Текст успешно извлечен с помощью OCR")
        print("Содержимое: \(text)")
    }
}
```

### Настройка параметров OCR через Mistral API

```swift
import FileExtractor

// Настройка API-ключа через UserDefaults
UserDefaults.standard.set("ваш_api_ключ", forKey: "mistral_api_key")

// Настройка параметров обработки OCR
let options = OCRProcessingOptions()
options.handleImageLinks = .replaceWithPlaceholder
options.imagePlaceholder = "[ИЗОБРАЖЕНИЕ]"
options.removeEmptyLines = true
options.trimWhitespace = true

// Использование OCR с настройками
Task {
    if let extractedText = await MistralAPIManager.shared.extractTextUsingMistralOCR(
        filePath: "/path/to/image.jpg", 
        processingOptions: options
    ) {
        print("Извлеченный текст: \(extractedText)")
    }
}

// Отмена текущей OCR-обработки
MistralAPIManager.shared.cancelProcessing()
```

### Работа с файловой системой

```swift
import FileExtractor

// Создание FileItem для работы с файлом
let fileItem = FileItem(
    name: "document.pdf",
    path: URL(fileURLWithPath: "/path/to/document.pdf"),
    isDirectory: false,
    size: 1024,
    modificationDate: Date(),
    children: nil
)

// Получение информации о файле
print("Имя файла: \(fileItem.name)")
print("Размер: \(fileItem.formattedSize)")
print("Дата изменения: \(fileItem.formattedDate)")
print("Тип иконки: \(fileItem.icon)")

// Проверка наличия тега цвета
if let tagColor = fileItem.tagColor {
    print("Файл имеет цветовой тег")
}
```

### Работа с извлеченными данными

```swift
import FileExtractor

// Создание объекта с извлеченными данными
let extractedData = ExtractedData(
    extractedText: "Текст, извлеченный из файла",
    originalFileModificationDate: Date(),
    originalFilePath: "/path/to/file.pdf",
    extractionMethod: "PDFKit"
)

// Сохранение данных в JSON для кэширования
let encoder = JSONEncoder()
if let jsonData = try? encoder.encode(extractedData) {
    try? jsonData.write(to: URL(fileURLWithPath: "/path/to/cache.json"))
}

// Загрузка кэшированных данных
if let cachedData = try? Data(contentsOf: URL(fileURLWithPath: "/path/to/cache.json")) {
    let decoder = JSONDecoder()
    if let extractedData = try? decoder.decode(ExtractedData.self, from: cachedData) {
        print("Извлеченный текст из кэша: \(extractedData.extractedText)")
        print("Дата извлечения: \(extractedData.extractionDate)")
    }
}
```

## Лицензия

MIT License

Copyright (c) 2025 ООО Лаборатория юридических исследований

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

## Авторы

(с) 2025 ООО Лаборатория юридических исследований
