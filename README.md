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
```

## Лицензия

[Укажите используемую лицензию]

## Авторы

[Ваше имя/организация]
