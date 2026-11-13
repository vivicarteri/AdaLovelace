//  CenarioAnimado.swift
//  As peças do CENÁRIO NOVO da Georgia (desenhado deitado) que piscam o olho.
//
//  COMO ISSO FOI FEITO
//  A Georgia mandou cada peça como um vídeo .mov com fundo transparente
//  (12 quadros por segundo, 10 s, numa tela de 3840 × 2878).
//  Num vídeo desses, quase tudo fica parado: só o olho muda. Então o vídeo foi convertido em:
//    - a peça parada, uma vez só ("cenarioLua");
//    - só o pedacinho do olho em cada quadro diferente ("cenarioLua_1", "cenarioLua_2"…);
//    - o RITMO: qual pedacinho aparece em cada um dos 120 quadros (0 = olho da peça parada).
//  Assim o app toca exatamente o que ela animou, gastando bem pouca memória
//  (o quadro inteiro do vídeo ocuparia uns 44 MB de memória CADA).
//
//  As posições estão em pixels da tela da Georgia (3840 × 2878).
//  ⚠️ Ainda são as posições dos vídeos de teste: quando o cenário final chegar,
//  cada peça vai para o lugar dela no cenário.

import SwiftUI

// Uma peça parada + o pedacinho que muda, tocados no ritmo do vídeo
struct PecaAnimada {
    let nome: String
    let peca: CGRect          // onde a peça fica na tela da Georgia
    let pedaco: CGRect        // onde fica o pedacinho que muda (também na tela da Georgia)
    let ritmo: [Int]          // um número por quadro do vídeo; 0 = sem pedacinho (peça parada)
    var fps: Double = 12

    // O pedacinho que deve aparecer agora (0 = nenhum)
    func quadro(t: Double) -> Int {
        guard !ritmo.isEmpty else { return 0 }
        let i = Int((t * fps).rounded(.down)) % ritmo.count
        return ritmo[max(0, i)]
    }
}

enum CenarioNovo {
    // Tamanho da tela em que a Georgia desenha o cenário deitado
    static let largura: CGFloat = 3840
    static let altura: CGFloat = 2878

    static let lua = PecaAnimada(
        nome: "cenarioLua",
        peca: CGRect(x: 1130, y: 434, width: 1685, height: 1689),
        pedaco: CGRect(x: 1470, y: 1456, width: 199, height: 391),
        ritmo: [0, 0, 1, 1, 1, 2, 2, 2, 3, 3, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 12, 14, 14,
                15, 16, 17, 18, 19, 20, 21, 22, 23, 23, 24, 25, 25, 25, 26, 26, 26, 27, 27, 27,
                28, 28, 28, 29, 29, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 39, 41, 41,
                42, 43, 42, 44, 45, 46, 47, 48, 49, 49, 50, 51, 51, 52, 52, 52, 53, 53, 54, 54,
                54, 55, 55, 56, 57, 57, 58, 59, 60, 61, 62, 63, 64, 63, 65, 65, 66, 67, 66, 68,
                69, 70, 71, 72, 73, 74, 75, 76, 76, 76, 77, 77, 77, 78, 78, 78]
    )

    static let passarinho = PecaAnimada(
        nome: "cenarioPassarinho",
        peca: CGRect(x: 1260, y: 244, width: 1207, height: 2467),
        pedaco: CGRect(x: 2228, y: 1402, width: 85, height: 69),
        ritmo: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 9, 10, 10, 11, 11, 11, 11, 11, 10, 12, 12, 13, 14, 15,
                16, 17, 18, 19, 20, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21,
                21, 21, 21, 21, 20, 19, 18, 17, 22, 23, 24, 25, 26, 26, 27, 27, 28, 28, 28, 28,
                27, 27, 26, 26, 25, 24, 23, 29, 30, 31, 32, 33, 34, 34, 34, 34, 34, 34, 34, 34,
                34, 34, 34, 34, 34, 34, 34, 35, 32, 31, 30, 29, 23, 24, 25, 26, 36, 27, 37, 28,
                28, 28, 28, 37, 27, 36, 26, 25, 24, 23, 29, 30, 31, 32, 33, 34]
    )
}

// Desenha uma PecaAnimada no tamanho pedido (a peça inteira ocupa o frame).
// t: o relógio de quem desenha (a cena já tem um). Sem t, a peça usa um relógio próprio.
// sombra: só a silhueta preta (o olho piscando não aparece na sombra, então nem desenha).
// Com "Reduzir movimento" ligado, fica parada com o olho da peça parada.
struct PecaAnimadaView: View {
    let peca: PecaAnimada
    var t: Double? = nil
    var fase: Double = 0     // para duas peças não piscarem exatamente juntas
    var sombra = false

    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento

    var body: some View {
        GeometryReader { geo in
            if let t {
                desenho(geo.size, quadro: reduzirMovimento ? 0 : peca.quadro(t: t + fase))
            } else {
                TimelineView(.animation(minimumInterval: 1 / peca.fps, paused: reduzirMovimento)) { contexto in
                    let agora = contexto.date.timeIntervalSinceReferenceDate + fase
                    desenho(geo.size, quadro: reduzirMovimento ? 0 : peca.quadro(t: agora))
                }
            }
        }
        .aspectRatio(peca.peca.width / peca.peca.height, contentMode: .fit)
        .accessibilityHidden(true)
    }

    private func desenho(_ tamanho: CGSize, quadro q: Int) -> some View {
        // Quanto a peça encolheu/cresceu da tela da Georgia para a tela do aparelho
        let ex = tamanho.width / peca.peca.width
        let ey = tamanho.height / peca.peca.height
        let p = peca.pedaco
        return ZStack(alignment: .topLeading) {
            Image(peca.nome)
                .resizable()
                .frame(width: tamanho.width, height: tamanho.height)
            if q > 0 && !sombra {
                Image("\(peca.nome)_\(q)")
                    .resizable()
                    .frame(width: p.width * ex, height: p.height * ey)
                    .offset(x: (p.minX - peca.peca.minX) * ex,
                            y: (p.minY - peca.peca.minY) * ey)
            }
        }
        .colorMultiply(sombra ? .black : .white)
    }
}

// FAIXA INFINITA
// As peças do cenário novo passam devagarinho pela tela e, quando saem de um lado,
// voltam pelo outro, para sempre (como na animatic da Georgia: a lua vai para a direita…).
//
// As medidas estão em pixels do Quadro (o mesmo da arte atual, 1290 de largura = a tela do iPhone).
// A volta inteira é mais larga que a tela: cada peça passa um tempo escondida fora da tela
// antes de reaparecer. No iPad deitado (mais largo) dá para ver mais da faixa.
struct ElementoDaFaixa {
    let peca: PecaAnimada
    let altura: CGFloat        // altura da peça no Quadro (a largura sai da proporção do desenho)
    let y: CGFloat             // centro, de cima para baixo, no Quadro
    let inicio: CGFloat        // onde o centro está no instante 0 (0 = borda esquerda da tela)
    let velocidade: CGFloat    // pixels do Quadro por segundo. Positivo = para a direita.
    var balanco: CGFloat = 0   // sobe e desce de leve, como boneco de papel (pixels do Quadro)
    var fase: Double = 0

    var largura: CGFloat { altura * peca.peca.width / peca.peca.height }
}

enum FaixaInfinita {
    // COMO UMA ESTEIRA: todas as peças andam no MESMO passo e com a mesma distância entre elas.
    // Assim uma nunca alcança a outra (antes o passarinho era mais rápido e passava
    // por cima da lua). Para pôr mais peças, aumente "volta" e reparta o "inicio".

    // ⚙️ Passo da esteira, em pixels do Quadro por segundo.
    // 12 px/s = ~2 min para uma peça atravessar a tela do iPhone.
    static let passo: CGFloat = 12

    // ⚙️ Comprimento da volta. Com 2 peças e volta de 2 telas, elas ficam a 1 tela de distância:
    // quando uma está saindo, a outra está entrando, e a tela nunca fica vazia.
    static let volta: CGFloat = Quadro.largura * 2

    // O relógio da faixa começa quando o app abre: assim as peças sempre começam
    // no "inicio" de cada uma, e não num ponto qualquer da volta.
    static let comeco = Date().timeIntervalSinceReferenceDate

    static let elementos: [ElementoDaFaixa] = [
        // Abaixo de ~y 750 tudo aparece também na sombra (a cortina do teatro esconde o alto).
        // Lua: alta o bastante para passar por cima da chama (vela no tamanho padrão).
        ElementoDaFaixa(peca: CenarioNovo.lua, altura: 640, y: 1060,
                        inicio: 950, velocidade: passo, balanco: 10, fase: 0),
        // Passarinho: 1 tela atrás da lua. Começa logo fora da tela, à esquerda, e entra em seguida.
        ElementoDaFaixa(peca: CenarioNovo.passarinho, altura: 460, y: 1000,
                        inicio: 950 - Quadro.largura, velocidade: passo, balanco: 24, fase: 0.7)
    ]

    // Onde está o centro da peça agora (em x do Quadro). Dá a volta sem pulo:
    // a peça só "teleporta" quando está bem longe, fora da tela.
    static func x(_ e: ElementoDaFaixa, t: Double) -> CGFloat {
        let sobra = (volta - Quadro.largura) / 2      // quanto da volta fica de cada lado da tela
        let andou = Double(e.inicio + sobra) + Double(e.velocidade) * t
        let naVolta = andou.truncatingRemainder(dividingBy: Double(volta))
        return CGFloat(naVolta < 0 ? naVolta + Double(volta) : naVolta) - sobra
    }
}

// Desenha a faixa dentro de uma cena que já tem relógio (t) e Quadro.
struct FaixaInfinitaView: View {
    let quadro: Quadro
    let t: Double
    var sombra = false

    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento

    var body: some View {
        // Com "Reduzir movimento", as peças ficam paradas onde começam (as duas dentro da tela)
        let relogio = reduzirMovimento ? 0 : max(0, t - FaixaInfinita.comeco)
        ZStack {
            ForEach(FaixaInfinita.elementos.indices, id: \.self) { i in
                let e = FaixaInfinita.elementos[i]
                let sobe = reduzirMovimento ? 0 : e.balanco * CGFloat(sin(relogio * 0.6 + e.fase * 4))
                PecaAnimadaView(peca: e.peca, t: relogio, fase: e.fase, sombra: sombra)
                    .frame(width: e.largura * quadro.escala, height: e.altura * quadro.escala)
                    .position(x: quadro.x(FaixaInfinita.x(e, t: relogio)),
                              y: quadro.y(e.y + sobe))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

#Preview("Lua e passarinho (cenário novo)") {
    HStack(spacing: 24) {
        PecaAnimadaView(peca: CenarioNovo.lua)
        PecaAnimadaView(peca: CenarioNovo.passarinho, fase: 0.7)
    }
    .padding()
    .background(Color(red: 0.1, green: 0.08, blue: 0.08))
}
