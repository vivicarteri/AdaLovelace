//  CaixaTeatro.swift
//  A caixa do teatro vista de fora e a "câmera" que entra e sai dela.
//
//  A abertura da caixa tem o mesmo formato da tela. Dentro dela aparece o palco de verdade, em miniatura.
//  ZOOM OUT: a câmera sai do teatro → o palco vai ficando pequeno dentro da caixa → a cortina da caixa fecha.
//  ZOOM IN:  a cortina da caixa abre → a câmera entra até o palco ocupar a tela toda.

import SwiftUI
import Foundation

struct MedidasCaixa {
    let tela: CGSize                 // tamanho da área da tela onde tudo é desenhado

    // A ABERTURA tem o mesmo formato da tela: é o que faz o zoom encaixar certinho
    // quando a câmera chega nela.
    var abertura: CGSize {
        let largura = min(tela.width * 0.16, 70)
        return CGSize(width: largura, height: largura * tela.height / max(tela.width, 1))
    }

    // A MOLDURA em volta da abertura: colunas dos lados, telhado em cima e palco embaixo.
    // É ela que dá cara de caixa de teatro. Sem moldura, a caixa ficava com o formato
    // comprido e estreito da tela do iPhone e parecia uma cartinha em pé.
    var coluna: CGFloat { abertura.width * 0.55 }
    var telhado: CGFloat { abertura.width * 0.42 }
    var palco: CGFloat { abertura.width * 0.30 }

    var caixa: CGSize {
        CGSize(width: abertura.width + coluna * 2,
               height: abertura.height + telhado + palco)
    }

    // Onde a caixa inteira fica na tela (é por aqui que a vista é posicionada)
    var centro: CGPoint {
        CGPoint(x: tela.width / 2, y: tela.height - 18 - caixa.height / 2)
    }

    // O meio da ABERTURA — é para cá que a câmera vai, e é daqui que sai a luz
    var centroDaAbertura: CGPoint {
        CGPoint(x: centro.x, y: centro.y - caixa.height / 2 + telhado + abertura.height / 2)
    }

    // Quanto a câmera aproxima para a abertura virar a tela inteira
    var zoomFinal: CGFloat { tela.width / abertura.width }
}

// A câmera. z = 0: vista de fora normal. z = 1: colada na caixa (a abertura ocupa a tela).
// O zoom é exponencial, para a aproximação parecer uma câmera de verdade (e não acelerar no fim).
nonisolated struct EfeitoCamera: GeometryEffect {
    var z: CGFloat
    var zoomFinal: CGFloat
    var alvo: CGPoint        // centro da abertura da caixa
    var tela: CGSize

    var animatableData: CGFloat {
        get { z }
        set { z = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let escala = pow(zoomFinal, z)
        let quanto = zoomFinal > 1 ? (escala - 1) / (zoomFinal - 1) : 0   // 0 → 1, junto com o zoom
        let dx = (tela.width / 2 - alvo.x) * quanto
        let dy = (tela.height / 2 - alvo.y) * quanto
        // Aumenta em volta do centro da caixa e leva a caixa para o centro da tela
        let t = CGAffineTransform(translationX: alvo.x + dx, y: alvo.y + dy)
            .scaledBy(x: escala, y: escala)
            .translatedBy(x: -alvo.x, y: -alvo.y)
        return ProjectionTransform(t)
    }
}

// Cortina de duas folhas que abre para os lados. abertura: 0 = fechada, 1 = aberta.
struct CortinaCaixa: View {
    var abertura: CGFloat

    var body: some View {
        GeometryReader { geo in
            let metade = geo.size.width / 2 * (1 - abertura)
            HStack(spacing: 0) {
                FolhaDeCortina()
                    .frame(width: metade)
                Spacer(minLength: 0)
                FolhaDeCortina()
                    .frame(width: metade)
                    .scaleEffect(x: -1, y: 1)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct FolhaDeCortina: View {
    var body: some View {
        Arte("cortinaCaixa") {
            ZStack {
                Cores.cortina
                HStack(spacing: 0) {
                    ForEach(0..<3, id: \.self) { _ in
                        LinearGradient(colors: [.black.opacity(0.3), .clear, .black.opacity(0.3)],
                                       startPoint: .leading, endPoint: .trailing)
                    }
                }
            }
        }
    }
}

// A caixa vista de fora: teatrinho de papel com telhado de cortina, colunas listradas,
// palco embaixo e, no meio, a abertura com o palco de verdade em miniatura lá dentro.
struct CaixaTeatroView: View {
    var medidas: MedidasCaixa
    var acesa: Bool
    var aberturaCortina: CGFloat          // 0 = fechada, 1 = aberta
    var conteudo: AnyView? = nil          // o palco em miniatura

    var body: some View {
        let a = medidas.abertura
        let caixa = medidas.caixa
        let desvioAbertura = -caixa.height / 2 + medidas.telhado + a.height / 2

        ZStack {
            // Corpo da caixa (quando a arte da Georgia chegar, entra inteira aqui)
            Arte("caixaTeatro") {
                ZStack {
                    RoundedRectangle(cornerRadius: 5).fill(Cores.papel)
                    // Colunas listradas dos dois lados, como a frente de um teatrinho
                    HStack(spacing: a.width) {
                        ColunaListrada(largura: medidas.coluna)
                        ColunaListrada(largura: medidas.coluna)
                    }
                    RoundedRectangle(cornerRadius: 5).stroke(Cores.tinta, lineWidth: 2)
                }
            }
            .frame(width: caixa.width, height: caixa.height)

            // A abertura, logo abaixo do telhado
            ZStack {
                Cores.fundoEscuro
                if let conteudo {
                    // O palco é desenhado no tamanho da tela e encolhido até caber na abertura
                    conteudo
                        .frame(width: medidas.tela.width, height: medidas.tela.height)
                        .scaleEffect(a.width / max(medidas.tela.width, 1))
                        .frame(width: a.width, height: a.height)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                CortinaCaixa(abertura: aberturaCortina)
                // Luz da vela passando pela fresta da cortina fechada
                Rectangle()
                    .fill(Cores.dourado)
                    .frame(width: 3)
                    .blur(radius: 2)
                    .opacity(acesa && aberturaCortina < 0.05 ? 0.9 : 0)
            }
            .frame(width: a.width, height: a.height)
            .clipped()
            .overlay(Rectangle().stroke(Cores.tinta, lineWidth: 2.5))
            .offset(y: desvioAbertura)

            // Telhado: cortininha vermelha com franjas caindo por cima da abertura
            ZStack(alignment: .bottom) {
                Cores.cortina
                HStack(spacing: 0) {
                    ForEach(0..<6, id: \.self) { _ in
                        Circle()
                            .fill(Cores.cortina)
                            .overlay(Circle().stroke(Cores.tinta, lineWidth: 1))
                            .frame(width: caixa.width / 6, height: caixa.width / 6)
                    }
                }
                .offset(y: caixa.width / 12)
                Estrela()
                    .fill(Cores.dourado)
                    .overlay(Estrela().stroke(Cores.tinta, lineWidth: 1))
                    .frame(width: medidas.telhado * 0.5, height: medidas.telhado * 0.5)
                    .offset(y: -medidas.telhado * 0.35)
            }
            .frame(width: caixa.width, height: medidas.telhado, alignment: .bottom)
            .offset(y: -caixa.height / 2 + medidas.telhado / 2)

            // Palco embaixo, um pouquinho mais largo que a caixa
            ZStack {
                RoundedRectangle(cornerRadius: 3).fill(Cores.papel)
                RoundedRectangle(cornerRadius: 3).stroke(Cores.tinta, lineWidth: 2)
                HStack(spacing: medidas.palco * 0.7) {
                    ForEach(0..<3, id: \.self) { _ in
                        Estrela()
                            .stroke(Cores.tinta, lineWidth: 1)
                            .frame(width: medidas.palco * 0.42, height: medidas.palco * 0.42)
                    }
                }
            }
            .frame(width: caixa.width * 1.14, height: medidas.palco)
            .offset(y: caixa.height / 2 - medidas.palco / 2)
        }
        .frame(width: caixa.width * 1.14, height: caixa.height)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Cores.dourado)
                .blur(radius: 24)
                .opacity(acesa ? 0.8 : 0)
        )
    }
}

// Coluna da frente do teatrinho, com listras de circo
private struct ColunaListrada: View {
    var largura: CGFloat

    var body: some View {
        GeometryReader { geo in
            let n = 3
            HStack(spacing: 0) {
                ForEach(0..<n, id: \.self) { i in
                    (i.isMultiple(of: 2) ? Cores.papel : Cores.fundoClaro.opacity(0.55))
                        .frame(width: largura / CGFloat(n))
                }
            }
            .frame(height: geo.size.height)
        }
        .frame(width: largura)
        .opacity(0.9)
    }
}

// MARK: - Previews

// A caixa aparece 2,5x maior que no app, para dar para ver os detalhes.
// Dentro da abertura vai o palco em miniatura, como no app.
#Preview("CaixaTeatroView") {
    @Previewable @State var acesa = true
    @Previewable @State var cortina: CGFloat = 1
    GeometryReader { geo in
        let medidas = MedidasCaixa(tela: geo.size)
        ZStack {
            (acesa ? Cores.papel : Cores.fundoEscuro).ignoresSafeArea()
            CaixaTeatroView(medidas: medidas, acesa: acesa, aberturaCortina: cortina,
                            conteudo: AnyView(CenarioView(acesa: acesa, progresso: 0.3, mostrarPersonagens: true,
                                                          quadro: Quadro(tela: medidas.tela))))
                .scaleEffect(2.5)
            VStack {
                Toggle("Vela acesa", isOn: $acesa)
                Slider(value: $cortina, in: 0...1) { Text("Cortina") }
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .padding()
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }
}

// A caixa no tamanho e no lugar de verdade. O slider (ou o botão) faz a câmera entrar nela.
#Preview("EfeitoCamera") {
    @Previewable @State var z: CGFloat = 0
    GeometryReader { geo in
        let medidas = MedidasCaixa(tela: geo.size)
        ZStack {
            ZStack {
                Cores.papel
                CaixaTeatroView(medidas: medidas, acesa: true, aberturaCortina: 1,
                                conteudo: AnyView(CenarioView(acesa: true, progresso: 0.3, mostrarPersonagens: true,
                                                              quadro: Quadro(tela: medidas.tela))))
                    .position(medidas.centro)
            }
            .modifier(EfeitoCamera(z: z, zoomFinal: medidas.zoomFinal,
                                   alvo: medidas.centroDaAbertura, tela: geo.size))

            VStack {
                Slider(value: $z, in: 0...1) { Text("Zoom") }
                Button(z < 0.5 ? "Entrar na caixa" : "Sair da caixa") {
                    withAnimation(.easeInOut(duration: 1.6)) { z = z < 0.5 ? 1 : 0 }
                }
                .buttonStyle(.borderedProminent)
                .tint(Cores.tinta)
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .padding()
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }
}

#Preview("CortinaCaixa") {
    @Previewable @State var abertura: CGFloat = 0.5
    VStack(spacing: 30) {
        ZStack {
            Cores.fundoClaro
            CortinaCaixa(abertura: abertura)
        }
        .frame(width: 200, height: 320)
        .clipped()
        .overlay(Rectangle().stroke(Cores.tinta, lineWidth: 2.5))
        Slider(value: $abertura, in: 0...1) { Text("Abertura") }
    }
    .padding(30)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Cores.fundoEscuro)
}

#Preview("FolhaDeCortina", traits: .sizeThatFitsLayout) {
    FolhaDeCortina()
        .frame(width: 100, height: 240)
        .padding()
}

#Preview("ColunaListrada", traits: .sizeThatFitsLayout) {
    ColunaListrada(largura: 40)
        .frame(height: 200)
        .padding()
        .background(Cores.tinta)
}
