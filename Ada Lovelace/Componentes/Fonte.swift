//
//  Fonte.swift
//  Ada Lovelace
//

import SwiftUI

/// Papéis e tamanhos de texto do app. Ajuste a família e os estilos aqui.
struct ADAFont {
    static let familyName = "IM_FELL_English_Roman"

    enum Role {
        case screenTitle, sectionTitle, body, footnote, smallNote, caption, microCaption
        case tipTitle, tipMessage
        case iconButton, iconButtonProminent, iconButtonDetail, matchboxIcon, heroSymbol
    }

    static func font(for role: Role, containerSize: CGFloat? = nil) -> Font {
        let size: CGFloat
        let textStyle: Font.TextStyle
        let isSymbol: Bool

        switch role {
        case .screenTitle:
            size = 34; textStyle = .largeTitle; isSymbol = false
        case .sectionTitle:
            size = 22; textStyle = .title2; isSymbol = false
        case .body:
            size = 17; textStyle = .body; isSymbol = false
        case .footnote:
            size = 14; textStyle = .footnote; isSymbol = false
        case .smallNote:
            size = 13; textStyle = .footnote; isSymbol = false
        case .caption:
            size = 12; textStyle = .caption; isSymbol = false
        case .microCaption:
            size = 11; textStyle = .caption2; isSymbol = false
        case .tipTitle:
            size = 16; textStyle = .headline; isSymbol = false
        case .tipMessage:
            size = 13; textStyle = .footnote; isSymbol = false
        case .iconButton:
            size = (containerSize ?? 52) * 0.4; textStyle = .body; isSymbol = true
        case .iconButtonProminent:
            size = (containerSize ?? 52) * 0.5; textStyle = .body; isSymbol = true
        case .iconButtonDetail:
            size = (containerSize ?? 52) * 0.2; textStyle = .body; isSymbol = true
        case .matchboxIcon:
            size = (containerSize ?? 52) * 0.26; textStyle = .body; isSymbol = true
        case .heroSymbol:
            size = 140; textStyle = .largeTitle; isSymbol = true
        }

        if isSymbol { return .system(size: size) }
        return .custom(familyName, size: size, relativeTo: textStyle)
    }
}

private struct ADAFontStyleModifier: ViewModifier {
    let role: ADAFont.Role
    let containerSize: CGFloat?

    func body(content: Content) -> some View {
        content.font(ADAFont.font(for: role, containerSize: containerSize))
    }
}

extension View {
    func adaFont(_ role: ADAFont.Role, containerSize: CGFloat? = nil) -> some View {
        modifier(ADAFontStyleModifier(role: role, containerSize: containerSize))
    }
}

/// Sample for SwiftUI previews.
struct MinhaOutraView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Título da Tela").adaFont(.screenTitle)
            Text("Este é o corpo do texto que se adapta automaticamente à fonte do app.")
                .adaFont(.body)
        }
    }
}
