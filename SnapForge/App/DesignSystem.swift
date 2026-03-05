import SwiftUI

// MARK: - DesignSystem
//
// Ultrathin liquid glassmorphism design language.
// Relies on SwiftUI Material system for translucent blurs
// and system-adaptive colors for native macOS feel.

enum DesignSystem {

    // MARK: - Colors

    enum Colors {
        // Brand accents
        static let forgeOrange = Color(hex: 0xE8620A)
        static let sparkGold = Color(hex: 0xFF9F0A)

        // Adaptive surface colors (work in light + dark mode)
        static let surfacePrimary = Color.primary.opacity(0.04)
        static let surfaceSecondary = Color.primary.opacity(0.06)
        static let surfaceHover = Color.primary.opacity(0.08)
        static let surfaceSelected = Color(hex: 0xE8620A).opacity(0.10)

        // Glass tints
        static let glassTint = Color.white.opacity(0.03)
        static let glassBorder = Color.white.opacity(0.12)
        static let glassBorderSubtle = Color.white.opacity(0.06)

        // Semantic
        static let destructive = Color.red
        static let success = Color.green
        static let warmGray = Color(hex: 0x86868B)

        // Legacy (kept for backward compat, prefer surfaces above)
        static let systemBlack = Color(hex: 0x1C1C1E)
        static let appleLinen = Color(hex: 0xF5F5F7)
    }

    // MARK: - Materials

    enum Materials {
        /// Menu bar panel, floating overlays
        static let ultraThin = Material.ultraThinMaterial
        /// Primary window backgrounds
        static let thin = Material.thinMaterial
        /// Sidebars, secondary panels
        static let regular = Material.regularMaterial
        /// Cards, elevated surfaces
        static let thick = Material.thickMaterial
    }

    // MARK: - Typography

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
        static let title3: Font = displayFont(size: 18)
        static let headline: Font = displayFont(size: 15)
        static let body: Font = bodyFont(size: 13)
        static let callout: Font = bodyFont(size: 12)
        static let caption: Font = bodyFont(size: 11)
        static let caption2: Font = bodyFont(size: 10)
        static let code: Font = monoFont(size: 12)
    }

    // MARK: - Spacing

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    // MARK: - Corner Radii

    enum Radii {
        static let sm: CGFloat = 6
        static let md: CGFloat = 10
        static let lg: CGFloat = 14
        static let xl: CGFloat = 20
    }

    // MARK: - Shadows

    enum Shadows {
        static let subtle = ShadowStyle(color: .black.opacity(0.06), radius: 2, x: 0, y: 1)
        static let medium = ShadowStyle(color: .black.opacity(0.10), radius: 6, x: 0, y: 2)
        static let elevated = ShadowStyle(color: .black.opacity(0.14), radius: 16, x: 0, y: 4)
        static let glow = ShadowStyle(color: Color(hex: 0xE8620A).opacity(0.25), radius: 12, x: 0, y: 0)
    }
}

// MARK: - ShadowStyle

struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - Color Extension

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

// MARK: - View Extensions

extension View {
    func forgeOrangeAccent() -> some View {
        self.tint(DesignSystem.Colors.forgeOrange)
    }

    func forgeShadow(_ style: ShadowStyle) -> some View {
        self.shadow(color: style.color, radius: style.radius, x: style.x, y: style.y)
    }

    /// Glass card surface with subtle border and shadow
    func glassCard(cornerRadius: CGFloat = DesignSystem.Radii.md) -> some View {
        self
            .background(DesignSystem.Materials.thick, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(DesignSystem.Colors.glassBorderSubtle, lineWidth: 0.5)
            )
            .forgeShadow(DesignSystem.Shadows.subtle)
    }

    /// Glass panel with ultra-thin material for floating elements
    func glassPanel(cornerRadius: CGFloat = DesignSystem.Radii.lg) -> some View {
        self
            .background(DesignSystem.Materials.ultraThin, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(DesignSystem.Colors.glassBorder, lineWidth: 0.5)
            )
            .forgeShadow(DesignSystem.Shadows.elevated)
    }
}
