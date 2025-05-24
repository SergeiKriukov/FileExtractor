import Foundation

/// Структура для хранения извлеченных данных файла и метаданных, используемых для кэширования.
struct ExtractedData: Codable {
    
    /// Извлеченный текст из файла.
    let extractedText: String
    
    /// Дата и время извлечения данных и создания/обновления кэш-файла.
    let extractionDate: Date
    
    /// Дата модификации оригинального файла на момент извлечения данных.
    /// Используется для проверки актуальности кэша.
    let originalFileModificationDate: Date
    
    /// (Опционально) Путь к оригинальному файлу, из которого были извлечены данные.
    let originalFilePath: String?
    
    /// (Опционально) Метод, использованный для извлечения данных (например, "OCR", "PDFParse").
    let extractionMethod: String?
    
    /// Инициализатор для создания экземпляра ExtractedData.
    /// - Parameters:
    ///   - extractedText: Извлеченный текст.
    ///   - originalFileModificationDate: Дата модификации оригинального файла.
    ///   - originalFilePath: Путь к оригинальному файлу (опционально).
    ///   - extractionMethod: Метод извлечения (опционально).
    init(extractedText: String, originalFileModificationDate: Date, originalFilePath: String? = nil, extractionMethod: String? = nil) {
        self.extractedText = extractedText
        self.extractionDate = Date() // Текущая дата и время
        self.originalFileModificationDate = originalFileModificationDate
        self.originalFilePath = originalFilePath
        self.extractionMethod = extractionMethod
    }
    
    // MARK: - Codable Conformance
    
    // Можно добавить кастомную логику кодирования/декодирования при необходимости,
    // но стандартная реализация Codable должна подойти для этих типов.
} 