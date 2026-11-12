//  TeatroSombrasView.swift
//  Fora da caixa (zoom out): a luz da vela projeta as sombras do circo na parede.
//  Para voltar: botão no canto superior esquerdo, tocar na caixa ou fazer pinça para dentro.

import SwiftUI
import TipKit

struct TeatroSombrasView: View {
    @EnvironmentObject private var sessao: Sessao
    var entrar: () -> Void
    var abrirConfiguracoes: () -> Void
    var aberturaCaixa: CGFloat = 0        // cortina da caixa: 0 = fechada (normal), 1 = aberta (só na animação)
    var conteudoDaCaixa: AnyView? = nil   // palco em miniatura (só na animação de entrar e sair)
    var mostrarBotoes = true              // os botões saem de cena durante o zoom
    var congelado = false                 // durante o zoom as sombras param, para o movimento ficar liso

    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento

    var body: some View {
        let acesa = sessao.estado == .acesa

        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let caixa = MedidasCaixa(tela: geo.size)
            ZStack {
                // Parede: clara com a vela acesa, escura com ela apagada
                (acesa ? Cores.papel : Cores.fundoEscuro)
                    .ignoresSafeArea()

                if acesa {
                    // Luz saindo da caixa
                    RadialGradient(colors: [Cores.dourado.opacity(0.75), .clear],
                                   center: UnitPoint(x: 0.5, y: caixa.centroDaAbertura.y / max(h, 1)),
                                   startRadius: 10, endRadius: h * 0.7)
                        .ignoresSafeArea()

                    // Sombras: as mesmas figuras do circo, pretas, maiores e borradas.
                    // A tela fica parada: só cada sombra tremula sozinha, por causa da chama.
                    Group {
                        if arteExiste("tendasombra") {
                            // Sombras desenhadas pela Georgia
                            CenaArte(quadro: Quadro(geo: geo), mostrarPersonagens: true,
                                     sombra: true, congelado: congelado)
                        } else {
                            // Sem arte: as figuras provisórias pintadas de preto
                            CenarioView(acesa: true, progresso: sessao.progresso, mostrarPersonagens: true, comFundo: false)
                                .colorMultiply(.black)
                        }
                    }
                    .opacity(0.7)
                    .blur(radius: 2.5)
                    .scaleEffect(1.15, anchor: .bottom)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }

                // Bambinela (cortina de cima) e letreiro
                VStack(spacing: 0) {
                    Arte("bambinela") { Bambinela() }
                        .frame(height: h * 0.14)
                    Spacer()
                }
                .ignoresSafeArea(edges: .top)
                .accessibilityHidden(true)

                Arte("letreiro") {
                    Text("Shadow Theater")
                        .font(.system(size: 22, weight: .bold, design: .serif).italic())
                        .foregroundStyle(Cores.tinta)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Cores.papel))
                        .overlay(Capsule().stroke(Cores.tinta, lineWidth: 2))
                }
                .frame(width: min(w * 0.55, 240), height: 60)
                .position(x: w / 2, y: h * 0.06)
                .accessibilityHidden(true)

                // A caixa do teatro, lá embaixo. Tocar nela entra de novo (a câmera vai até ela).
                Button(action: entrar) {
                    CaixaTeatroView(medidas: caixa, acesa: acesa,
                                    aberturaCortina: aberturaCaixa, conteudo: conteudoDaCaixa)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Entrar na caixa")
                .position(caixa.centro)

                // Em cima: voltar para dentro (esquerda) e configurações (direita)
                VStack {
                    HStack {
                        BotaoRedondo(icone: "arrow.up.left.and.arrow.down.right", rotulo: "Entrar na caixa",
                                     tamanho: 44, acao: entrar)
                            .popoverTip(DicaEntrarNaCaixa(), arrowEdge: .top)
                        Spacer()
                        BotaoRedondo(icone: "gearshape", rotulo: "Configurações", tamanho: 44, acao: abrirConfiguracoes)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .opacity(mostrarBotoes ? 1 : 0)   // no zoom eles somem: senão cresceriam junto
            }
            .contentShape(Rectangle())
            .gesture(
                MagnifyGesture().onEnded { valor in
                    if valor.magnification > 1.3 {
                        DicaEntrarNaCaixa().invalidate(reason: .actionPerformed)   // já aprendeu a pinça
                        entrar()
                    }
                }
            )
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(acesa ? "Teatro de sombras. As sombras do circo aparecem na parede"
                                  : "Teatro de sombras, no escuro. A vela está apagada")
    }
}

// Cortina de cima com franjas arredondadas
private struct Bambinela: View {
    var body: some View {
        GeometryReader { geo in
            let n = 9
            let largura = geo.size.width / CGFloat(n)
            ZStack(alignment: .bottom) {
                Cores.cortina
                HStack(spacing: 0) {
                    ForEach(0..<n, id: \.self) { _ in
                        Circle()
                            .fill(Cores.cortina)
                            .overlay(Circle().stroke(Cores.tinta, lineWidth: 1.5))
                            .frame(width: largura, height: largura)
                    }
                }
                .offset(y: largura / 2)
            }
        }
    }
}
