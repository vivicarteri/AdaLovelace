//  Arte.swift
//  Cores do app e o "lugar da arte" da Georgia.
//
//  COMO TROCAR UM DESENHO:
//  Arrastem o PNG (fundo transparente) para o Assets.xcassets com o nome indicado
//  em cada lugar do código (ex.: "lua", "sol", "personagem1", "caixaFosforo").
//  Se a imagem existir, o app usa ela. Se não existir, desenha a forma provisória.

import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

enum Cores {
    static let papel = Color(red: 0.93, green: 0.87, blue: 0.74)
    static let tinta = Color(red: 0.13, green: 0.11, blue: 0.09)
    static let fundoEscuro = Color(red: 0.13, green: 0.12, blue: 0.10)
    static let fundoClaro = Color(red: 0.60, green: 0.53, blue: 0.40)
    static let cortina = Color(red: 0.42, green: 0.11, blue: 0.11)
    static let dourado = Color(red: 0.98, green: 0.82, blue: 0.40)
    static let cera = Color(red: 0.96, green: 0.91, blue: 0.80)
    static let madeira = Color(red: 0.36, green: 0.25, blue: 0.17)
}

func arteExiste(_ nome: String) -> Bool {
    #if canImport(UIKit)
    return UIImage(named: nome) != nil
    #elseif canImport(AppKit)
    return NSImage(named: nome) != nil
    #else
    return false
    #endif
}

// Usa a imagem do Assets se ela existir. Se não, mostra a forma provisória.
struct Arte<Provisorio: View>: View {
    let nome: String
    let provisorio: () -> Provisorio

    init(_ nome: String, @ViewBuilder provisorio: @escaping () -> Provisorio) {
        self.nome = nome
        self.provisorio = provisorio
    }

    var body: some View {
        if arteExiste(nome) {
            Image(nome).resizable().scaledToFit()
        } else {
            provisorio()
        }
    }
}

// MARK: - Previews

#Preview("Cores", traits: .sizeThatFitsLayout) {
    let cores: [(nome: String, cor: Color)] = [
        ("papel", Cores.papel), ("tinta", Cores.tinta),
        ("fundoEscuro", Cores.fundoEscuro), ("fundoClaro", Cores.fundoClaro),
        ("cortina", Cores.cortina), ("dourado", Cores.dourado),
        ("cera", Cores.cera), ("madeira", Cores.madeira),
    ]
    LazyVGrid(columns: Array(repeating: GridItem(.fixed(90)), count: 4), spacing: 16) {
        ForEach(cores, id: \.nome) { item in
            VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(item.cor)
                    .frame(height: 60)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(.gray, lineWidth: 1))
                Text(item.nome).font(.caption)
            }
        }
    }
    .padding()
}

// Com a imagem no Assets ela aparece; sem a imagem, aparece a forma provisória.
#Preview("Arte: com e sem imagem", traits: .sizeThatFitsLayout) {
    HStack(spacing: 24) {
        VStack {
            Arte("lua") { Circle().fill(Cores.cortina) }
                .frame(width: 120, height: 120)
            Text("\"lua\" está no Assets")
        }
        VStack {
            Arte("naoExiste") { Circle().fill(Cores.cortina) }
                .frame(width: 120, height: 120)
            Text("sem imagem → provisório")
        }
    }
    .font(.caption)
    .foregroundStyle(Cores.papel)
    .padding()
    .background(Cores.fundoEscuro)
}
