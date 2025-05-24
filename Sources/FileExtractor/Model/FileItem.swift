import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct FileItem: Identifiable, Hashable, Transferable {
    var id = UUID()
    var name: String
    var path: URL
    var isDirectory: Bool
    var size: Int64
    var modificationDate: Date
    var children: [FileItem]?
    var hasMetadata: Bool = false
    var hasExtractedData: Bool = false
    
    // Свойство для определения, является ли файл/папка скрытым
    var isHidden: Bool {
        return name.starts(with: ".")
    }
    
    // Поддержка протокола Transferable для перетаскивания
    static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation { item in
            item.path
        }
    }
    
    var icon: String {
        if isDirectory {
            return "folder"
        } else {
            switch path.pathExtension.lowercased() {
            case "pdf":
                return "doc.text"
            case "jpg", "jpeg", "png", "gif":
                return "photo"
            case "mp3", "wav", "aac":
                return "music.note"
            case "mp4", "mov", "avi":
                return "film"
            case "swift", "java", "py", "js", "html", "css":
                return "doc.plaintext"
            default:
                return "doc"
            }
        }
    }
    
    var formattedSize: String {
        if isDirectory {
            return "--"
        }
        
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: modificationDate)
    }
    
    // Вычисляемое свойство для сортировки по размеру
    var sizeForSorting: Int64 {
        // Для директорий возвращаем -1, чтобы они всегда были в начале при сортировке по возрастанию
        // и в конце при сортировке по убыванию
        return isDirectory ? -1 : size
    }
    
    var tagColor: Color? {
        do {
            let values = try path.resourceValues(forKeys: [.labelNumberKey])
            if let labelNumber = values.labelNumber, labelNumber > 0 && labelNumber < NSWorkspace.shared.fileLabelColors.count {
                let nsColor = NSWorkspace.shared.fileLabelColors[labelNumber]
                return Color(nsColor: nsColor)
            }
        } catch {
            print("Ошибка получения номера тега для \(path.path): \(error)")
        }
        return nil // Нет тега или ошибка
    }
    
    static func == (lhs: FileItem, rhs: FileItem) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
} 
