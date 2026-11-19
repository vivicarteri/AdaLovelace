//  Floresta.swift
//  O cenário novo da Georgia: a floresta, montada igual ao mockup dela (IMG_3976).
//
//  COMO FOI MONTADO
//  A Georgia desenhou a floresta numa tela DEITADA de 2732 × 2048 (a tela do iPad deitado).
//  Todas as medidas aqui estão nessa tela ("pixels da Georgia"). Ela é encaixada pela ALTURA:
//    - iPad: aparece a floresta inteira (deitado) e ela fica PARADA; só o céu se mexe.
//    - iPhone: a mata e as estrelas formam um rolo contínuo. Os astros atravessam a
//      área visível e as nuvens e os pássaros seguem os próprios percursos.
//  Com a vela APAGADA a floresta não aparece (o palco fica escuro); ela surge ao acender.
//
//  Camadas, de trás para a frente (igual ao mockup):
//    fundo (céu + silhuetas bem apagadas) → árvores azul-escuras → árvores cinza (com contorno)
//    → estrelas → SOL e LUA (eclipse) → nuvens → arbustos → passarinhos
//
//  A história recomeça em loop ao terminar o roteiro.
//  Ela só anda com a vela acesa. O sol vem da direita e a lua da esquerda; eles só se encontram
//  no ECLIPSE, no meio do roteiro (a cena do mockup). Nuvens e passarinhos passam em sentidos
//  contrários, cada um com seu tempo em cena.
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

    static let bosqueDeTras = Peca(nome: "florestaFundoArvores2", x: 80, y: 1047, w: 1816, h: 994,
             tinta: azulNoite, sombra: .arvoresDeTras)
    static let bosqueDaFrente = Peca(nome: "florestaFundoArvores1", x: 893, y: 1051, w: 1586, h: 955,
             tinta: cinzaNoite, sombra: .arvoresDaFrente)

    // Composição estática do mockup.
    static let arvores: [Peca] = [
        bosqueDeTras,
        Peca(nome: "florestaFundoArvores1", x: 893 - 1586, y: 1051, w: 1586, h: 955,
             tinta: cinzaNoite, espelho: true, sombra: .arvoresDaFrente),
        bosqueDaFrente
    ]

    // No rolo do iPhone, árvores individuais completam o espaço entre os dois bosques.
    static let arvoresDoRolo: [Peca] = [
        bosqueDeTras,
        Peca(nome: "florestaArvore3Cinza", x: 1910, y: 1138, w: 295, h: 862,
             tinta: azulNoite, sombra: .arvoresDeTras),
        Peca(nome: "florestaArvore1Cinza", x: 2246, y: 1174, w: 299, h: 830,
             tinta: azulNoite, sombra: .arvoresDeTras),
        Peca(nome: "florestaArvore2Cinza", x: 2514, y: 1198, w: 207, h: 808,
             tinta: azulNoite, sombra: .arvoresDeTras),
        Peca(nome: "florestaArvore2", x: 42, y: 1090, w: 233, h: 910,
             tinta: cinzaNoite, sombra: .arvoresDaFrente),
        Peca(nome: "florestaArvore3", x: 338, y: 1038, w: 330, h: 964,
             tinta: cinzaNoite, sombra: .arvoresDaFrente),
        Peca(nome: "florestaArvore1", x: 622, y: 1112, w: 320, h: 890,
             tinta: cinzaNoite, sombra: .arvoresDaFrente),
        bosqueDaFrente,
        Peca(nome: "florestaArvore1", x: 2376, y: 1056, w: 343, h: 952,
             tinta: cinzaNoite, espelho: true, sombra: .arvoresDaFrente)
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

    // Centro e amplitude em pixels da arte. O movimento inteiro fica acima das copas.
    struct Estrela {
        let nome: String
        let x: CGFloat, y: CGFloat, altura: CGFloat
        let fase: Double
        // As estrelas do meio atravessam entre os eclipses. A passagem pode cruzar o fim do ciclo.
        var passagem: Range<Double>? = nil
    }

    static let estrelas: [Estrela] = [
        Estrela(nome: "florestaEstrela1", x: 730, y: 148, altura: 138, fase: 0),
        Estrela(nome: "florestaEstrela2", x: 1620, y: 105, altura: 112, fase: 1.7),
        Estrela(nome: "florestaEstrela1", x: 2460, y: 155, altura: 120, fase: 3.1)
    ]

    // As passagens se alternam em altura com as nuvens e aves que estão em cena.
    static let estrelasEmTravessia: [Estrela] = [
        Estrela(nome: "florestaEstrela2", x: centroX, y: 450, altura: 116, fase: 5.2, passagem: 560..<645),
        Estrela(nome: "florestaEstrela1", x: centroX, y: 903, altura: 132, fase: 0.9, passagem: 32..<104),
        Estrela(nome: "florestaEstrela2", x: centroX, y: 492, altura: 112, fase: 1.7, passagem: 95..<210),
        Estrela(nome: "florestaEstrela2", x: centroX, y: 563, altura: 100, fase: 2.6, passagem: 390..<476),
        Estrela(nome: "florestaEstrela1", x: centroX, y: 815, altura: 126, fase: 4.4, passagem: 462..<568)
    ]

    // Peça que anda no céu (sol, lua, nuvem, passarinho)
    struct Andante {
        let peca: PecaAnimada
        let altura: CGFloat     // altura da peça, pixels da Georgia
        let y: CGFloat          // centro
        let passagem: Range<Double>  // segundos do ciclo, da entrada até a saída
        let sentido: CGFloat
        var balanco: CGFloat = 0
        var fase: Double = 0
        var ondula: CGFloat = 0      // ondulação do percurso, em pixels da Georgia

        var arco: (subida: CGFloat, pontoAlto: Double)? = nil

        func centroY(_ t: Double, parado: Bool = false) -> CGFloat {
            var centro = y
            if let arco {
                // Uma curva longa entre duas passagens pelo alto, no ritmo próprio da peça.
                let descida = (1 - cos(4 * .pi * (t - arco.pontoAlto) / RelogioDaHistoria.ciclo)) / 2
                centro += arco.subida * descida * descida
            }
            guard !parado else { return centro }
            return centro + balanco * Floresta.onda(57, t, fase: fase * 4)
                + ondula * Floresta.onda(12, t, fase: fase)
        }

        var largura: CGFloat { altura * peca.peca.width / peca.peca.height }
    }

    // O par divide a mesma passagem: entra aos 3min30 e sai aos 6min30 do roteiro.
    static let passagemDosAstros = 210.0..<390.0

    // A distância entre os centros diminui à soma das velocidades dos astros.
    // As bordas se tocam quando essa distância chega à soma das meias larguras.
    static func tempoDoCenario(_ tempo: Double, larguraVisivel: CGFloat, larguraDosAstros: CGFloat) -> Double {
        let passagem = passagemDosAstros.upperBound - passagemDosAstros.lowerBound
        let percursoRelativo = 2 * larguraVisivel + larguraDosAstros
        let sobreposicao = percursoRelativo > 0 ? passagem * larguraDosAstros / percursoRelativo : 0
        let inicio = passagemDosAstros.lowerBound + (passagem - sobreposicao) / 2
        let duracaoLenta = sobreposicao * 4
        let atraso = duracaoLenta - sobreposicao
        let fase = tempo.truncatingRemainder(dividingBy: RelogioDaHistoria.ciclo + atraso)
        let tempoEmSobreposicao = min(duracaoLenta, max(0, fase - inicio))
        return fase - tempoEmSobreposicao * 0.75
    }

    static func astros(no quadro: Quadro) -> (sol: Andante, lua: Andante) {
        let escalaNaTela = escala * quadro.escala
        let fimDaBarra = MedidasBarraDoPalco.margemSuperior + MedidasBarraDoPalco.diametro
        let topo = max(altura * topoDasSombras, (fimDaBarra + 8 - quadro.origem.y) / max(escalaNaTela, 0.001))
        // Os astros terminam acima das copas. Reservamos espaço para o balanço nas duas extremidades.
        let balanco: CGFloat = 8
        let alturaLua = max(0, 968 - topo - 2 * balanco)
        let centro = topo + balanco + alturaLua / 2
        let sol = Andante(peca: CenarioNovo.sol, altura: alturaLua * 0.96, y: centro,
                          passagem: passagemDosAstros, sentido: -1,
                          balanco: balanco, fase: 1.3)
        let lua = Andante(peca: CenarioNovo.lua, altura: alturaLua, y: centro,
                          passagem: passagemDosAstros, sentido: 1,
                          balanco: balanco)
        return (sol, lua)
    }

    // As nuvens atravessam em momentos diferentes, com curvas abertas pelo meio do céu.
    // A nuvem baixa passa uma vez antes do eclipse e outra depois.
    static let nuvens: [Andante] = [
        Andante(peca: CenarioNovo.nuvem3, altura: 158, y: 333,
                passagem: 52..<104, sentido: -1,
                balanco: 4, fase: 0.4, arco: (300, 70)),
        Andante(peca: CenarioNovo.nuvem2, altura: 136, y: 325,
                passagem: 156..<210, sentido: 1,
                balanco: 5, fase: 1.1, arco: (420, 32)),
        Andante(peca: CenarioNovo.nuvem1, altura: 144, y: 790,
                passagem: 104..<156, sentido: -1,
                fase: 2.5, ondula: 32),
        Andante(peca: CenarioNovo.nuvem1, altura: 144, y: 790,
                passagem: 390..<462, sentido: -1,
                fase: 2.5, ondula: 32),
        Andante(peca: CenarioNovo.nuvem3, altura: 176, y: 342,
                passagem: 462..<534, sentido: 1,
                balanco: 4, fase: 3.2, arco: (280, 500))
    ]

    static let passarinhos: [Andante] = [
        Andante(peca: CenarioNovo.passarinho, altura: 214, y: 362,
                passagem: 0..<52, sentido: 1,
                balanco: 4, fase: 0.7, ondula: 5, arco: (325, 175)),
        Andante(peca: CenarioNovo.passarinho2, altura: 202, y: 358,
                passagem: 534..<600, sentido: -1,
                balanco: 4, fase: 2.1, ondula: 5, arco: (350, 420))
    ]

    // O primeiro e o último ponto deixam a peça inteira fora da área visível.
    static func x(_ a: Andante, relogio: Double, larguraVisivel: CGFloat) -> CGFloat? {
        guard a.passagem.contains(relogio) else { return nil }
        let duracao = a.passagem.upperBound - a.passagem.lowerBound
        let progresso = (relogio - a.passagem.lowerBound) / duracao
        return centroX + a.sentido * (progresso - 0.5) * (larguraVisivel + a.largura)
    }

    // Frequência que fecha o ciclo: "n" voltas completas em 10 minutos (balanços, estrelas…)
    static func onda(_ n: Double, _ relogio: Double, fase: Double = 0) -> Double {
        sin(2 * .pi * n * relogio / RelogioDaHistoria.ciclo + fase)
    }
}

// O RELÓGIO DA HISTÓRIA
// O roteiro tem 600 segundos de animação.
// Ela só anda com a vela ACESA: pausa quando a vela apaga e volta do zero com uma vela nova.
// A vista converte o tempo acumulado em tempo de cena conforme a largura visível.
@MainActor
enum RelogioDaHistoria {
    // ⚙️ Duração da história, em segundos
    static let ciclo: Double = 600

    private static var acumulado: TimeInterval = 0
    private static var acesaDesde: Date?
    #if DEBUG
    private static var velocidade: Double = 1
    #else
    private static let velocidade: Double = 1
    #endif

    static func acender(agora: Date = Date()) {
        guard acesaDesde == nil else { return }
        #if DEBUG
        atualizarVelocidadeDeTeste(agora: agora)
        #endif
        acesaDesde = agora
    }

    static func pausar(agora: Date = Date()) {
        guard acesaDesde != nil else { return }
        acumulado = tempo(em: agora)
        acesaDesde = nil
    }

    static func zerar() {
        acumulado = 0
        acesaDesde = nil
    }

    // Tempo acumulado de reprodução desde o início da história.
    static func tempo(em data: Date) -> Double {
        let decorrido = acesaDesde.map { max(0, data.timeIntervalSince($0)) } ?? 0
        return acumulado + decorrido * velocidade
    }

    #if DEBUG
    static func atualizarVelocidadeDeTeste(agora: Date = Date()) {
        let padrao = UserDefaults.standard
        let novaVelocidade = padrao.bool(forKey: Chaves.acelerarCenario)
            ? min(20, max(2, padrao.double(forKey: Chaves.velocidadeDoCenario)))
            : 1
        guard novaVelocidade != velocidade else { return }

        // Guarda a posição no ritmo anterior antes de começar a contar no novo.
        if acesaDesde != nil {
            acumulado = tempo(em: agora)
            acesaDesde = agora
        }
        velocidade = novaVelocidade
    }
    #endif
}

// A floresta inteira, desenhada dentro da cena (que já tem relógio e Quadro).
// sombra: só as silhuetas pretas (sem o fundo).
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
        // O relógio da história só anda com a vela acesa. O cenário e as
        // sombras usam o mesmo, então andam juntos. Com "Reduzir movimento", tudo fica parado
        // no eclipse (a cena do mockup).
        let tempo = RelogioDaHistoria.tempo(em: Date(timeIntervalSinceReferenceDate: t))
        GeometryReader { geo in
            let larguraVisivel = geo.size.width / max(Floresta.escala * quadro.escala, 0.001)
            let astros = Floresta.astros(no: quadro)
            let relogio = reduzirMovimento ? RelogioDaHistoria.ciclo / 2
                : Floresta.tempoDoCenario(tempo, larguraVisivel: larguraVisivel,
                                         larguraDosAstros: astros.sol.largura + astros.lua.largura)
            ZStack {
                let emRolagem = Floresta.desliza && !reduzirMovimento
                let arvores = emRolagem ? Floresta.arvoresDoRolo : Floresta.arvores
                if !sombra {
                    faixa(relogio, larguraVisivel: larguraVisivel) { peca(Floresta.fundo) }
                }
                faixa(relogio, larguraVisivel: larguraVisivel, alternaEspelho: !emRolagem) {
                    ForEach(arvores.indices, id: \.self) { i in
                        let p = arvores[i]
                        if mostra(p.sombra) { peca(p) }
                    }
                    if mostra(.ceu) { estrelas() }
                }
                if mostra(.ceu) {
                    estrelasEmTravessia(relogio, larguraVisivel)
                    andante(astros.sol, relogio, larguraVisivel)
                    andante(astros.lua, relogio, larguraVisivel)
                    ForEach(Floresta.nuvens.indices, id: \.self) { i in
                        andante(Floresta.nuvens[i], relogio, larguraVisivel)
                    }
                }
                if mostra(.arbustos) {
                    faixa(relogio, larguraVisivel: larguraVisivel) {
                        ForEach(Floresta.arbustos.indices, id: \.self) { i in peca(Floresta.arbustos[i]) }
                    }
                }
                if mostra(.ceu) {
                    ForEach(Floresta.passarinhos.indices, id: \.self) { i in
                        andante(Floresta.passarinhos[i], relogio, larguraVisivel)
                    }
                }
            }
        }
        .opacity(acesa || sombra ? 1 : 0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var escala: CGFloat { Floresta.escala * quadro.escala }

    // Cada par de painéis fecha uma volta. O espelho une bordas idênticas.
    private func faixa<Conteudo: View>(_ relogio: Double, larguraVisivel: CGFloat,
                                       alternaEspelho: Bool = true,
                                       @ViewBuilder conteudo: () -> Conteudo) -> some View {
        let largura = Floresta.largura * escala
        let voltas = Floresta.desliza && !reduzirMovimento ? 2 * relogio / RelogioDaHistoria.ciclo : 0
        let painel = Int(floor(voltas))
        let fracao = voltas - Double(painel)
        let vizinhos = max(1, Int(ceil(larguraVisivel / Floresta.largura)))
        let centro = quadro.x(Floresta.noQuadro(x: Floresta.centroX))
        let painelDeArte = ZStack { conteudo() }
        return ZStack {
            ForEach(-vizinhos...vizinhos, id: \.self) { i in
                painelDeArte
                    .frame(width: largura, height: Floresta.altura * escala)
                    .clipped()
                    .scaleEffect(x: alternaEspelho && !(painel + i).isMultiple(of: 2) ? -1 : 1, y: 1)
                    .position(x: centro + (CGFloat(i) - fracao) * largura,
                              y: quadro.y(Quadro.altura / 2))
            }
        }
    }

    private func peca(_ p: Floresta.Peca) -> some View {
        return Image(p.nome)
            .resizable()
            .frame(width: p.w * Floresta.escala * quadro.escala, height: p.h * Floresta.escala * quadro.escala)
            .scaleEffect(x: p.espelho ? -1 : 1, y: 1)
            .colorMultiply(sombra ? .black : p.tinta)
            .position(x: (p.x + p.w / 2) * escala, y: (p.y + p.h / 2) * escala)
    }

    // Uma peça do céu andando (sol, lua, nuvem, passarinho)
    @ViewBuilder
    private func andante(_ a: Floresta.Andante, _ relogio: Double, _ larguraVisivel: CGFloat) -> some View {
        if let x = Floresta.x(a, relogio: relogio, larguraVisivel: larguraVisivel) {
            let y = a.centroY(relogio, parado: reduzirMovimento)
            // Os quadros da peça seguem o tempo real, inclusive durante o eclipse.
            PecaAnimadaView(peca: a.peca, t: t, fase: a.fase, sombra: sombra)
                .frame(width: a.largura * escala, height: a.altura * escala)
                .position(x: quadro.x(Floresta.noQuadro(x: x)), y: quadro.y(Floresta.noQuadro(y: y)))
                .clipped()
        }
    }

    // Estrelas: pulsando e flutuando devagarinho
    private func estrelas() -> some View {
        ZStack {
            ForEach(Floresta.estrelas.indices, id: \.self) { i in
                let e = Floresta.estrelas[i]
                estrela(e)
                    .position(x: e.x * escala, y: e.y * escala)
            }
        }
    }

    private func estrelasEmTravessia(_ relogio: Double, _ larguraVisivel: CGFloat) -> some View {
        ForEach(Floresta.estrelasEmTravessia.indices, id: \.self) { i in
            let e = Floresta.estrelasEmTravessia[i]
            if let passagem = e.passagem {
                let tempo = relogio < passagem.lowerBound ? relogio + RelogioDaHistoria.ciclo : relogio
                if passagem.contains(tempo) {
                    let progresso = (tempo - passagem.lowerBound) / (passagem.upperBound - passagem.lowerBound)
                    // A estrela inteira sai de cena mesmo no maior tamanho da pulsação.
                    let x = e.x + (0.5 - progresso) * (larguraVisivel + e.altura * 1.06)
                    estrela(e)
                        .position(x: quadro.x(Floresta.noQuadro(x: x)), y: quadro.y(Floresta.noQuadro(y: e.y)))
                        .clipped()
                }
            }
        }
    }

    private func estrela(_ e: Floresta.Estrela) -> some View {
        let pulso = reduzirMovimento ? 0 : (1 + Floresta.onda(86, t, fase: e.fase)) / 2
        let tamanho = e.altura * escala * (1 + 0.06 * pulso)
        let flutua = reduzirMovimento ? 0 : 8 * Floresta.onda(48, t, fase: e.fase)
        return Image(e.nome)
            .resizable()
            .scaledToFit()
            .frame(width: tamanho, height: tamanho)
            .offset(y: flutua * escala)
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

