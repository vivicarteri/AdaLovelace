//  Floresta.swift
//  O cenário novo da Georgia: a floresta, montada igual ao mockup dela (IMG_3976).
//
//  COMO FOI MONTADO
//  A Georgia desenhou a floresta numa tela DEITADA de 2732 × 2048 (a tela do iPad deitado).
//  Todas as medidas aqui estão nessa tela ("pixels da Georgia"). Ela é encaixada pela ALTURA:
//    - iPad: aparece a floresta inteira (deitado) e ela fica PARADA; só o céu se mexe.
//    - iPhone (em pé): aparece o pedaço do meio e a floresta DESLIZA devagar de um lado
//      para o outro, com profundidade: o fundo anda menos, a frente anda mais.
//  Com a vela APAGADA a floresta não aparece (o palco fica escuro); ela surge ao acender.
//
//  Camadas, de trás para a frente (igual ao mockup):
//    fundo (céu + silhuetas bem apagadas) → árvores azul-escuras → árvores cinza (com contorno)
//    → estrelas → SOL e LUA (eclipse) → nuvens → arbustos → passarinhos
//
//  O CÉU (história em loop): o sol anda para a esquerda e a lua para a direita; eles só se
//  encontram no meio (o eclipse) — o app abre exatamente no eclipse, como no mockup.
//  Nuvens e passarinhos passam em sentidos contrários, em alturas diferentes ("quase encontros").
//
//  Se "florestaFundo" não estiver no Assets, o app volta para a tenda do circo.

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum Floresta {
    // Tela em que a Georgia desenhou a floresta
    static let largura: CGFloat = 2732
    static let altura: CGFloat = 2048

    // ⚙️ Qual x da floresta fica no MEIO da tela (1366 = o meio da floresta)
    static let centroX: CGFloat = 1366

    // Quanto a floresta cresce para ocupar a altura do Quadro
    static let escala: CGFloat = Quadro.altura / altura

    // A floresta está no Assets? (a conta é feita uma vez e guardada)
    static let ligada: Bool = arteExiste("florestaFundo")

    // Só o iPhone desliza a floresta. No iPad ela fica parada (só o céu se mexe).
    static var desliza: Bool {
        #if canImport(UIKit)
        UIDevice.current.userInterfaceIdiom == .phone
        #else
        false
        #endif
    }

    // ⚙️ Tempo de uma ida e volta da floresta no iPhone, em segundos (maior = mais devagar)
    static let periodoDoDeslize: Double = 150

    // Pixels da Georgia → pixels do Quadro (o mesmo sistema da vela e do resto do palco)
    static func noQuadro(x: CGFloat) -> CGFloat { Quadro.largura / 2 + (x - centroX) * escala }
    static func noQuadro(y: CGFloat) -> CGFloat { y * escala }

    // Quanto a floresta pode andar para cada lado, em pontos da tela (0 = não anda)
    static func amplitudeDoDeslize(_ quadro: Quadro) -> CGFloat {
        guard desliza, quadro.escala > 0 else { return 0 }
        let telaNoQuadro = (2 * quadro.origem.x + Quadro.largura * quadro.escala) / quadro.escala
        let sobra = (largura * escala - telaNoQuadro) / 2
        return max(0, sobra) * quadro.escala * 0.85   // ⚙️ 0,85 = não chega até a beiradinha
    }

    // Onde começa o céu (o alto do eclipse), em fração da altura da tela.
    // O teatro de sombras usa isso para o eclipse nunca sumir atrás da cortina de cima.
    static let topoDasSombras: CGFloat = 0.12

    // MARK: Camadas paradas

    struct Peca {
        let nome: String
        let x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat   // canto de cima, pixels da Georgia
        var tinta: Color = .white       // colorMultiply: escurece/azula a peça (branco = cor original)
        var espelho = false
        var profundidade: CGFloat = 1   // no iPhone: quanto ela anda (0 = parada, 1 = anda tudo)
        var fazSombra = true            // aparece no teatro de sombras?
        var forcaDaSombra: Double = 1   // quão escura é a sombra dela (árvores mais claras: o céu é o protagonista)
    }

    // Cores do mockup: as peças vêm claras e a Georgia escureceu para a noite
    static let azulNoite = Color(red: 0.34, green: 0.32, blue: 0.50)      // árvores do fundo
    static let cinzaNoite = Color(red: 0.80, green: 0.76, blue: 0.80)     // árvores da frente
    static let arbustoEscuro = Color(red: 0.40, green: 0.44, blue: 0.58)  // arbustos de trás
    static let arbustoClaro = Color(red: 0.80, green: 0.82, blue: 0.95)   // arbustos da frente

    static let fundo = Peca(nome: "florestaFundo", x: 0, y: 0, w: 2732, h: 2048,
                            profundidade: 0.3, fazSombra: false)

    static let arvores: [Peca] = [
        Peca(nome: "florestaFundoArvores2", x: 42, y: 660, w: 2522, h: 1381,
             tinta: azulNoite, profundidade: 0.55, fazSombra: false),
        Peca(nome: "florestaFundoArvores1", x: 42, y: 408, w: 2655, h: 1598,
             tinta: cinzaNoite, profundidade: 0.8, forcaDaSombra: 0.45)
    ]

    // A Georgia mandou dois arbustos; do lado direito eles se repetem espelhados (como no mockup)
    static let arbustos: [Peca] = [
        Peca(nome: "florestaArbusto1", x: 0, y: 1426, w: 1158, h: 622, tinta: arbustoEscuro, forcaDaSombra: 0.6),
        Peca(nome: "florestaArbusto1", x: 1574, y: 1426, w: 1158, h: 622, tinta: arbustoEscuro, espelho: true,
             forcaDaSombra: 0.6),
        Peca(nome: "florestaArbusto2", x: 474, y: 1691, w: 1144, h: 357, tinta: arbustoClaro, forcaDaSombra: 0.6),
        Peca(nome: "florestaArbusto2", x: 1114, y: 1691, w: 1144, h: 357, tinta: arbustoClaro, espelho: true,
             forcaDaSombra: 0.6)
    ]

    // MARK: Céu

    // Estrelas paradas que piscam devagar (centro e altura em pixels da Georgia)
    struct Estrela {
        let nome: String
        let x: CGFloat, y: CGFloat, altura: CGFloat
        let fase: Double
    }

    static let estrelas: [Estrela] = [
        Estrela(nome: "florestaEstrela1", x: 730, y: 238, altura: 175, fase: 0),
        Estrela(nome: "florestaEstrela2", x: 195, y: 628, altura: 135, fase: 1.7),
        Estrela(nome: "florestaEstrela1", x: 2085, y: 333, altura: 146, fase: 3.1),
        Estrela(nome: "florestaEstrela2", x: 2460, y: 180, altura: 120, fase: 4.4),
        Estrela(nome: "florestaEstrela2", x: 1915, y: 1232, altura: 105, fase: 5.2),
        Estrela(nome: "florestaEstrela2", x: 1180, y: 160, altura: 90, fase: 2.6),
        Estrela(nome: "florestaEstrela1", x: 980, y: 1180, altura: 120, fase: 0.9)
    ]

    // Peça que anda no céu, dando a volta (sai de um lado e volta pelo outro)
    struct Andante {
        let peca: PecaAnimada
        let altura: CGFloat     // altura da peça, pixels da Georgia
        let y: CGFloat          // centro
        let inicio: CGFloat     // x do centro quando o app abre
        let velocidade: CGFloat // pixels da Georgia por segundo (negativo = para a esquerda)
        var balanco: CGFloat = 0
        var fase: Double = 0

        var largura: CGFloat { altura * peca.peca.width / peca.peca.height }
    }

    // ⚙️ Passo do céu: ~14 px/s = uma peça leva ~2 min para atravessar a tela do iPhone
    // e ~4 min para atravessar o iPad. O eclipse no meio volta a cada ~4 min e meio.
    static let passo: CGFloat = 14

    // A volta: a floresta inteira + uma folga de cada lado (a peça some antes de dar a volta)
    static let folga: CGFloat = 560
    static var volta: CGFloat { largura + 2 * folga }

    // Sol e lua começam no eclipse (posições do mockup: a lua na frente, um pouco à esquerda).
    // ⚙️ Um pouco mais altos que no mockup, para a lua não passar atrás da chama da vela.
    static let sol = Andante(peca: CenarioNovo.sol, altura: 732, y: 650,
                             inicio: 1462, velocidade: -passo, balanco: 8, fase: 1.3)
    static let lua = Andante(peca: CenarioNovo.lua, altura: 763, y: 647,
                             inicio: 1349, velocidade: passo, balanco: 8, fase: 0)

    // Nuvens: mais devagar (estão longe), em sentidos contrários e alturas diferentes
    static let nuvens: [Andante] = [
        Andante(peca: CenarioNovo.nuvem3, altura: 184, y: 554, inicio: 489,
                velocidade: passo * 0.45, balanco: 5, fase: 0.4),
        Andante(peca: CenarioNovo.nuvem2, altura: 144, y: 854, inicio: 1661,
                velocidade: -passo * 0.4, balanco: 5, fase: 1.1),
        Andante(peca: CenarioNovo.nuvem1, altura: 229, y: 1316, inicio: 1127,
                velocidade: passo * 0.35, balanco: 5, fase: 2.5),
        Andante(peca: CenarioNovo.nuvem3, altura: 191, y: 1048, inicio: 2387,
                velocidade: -passo * 0.5, balanco: 5, fase: 3.2)
    ]

    // Passarinhos: um alto, outro baixo, em sentidos contrários — NUNCA na faixa do sol e da lua,
    // para não ficarem um em cima do outro.
    static let passarinhos: [Andante] = [
        Andante(peca: CenarioNovo.passarinho, altura: 300, y: 230, inicio: 693,
                velocidade: passo * 1.3, balanco: 18, fase: 0.7),
        Andante(peca: CenarioNovo.passarinho2, altura: 300, y: 1330, inicio: 1973,
                velocidade: -passo * 1.3, balanco: 16, fase: 2.1)
    ]

    // Onde está o centro da peça agora (x, pixels da Georgia). A volta fica escondida fora da tela.
    static func x(_ a: Andante, relogio: Double) -> CGFloat {
        let andou = Double(a.inicio + folga) + Double(a.velocidade) * relogio
        let naVolta = andou.truncatingRemainder(dividingBy: Double(volta))
        return CGFloat(naVolta < 0 ? naVolta + Double(volta) : naVolta) - folga
    }
}

// A floresta inteira, desenhada dentro da cena (que já tem relógio e Quadro).
// sombra: só as silhuetas pretas (sem o fundo, sem as árvores de trás e sem as estrelas).
// acesa: com a vela apagada a floresta some.
struct FlorestaView: View {
    let quadro: Quadro
    let t: Double
    var sombra = false
    var acesa = true

    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento

    var body: some View {
        // O mesmo relógio da esteira: o cenário e as sombras andam juntos
        let relogio = reduzirMovimento ? 0 : max(0, t - FaixaInfinita.comeco)
        let onda = CGFloat(sin(relogio * 2 * .pi / Floresta.periodoDoDeslize))
        let deslize = reduzirMovimento ? 0 : Floresta.amplitudeDoDeslize(quadro) * onda

        ZStack {
            if !sombra { peca(Floresta.fundo, deslize: deslize) }
            ForEach(Floresta.arvores.indices, id: \.self) { i in
                let p = Floresta.arvores[i]
                if !sombra || p.fazSombra { peca(p, deslize: deslize) }
            }
            if !sombra { estrelas(relogio) }

            andante(Floresta.sol, relogio)
            andante(Floresta.lua, relogio)          // na frente do sol: é ela que faz o eclipse
            ForEach(Floresta.nuvens.indices, id: \.self) { i in andante(Floresta.nuvens[i], relogio) }

            ForEach(Floresta.arbustos.indices, id: \.self) { i in peca(Floresta.arbustos[i], deslize: deslize) }

            ForEach(Floresta.passarinhos.indices, id: \.self) { i in andante(Floresta.passarinhos[i], relogio) }
        }
        .opacity(acesa || sombra ? 1 : 0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // Uma peça parada (fundo, árvores, arbustos). No iPhone ela desliza conforme a profundidade.
    private func peca(_ p: Floresta.Peca, deslize: CGFloat) -> some View {
        let x = Floresta.noQuadro(x: p.x + p.w / 2)
        let y = Floresta.noQuadro(y: p.y + p.h / 2)
        return Image(p.nome)
            .resizable()
            .frame(width: p.w * Floresta.escala * quadro.escala, height: p.h * Floresta.escala * quadro.escala)
            .scaleEffect(x: p.espelho ? -1 : 1, y: 1)
            .colorMultiply(sombra ? .black : p.tinta)
            .opacity(sombra ? p.forcaDaSombra : 1)
            .position(x: quadro.x(x) + deslize * p.profundidade, y: quadro.y(y))
    }

    // Uma peça do céu andando (sol, lua, nuvem, passarinho)
    private func andante(_ a: Floresta.Andante, _ relogio: Double) -> some View {
        let sobe = reduzirMovimento ? 0 : a.balanco * CGFloat(sin(relogio * 0.6 + a.fase * 4))
        let x = Floresta.noQuadro(x: Floresta.x(a, relogio: relogio))
        let y = Floresta.noQuadro(y: a.y + sobe)
        return PecaAnimadaView(peca: a.peca, t: relogio, fase: a.fase, sombra: sombra)
            .frame(width: a.largura * Floresta.escala * quadro.escala,
                   height: a.altura * Floresta.escala * quadro.escala)
            .position(x: quadro.x(x), y: quadro.y(y))
    }

    // Estrelas: paradas no céu, piscando e flutuando devagarinho
    private func estrelas(_ relogio: Double) -> some View {
        ZStack {
            ForEach(Floresta.estrelas.indices, id: \.self) { i in
                let e = Floresta.estrelas[i]
                let brilho = reduzirMovimento ? 1 : 0.7 + 0.3 * sin(relogio * 0.9 + e.fase)
                let tamanho = e.altura * Floresta.escala * quadro.escala * CGFloat(0.94 + 0.06 * brilho)
                let flutua = reduzirMovimento ? 0 : 10 * CGFloat(sin(relogio * 0.35 + e.fase))
                Image(e.nome)
                    .resizable()
                    .scaledToFit()
                    .frame(width: tamanho, height: tamanho)
                    .rotationEffect(.degrees(reduzirMovimento ? 0 : 6 * sin(relogio * 0.2 + e.fase)))
                    .opacity(brilho)
                    .position(x: quadro.x(Floresta.noQuadro(x: e.x)),
                              y: quadro.y(Floresta.noQuadro(y: e.y + flutua)))
            }
        }
    }
}

// MARK: - Previews

#Preview("Floresta: vela acesa") {
    GeometryReader { geo in
        TimelineView(.animation(minimumInterval: 1 / 30)) { contexto in
            FlorestaView(quadro: Quadro(tela: geo.size), t: contexto.date.timeIntervalSinceReferenceDate)
        }
    }
    .ignoresSafeArea()
    .background(Cores.fundoEscuro)
}

// Como as sombras ficam no teatro de sombras
#Preview("Floresta: sombras") {
    GeometryReader { geo in
        TimelineView(.animation(minimumInterval: 1 / 30)) { contexto in
            FlorestaView(quadro: Quadro(tela: geo.size), t: contexto.date.timeIntervalSinceReferenceDate,
                         sombra: true)
                .opacity(0.7)
                .blur(radius: 2.5)
                .scaleEffect(1.15, anchor: .bottom)
        }
    }
    .ignoresSafeArea()
    .background(Cores.papel)
}
