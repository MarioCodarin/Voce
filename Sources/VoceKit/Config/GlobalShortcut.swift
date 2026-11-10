import Foundation

/// Global shortcuts offered in Settings. The numbers are Carbon key constants,
/// kept here so the UI can describe them without importing Carbon.
public enum GlobalShortcut: String, CaseIterable, Sendable, Codable {
    case optionCommandV = "opt-cmd-v"
    case controlOptionV = "ctrl-opt-v"
    case off = "off"

    /// `kVK_ANSI_V`: the only key offered today.
    public var keyCode: UInt32? {
        self == .off ? nil : 9
    }

    /// Carbon modifier masks (cmdKey, optionKey, controlKey).
    public var modifiers: UInt32? {
        switch self {
        case .optionCommandV: 256 | 2048
        case .controlOptionV: 4096 | 2048
        case .off: nil
        }
    }

    public var symbol: String {
        switch self {
        case .optionCommandV: "⌥⌘V"
        case .controlOptionV: "⌃⌥V"
        case .off: ""
        }
    }

    public func displayName(for interface: InterfaceLanguage) -> String {
        switch self {
        case .off:
            switch interface.resolved {
            case .italian: "Disattivata"
            case .spanish: "Desactivada"
            case .french: "Désactivée"
            case .german: "Deaktiviert"
            case .portuguese: "Desativada"
            default: "Off"
            }
        default:
            symbol
        }
    }

    public static func stored(_ raw: String?) -> GlobalShortcut {
        raw.flatMap(GlobalShortcut.init(rawValue:)) ?? .optionCommandV
    }
}
