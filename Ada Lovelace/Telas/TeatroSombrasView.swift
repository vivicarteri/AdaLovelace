//  TeatroSombrasView.swift
//  Fora da caixa (zoom out): a luz da vela projeta as sombras do circo na parede.
//  Tocar na caixa volta para o palco.

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct TeatroSombrasView: View {
    @EnvironmentObject private var sessao: Sessao
    var entrar: () -> Void
    var aberturaCaixa: CGFloat = 0        // cortina da caixa: 0 = fechada (normal), 1 = aberta (só na animação)
    var conteudoDaCaixa: AnyView? = nil   // palco em miniatura (só na animação de entrar e sair)
    var congelado = false                 // durante o zoom as sombras param, para o movimento ficar liso
    var mostrarCamadas = true             // VoiceOver: rotor das camadas (fica de fora na animação)

    var body: some View {
        let acesa = sessao.estado == .acesa

        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let caixa = MedidasCaixa(tela: geo.size)
            let luz = Projecao(sessao: sessao, caixa: caixa, tela: geo.size)
            ZStack {
                // Parede: clara com a vela acesa, escura com ela apagada.
                // Na floresta a parede é quase branca (referência da Georgia), para as sombras cinza
                // ficarem bem definidas.
                (acesa ? (Floresta.ligada ? Color(white: 0.96) : Cores.papel) : Cores.fundoEscuro)
                    .ignoresSafeArea()

                if acesa {
                    // Luz saindo da caixa (na floresta, só um calorzinho perto dela)
                    RadialGradient(colors: [Cores.dourado.opacity(Floresta.ligada ? 0.14 : 0.75), .clear],
                                   center: luz.ancora,
                                   startRadius: 10, endRadius: h * 0.7)
                        .ignoresSafeArea()

                    // Sombras: as mesmas figuras do circo, pretas, maiores e borradas.
                    // A tela fica parada: só cada sombra tremula sozinha, por causa da chama.
                    Group {
                        if Floresta.ligada {
                            // Floresta: uma camada de sombras por distância. Perto da parede (céu) =
                            // nítida; perto da chama (mata) = borrada, maior e mais pesada.
                            let fator = min(w, h) / 400   // o borrão cresce junto com a tela (iPad)
                            ZStack {
                                ForEach(CamadaDaSombra.allCases, id: \.self) { camada in
                                    CenaArte(quadro: Quadro(geo: geo), mostrarPersonagens: true,
                                             sombra: true, congelado: congelado, luz: sessao.movimento,
                                             camadaDaSombra: camada)
                                        // A transparência é de cada silhueta (FlorestaView): onde duas se
                                        // cruzam, a sombra fica mais escura, como num teatro de verdade.
                                        .blur(radius: camada.borrao * fator)
                                        .scaleEffect(camada.escala, anchor: UnitPoint(x: 0.5, y: camada.ancoraY))
                                }
                            }
                        } else if arteExiste("tendasombra") {
                            // Sombras desenhadas pela Georgia (circo)
                            CenaArte(quadro: Quadro(geo: geo), mostrarPersonagens: true,
                                     sombra: true, congelado: congelado, luz: sessao.movimento)
                                .opacity(0.7)
                                .blur(radius: 2.5)
                        } else {
                            // Sem arte: as figuras provisórias pintadas de preto
                            CenarioView(acesa: true, progresso: sessao.progresso, mostrarPersonagens: true, comFundo: false)
                                .colorMultiply(.black)
                                .opacity(0.7)
                                .blur(radius: 2.5)
                        }
                    }
                    // Projetadas a partir da CHAMA: vela alta = sombras mais compactas;
                    // vela baixa (pequena ou no fim) = sombras que sobem e esticam na parede.
                    .offset(y: luz.descida)
                    .scaleEffect(x: luz.escalaX, y: luz.escalaY, anchor: luz.ancora)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }

                // Bambinela (cortina de cima)
                VStack(spacing: 0) {
                    // A arte da Georgia é bem comprida: ela preenche a faixa. Numa tela em pé
                    // (iPhone) sobram os lados, que são cortados; numa tela deitada (iPad) a faixa
                    // fica mais alta, para a cortina aparecer INTEIRA (antes cortava as franjas).
                    let faixa = MedidasBambinela.altura(largura: w, altura: h)
                    if arteExiste(MedidasBambinela.nome) {
                        Image(MedidasBambinela.nome).resizable().scaledToFill()
                            .frame(width: w, height: faixa)
                            .clipped()
                    } else {
                        Bambinela().frame(height: faixa)
                    }
                    Spacer()
                }
                .ignoresSafeArea(edges: .top)
                .accessibilityHidden(true)

                // (O letreiro "Teatro de Sombras" saiu, a pedido do time: a cortina de cima fica sozinha.)

                // A caixa do teatro, lá embaixo. Tocar nela entra de novo (a câmera vai até ela).
                Button(action: entrar) {
                    CaixaTeatroView(medidas: caixa, acesa: acesa,
                                    aberturaCortina: aberturaCaixa, conteudo: conteudoDaCaixa)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Entrar na caixa")
                .accessibilityHint("Volta para a vela")
                .accessibilityInputLabels(["Entrar na caixa", "Voltar para a vela", "Caixa de teatro"])
                .position(caixa.centro)

                // Rotor "Camadas de papel": céu, floresta e estado da vela, uma de cada vez
                if mostrarCamadas {
                    CamadasDaCenaAcessiveis(camadas: acesa ? DescricaoDaCena.camadas(sombra: true) : [],
                                            estadoDaVela: sessao.descricaoDaVela)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(acesa ? "Teatro de sombras. As sombras da cena de papel aparecem na parede"
                                  : "Teatro de sombras, no escuro. A vela está apagada")
    }
}

// MEDIDAS DA CORTINA DE CIMA (bambinela)
// A faixa tem 14% da altura da tela. Se a tela for larga demais para isso (iPad deitado),
// ela cresce até a arte caber inteira na largura (no máximo 22% da altura), para as
// franjas de baixo não serem cortadas.
enum MedidasBambinela {
    static let nome = "bambinela"
    static let alturaPadrao: CGFloat = 0.14
    static let alturaMaxima: CGFloat = 0.22
    // Na arte da Georgia (3032 × 476), as franjas terminam a 437 px do alto
    static let fimDasFranjas: CGFloat = 437.0 / 476.0

    // Largura ÷ altura da arte (lida do Assets; se a Georgia trocar a imagem, acompanha)
    static let proporcao: CGFloat? = {
        #if canImport(UIKit)
        if let tamanho = UIImage(named: nome)?.size, tamanho.height > 0 { return tamanho.width / tamanho.height }
        #endif
        return nil
    }()

    static func altura(largura w: CGFloat, altura h: CGFloat) -> CGFloat {
        guard arteExiste(nome), let proporcao else { return h * alturaPadrao }
        return min(max(h * alturaPadrao, w / proporcao), h * alturaMaxima)
    }

    // Onde a cortina termina de verdade (pontos, a partir do alto)
    static func fim(largura w: CGFloat, altura h: CGFloat) -> CGFloat {
        let faixa = altura(largura: w, altura: h)
        guard arteExiste(nome), let proporcao else {
            return faixa + w / 9 / 2   // provisória: as bolinhas descem meia bolinha
        }
        // A arte preenche a faixa: se ela ficou mais alta que a faixa (tela em pé), o meio fica
        // na faixa e as pontas de cima e de baixo são cortadas por igual.
        let alturaDaArte = max(faixa, w / proporcao)
        let cortada = (alturaDaArte - faixa) / 2
        return min(faixa, alturaDaArte * fimDasFranjas - cortada)
    }
}

// Cortina de cima com franjas arredondadas (provisória, quando não há arte)
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
    static let folgaDaCortina: CGFloat = 28   // (folga maior: o eclipse não encosta nas franjas)

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

        // Onde a cortina de cima (Bambinela) termina, com as franjas, em qualquer tela
        let limite = (MedidasBambinela.fim(largura: tela.width, altura: h) + Projecao.folgaDaCortina) / h

        // O alto do céu (eclipse) vai parar em: ancora + (topo + descida - ancora) × escalaY.
        // A descida é a menor que deixa esse ponto abaixo da cortina.
        let a = ancora.y
        let topo = Floresta.ligada ? CamadaDaSombra.topoDoCeu : 0
        descida = max(0, a - topo - (a - limite) / escalaY) * h
    }
}

