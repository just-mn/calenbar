import AppKit
import SwiftUI

/// Color scheme for a category of alerts (upcoming events or overdue reminders).
struct AlertColorProfile: Equatable {
    enum Preset: String, CaseIterable {
        case orange, red, blue, green, pink, custom

        var displayName: String {
            switch self {
            case .orange: return Str.colorOrange
            case .red:    return Str.colorRed
            case .blue:   return Str.colorBlue
            case .green:  return Str.colorGreen
            case .pink:   return Str.colorPink
            case .custom: return Str.colorCustom
            }
        }

        /// Base color for presets (used as both text and bg when not custom).
        var baseColor: NSColor {
            switch self {
            case .orange: return NSColor(red: 1.00, green: 0.50, blue: 0.00, alpha: 1)
            case .red:    return NSColor(red: 1.00, green: 0.22, blue: 0.18, alpha: 1)
            case .blue:   return NSColor(red: 0.20, green: 0.50, blue: 1.00, alpha: 1)
            case .green:  return NSColor(red: 0.15, green: 0.78, blue: 0.30, alpha: 1)
            case .pink:   return NSColor(red: 1.00, green: 0.18, blue: 0.60, alpha: 1)
            case .custom: return .labelColor
            }
        }
    }

    var preset: Preset = .orange

    // Custom-only color values
    var customTextR: Double = 1.0
    var customTextG: Double = 0.5
    var customTextB: Double = 0.0
    var customBgR: Double   = 1.0
    var customBgG: Double   = 0.5
    var customBgB: Double   = 0.0

    var textNSColor: NSColor {
        guard preset == .custom else { return preset.baseColor }
        return NSColor(red: customTextR, green: customTextG, blue: customTextB, alpha: 1)
    }

    var bgNSColor: NSColor {
        guard preset == .custom else { return preset.baseColor }
        return NSColor(red: customBgR, green: customBgG, blue: customBgB, alpha: 1)
    }

    var textSwiftUIColor: Color { Color(nsColor: textNSColor) }
    var bgSwiftUIColor:   Color { Color(nsColor: bgNSColor) }
}
