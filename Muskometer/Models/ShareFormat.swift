import Foundation

enum ShareFormat: String, CaseIterable, Identifiable, Sendable {
    case image
    case text

    var id: String { rawValue }

    var label: String {
        switch self {
        case .image:
            return "Image card"
        case .text:
            return "Text summary"
        }
    }

    var buttonTitle: String {
        switch self {
        case .image:
            return "Copy Image"
        case .text:
            return "Copy Text"
        }
    }

    var buttonIcon: String {
        switch self {
        case .image:
            return "photo.on.rectangle"
        case .text:
            return "doc.on.doc"
        }
    }

    var helpText: String {
        switch self {
        case .image:
            return "Copy a shareable image card to the clipboard"
        case .text:
            return "Copy a text summary to the clipboard"
        }
    }
}