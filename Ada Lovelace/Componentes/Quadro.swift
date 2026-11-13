//  Quadro.swift
//  A arte da Georgia foi desenhada num quadro de 1290 × 2796 pixels (tela inteira do iPhone).
//  Cada desenho foi recortado e guardamos ONDE ele ficava no quadro.
//  O Quadro converte essas posições para a tela de qualquer aparelho (iPhone ou iPad).

import SwiftUI
import Foundation

struct Quadro {
    static let largura: CGFloat = 1290
    static let altura: CGFloat = 2796

    let escala: CGFloat
    let origem: CGPoint

    // tela: tamanho da tela inteira. deslocamento: para usar dentro de uma área que não começa no canto.
    init(tela: CGSize, deslocamento: CGPoint = .zero) {
        escala = min(tela.width / Quadro.largura, tela.height / Quadro.altura)
        origem = CGPoint(x: (tela.width - Quadro.largura * escala) / 2 + deslocamento.x,
                         y: (tela.height - Quadro.altura * escala) / 2 + deslocamento.y)
    }

    // Quadro para usar dentro de um GeometryReader que respeita a área segura
    init(geo: GeometryProxy) {
        let i = geo.safeAreaInsets
        self.init(tela: CGSize(width: geo.size.width + i.leading + i.trailing,
                               height: geo.size.height + i.top + i.bottom),
                  deslocamento: CGPoint(x: -i.leading, y: -i.top))
    }

    func x(_ v: CGFloat) -> CGFloat { origem.x + v * escala }
    func y(_ v: CGFloat) -> CGFloat { origem.y + v * escala }
}

// Onde cada camada fica no quadro original (em pixels da arte)
enum PosicaoArte {
    private static func r(_ x0: CGFloat, _ y0: CGFloat, _ x1: CGFloat, _ y1: CGFloat) -> CGRect {
        CGRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0)
    }
    static let tenda = r(0, 0, 1290, 2725)
    static let lua = r(264, 442, 1025, 1237)
    static let picadeiro = r(3, 2152, 1290, 2643)
    static let suporte = r(469, 2542, 825, 2770)
}

// Medidas da vela da arte (em pixels da arte)
enum ArteVela {
    static let largura: CGFloat = 230        // largura do corpo
    static let centroX: CGFloat = 634
    static let corpoTopo: CGFloat = 1083     // topo do desenho (ponta do pavio)
    static let corpoBaixo: CGFloat = 2689    // fim do desenho (escondido atrás do suporte)
    static let topoBaixo: CGFloat = 1330     // até onde vão os escorridos (recorte "velaTopo")
    static let baseY: CGFloat = 2542         // onde a vela "nasce" (topo do suporte)
    static let alturaMaxima: CGFloat = 1459  // da base até o pavio, com a vela no tamanho máximo
    static let chamaDentro: CGFloat = 22     // quanto a chama entra no pavio
    static let chamaLargura: CGFloat = 107
    static let chamaAltura: CGFloat = 247
    static let chamaDesvioX: CGFloat = -6.5  // a chama fica um pouquinho à esquerda do centro
}

// ARTE ANIMADA (quadro a quadro)
//
// O movimento "de boneco de papel" (balançar, tremular) continua sendo feito no código.
// Isto aqui é para a animação DESENHADA dentro da peça: o olho do passarinho piscando,
// uma bandeirinha tremulando, uma boca abrindo.
//
// COMO A GEORGIA MANDA:
//   - Um PNG por quadro, com fundo transparente, numerados a partir de 1:
//         passarinho_1, passarinho_2, passarinho_3…
//     (a peça parada continua valendo: se existir só "passarinho", ele é usado e pronto)
//   - A versão de sombra segue o mesmo esquema, com "sombra" antes do número:
//         passarinhosombra_1, passarinhosombra_2…
//   - TODOS os quadros da mesma peça precisam ter EXATAMENTE o mesmo tamanho em pixels
//     e o desenho na mesma posição dentro do quadro. Se um quadro vier maior ou deslocado,
//     a peça "pula" na tela. (No Procreate: mesma seleção de recorte para todos.)
//   - Manda o recorte da peça, não o canvas inteiro de 1290 × 2796.
//
// O RITMO quem desenha é ela: são 12 quadros por segundo, então 4 quadros = 1/3 de segundo.
// Para uma piscada de vez em quando, use a "espera" na tabela abaixo: a animação toca,
// depois segura o primeiro quadro por alguns segundos e recomeça.
enum ArteAnimada {
    static let fpsPadrao: Double = 12

    // Ritmo de cada peça. Só precisa entrar aqui quem quer algo diferente do padrão.
    // Exemplo de piscada: toca os quadros e fica 3,5 s de olho aberto antes de repetir.
    //     "passarinho": (fps: 12, espera: 3.5)
    static let ritmo: [String: (fps: Double, espera: Double)] = [:]

    // Quantos quadros existem no Assets. A conta é feita uma vez e guardada.
    private static var contagem: [String: Int] = [:]

    static func quadros(_ nome: String) -> Int {
        if let n = contagem[nome] { return n }
        var n = 0
        while arteExiste("\(nome)_\(n + 1)") { n += 1 }
        contagem[nome] = n
        return n
    }

    // O nome da imagem que deve aparecer agora.
    // fase: para duas peças iguais não piscarem exatamente juntas.
    static func quadroAtual(_ nome: String, t: Double, fase: Double) -> String {
        let n = quadros(nome)
        guard n > 1 else { return n == 1 ? "\(nome)_1" : nome }

        let r = ritmo[semSombra(nome)] ?? (fps: fpsPadrao, espera: 0)
        let fps = max(1, r.fps)
        let animacao = Double(n) / fps
        let ciclo = animacao + max(0, r.espera)
        let dentro = (t + fase).truncatingRemainder(dividingBy: ciclo)

        // Durante a espera, fica no primeiro quadro
        let i = dentro < animacao ? min(Int(dentro * fps), n - 1) : 0
        return "\(nome)_\(i + 1)"
    }

    // "passarinhosombra" → "passarinho" (o ritmo é o mesmo da peça e da sombra dela)
    private static func semSombra(_ nome: String) -> String {
        nome.hasSuffix("sombra") ? String(nome.dropLast(6)) : nome
    }
}

// Uma imagem que pode ser parada ou animada quadro a quadro — quem decide é o Assets.
struct ImagemAnimada: View {
    let nome: String
    var t: Double = 0
    var fase: Double = 0

    var body: some View {
        Image(ArteAnimada.quadroAtual(nome, t: t, fase: fase))
            .resizable()
    }
}

// Um desenho recortado, colocado no lugar certo da tela
struct Camada: View {
    let nome: String
    let retangulo: CGRect
    let quadro: Quadro
    var giro: Double = 0
    var pivo: UnitPoint = .center
    var tremor: (escala: CGFloat, dx: CGFloat, opacidade: Double) = (1, 0, 1)   // só nas sombras
    var t: Double = 0        // relógio da cena, para a animação desenhada
    var fase: Double = 0     // para as peças não animarem todas juntas

    var body: some View {
        ImagemAnimada(nome: nome, t: t, fase: fase)
            .frame(width: retangulo.width * quadro.escala, height: retangulo.height * quadro.escala)
            .rotationEffect(.radians(giro), anchor: pivo)
            .scaleEffect(tremor.escala, anchor: .bottom)
            .offset(x: tremor.dx)
            .opacity(tremor.opacidade)
            .position(x: quadro.x(retangulo.midX), y: quadro.y(retangulo.midY))
    }
}

// As camadas do cenário (normais ou as versões de sombra): tenda, a faixa infinita
// com as peças novas da Georgia (lua e passarinho) e o picadeiro.
// As SOMBRAS andam junto com as peças (mesma conta, mesmo ritmo)
// e ainda tremulam devagarinho por causa da chama.
struct CenaArte: View {
    var quadro: Quadro
    var mostrarPersonagens: Bool
    var sombra = false
    var congelado = false   // durante a transição de zoom tudo para, para o movimento ficar liso

    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento

    var body: some View {
        // Na home (sem personagens) normalmente nada se mexe, e aí a animação fica pausada
        // para não gastar bateria. Mas se alguma peça tiver animação desenhada (um olho
        // piscando, por exemplo), ela precisa continuar rodando também na home.
        // Nas sombras, mostrarPersonagens é sempre true, então o tremor da chama continua.
        TimelineView(.animation(minimumInterval: 1 / 30,
                                paused: reduzirMovimento || congelado
                                        || (!mostrarPersonagens && !CenaArte.temArteAnimada))) { contexto in
            let t = reduzirMovimento ? 0 : contexto.date.timeIntervalSinceReferenceDate
            ZStack {
                camada("tenda", PosicaoArte.tenda, t: t, indice: 0)
                // A lua antiga saiu: no lugar dela passam as peças novas da Georgia (lua e passarinho).
                // Elas só aparecem com a vela acesa (somem devagar quando apaga).
                FaixaInfinitaView(quadro: quadro, t: t, sombra: sombra)
                    .offset(x: sombra && !reduzirMovimento ? CenaArte.tremor(t: t, indice: 1).dx : 0)
                    .opacity(mostrarPersonagens ? 1 : 0)
                // Os acrobatas saíram do cenário (pedido do time). As imagens continuam no Assets.
                camada("picadeiro", PosicaoArte.picadeiro, t: t, indice: 4)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func camada(_ nome: String, _ r: CGRect, t: Double, indice: Double,
                        giro: Double = 0, pivo: UnitPoint = .center) -> some View {
        Camada(nome: sombra ? CenaArte.nomeDaSombra(nome) : CenaArte.nomeDaArte(nome),
               retangulo: r, quadro: quadro, giro: giro, pivo: pivo,
               tremor: sombra && !reduzirMovimento ? CenaArte.tremor(t: t, indice: indice) : (1, 0, 1),
               t: t,
               // A peça e a sombra dela usam a MESMA fase, para piscarem juntas
               fase: indice * 0.37)
    }

    // As peças do cenário, na ordem em que são desenhadas
    static let pecas = ["tenda", "picadeiro"]

    // Tem alguma peça com animação desenhada? (a conta é feita uma vez e guardada)
    private static var cacheArteAnimada: Bool?

    static var temArteAnimada: Bool {
        if let c = cacheArteAnimada { return c }
        // (A faixa infinita não entra aqui: ela só aparece com a vela acesa, e aí a cena
        // já está rodando. Com a vela apagada, a cena para e não gasta bateria.)
        let tem = pecas.contains { ArteAnimada.quadros(nomeDaArte($0)) > 1 }
        cacheArteAnimada = tem
        return tem
    }

    // Respiração da chama nas sombras: bem lenta e bem leve, só para a parede não ficar morta.
    // (Era rápida demais e cansava a vista — as contas abaixo são ~4x mais lentas e mais suaves.)
    static func tremor(t: Double, indice: Double) -> (escala: CGFloat, dx: CGFloat, opacidade: Double) {
        let a = sin(t * 1.7 + indice * 1.7) * 0.6 + sin(t * 2.9 + indice * 2.3) * 0.4
        let b = sin(t * 1.3 + indice * 2.9) * 0.6 + sin(t * 2.3 + indice * 0.7) * 0.4
        let c = sin(t * 1.1 + indice * 1.3) * 0.5 + sin(t * 0.7 + indice * 3.1) * 0.5
        return (1 + 0.005 * CGFloat(a), 0.7 * CGFloat(b), 0.94 + 0.06 * c)
    }

    // Nomes das imagens no Assets
    static func nomeDaArte(_ nome: String) -> String {
        nome == "picadeiro" ? "picadero" : nome
    }

    static func nomeDaSombra(_ nome: String) -> String {
        nome == "picadeiro" ? "picadeirosombra" : nome + "sombra"
    }
}

// MARK: - Previews

// Se a Georgia mandar os quadros "tenda_1", "tenda_2"…, esta preview já mostra a animação.
// Por enquanto só existe a peça parada, então ela aparece sem se mexer.
// (As peças novas, lua e passarinho, usam outro sistema: veja CenarioAnimado.swift.)
#Preview("ImagemAnimada", traits: .sizeThatFitsLayout) {
    TimelineView(.animation) { contexto in
        ImagemAnimada(nome: "tenda", t: contexto.date.timeIntervalSinceReferenceDate)
            .scaledToFit()
            .frame(height: 300)
    }
    .padding()
    .background(Cores.fundoClaro)
}

// Duas peças soltas, cada uma no lugar dela no quadro. O picadeiro está girado de leve.
// (Os acrobatas saíram do cenário; a lua antiga continua no Assets só para esta preview.)
#Preview("Camada") {
    GeometryReader { geo in
        let quadro = Quadro(tela: geo.size)
        ZStack {
            Camada(nome: "lua", retangulo: PosicaoArte.lua, quadro: quadro)
            Camada(nome: "picadero", retangulo: PosicaoArte.picadeiro, quadro: quadro,
                   giro: 0.05, pivo: .bottom)
        }
    }
    .ignoresSafeArea()
    .background(Cores.fundoClaro)
}

#Preview("CenaArte") {
    GeometryReader { geo in
        CenaArte(quadro: Quadro(tela: geo.size), mostrarPersonagens: true)
    }
    .ignoresSafeArea()
    .background(Cores.fundoClaro)
}

#Preview("CenaArte: sem personagens") {
    GeometryReader { geo in
        CenaArte(quadro: Quadro(tela: geo.size), mostrarPersonagens: false)
    }
    .ignoresSafeArea()
    .background(Cores.fundoEscuro)
}

// As sombras com os mesmos efeitos do teatro de sombras (opacidade, borrão e maiores)
#Preview("CenaArte: sombras") {
    GeometryReader { geo in
        CenaArte(quadro: Quadro(tela: geo.size), mostrarPersonagens: true, sombra: true)
            .opacity(0.7)
            .blur(radius: 2.5)
            .scaleEffect(1.15, anchor: .bottom)
    }
    .ignoresSafeArea()
    .background(Cores.papel)
}
