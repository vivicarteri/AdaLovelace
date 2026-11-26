//  Fumaca.swift
//  Fumaça de verdade (pedido da Sofia): em vez de bolinhas redondas, FIOS que sobem e ondulam.
//
//  Como funciona:
//  - A fonte (a cabeça do fósforo ou a ponta do pavio) solta pontinhos sem parar.
//  - Cada ponto sobe, freia, e é empurrado para os lados por um "vento" suave. Perto da fonte
//    a fumaça sobe reta (como na vida real) e, mais para cima, começa a ondular.
//  - Os pontos de um mesmo fio são ligados por uma linha macia que vai engrossando e sumindo.
//  - Quando a fonte se mexe (arrastar o fósforo), o ponto novo nasce onde ela está e herda um
//    pouco da velocidade dela. A fumaça que já saiu continua no ar: o rastro fica para trás.
//  - A baforada (o fósforo pegando fogo, a vela apagando) solta alguns fios mais largos por um
//    instante; depois fica só um fio fino.
//  - Sem fumaça no ar, o desenho para de atualizar (bateria).

import SwiftUI

// Um pontinho de fumaça
struct PontoDeFumaca {
    var posicao: CGPoint
    var velocidade: CGVector
    let nascimento: Double
    let forca: Double          // opacidade ao nascer (0 a 1)
}

// Um fio de fumaça: os pontos que saíram em sequência de uma fonte
final class FioDeFumaca {
    var pontos: [PontoDeFumaca] = []
    let semente: Double
    let largura: CGFloat        // largura ao nascer (em unidades: escala)
    let alargamento: CGFloat    // quanto engrossa por segundo (em unidades)
    let subida: CGFloat         // velocidade para cima ao nascer (unidades por segundo)
    let turbulencia: CGFloat    // quanto o vento empurra para os lados
    let vida: Double            // quanto tempo cada ponto vive (segundos)
    let desvio: CGVector        // distância da fonte (em unidades)
    let comeco: Double
    let duracao: Double?        // nil = solta enquanto a fonte estiver acesa
    let forcaInicial: Double, forcaFinal: Double   // opacidade dos pontos novos, do começo ao fim
    var emitindo = true
    var proximaEmissao: Double

    init(semente: Double, largura: CGFloat, alargamento: CGFloat, subida: CGFloat, turbulencia: CGFloat,
         vida: Double, desvio: CGVector = .zero, comeco: Double, duracao: Double?,
         forcaInicial: Double, forcaFinal: Double) {
        self.semente = semente
        self.largura = largura
        self.alargamento = alargamento
        self.subida = subida
        self.turbulencia = turbulencia
        self.vida = vida
        self.desvio = desvio
        self.comeco = comeco
        self.duracao = duracao
        self.forcaInicial = forcaInicial
        self.forcaFinal = forcaFinal
        self.proximaEmissao = comeco
    }

    // Opacidade dos pontos que nascem agora
    func forca(em t: Double) -> Double {
        guard let duracao, duracao > 0 else { return forcaInicial }
        let k = min(1, max(0, (t - comeco) / duracao))
        return forcaInicial + (forcaFinal - forcaInicial) * k
    }
}

@MainActor
@Observable
final class MotorDeFumaca {
    // ⚙️ AJUSTES DA FUMAÇA (em "unidades": 1 unidade = escala pontos; a vela tem ~50 unidades de largura)
    static let pontosPorSegundo: Double = 45
    static let empuxo: CGFloat = 30            // aceleração para cima (o ar quente sobe)
    static let arrasto: CGFloat = 1.1          // o quanto o ar freia a fumaça (por segundo)
    static let heranca: CGFloat = 0.3          // quanto da velocidade da fonte o ponto novo leva
    static let tempoAteOndular: Double = 0.45  // perto da fonte a fumaça sobe reta; depois ondula

    // Só isto é observado: a tela desenha enquanto tem fumaça no ar
    private(set) var emCena = false

    @ObservationIgnored var escala: CGFloat = 1
    @ObservationIgnored var reduzirMovimento = false
    @ObservationIgnored private(set) var fios: [FioDeFumaca] = []
    @ObservationIgnored private var fonte: CGPoint?
    @ObservationIgnored private var fonteDaUltimaEmissao: CGPoint?
    @ObservationIgnored private var ultimaMexida: (ponto: CGPoint, t: Double)?
    @ObservationIgnored private var velocidadeDaFonte: CGVector = .zero
    @ObservationIgnored private(set) var agora: Double = 0
    @ObservationIgnored private var avisandoQueAcabou = false

    private static func relogio() -> Double { Date().timeIntervalSinceReferenceDate }

    // A fonte mudou de lugar (pode ser chamado a cada quadro de uma animação)
    func mover(para ponto: CGPoint) {
        let t = Self.relogio()
        if let ultima = ultimaMexida, t - ultima.t > 0.001 {
            let dt = CGFloat(t - ultima.t)
            let instantanea = CGVector(dx: (ponto.x - ultima.ponto.x) / dt, dy: (ponto.y - ultima.ponto.y) / dt)
            // Média suave: um quadro atrasado não vira um "tranco" na fumaça
            let peso = min(1, dt / 0.06)
            velocidadeDaFonte.dx += (instantanea.dx - velocidadeDaFonte.dx) * peso
            velocidadeDaFonte.dy += (instantanea.dy - velocidadeDaFonte.dy) * peso
        }
        ultimaMexida = (ponto, t)
        fonte = ponto
    }

    // A FONTE PEGA FOGO OU APAGA: uma baforada e depois um fio.
    // fio: por quanto tempo o fio fino continua (nil = até pararDeSoltar()).
    // forcaDoFio: opacidade do fio fino. intensidade: o tamanho da baforada.
    func baforada(fio duracaoDoFio: Double?, forcaDoFio: Double, intensidade: CGFloat = 1) {
        let t = Self.relogio()
        agora = max(agora, t)
        fonteDaUltimaEmissao = nil
        if reduzirMovimento {
            // Sem subir nem ondular: a fumaça aparece e some no lugar
            fios.append(FioDeFumaca(semente: .random(in: 0...100), largura: 6 * intensidade, alargamento: 6,
                                    subida: 4, turbulencia: 0, vida: 1.6, comeco: t, duracao: 0.5,
                                    forcaInicial: 0.35, forcaFinal: 0))
        } else {
            // A baforada: alguns fios largos que saem com força e somem rápido
            let quantos = intensidade >= 1 ? 3 : 2
            for i in 0..<quantos {
                let lado = CGFloat(i) - CGFloat(quantos - 1) / 2
                fios.append(FioDeFumaca(semente: .random(in: 0...100),
                                        largura: 3 * intensidade, alargamento: 14 * intensidade,
                                        subida: 75 * intensidade, turbulencia: 1.5,
                                        vida: 2.2, desvio: CGVector(dx: lado * 1.6, dy: 0),
                                        comeco: t, duracao: 0.7,
                                        forcaInicial: 0.5, forcaFinal: 0))
            }
            // O fio fino que continua
            fios.append(FioDeFumaca(semente: .random(in: 0...100), largura: 1.3, alargamento: 8,
                                    subida: 45, turbulencia: 1, vida: 3,
                                    comeco: t, duracao: duracaoDoFio,
                                    forcaInicial: forcaDoFio, forcaFinal: duracaoDoFio == nil ? forcaDoFio : 0))
        }
        emCena = true
    }

    // A fonte apagou ou saiu de cena: para de soltar. O que já saiu termina de subir e some.
    func pararDeSoltar() {
        for fio in fios { fio.emitindo = false }
    }

    // MARK: A física (chamada a cada quadro pelo desenho)

    func avancar(ate t: Double) {
        let dt = min(1.0 / 20, max(0, t - agora))
        agora = max(agora, t)
        guard dt > 0 else { return }
        let u = escala

        for fio in fios {
            // 1) Os pontos que já estão no ar
            let ondula = reduzirMovimento ? 0 : fio.turbulencia
            for i in fio.pontos.indices {
                var p = fio.pontos[i]
                let idade = t - p.nascimento
                let solta = CGFloat(min(1, idade / Self.tempoAteOndular))
                let vento = Self.vento(p.posicao, t, fio.semente, u) * ondula * solta * 60 * u
                let empuxo = reduzirMovimento ? 0 : Self.empuxo * u
                let freio = exp(-Self.arrasto * CGFloat(dt))
                p.velocidade.dx = p.velocidade.dx * freio + vento * CGFloat(dt)
                p.velocidade.dy = p.velocidade.dy * freio - empuxo * CGFloat(dt)
                p.posicao.x += p.velocidade.dx * CGFloat(dt)
                p.posicao.y += p.velocidade.dy * CGFloat(dt)
                fio.pontos[i] = p
            }
            // Os mais velhos estão no começo da lista
            while let primeiro = fio.pontos.first, t - primeiro.nascimento > fio.vida {
                fio.pontos.removeFirst()
            }

            // 2) Pontos novos saindo da fonte
            if let duracao = fio.duracao, t > fio.comeco + duracao { fio.emitindo = false }
            guard fio.emitindo, let fonte else { continue }
            let desvio = CGVector(dx: fio.desvio.dx * u, dy: fio.desvio.dy * u)
            let origem = CGPoint(x: fonte.x + desvio.dx, y: fonte.y + desvio.dy)
            let anterior = fonteDaUltimaEmissao.map { CGPoint(x: $0.x + desvio.dx, y: $0.y + desvio.dy) } ?? origem
            let intervalo = 1 / Self.pontosPorSegundo
            guard fio.proximaEmissao <= t else { continue }
            let quantos = min(6, Int((t - fio.proximaEmissao) / intervalo) + 1)
            let herdada = reduzirMovimento ? .zero : CGVector(dx: velocidadeDaFonte.dx * Self.heranca,
                                                              dy: velocidadeDaFonte.dy * Self.heranca)
            for j in 0..<quantos {
                // Se a fonte andou muito num quadro só, os pontos se espalham pelo caminho (sem buraco)
                let k = CGFloat(j + 1) / CGFloat(quantos)
                let lugar = CGPoint(x: anterior.x + (origem.x - anterior.x) * k,
                                    y: anterior.y + (origem.y - anterior.y) * k)
                fio.pontos.append(PontoDeFumaca(posicao: lugar,
                                                velocidade: CGVector(dx: herdada.dx, dy: herdada.dy - fio.subida * u),
                                                nascimento: fio.proximaEmissao,
                                                forca: fio.forca(em: fio.proximaEmissao)))
                fio.proximaEmissao += intervalo
            }
            if fio.proximaEmissao < t { fio.proximaEmissao = t }   // não acumula atraso
        }
        if let fonte { fonteDaUltimaEmissao = fonte }

        fios.removeAll { !$0.emitindo && $0.pontos.isEmpty }
        // Acabou a fumaça: avisa a tela para parar de desenhar (depois do quadro, não durante)
        if fios.isEmpty && emCena && !avisandoQueAcabou {
            avisandoQueAcabou = true
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.avisandoQueAcabou = false
                if self.fios.isEmpty { self.emCena = false }
            }
        }
    }

    // O vento: ondas suaves que dependem da altura e do tempo. Pontos vizinhos do mesmo fio
    // sentem quase o mesmo vento, então o fio faz curvas macias (e não fica "picotado").
    private static func vento(_ p: CGPoint, _ t: Double, _ s: Double, _ u: CGFloat) -> CGFloat {
        let y = Double(p.y / max(u, 0.01)), x = Double(p.x / max(u, 0.01))
        let onda = sin(y * 0.055 + t * 1.3 + s)
            + 0.6 * sin(y * 0.13 - t * 2.1 + s * 1.7)
            + 0.35 * sin(x * 0.09 + y * 0.05 + t * 2.9 + s * 2.3)
        return CGFloat(onda)
    }
}

// O DESENHO: um Canvas que preenche o espaço dado (as posições do motor são deste espaço)
struct DesenhoDaFumaca: View {
    let motor: MotorDeFumaca
    // ⚙️ Cor da fumaça
    var cor = Color(white: 0.86)

    var body: some View {
        TimelineView(.animation(paused: !motor.emCena)) { contexto in
            Canvas { gc, _ in
                motor.avancar(ate: contexto.date.timeIntervalSinceReferenceDate)
                let u = motor.escala
                // Halo largo e bem transparente (o "volume" da fumaça)
                gc.drawLayer { camada in
                    camada.addFilter(.blur(radius: 3.5 * u))
                    tracar(camada, larguraExtra: 2.4, opacidade: 0.3)
                }
                // O fio em si, com um desfoque leve
                gc.drawLayer { camada in
                    camada.addFilter(.blur(radius: 0.9 * u))
                    tracar(camada, larguraExtra: 1, opacidade: 0.8)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // Liga os pontos de cada fio com curvas que se encontram no meio entre um ponto e o próximo:
    // assim os pedaços se emendam sem buraco e sem sobrepor (a opacidade fica lisa).
    private func tracar(_ gc: GraphicsContext, larguraExtra: CGFloat, opacidade: Double) {
        let agora = motor.agora
        let u = motor.escala
        for fio in motor.fios {
            let p = fio.pontos
            guard p.count >= 2 else { continue }
            for i in p.indices {
                let ponto = p[i]
                let idade = agora - ponto.nascimento
                let resto = max(0, 1 - idade / fio.vida)
                let entrada = min(1, idade / 0.08)
                let alfa = ponto.forca * pow(resto, 1.6) * entrada * opacidade
                guard alfa > 0.004 else { continue }
                let inicio = i == 0 ? ponto.posicao : meio(p[i - 1].posicao, ponto.posicao)
                let fim = i == p.count - 1 ? ponto.posicao : meio(ponto.posicao, p[i + 1].posicao)
                var caminho = Path()
                caminho.move(to: inicio)
                caminho.addQuadCurve(to: fim, control: ponto.posicao)
                let largura = (fio.largura + fio.alargamento * CGFloat(idade)) * u * larguraExtra
                gc.stroke(caminho, with: .color(cor.opacity(alfa)),
                          style: StrokeStyle(lineWidth: largura, lineCap: .butt, lineJoin: .round))
            }
        }
    }

    private func meio(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
        CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
    }
}

// FUMAÇA DA VELA APAGANDO: a fonte fica parada na ponta do pavio.
// A vista ocupa o mesmo espaço da fumaça antiga (o resto da vela não sai do lugar);
// o desenho é maior e sobe além dela.
struct FumacaDaVela: View {
    var desde: Date
    var largura: CGFloat
    var fonte: CGPoint = .zero     // a ponta do pavio, a partir do meio da base desta vista

    @State private var motor = MotorDeFumaca()
    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento

    var body: some View {
        let w = largura * 8, h = largura * 9
        Color.clear
            .frame(width: largura, height: largura * 2.2)
            .overlay(alignment: .bottom) {
                DesenhoDaFumaca(motor: motor)
                    .frame(width: w, height: h)
            }
            // Recomeça sempre que a vela apaga de novo (a data muda). Só solta fumaça se a vela
            // acabou de apagar (abrir o app com a vela apagada há tempo não solta fumaça).
            .task(id: desde) {
                guard Date().timeIntervalSince(desde) < 1 else { return }
                motor.escala = largura / 50
                motor.reduzirMovimento = reduzirMovimento
                motor.mover(para: CGPoint(x: w / 2 + fonte.x, y: h + fonte.y))
                motor.baforada(fio: 3, forcaDoFio: 0.6, intensidade: 0.8)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

// Põe o fósforo no lugar e conta à fumaça onde a cabeça está A CADA QUADRO, também durante as
// animações (o caminho até o pavio, a mola de volta). Sem isto a fumaça pularia direto para o
// fim da animação, porque o estado já guarda o lugar final.
struct PosicaoAnimadaDoFosforo: ViewModifier, Animatable {
    var cabeca: CGPoint
    var deslocamentoY: CGFloat               // da cabeça até o meio da vista do fósforo
    var aoMudar: (CGPoint) -> Void

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(cabeca.x, cabeca.y) }
        set { cabeca = CGPoint(x: newValue.first, y: newValue.second) }
    }

    func body(content: Content) -> some View {
        aoMudar(cabeca)
        return content.position(x: cabeca.x, y: cabeca.y + deslocamentoY)
    }
}

#Preview("Fumaça da vela") {
    @Previewable @State var desde = Date()
    VStack(spacing: 40) {
        FumacaDaVela(desde: desde, largura: 50)
        Button("Apagar de novo") { desde = .now }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Cores.fundoEscuro)
}
