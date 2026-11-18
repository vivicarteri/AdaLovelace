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
            let luz = Projecao(sessao: sessao, caixa: caixa, tela: geo.size)
            ZStack {
                // Parede: clara com a vela acesa, escura com ela apagada
                (acesa ? Cores.papel : Cores.fundoEscuro)
                    .ignoresSafeArea()

                if acesa {
                    // Luz saindo da caixa
                    RadialGradient(colors: [Cores.dourado.opacity(0.75), .clear],
                                   center: luz.ancora,
                                   startRadius: 10, endRadius: h * 0.7)
                        .ignoresSafeArea()

                    // Sombras: as mesmas figuras do circo, pretas, maiores e borradas.
                    // A tela fica parada: só cada sombra tremula sozinha, por causa da chama.
                    Group {
                        if arteExiste("tendasombra") {
                            // Sombras desenhadas pela Georgia
                            CenaArte(quadro: Quadro(geo: geo), mostrarPersonagens: true,
                                     sombra: true, congelado: congelado, luz: sessao.movimento)
                        } else {
                            // Sem arte: as figuras provisórias pintadas de preto
                            CenarioView(acesa: true, progresso: sessao.progresso, mostrarPersonagens: true, comFundo: false)
                                .colorMultiply(.black)
                        }
                    }
                    .opacity(0.7)
                    .blur(radius: 2.5)
                    // Projetadas a partir da CHAMA: vela alta = sombras mais compactas;
                    // vela baixa (pequena ou no fim) = sombras que sobem e esticam na parede.
                    .offset(y: luz.descida)
                    .scaleEffect(x: luz.escalaX, y: luz.escalaY, anchor: luz.ancora)
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
                    Text("Teatro de Sombras")
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
                        Spacer()
                        BotaoRedondo(icone: "gearshape", rotulo: "Configurações", tamanho: 44, acao: abrirConfiguracoes)
                    }
                    // Dica EMBUTIDA na tela (e não um balão por cima): o balão (popoverTip) bloqueava
                    // a tela, e a pinça feita com ele aberto só fechava a dica.
                    TipView(DicaEntrarNaCaixa(), arrowEdge: .top)
                        .frame(maxWidth: 340)
                        .frame(maxWidth: .infinity, alignment: .leading)
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

// COMO A SOMBRA É PROJETADA
// A luz é a chama da vela, lá dentro da caixa. Como numa vela de verdade:
//  - a sombra cresce a partir da chama (ela é o "ponto de onde a sombra sai");
//  - quanto mais BAIXA a chama, mais a sombra estica para cima e fica maior.
// A altura da chama depende do tamanho escolhido no slider E de quanto a vela já derreteu,
// então as sombras mudam com a vela escolhida e vão mudando com o tempo.
// A caixa é pequenininha na tela, então a diferença é exagerada de propósito (teatral),
// senão ninguém perceberia.
struct Projecao {
    // ⚙️ Tamanho da sombra com a chama no ALTO (vela grande e nova) e no FIM da vela
    static let escalaAlta = (x: CGFloat(1.08), y: CGFloat(1.08))
    static let escalaBaixa = (x: CGFloat(1.22), y: CGFloat(1.42))
    // ⚙️ Folga entre o alto da sombra e a cortina de cima, em pontos
    static let folgaDaCortina: CGFloat = 8

    let ancora: UnitPoint      // onde a chama está (de onde a sombra sai)
    let escalaX: CGFloat
    let escalaY: CGFloat
    let descida: CGFloat       // quanto a sombra desce antes de crescer (para o alto não sumir na cortina)

    @MainActor
    init(sessao: Sessao, caixa: MedidasCaixa, tela: CGSize) {
        // Altura da chama: 1 = a maior vela, inteira; 0 = vela no fim
        let cheia = GeometriaVela.alturaCheia(posicao: sessao.config.posicaoSlider, alturaMaxima: ArteVela.alturaMaxima)
        let altura = min(1, max(0, cheia * CGFloat(1 - sessao.progresso) / ArteVela.alturaMaxima))

        // Onde a chama fica no palco (fração da altura) e, portanto, dentro da abertura da caixa
        let chamaNaArte = ArteVela.baseY - ArteVela.alturaMaxima * altura
            + VelaView.centroDaChama(largura: ArteVela.largura).y
        let fracaoNoPalco = min(1, max(0, chamaNaArte / Quadro.altura))
        let topoDaAbertura = caixa.centroDaAbertura.y - caixa.abertura.height / 2
        let y = topoDaAbertura + fracaoNoPalco * caixa.abertura.height
        let h = max(tela.height, 1)
        ancora = UnitPoint(x: caixa.centroDaAbertura.x / max(tela.width, 1), y: y / h)

        // Chama baixa = sombra maior e mais esticada
        let baixa = 1 - altura
        escalaX = Projecao.escalaAlta.x + (Projecao.escalaBaixa.x - Projecao.escalaAlta.x) * baixa
        escalaY = Projecao.escalaAlta.y + (Projecao.escalaBaixa.y - Projecao.escalaAlta.y) * baixa

        // Onde a cortina de cima (Bambinela) termina: a faixa tem 14% da altura e as
        // bolinhas penduradas descem meia bolinha (são 9 na largura). No iPad elas descem bem mais.
        let limite = (h * 0.14 + tela.width / 9 / 2 + Projecao.folgaDaCortina) / h

        // O alto do céu (eclipse) vai parar em: ancora + (topo + descida - ancora) × escalaY.
        // A descida é a menor que deixa esse ponto abaixo da cortina.
        let a = ancora.y
        let topo = Floresta.ligada ? Floresta.topoDasSombras : 0
        descida = max(0, a - topo - (a - limite) / escalaY) * h
    }
}

