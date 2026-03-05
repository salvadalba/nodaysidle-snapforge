import SwiftUI

enum DesignSystem {
    enum Colors {
        static let forgeOrange = Color(hex: 0xE8620A)
        static let systemBlack = Color(hex: 0x1C1C1E)
        static let sparkGold = Color(hex: 0xFF9F0A)
        static let appleLinen = Color(hex: 0xF5F5F7)
        static let warmGray = Color(hex: 0x86868B)
    }

    enum Typography {
        static func displayFont(size: CGFloat) -> Font {
            .system(size: size, weight: .semibold, design: .default)
        }

        static func bodyFont(size: CGFloat) -> Font {
            .system(size: size, weight: .regular, design: .default)
        }

        static func monoFont(size: CGFloat) -> Font {
            .system(size: size, weight: .medium, design: .monospaced)
        }

        static let largeTitle: Font = displayFont(size: 34)
        static let title: Font = displayFont(size: 28)
        static let title2: Font = displayFont(size: 22)
        static let headline: Font = displayFont(size: 17)
        static let body: Font = bodyFont(size: 15)
        static let callout: Font = bodyFont(size: 13)
        static let caption: Font = bodyFont(size: 11)
        static let code: Font = monoFont(size: 13)
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    enum Shadows {
        static let subtle = ShadowStyle(color: .black.opacity(0.08), radius: 2, x: 0, y: 1)
        static let medium = ShadowStyle(color: .black.opacity(0.12), radius: 8, x: 0, y: 2)
        static let elevated = ShadowStyle(color: .black.opacity(0.15), radius: 16, x: 0, y: 4)
    }
}

struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

extension Color {
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

extension View {
    func forgeOrangeAccent() -> some View {
        self.tint(DesignSystem.Colors.forgeOrange)
    }

    func forgeShadow(_ style: ShadowStyle) -> some View {
        self.shadow(color: style.color, radius: style.radius, x: style.x, y: style.y)
    }
}
