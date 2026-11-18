//  Floresta.swift
//  O cenário novo da Georgia: a floresta, montada igual ao mockup dela (IMG_3976).
//
//  COMO FOI MONTADO
//  A Georgia desenhou a floresta numa tela DEITADA de 2732 × 2048 (a tela do iPad deitado).
//  Todas as medidas aqui estão nessa tela ("pixels da Georgia"). Ela é encaixada pela ALTURA:
//    - iPad: aparece a floresta inteira (deitado) e ela fica PARADA; só o céu se mexe.
//    - iPhone (em pé): aparece um pedaço e uma "CÂMERA" passa devagar de um lado para o outro:
//      TUDO anda junto, na mesma velocidade — fundo, árvores, arbustos, estrelas, sol, lua,
//      nuvens e passarinhos (pedido da Georgia). Sol, lua, nuvens e passarinhos ainda têm o
//      caminho próprio deles por cima disso.
//  Com a vela APAGADA a floresta não aparece (o palco fica escuro); ela surge ao acender.
//
//  Camadas, de trás para a frente (igual ao mockup):
//    fundo (céu + silhuetas bem apagadas) → árvores azul-escuras → árvores cinza (com contorno)
//    → estrelas → SOL e LUA (eclipse) → nuvens → arbustos → passarinhos
//
//  A HISTÓRIA dura 10 minutos (a vela mais curta) e recomeça igual, em loop (RelogioDaHistoria).
//  Ela só anda com a vela acesa. O sol vem da direita e a lua da esquerda; eles só se encontram
//  no ECLIPSE, aos 5 minutos (a cena do mockup). Nuvens e passarinhos passam em sentidos
//  contrários, em alturas diferentes ("quase encontros").
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
        var sombra: CamadaDaSombra? = nil   // em qual camada ela faz sombra no teatro (nil = não faz)
    }

    // Cores do mockup: as peças vêm claras e a Georgia escureceu para a noite
    static let azulNoite = Color(red: 0.34, green: 0.32, blue: 0.50)      // árvores do fundo
    static let cinzaNoite = Color(red: 0.80, green: 0.76, blue: 0.80)     // árvores da frente
    static let arbustoEscuro = Color(red: 0.40, green: 0.44, blue: 0.58)  // arbustos de trás
    static let arbustoClaro = Color(red: 0.80, green: 0.82, blue: 0.95)   // arbustos da frente

    static let fundo = Peca(nome: "florestaFundo", x: 0, y: 0, w: 2732, h: 2048)   // o céu de fundo não faz sombra

    static let arvores: [Peca] = [
        Peca(nome: "florestaFundoArvores2", x: 42, y: 660, w: 2522, h: 1381,
             tinta: azulNoite, sombra: .arvoresDeTras),
        Peca(nome: "florestaFundoArvores1", x: 42, y: 408, w: 2655, h: 1598,
             tinta: cinzaNoite, sombra: .arvoresDaFrente)
    ]

    // A Georgia mandou dois arbustos; do lado direito eles se repetem espelhados (como no mockup)
    static let arbustos: [Peca] = [
        Peca(nome: "florestaArbusto1", x: 0, y: 1426, w: 1158, h: 622, tinta: arbustoEscuro, sombra: .arbustos),
        Peca(nome: "florestaArbusto1", x: 1574, y: 1426, w: 1158, h: 622, tinta: arbustoEscuro, espelho: true,
             sombra: .arbustos),
        Peca(nome: "florestaArbusto2", x: 474, y: 1691, w: 1144, h: 357, tinta: arbustoClaro, sombra: .arbustos),
        Peca(nome: "florestaArbusto2", x: 1114, y: 1691, w: 1144, h: 357, tinta: arbustoClaro, espelho: true,
             sombra: .arbustos)
    ]

    // MARK: Céu

    // Estrelas: no protótipo da Georgia elas SOBEM E DESCEM bastante (do céu até o meio da mata),
    // cada uma no seu ritmo, quase sem andar para o lado. Também piscam devagar.
    // (centro "y" = meio do caminho; "subida" = quanto sobe e desce para cada lado; pixels da Georgia)
    struct Estrela {
        let nome: String
        let x: CGFloat, y: CGFloat, altura: CGFloat
        let fase: Double
        var subida: CGFloat = 380
    }

    static let estrelas: [Estrela] = [
        Estrela(nome: "florestaEstrela1", x: 730, y: 620, altura: 175, fase: 0, subida: 420),
        Estrela(nome: "florestaEstrela2", x: 195, y: 820, altura: 135, fase: 1.7, subida: 380),
        Estrela(nome: "florestaEstrela1", x: 2085, y: 700, altura: 146, fase: 3.1, subida: 400),
        Estrela(nome: "florestaEstrela2", x: 2460, y: 640, altura: 120, fase: 4.4, subida: 360),
        Estrela(nome: "florestaEstrela2", x: 1915, y: 980, altura: 105, fase: 5.2, subida: 330),
        Estrela(nome: "florestaEstrela2", x: 1180, y: 560, altura: 90, fase: 2.6, subida: 360),
        Estrela(nome: "florestaEstrela1", x: 980, y: 900, altura: 120, fase: 0.9, subida: 400)
    ]

    // Peça que anda no céu (sol, lua, nuvem, passarinho)
    struct Andante {
        let peca: PecaAnimada
        let altura: CGFloat     // altura da peça, pixels da Georgia
        let y: CGFloat          // centro
        let caminho: Caminho
        var balanco: CGFloat = 0
        var fase: Double = 0
        var ondula: CGFloat = 0      // sobe e desce enquanto anda (passarinhos), pixels da Georgia

        var largura: CGFloat { altura * peca.peca.width / peca.peca.height }
    }

    // Os dois jeitos de andar. Os dois fecham a conta certinho no ciclo de 10 minutos.
    enum Caminho {
        // Atravessa a cena e dá a volta por fora: passa em "x" no instante "quando" (segundos do ciclo),
        // "voltas" vezes por ciclo, para a direita (sentido 1) ou para a esquerda (sentido -1).
        case atravessa(x: CGFloat, quando: Double, voltas: Int, sentido: CGFloat)
        // Vai e volta devagar em volta de "x" (nuvens). "fase" de 0 a 1 = em que ponto do ciclo começa.
        case vaiEVolta(x: CGFloat, amplitude: CGFloat, fase: Double)
    }

    // A volta de quem atravessa: a floresta inteira + uma folga de cada lado
    // (a peça some antes de dar a volta, inclusive com a câmera do iPhone andando)
    static let folga: CGFloat = 560
    static var volta: CGFloat { largura + 2 * folga }

    // SOL E LUA: começam escondidos dos lados, vão se aproximando e se encontram no
    // ECLIPSE no meio do ciclo (5 min), bem quando a câmera do iPhone passa pelo centro.
    // Depois se separam e somem; aos 10 min a história recomeça.
    // ⚙️ Um pouco mais altos que no mockup, para a lua não passar atrás da chama da vela.
    static let sol = Andante(peca: CenarioNovo.sol, altura: 732, y: 650,
                             caminho: .atravessa(x: 1462, quando: 300, voltas: 1, sentido: -1),
                             balanco: 8, fase: 1.3)
    static let lua = Andante(peca: CenarioNovo.lua, altura: 763, y: 647,
                             caminho: .atravessa(x: 1349, quando: 300, voltas: 1, sentido: 1),
                             balanco: 8, fase: 0)

    // NUVENS: no protótipo elas ATRAVESSAM a cena devagar, umas para cada lado, em alturas diferentes
    // (uma volta a cada 10 min, espalhadas no tempo para nunca ficar sem nuvem)
    static let nuvens: [Andante] = [
        Andante(peca: CenarioNovo.nuvem3, altura: 184, y: 330,
                caminho: .atravessa(x: 1366, quando: 120, voltas: 1, sentido: -1), balanco: 5, fase: 0.4),
        Andante(peca: CenarioNovo.nuvem2, altura: 144, y: 980,
                caminho: .atravessa(x: 1366, quando: 270, voltas: 1, sentido: 1), balanco: 5, fase: 1.1),
        Andante(peca: CenarioNovo.nuvem1, altura: 229, y: 1316,
                caminho: .atravessa(x: 1366, quando: 420, voltas: 1, sentido: -1), balanco: 5, fase: 2.5),
        Andante(peca: CenarioNovo.nuvem3, altura: 191, y: 560,
                caminho: .atravessa(x: 1366, quando: 560, voltas: 1, sentido: 1), balanco: 5, fase: 3.2)
    ]

    // PASSARINHOS: um alto, outro baixo, em sentidos contrários (nunca na faixa do sol e da lua).
    // Cruzam a cena 2 vezes por ciclo e se "quase encontram" no meio aos 2min30 e aos 7min30.
    static let passarinhos: [Andante] = [
        Andante(peca: CenarioNovo.passarinho, altura: 300, y: 290,
                caminho: .atravessa(x: 1366, quando: 150, voltas: 2, sentido: 1), balanco: 18, fase: 0.7,
                ondula: 110),
        Andante(peca: CenarioNovo.passarinho2, altura: 300, y: 1330,
                caminho: .atravessa(x: 1366, quando: 150, voltas: 2, sentido: -1), balanco: 16, fase: 2.1,
                ondula: 120)
    ]

    // Onde está o centro da peça no instante "relogio" (segundos do ciclo), em x da Georgia
    static func x(_ a: Andante, relogio: Double) -> CGFloat {
        switch a.caminho {
        case let .atravessa(x0, quando, voltas, sentido):
            let velocidade = Double(sentido) * Double(volta) * Double(voltas) / RelogioDaHistoria.ciclo
            let andou = Double(x0 + folga) + velocidade * (relogio - quando)
            let naVolta = andou.truncatingRemainder(dividingBy: Double(volta))
            return CGFloat(naVolta < 0 ? naVolta + Double(volta) : naVolta) - folga
        case let .vaiEVolta(x0, amplitude, fase):
            return x0 + amplitude * CGFloat(sin(2 * .pi * (relogio / RelogioDaHistoria.ciclo + fase)))
        }
    }

    // Frequência que fecha o ciclo: "n" voltas completas em 10 minutos (balanços, estrelas…)
    static func onda(_ n: Double, _ relogio: Double, fase: Double = 0) -> Double {
        sin(2 * .pi * n * relogio / RelogioDaHistoria.ciclo + fase)
    }
}

// O RELÓGIO DA HISTÓRIA
// A história do cenário dura 10 minutos (o tempo da vela mais curta) e recomeça igualzinha.
// Ela só anda com a vela ACESA: pausa quando a vela apaga e volta do zero com uma vela nova.
// Assim a vela de 10 min mostra a história exatamente uma vez; as maiores repetem.
@MainActor
enum RelogioDaHistoria {
    // ⚙️ Duração da história, em segundos
    static let ciclo: Double = 600

    private static var acumulado: TimeInterval = 0
    private static var acesaDesde: Date?

    static func acender(agora: Date = Date()) {
        if acesaDesde == nil { acesaDesde = agora }
    }

    static func pausar(agora: Date = Date()) {
        guard let desde = acesaDesde else { return }
        acumulado += max(0, agora.timeIntervalSince(desde))
        acesaDesde = nil
    }

    static func zerar() {
        acumulado = 0
        acesaDesde = nil
    }

    // Em que ponto da história estamos (0 a 600 segundos)
    static func tempo(em data: Date) -> Double {
        let total = acumulado + (acesaDesde.map { max(0, data.timeIntervalSince($0)) } ?? 0)
        return total.truncatingRemainder(dividingBy: ciclo)
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
    var camada: CamadaDaSombra? = nil   // no teatro: desenha só as sombras desta camada (nil = todas)

    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento

    // No cenário tudo aparece. Na sombra, só o que é da camada pedida.
    private func mostra(_ c: CamadaDaSombra?) -> Bool {
        guard sombra else { return true }
        guard let c else { return false }
        return camada == nil || camada == c
    }

    var body: some View {
        // O relógio da história (10 min, em loop, só anda com a vela acesa). O cenário e as
        // sombras usam o mesmo, então andam juntos. Com "Reduzir movimento", tudo fica parado
        // no eclipse (a cena do mockup).
        let relogio = reduzirMovimento ? RelogioDaHistoria.ciclo / 2
            : RelogioDaHistoria.tempo(em: Date(timeIntervalSinceReferenceDate: t))
        // A câmera (só no iPhone): uma ida e volta por ciclo, passando pelo centro aos 0 e 5 min
        let onda = CGFloat(Floresta.onda(1, relogio))
        let camera = reduzirMovimento ? 0 : Floresta.amplitudeDoDeslize(quadro) * onda

        ZStack {
            if !sombra { peca(Floresta.fundo) }
            ForEach(Floresta.arvores.indices, id: \.self) { i in
                let p = Floresta.arvores[i]
                if mostra(p.sombra) { peca(p) }
            }
            if mostra(.ceu) {
                estrelas(relogio)
                andante(Floresta.sol, relogio)
                andante(Floresta.lua, relogio)      // na frente do sol: é ela que faz o eclipse
                ForEach(Floresta.nuvens.indices, id: \.self) { i in andante(Floresta.nuvens[i], relogio) }
            }

            if mostra(.arbustos) {
                ForEach(Floresta.arbustos.indices, id: \.self) { i in peca(Floresta.arbustos[i]) }
            }

            if mostra(.ceu) {
                ForEach(Floresta.passarinhos.indices, id: \.self) { i in andante(Floresta.passarinhos[i], relogio) }
            }
        }
        // A CÂMERA: o mundo inteiro anda junto (cenário e sombras)
        .offset(x: camera)
        .opacity(acesa || sombra ? 1 : 0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // Uma peça parada (fundo, árvores, arbustos). Quem anda é a câmera (o mundo inteiro).
    private func peca(_ p: Floresta.Peca) -> some View {
        let x = Floresta.noQuadro(x: p.x + p.w / 2)
        let y = Floresta.noQuadro(y: p.y + p.h / 2)
        return Image(p.nome)
            .resizable()
            .frame(width: p.w * Floresta.escala * quadro.escala, height: p.h * Floresta.escala * quadro.escala)
            .scaleEffect(x: p.espelho ? -1 : 1, y: 1)
            .colorMultiply(sombra ? .black : p.tinta)
            .position(x: quadro.x(x), y: quadro.y(y))
    }

    // Uma peça do céu andando (sol, lua, nuvem, passarinho)
    private func andante(_ a: Floresta.Andante, _ relogio: Double) -> some View {
        // Balancinho de boneco de papel + (passarinhos) o voo ondulado: sobe e desce 12 vezes por ciclo
        let sobe = reduzirMovimento ? 0 : a.balanco * CGFloat(Floresta.onda(57, relogio, fase: a.fase * 4))
            + a.ondula * CGFloat(Floresta.onda(12, relogio, fase: a.fase))
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
                let brilho = reduzirMovimento ? 1 : 0.7 + 0.3 * Floresta.onda(86, relogio, fase: e.fase)
                let tamanho = e.altura * Floresta.escala * quadro.escala * CGFloat(0.94 + 0.06 * brilho)
                // Sobe e desce: 2 idas e voltas a cada 10 min (como no protótipo)
                let flutua = reduzirMovimento ? 0 : e.subida * CGFloat(Floresta.onda(2, relogio, fase: e.fase))
                Image(e.nome)
                    .resizable()
                    .scaledToFit()
                    .frame(width: tamanho, height: tamanho)
                    .rotationEffect(.degrees(reduzirMovimento ? 0 : 6 * Floresta.onda(19, relogio, fase: e.fase)))
                    .opacity(sombra ? 1 : brilho)   // a sombra da estrela não pisca
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

// AS SOMBRAS EM CAMADAS (regra física do teatro de sombras)
// Quanto mais PERTO DA PAREDE um boneco está, mais nítida e menor é a sombra dele.
// Quanto mais PERTO DA CHAMA, mais borrada, maior e mais pesada (vira uma massa escura).
// Pela referência da Georgia: o céu fica perto da parede (nítido) e a mata perto da chama.
// Elas vêm em ordem: primeiro a que fica mais perto da parede.
enum CamadaDaSombra: CaseIterable {
    case ceu, arvoresDeTras, arvoresDaFrente, arbustos

    // ⚙️ Borrão (em pontos, numa tela de iPhone; no iPad cresce junto com a tela)
    var borrao: CGFloat {
        switch self {
        case .ceu: 5
        case .arvoresDeTras: 12
        case .arvoresDaFrente: 16
        case .arbustos: 18
        }
    }

    // ⚙️ Quão escura é a sombra
    var opacidade: Double {
        switch self {
        case .ceu: 0.62
        case .arvoresDeTras: 0.45
        case .arvoresDaFrente: 0.58
        case .arbustos: 0.75
        }
    }

    // ⚙️ Tamanho da sombra na parede, comparado com o cenário (como na referência da Georgia:
    // o céu fica pequeno, lá em cima; a mata vira uma massa que sobe do chão até o meio da tela).
    // Quem está mais perto da chama fica maior.
    var escala: CGFloat {
        switch self {
        case .ceu: 0.5
        case .arvoresDeTras: 0.5
        case .arvoresDaFrente: 0.58
        case .arbustos: 0.75
        }
    }

    // ⚙️ De onde a camada encolhe (fração da altura da tela): o céu encolhe em volta do alto
    // da tela (fica lá em cima); a mata encolhe para o chão (fica embaixo, perto da caixa).
    var ancoraY: CGFloat {
        switch self {
        case .ceu: 0.40
        default: 1.0
        }
    }

    // Onde o alto do céu (eclipse) vai parar depois de encolher (fração da altura da tela)
    static var topoDoCeu: CGFloat {
        CamadaDaSombra.ceu.ancoraY + (Floresta.topoDasSombras - CamadaDaSombra.ceu.ancoraY) * CamadaDaSombra.ceu.escala
    }
}

