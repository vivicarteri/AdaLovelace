//  CortinaLateral.swift
//  A cortina do FIM da vela (arte da Georgia: "Cortina_Horizontal"): dois panos que FECHAM dos
//  lados para o meio quando a vela acaba e REABREM para os lados quando a vela nova aparece.
//
//  A Georgia desenhou só o pano da esquerda; o da direita é o mesmo, espelhado.
//  Os panos ocupam a altura toda da tela (as franjas ficam embaixo) e, fechados, se encontram
//  no meio com uma pequena sobra (um passa um pouquinho por cima do outro), em qualquer tela.

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct CortinaLateralView: View {
    var fechada: Bool
    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento

    static let nome = "cortinaLateral"
    // ⚙️ Quanto um pano passa por cima do outro no meio, fechados (pontos)
    static let sobraNoMeio: CGFloat = 14
    // Na arte, a borda de dentro do pano é inclinada: em cima ela fica 5,5% da largura do pano
    // mais para dentro do que embaixo. Sem descontar isso, sobrava uma fresta escura no meio.
    static let inclinacaoDaBorda: CGFloat = 0.056

    // Largura ÷ altura do pano (lido da arte; se a Georgia trocar a imagem, acompanha)
    static let proporcao: CGFloat = {
        #if canImport(UIKit)
        if let t = UIImage(named: nome)?.size, t.height > 0 { return t.width / t.height }
        #endif
        return 0.7
    }()

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            // Cada pano cobre pelo menos metade da tela (mais a sobra). Numa tela estreita (iPhone)
            // o pano é mais largo que a metade e o pedaço de fora (com a corda) fica escondido.
            let largura = max(w / 2 + CortinaLateralView.sobraNoMeio, h * CortinaLateralView.proporcao)
            let meio = w / 2
            // Quanto cada pano passa do meio (a sobra + a parte inclinada da borda)
            let sobra = CortinaLateralView.sobraNoMeio + largura * CortinaLateralView.inclinacaoDaBorda
            // Aberta: cada pano anda só o necessário para sair da tela (a parte que já está fora
            // não conta). Assim o movimento que a pessoa vê dura a animação inteira, sem correr.
            let deslocamento = reduzirMovimento || fechada ? 0 : meio + sobra + 30

            ZStack {
                pano
                    .frame(width: largura, height: h, alignment: .bottomTrailing)
                    .clipped()
                    .position(x: meio + sobra - largura / 2 - deslocamento, y: h / 2)
                pano
                    .scaleEffect(x: -1, y: 1)
                    .frame(width: largura, height: h, alignment: .bottomLeading)
                    .clipped()
                    .position(x: meio - sobra + largura / 2 + deslocamento, y: h / 2)
            }
            .opacity(reduzirMovimento ? (fechada ? 1 : 0) : 1)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // O pano da arte: preenche a altura; se precisar ser mais largo que o desenho, cresce junto
    // (sem deformar) e corta o lado de fora.
    @ViewBuilder
    private var pano: some View {
        if arteExiste(CortinaLateralView.nome) {
            Image(CortinaLateralView.nome)
                .resizable()
                .scaledToFill()
        } else {
            Cores.cortina
        }
    }
}

#Preview("Cortina lateral") {
    @Previewable @State var fechada = true
    ZStack {
        Cores.fundoEscuro
        CortinaLateralView(fechada: fechada)
        Button(fechada ? "Abrir" : "Fechar") {
            withAnimation(.easeInOut(duration: 1.6)) { fechada.toggle() }
        }
        .buttonStyle(.borderedProminent)
    }
}
