//  CeraView.swift
//  A cera da Georgia derretendo no topo da vela, e os escorridos que correm pela vela até o fim.
//
//  DOIS RITMOS:
//  1. O formato da cera no topo acompanha o quanto a vela já queimou ("progresso").
//     São os quadros "velaCera_1…145": os 13 desenhos dela (cera nova → escorridos crescem →
//     a cera vira um escorrido só) com 11 quadros intermediários entre cada par, no mesmo traço.
//  2. Com a vela acesa, de tempos em tempos a ponta de um escorrido do topo se estica, solta
//     uma gota e a gota desce COLADA na vela até entrar no suporte. A gota é desenhada do jeito
//     que a Georgia desenha cera no corpo da vela: duas linhas de tinta abertas em cima, fundo
//     redondo de traço mais grosso e o bege mais escuro por dentro.
//
//  Tudo aqui é medido em pixels do quadro da cera (420 × 760, a mesma escala do "velaCorpo"
//  com 60 px de folga de cada lado). "escala" converte para pontos da tela.

import SwiftUI

struct CeraView: View {
    var progresso: Double
    var acesa = false
    var escala: CGFloat = 1     // pontos da tela por pixel do quadro
    var fim: CGFloat = 760      // onde a vela termina (dentro do suporte), em pixels do quadro

    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento
    @State private var escorridos: [Escorrido] = []
    @State private var quadroAtual = 0      // a tarefa das gotas lê daqui (a cópia da View dentro dela fica velha)
    @State private var fimAtual: CGFloat = 760

    static let quadros = (1...CeraPontas.porQuadro.count).map { "velaCera_\($0)" }
    static let larguraQuadro: CGFloat = 420
    static let alturaQuadro: CGFloat = 760

    private var quadro: Int {
        let n = CeraView.quadros.count
        return Int((min(max(progresso, 0), 1) * Double(n - 1)).rounded())
    }

    var body: some View {
        let q = quadro
        Image(CeraView.quadros[q])
            .resizable()
            // As gotas ficam por trás da cera do topo: saem de baixo da ponta do escorrido
            // desenhado, como a cera derretida que corre por baixo da que já endureceu.
            .background(alignment: .top) {
                if !escorridos.isEmpty {
                    TimelineView(.animation) { contexto in
                        Canvas { gc, _ in
                            gc.scaleBy(x: escala, y: escala)
                            for e in escorridos {
                                desenhar(e, agora: contexto.date, em: &gc)
                            }
                        }
                    }
                    .frame(height: (fim + 120) * escala)
                    .allowsHitTesting(false)
                }
            }
            .accessibilityHidden(true)
            .onAppear { quadroAtual = q; fimAtual = fim }
            .onChange(of: fim) { _, novo in fimAtual = novo }
            .onChange(of: q) { antigo, novo in
                quadroAtual = novo
                if novo < antigo { escorridos.removeAll(); return }   // vela nova
                // Um escorrido do topo que deixou de existir não volta para dentro da cera:
                // ele desce pela vela.
                guard acesa, !reduzirMovimento else { return }
                let agora = CeraPontas.porQuadro[novo]
                for p in CeraPontas.porQuadro[antigo]
                where !agora.contains(where: { abs($0[0] - p[0]) < 22 && $0[1] > p[1] - 30 }) {
                    soltar(de: p)
                }
            }
            .task(id: acesa && !reduzirMovimento) {
                if reduzirMovimento { escorridos.removeAll(); return }
                var espera = Double.random(in: 1.5...3)      // a primeira vem logo
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(acesa ? espera : 2))
                    if Task.isCancelled { break }
                    escorridos.removeAll { $0.saiu(fim: fimAtual) }
                    // Apagada, não sai gota nova; as que já estavam descendo terminam o caminho
                    guard acesa else { if escorridos.isEmpty { break } else { continue } }
                    espera = .random(in: 4...8)
                    if let p = CeraPontas.porQuadro[quadroAtual].shuffled().first(where: livre) {
                        soltar(de: p)
                    }
                }
            }
    }

    // MARK: - Soltar e arrumar

    private func livre(_ p: [CGFloat]) -> Bool {
        // Só as pontas em cima do corpo (as da beirada escorreriam por fora da vela),
        // e sem outra gota ainda saindo do mesmo lugar
        p.count == 3 && p[0] > 115 && p[0] < 275
            && !escorridos.contains { abs($0.x - p[0]) < 20 && $0.saindo(agora: .now) }
    }

    private func soltar(de p: [CGFloat]) {
        guard livre(p) else { return }
        escorridos.append(Escorrido(
            inicio: .now, x: p[0], y: p[1], largura: min(max(p[2], 14), 60),
            semente: .random(in: 0...(2 * .pi)),
            curva: .random(in: 2...5),
            inclinacao: .random(in: -0.015...0.015),
            onda: .random(in: 90...150),
            velocidade: .random(in: 75...110),
            comprimento: .random(in: 130...200)))
    }

    // MARK: - Desenho (cores e traço tirados dos desenhos da Georgia)

    private static let tinta = Color(red: 30 / 255, green: 27 / 255, blue: 22 / 255)
    private static let ceraCorpo = Color(red: 236 / 255, green: 227 / 255, blue: 208 / 255) // o corpo da vela
    private static let bege = Color(red: 205 / 255, green: 193 / 255, blue: 169 / 255)      // o de dentro das marcas dela

    // A gota tem o jeito das marcas que a Georgia desenhou no corpo da vela: duas linhas que
    // descem engrossando até um fundo redondo de traço mais grosso, abertas em cima,
    // e o bege mais escuro por dentro (mais forte de um lado, com uma faixa clara do outro).
    // Enquanto ainda está presa, o começo dela fica escondido atrás da ponta do topo.
    private func desenhar(_ e: Escorrido, agora: Date, em gc: inout GraphicsContext) {
        let (yC, raio) = e.cabeca(agora: agora, fim: fim)
        let yJ = e.y - e.largura * 0.6              // presa: começa escondida dentro da ponta
        let yT = max(yJ, yC - e.comprimento)        // onde a gota começa em cima
        let preso = 1 - suave((yC - e.comprimento - yJ) / 50)   // 1 enquanto ainda sai da ponta do topo
        let alto = max(1, yC - yT)
        let fundoGota = raio * 1.1
        let yF = yC + fundoGota

        // Meia largura em cada altura: a gota afina para cima
        func meia(_ y: CGFloat) -> CGFloat {
            let u = min(1, max(0, (yC - y) / max(alto, e.comprimento * 0.6)))     // 0 embaixo, 1 em cima
            return raio * (1 - 0.5 * pow(u, 1.3)) * (1 + 0.06 * CGFloat(sin(Double(y) / 23 + e.semente)))
        }
        // Solta, ela é aberta em cima: o traço e o bege vão sumindo
        func aberta(_ y: CGFloat) -> CGFloat {
            let solta = suave((y - yT) / (alto * 0.55))
            return solta + (1 - solta) * preso
        }

        var esquerda: [CGPoint] = [], direita: [CGPoint] = []
        var y = yT
        while y < yC {
            let c = e.centro(y), w = meia(y)
            esquerda.append(CGPoint(x: c - w, y: y))
            direita.append(CGPoint(x: c + w, y: y))
            y += 3
        }
        let cb = e.centro(yC)
        var fundo: [CGPoint] = []
        for i in 0...20 {
            let a = Double.pi * Double(i) / 20
            fundo.append(CGPoint(x: cb - raio * CGFloat(cos(a)), y: yC + fundoGota * CGFloat(sin(a))))
        }
        var forma = Path()
        forma.addLines(esquerda + fundo + direita.reversed())
        forma.closeSubpath()

        // Gradientes de cima (yT) para baixo (yF)
        let de = CGPoint(x: 0, y: yT), ate = CGPoint(x: 0, y: yF)
        func degrade(_ cor: (CGFloat) -> Color) -> GraphicsContext.Shading {
            .linearGradient(Gradient(stops: (0...20).map { i in
                let k = CGFloat(i) / 20
                return .init(color: cor(yT + (yF - yT) * k), location: k)
            }), startPoint: de, endPoint: ate)
        }

        // Uma camada de cera por baixo (esconde os riscos do corpo)…
        gc.fill(forma, with: degrade { y in CeraView.ceraCorpo.opacity(Double(0.6 * aberta(y))) })
        // …e o bege: uma aguada por dentro e mais forte do lado da sombra, em degraus suaves
        gc.fill(forma, with: degrade { y in CeraView.bege.opacity(Double(0.45 * aberta(y))) })
        let sombra = degrade { y in CeraView.bege.opacity(Double(0.3 * aberta(y))) }
        for passo in [0.3, 0.55, 0.8] as [CGFloat] {
            gc.fill(forma.intersection(forma.offsetBy(dx: raio * 2 * passo, dy: -1.5)), with: sombra)
        }
        // As linhas de tinta, por fora: finas em cima, grossas no fundo
        func traco(_ p: CGPoint) -> CGFloat {
            if p.y > yC { return 3.0 + 1.4 * min(1, (p.y - yC) / fundoGota) }
            let u = min(1, max(0, (yC - p.y) / alto))
            return 3.0 - 1.5 * u * (1 - preso)
        }
        let metade = fundo.count / 2
        let tinta = degrade { y in CeraView.tinta.opacity(Double(aberta(y))) }
        gc.fill(fita(esquerda + fundo[...metade], traco), with: tinta)
        gc.fill(fita(Array(fundo[metade...]) + direita.reversed(), traco), with: tinta)
    }

    // Uma linha de tinta de grossura variável por fora de uma borda
    // (a borda vem no sentido em que a forma é contornada, então a normal aponta para fora)
    private func fita(_ p: [CGPoint], _ grossura: (CGPoint) -> CGFloat) -> Path {
        guard p.count > 1 else { return Path() }
        var dentro: [CGPoint] = [], fora: [CGPoint] = []
        for i in p.indices {
            let a = p[max(0, i - 1)], b = p[min(p.count - 1, i + 1)]
            var nx = -(b.y - a.y), ny = b.x - a.x
            let n = max(0.0001, (nx * nx + ny * ny).squareRoot())
            nx /= n; ny /= n
            let g = grossura(p[i])
            dentro.append(CGPoint(x: p[i].x - nx * 0.6, y: p[i].y - ny * 0.6))
            fora.append(CGPoint(x: p[i].x + nx * g, y: p[i].y + ny * g))
        }
        var path = Path()
        path.addLines(dentro + fora.reversed())
        path.closeSubpath()
        return path
    }
}

private func suave(_ x: CGFloat) -> CGFloat {
    let k = min(1, max(0, x))
    return k * k * (3 - 2 * k)
}

// Uma gota de cera descendo pela vela
struct Escorrido {
    let inicio: Date
    let x: CGFloat, y: CGFloat        // ponta do escorrido do topo de onde ela sai
    let largura: CGFloat              // largura dessa ponta
    let semente: Double
    let curva: CGFloat                // quanto ela serpenteia (a vela não é lisa)
    let inclinacao: CGFloat           // e desce um pouquinho torta
    let onda: CGFloat
    let velocidade: CGFloat           // pixels do quadro por segundo
    let comprimento: CGFloat          // tamanho da gota (as marcas da Georgia no corpo têm uns 200 px)

    static let formando = 2.2         // segundos que a ponta leva se esticando até a gota soltar

    // Meia largura da gota (as marcas dela no corpo têm uns 16–20 px por dentro)
    var fio: CGFloat { min(max(largura * 0.3, 6), 10.5, largura / 2 - 4) }   // mais fina que a ponta

    // Onde o meio da gota está em cada altura: sai da ponta e serpenteia um pouquinho
    func centro(_ yy: CGFloat) -> CGFloat {
        let d = max(0, yy - y)
        let k = min(1, d / 90)
        let s = k * k * (3 - 2 * k)
        let noCorpo = min(max(x, 128), 262)          // longe das beiradas do corpo
        return x + (noCorpo - x) * s + (curva * CGFloat(sin(Double(d / onda) + semente)) + inclinacao * d) * s
    }

    private var comeco: CGFloat { y + 34 }

    private func duracao(fim: CGFloat) -> Double {
        Double(max(1, fim + 80 + comprimento - comeco) / velocidade)
    }

    // Ainda saindo da ponta do topo (não sai outra do mesmo lugar)
    func saindo(agora: Date) -> Bool {
        agora.timeIntervalSince(inicio) < Escorrido.formando + Double((comprimento + 60) / velocidade)
    }

    // Já entrou inteira no suporte
    func saiu(fim: CGFloat) -> Bool {
        Date.now.timeIntervalSince(inicio) > Escorrido.formando + duracao(fim: fim)
    }

    // Onde está o fundo da gota (y do centro do fundo redondo) e a meia largura dela
    func cabeca(agora: Date, fim: CGFloat) -> (CGFloat, CGFloat) {
        let t = agora.timeIntervalSince(inicio)
        if t < Escorrido.formando {
            // Sai devagar de baixo da ponta, ainda presa
            let k = CGFloat(t / Escorrido.formando)
            let s = k * k * (3 - 2 * k)
            return (y - fio * 1.6 + (comeco - y + fio * 1.6) * s, fio)
        }
        // Depois desce colada na vela até entrar no suporte, com aquele "anda e segura" da cera
        let distancia = max(1, fim + 80 + comprimento - comeco)
        let u = min(1, (t - Escorrido.formando) / duracao(fim: fim))
        var p = 0.55 * u + 0.45 * (1 - (1 - u) * (1 - u))
        p += 0.012 * sin(u * .pi * 6 + semente) * u * (1 - u) * 4
        return (comeco + distancia * CGFloat(p), fio)
    }
}

#Preview("Cera escorrendo") {
    @Previewable @State var progresso = 0.3
    VStack {
        VelaView(alturaCheia: 520, largura: 120, progresso: progresso, acesa: true)
        Slider(value: $progresso, in: 0...1) { Text("Progresso da vela") }
            .padding()
    }
    .background(Cores.fundoEscuro)
}
