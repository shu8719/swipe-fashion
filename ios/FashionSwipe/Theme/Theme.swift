import SwiftUI
import UIKit

/// Material 3 ベースのデザイントークン（Figma「Swipe Fashion テーマ」準拠）。
/// 画面では色・角丸・余白・文字を直書きせず、ここから参照する。
enum Theme {

    // MARK: - Color（Light / Dark）

    enum Colors {
        static let primary              = Color(light: 0x00658E, dark: 0x85CFFF)
        static let onPrimary            = Color(light: 0xFFFFFF, dark: 0x00344C)
        static let primaryContainer     = Color(light: 0xC7E7FF, dark: 0x004C6C)
        static let onPrimaryContainer   = Color(light: 0x001E2E, dark: 0xC7E7FF)

        static let secondary            = Color(light: 0x4E616D, dark: 0xB5C9D8)
        static let secondaryContainer   = Color(light: 0xD1E5F4, dark: 0x374955)
        static let onSecondaryContainer = Color(light: 0x0A1E28, dark: 0xD1E5F4)

        static let tertiary             = Color(light: 0x006C48, dark: 0x6EDBA8)
        static let onTertiary           = Color(light: 0xFFFFFF, dark: 0x003824)
        static let tertiaryContainer    = Color(light: 0x8CF8C2, dark: 0x005236)
        static let onTertiaryContainer  = Color(light: 0x002113, dark: 0x8CF8C2)

        static let error                = Color(light: 0xBA1A1A, dark: 0xFFB4AB)
        static let onError              = Color(light: 0xFFFFFF, dark: 0x690005)
        static let errorContainer       = Color(light: 0xFFDAD6, dark: 0x93000A)
        static let onErrorContainer     = Color(light: 0x410002, dark: 0xFFDAD6)

        static let surface              = Color(light: 0xF7F9FE, dark: 0x101418)
        static let onSurface            = Color(light: 0x181C20, dark: 0xDFE3E8)
        static let onSurfaceVariant     = Color(light: 0x41484D, dark: 0xC1C7CE)

        static let surfaceContainerLowest  = Color(light: 0xFFFFFF, dark: 0x0B0F12)
        static let surfaceContainerLow     = Color(light: 0xF1F4F9, dark: 0x181C20)
        static let surfaceContainer        = Color(light: 0xEBEEF3, dark: 0x1C2024)
        static let surfaceContainerHigh    = Color(light: 0xE5E8ED, dark: 0x262A2E)
        static let surfaceContainerHighest = Color(light: 0xDFE3E8, dark: 0x313539)

        static let outline              = Color(light: 0x71787E, dark: 0x8B9198)
        static let outlineVariant       = Color(light: 0xC1C7CE, dark: 0x41484D)

        static let scrim                = Color.black.opacity(0.32)

        /// ロゴのグラデーション（Sky → Mint）
        static let brandGradient = LinearGradient(
            colors: [Color(light: 0x72C5F3, dark: 0x72C5F3), Color(light: 0x87DFA2, dark: 0x87DFA2)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )

        // 役割：LIKE は Tertiary（緑）、SKIP と削除は Error（赤）
        static let like             = tertiary
        static let likeContainer    = tertiaryContainer
        static let onLikeContainer  = onTertiaryContainer
        static let skip             = error
    }

    // MARK: - Shape

    enum Radius {
        static let extraSmall: CGFloat = 4
        static let small: CGFloat      = 8    // チップ
        static let medium: CGFloat     = 12   // 商品カード
        static let large: CGFloat      = 16   // 大きめのカード・ボタン
        static let extraLarge: CGFloat = 28   // スワイプカード・シート・ダイアログ
    }

    // MARK: - Spacing（4pt 刻み）

    enum Spacing {
        static let s4: CGFloat  = 4
        static let s8: CGFloat  = 8
        static let s12: CGFloat = 12
        static let s16: CGFloat = 16
        static let s20: CGFloat = 20
        static let s24: CGFloat = 24
        static let s32: CGFloat = 32
    }

    // MARK: - Typography（M3 タイプスケール。日本語はシステムフォント＝ヒラギノ）

    struct TypeStyle {
        let size: CGFloat
        let lineHeight: CGFloat
        let weight: Font.Weight
        var design: Font.Design = .default

        var font: Font { .system(size: size, weight: weight, design: design) }

        /// SwiftUI は行の高さを直接指定できないので、フォント本来の行の高さとの差を行間で足す
        var lineSpacing: CGFloat {
            max(0, lineHeight - UIFont.systemFont(ofSize: size).lineHeight)
        }
    }

    enum Typography {
        static let headlineMedium = TypeStyle(size: 28, lineHeight: 36, weight: .bold)
        static let headlineSmall  = TypeStyle(size: 24, lineHeight: 32, weight: .bold)
        static let titleLarge     = TypeStyle(size: 22, lineHeight: 28, weight: .bold)
        static let titleMedium    = TypeStyle(size: 16, lineHeight: 24, weight: .semibold)
        static let titleSmall     = TypeStyle(size: 14, lineHeight: 20, weight: .semibold)
        static let bodyLarge      = TypeStyle(size: 16, lineHeight: 24, weight: .regular)
        static let bodyMedium     = TypeStyle(size: 14, lineHeight: 20, weight: .regular)
        static let bodySmall      = TypeStyle(size: 12, lineHeight: 16, weight: .regular)
        static let labelLarge     = TypeStyle(size: 14, lineHeight: 20, weight: .semibold)
        static let labelMedium    = TypeStyle(size: 12, lineHeight: 16, weight: .semibold)
        static let labelSmall     = TypeStyle(size: 11, lineHeight: 16, weight: .semibold)
        static let logo           = TypeStyle(size: 22, lineHeight: 28, weight: .bold, design: .rounded)
    }

    // MARK: - Elevation（M3 Elevation 1〜3 に近い、弱い2段の影）

    enum Elevation: Int {
        case level1 = 1, level2, level3

        var keyShadow: (y: CGFloat, radius: CGFloat) {
            switch self {
            case .level1: return (1, 1)
            case .level2: return (1, 1)
            case .level3: return (1, 1.5)
            }
        }

        var ambientShadow: (y: CGFloat, radius: CGFloat) {
            switch self {
            case .level1: return (1, 2)
            case .level2: return (2, 4)
            case .level3: return (4, 5.5)
            }
        }
    }
}

// MARK: - Modifiers

extension View {
    func typography(_ style: Theme.TypeStyle) -> some View {
        font(style.font).lineSpacing(style.lineSpacing)
    }

    func elevation(_ level: Theme.Elevation) -> some View {
        shadow(color: .black.opacity(0.3), radius: level.keyShadow.radius, x: 0, y: level.keyShadow.y)
            .shadow(color: .black.opacity(0.15), radius: level.ambientShadow.radius, x: 0, y: level.ambientShadow.y)
    }
}

extension Color {
    /// ライト／ダークで切り替わる色を 0xRRGGBB で作る
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(rgb: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

private extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(red:   CGFloat((rgb >> 16) & 0xFF) / 255,
                  green: CGFloat((rgb >> 8) & 0xFF) / 255,
                  blue:  CGFloat(rgb & 0xFF) / 255,
                  alpha: 1)
    }
}
