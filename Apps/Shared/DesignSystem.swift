import SwiftUI
import NorteKit

extension Color {
    /// Cria uma cor a partir de hex "RRGGBB" (sem "#").
    init(hex: String) {
        let value = UInt32(hex, radix: 16) ?? 0x8E8E93
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }

    /// Cor de fundo de pílula/bloco garantidamente legível com texto branco:
    /// escurece cores muito claras (pastéis) mantendo o matiz.
    init(pillHex hex: String) {
        let value = UInt32(hex, radix: 16) ?? 0x7C5CFF
        var r = Double((value >> 16) & 0xFF) / 255
        var g = Double((value >> 8) & 0xFF) / 255
        var b = Double(value & 0xFF) / 255
        let maxC = max(r, g, b, 0.001)
        if maxC > 0.7 {                 // clara demais → escurece p/ texto branco
            let scale = 0.7 / maxC
            r *= scale; g *= scale; b *= scale
        }
        self.init(red: r, green: g, blue: b)
    }
}

extension TaskContext {
    var color: Color { Color(hex: colorHex) }
}

extension Urgency {
    var color: Color {
        switch self {
        case .alta: return Color(hex: "FF453A")
        case .media: return Color(hex: "FFD60A")
        case .baixa: return Color(hex: "30D158")
        }
    }
}

extension String {
    /// Capitaliza apenas a primeira letra ("segunda-feira, 7 de setembro" →
    /// "Segunda-feira, 7 de setembro").
    var norteSentenceCased: String {
        guard let first = first else { return self }
        return first.uppercased() + dropFirst()
    }
}

enum Norte {
    /// Fundo base do app (tema escuro).
    static let background = Color(hex: "121216")
    static let cardBackground = Color.white.opacity(0.06)
    static let secondaryText = Color.white.opacity(0.55)
}
