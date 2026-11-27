//  VelaView.swift
//  A vela: corpo de cera, enfeites, pavio, chama e fumaça (a fumaça fica em Fumaca.swift).
//  A vista fica "em pé" no chão: a base da vela é a parte de baixo da vista.

import SwiftUI

struct VelaView: View {
    var alturaCheia: CGFloat          // altura da vela inteira (já depende do tamanho escolhido)
    var largura: CGFloat
    var progresso: Double = 0         // 0 = inteira, 1 = acabou
    var acesa = false
    var destaque = false              // vela acesa no palco: ganha um contorno escuro para aparecer mais no cenário
    var apagouEm: Date? = nil         // para a fumaça
    var fumacaCurta = false           // a vela acabou: só um fiozinho de fumaça, sem baforada
    var movimento: Movimento? = nil   // para a chama ficar sempre para cima
    var enfeites: [Enfeite] = []
    var caidos: Set<UUID> = []
    var marcas: [Marca] = []
    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento

    static func espacoChama(largura: CGFloat) -> CGFloat { largura * 1.8 }

    // Onde fica o MEIO da chama, medido a partir do topo da cera.
    // Serve para quem precisa acertar um toque nela (apagar tocando na chama).
    static func centroDaChama(largura: CGFloat) -> CGPoint {
        let usa = arteExiste("velaCorpo")
        let s = largura / ArteVela.largura
        let altura = usa ? ArteVela.chamaAltura * s : largura * 1.2
        return CGPoint(x: usa ? ArteVela.chamaDesvioX * s : 0,
                       y: (usa ? ArteVela.chamaDentro * s : -largura * 0.12) - altura / 2)
    }

    static func alturaDaChama(largura: CGFloat) -> CGFloat {
        arteExiste("velaCorpo") ? ArteVela.chamaAltura * largura / ArteVela.largura : largura * 1.2
    }

    private var alturaCera: CGFloat { max(3, alturaCheia * CGFloat(1 - progresso)) }
    private var espacoChama: CGFloat { VelaView.espacoChama(largura: largura) }
    private var usaArte: Bool { arteExiste("velaCorpo") }
    private var escalaArte: CGFloat { largura / ArteVela.largura }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.clear

            // Alfinetes ATRÁS da cera: a agulha vai até o meio da vela e a própria vela esconde
            // o que está dentro. Mesmo com a borda da cera mudando enquanto ela derrete, o
            // alfinete continua parecendo espetado (não flutua nem escorrega de lado).
            alfinetesAtras

            if usaArte {
                corpoComArte
                    // Destaque da vela acesa: uma sombra escura bem rente, que separa a cera
                    // das árvores claras atrás dela (como as outras peças de papel)
                    .shadow(color: .black.opacity(destaque ? 0.45 : 0), radius: largura * 0.1)
            } else {
                // Corpo de cera provisório, com escorridos no topo
                ZStack(alignment: .top) {
                    RoundedRectangle(cornerRadius: largura * 0.08)
                        .fill(Cores.cera)
                        .overlay(RoundedRectangle(cornerRadius: largura * 0.08).stroke(Cores.tinta, lineWidth: 2))
                    Escorridos(largura: largura)
                        .frame(height: min(alturaCera, largura * 0.7))
                }
                .frame(width: largura, height: alturaCera)
            }

            // Furinhos e penduricalhos, na FRENTE da cera, espetados na borda de verdade dela
            // (a vela é meio torta: uma distância fixa do meio deixaria alguns flutuando).
            furinhosEPenduricalhos

            // Pavio (o da arte já vem desenhado), chama e fumaça
            ZStack(alignment: .bottom) {
                if !usaArte {
                    Capsule()
                        .fill(Cores.tinta)
                        .frame(width: 3, height: largura * 0.22)
                }
                if acesa {
                    Group {
                        if usaArte {
                            ChamaView(tamanho: ArteVela.chamaAltura * escalaArte,
                                      movimento: movimento, ancora: ArteVela.ancoraDaChama)
                                .offset(x: ArteVela.chamaDesvioX * escalaArte, y: ArteVela.chamaDentro * escalaArte)
                        } else {
                            ChamaView(tamanho: largura * 1.2, movimento: movimento)
                                .offset(y: -largura * 0.12)
                        }
                    }
                    .transition(.scale(scale: 0.2, anchor: .bottom).combined(with: .opacity))
                }
                if !acesa, let apagouEm {
                    // A fumaça sai da ponta do pavio (Fumaca.swift)
                    FumacaDaVela(desde: apagouEm, largura: largura,
                                 fonte: usaArte ? CGPoint(x: ArteVela.chamaDesvioX * escalaArte,
                                                          y: -ArteVela.pavio * escalaArte)
                                                : CGPoint(x: 0, y: -largura * 0.22),
                                 curta: fumacaCurta)
                }
            }
            .offset(y: -alturaCera)
        }
        .frame(width: largura * 3, height: alturaCheia + espacoChama, alignment: .bottom)
        // Acender tem que parecer instantâneo (~100 ms); apagar pode continuar macio (a fumaça cobre).
        .animation(.easeOut(duration: acesa ? 0.1 : 0.4), value: acesa)
    }

    // ⚙️ Quanto o alfinete anda para fora da vela enquanto cai (em larguras de vela)
    private static let afastamentoNaQueda: CGFloat = 0.4

    // Alfinetes que ainda não caíram, desenhados atrás da cera. Cada um tem o desenho da Georgia
    // e, atrás dele, um fio da cor da agulha que continua da ponta até o meio da vela.
    private var alfinetesAtras: some View {
        let larguraTotal = largura * 3
        let alturaTotal = alturaCheia + espacoChama
        let meioX = larguraTotal / 2
        let espessura = EnfeiteView.espessuraDaAgulha(largura: largura)
        return ZStack {
            ForEach(enfeites.filter { $0.tipo == .alfinete && !caidos.contains($0.id) }) { enfeite in
                let h = CGFloat(enfeite.altura) * alturaCheia
                let meio = VelaView.meioDoEnfeite(.alfinete, estilo: enfeite.desenho, lado: enfeite.lado,
                                                  altura: h, largura: largura, alturaCera: alturaCheia)
                let tamanho = EnfeiteView.tamanho(.alfinete, estilo: enfeite.desenho, largura: largura)
                let ponta = EnfeiteView.ponta(.alfinete, estilo: enfeite.desenho, largura: largura)
                // Onde fica a ponta do desenho, a partir do meio da vela (do lado direito é espelhado)
                let pontaX = meio.x + (enfeite.lado < 0 ? ponta.x - tamanho.width / 2
                                                        : tamanho.width / 2 - ponta.x)
                // A linha da agulha fica na altura onde ele espeta
                let linha = alturaTotal - h
                ZStack {
                    // O fio sobrepõe um pouco a ponta do desenho, para não aparecer emenda
                    Capsule()
                        .fill(EnfeiteView.corDaAgulha)
                        .frame(width: abs(pontaX) + espessura * 2, height: espessura)
                        .position(x: meioX + pontaX / 2, y: linha)
                    EnfeiteView(tipo: .alfinete, lado: enfeite.lado, largura: largura, estilo: enfeite.desenho)
                        .position(x: meioX + meio.x, y: linha + meio.y)
                }
                .transition(.asymmetric(insertion: .opacity, removal: quedaDoAlfinete(lado: enfeite.lado)))
            }
        }
        .frame(width: larguraTotal, height: alturaTotal)
        // A queda anima só os enfeites. Na vista inteira ela animava também a cera, que troca de
        // desenho no mesmo instante (a cera "piscava"), e a vela nova surgindo desde o toco.
        .animation(.easeIn(duration: Haptics.tempoQueda), value: caidos)
        .accessibilityHidden(true)
    }

    // Caindo, o alfinete sai para fora da vela enquanto desce, como se soltasse da cera.
    // Com Reduzir movimento ele só some.
    private func quedaDoAlfinete(lado: Double) -> AnyTransition {
        guard !reduzirMovimento else { return .opacity }
        let paraFora = (lado < 0 ? -1 : 1) * largura * Self.afastamentoNaQueda
        return .offset(x: paraFora, y: alturaCheia).combined(with: .opacity)
    }

    private var furinhosEPenduricalhos: some View {
        let larguraTotal = largura * 3
        let alturaTotal = alturaCheia + espacoChama
        let meioX = larguraTotal / 2
        return ZStack {
            // Furinhos de onde a pessoa já tentou espetar (um pouquinho para dentro da borda)
            ForEach(marcas) { marca in
                let h = CGFloat(marca.altura) * alturaCheia
                let borda = bordaDaCera(lado: marca.lado, altura: h)
                Circle()
                    .fill(Cores.tinta.opacity(0.45))
                    .frame(width: 5, height: 5)
                    .position(x: meioX + borda + (marca.lado < 0 ? 4 : -4), y: alturaTotal - h)
            }

            // Penduricalhos que ainda não caíram (os alfinetes ficam atrás da cera, em alfinetesAtras)
            ForEach(enfeites.filter { $0.tipo != .alfinete && !caidos.contains($0.id) }) { enfeite in
                let h = CGFloat(enfeite.altura) * alturaCheia
                let borda = meioX + bordaDaCera(lado: enfeite.lado, altura: h)
                let meio = VelaView.meioDoEnfeite(enfeite.tipo, estilo: enfeite.desenho, lado: enfeite.lado,
                                                  altura: h, largura: largura, alturaCera: alturaCheia)
                EnfeiteView(tipo: enfeite.tipo, lado: enfeite.lado, largura: largura, estilo: enfeite.desenho)
                    .position(x: meioX + meio.x, y: alturaTotal - h + meio.y)
                    // Só aparece o que está FORA da cera: a ponta da agulha fica escondida dentro
                    .mask(alignment: enfeite.lado < 0 ? .leading : .trailing) {
                        Rectangle().frame(width: max(0, enfeite.lado < 0 ? borda : larguraTotal - borda))
                    }
                    .transition(.asymmetric(insertion: .opacity,
                                            removal: .offset(y: alturaCheia).combined(with: .opacity)))
            }
        }
        .frame(width: larguraTotal, height: alturaTotal)
        .animation(.easeIn(duration: Haptics.tempoQueda), value: caidos)
    }

    // A borda é medida na vela INTEIRA (como na hora de espetar). Antes ela era medida na vela
    // derretendo: o desenho do corpo estica conforme a cera desce, a borda mudava um pouquinho
    // a cada instante e os enfeites ficavam escorregando de lado com a vela acesa.
    private func bordaDaCera(lado: Double, altura h: CGFloat) -> CGFloat {
        VelaView.bordaDaCera(lado: lado, altura: h, largura: largura, alturaCera: alturaCheia)
    }

    // Onde fica a borda da cera (x, em pontos, a partir do meio da vela) a "h" pontos acima da base.
    // Faz a mesma conta da montagem da vela (corpoComArte): a peça de cima tem altura fixa e o
    // corpo estica ou encolhe conforme o tamanho da vela.
    static func bordaDaCera(lado: Double, altura h: CGFloat, largura: CGFloat, alturaCera: CGFloat) -> CGFloat {
        let sinal: CGFloat = lado < 0 ? -1 : 1
        guard arteExiste("velaCorpo") else { return sinal * largura / 2 }
        let reserva = sinal * largura * 0.42
        let s = largura / ArteVela.largura
        let pixelParaPonto = ArteVela.k * s          // pixel do desenho da Georgia → ponto na tela
        let topo = (ArteVela.topoBaixo - ArteVela.corpoTopo) * s
        let inteiro = (ArteVela.corpoBaixo - ArteVela.corpoTopo) * s
        let liso = (ArteVela.corpoBaixo - ArteVela.topoBaixo) * s
        let escondido = ArteVela.escondido * s
        let distanciaDoTopo = alturaCera - h

        if distanciaDoTopo < topo {
            guard let linhas = PerfilDaVela.topo,
                  let px = PerfilDaVela.borda(linhas, fracao: max(0, distanciaDoTopo) / topo, lado: lado)
            else { return reserva }
            return px * pixelParaPonto
        }
        let corpo = max(1, alturaCera + escondido - topo)
        let alturaDesenho = liso > 0 ? corpo * inteiro / liso : corpo
        let y = (distanciaDoTopo - topo) + (alturaDesenho - corpo)
        guard let linhas = PerfilDaVela.corpo,
              let px = PerfilDaVela.borda(linhas, fracao: y / alturaDesenho, lado: lado)
        else { return reserva }
        return px * pixelParaPonto
    }

    // Onde fica o MEIO do desenho do enfeite, a partir do ponto (meio da vela, linha onde ele espeta).
    // A ponta da agulha entra um pouco na cera, bem na borda.
    static func meioDoEnfeite(_ tipo: TipoEnfeite, estilo: Int, lado: Double, altura h: CGFloat,
                              largura: CGFloat, alturaCera: CGFloat) -> CGPoint {
        let borda = bordaDaCera(lado: lado, altura: h, largura: largura, alturaCera: alturaCera)
        let tamanho = EnfeiteView.tamanho(tipo, estilo: estilo, largura: largura)
        let ponta = EnfeiteView.ponta(tipo, estilo: estilo, largura: largura)   // no desenho do lado esquerdo
        let enterrado = EnfeiteView.enterrado(tipo, estilo: estilo, largura: largura)
        let daPontaAoMeio = ponta.x - tamanho.width / 2
        let x = lado < 0
            ? borda + enterrado - daPontaAoMeio     // esquerda: a ponta aponta para a direita (para dentro)
            : borda - enterrado + daPontaAoMeio     // direita: o desenho é espelhado
        return CGPoint(x: x, y: tamanho.height / 2 - ponta.y)
    }

    // Vela da Georgia, montada com as DUAS peças que ela desenhou:
    //   "velaTopo"  = os escorridos e o pavio (sempre no alto, sempre do mesmo tamanho)
    //   "velaCorpo" = a vela inteira; aqui usamos só a parte LISA dela, esticada ou
    //                 encolhida para a vela ficar do tamanho escolhido.
    //
    // O pulo do gato é onde as duas se encontram. O desenho do corpo também tem os
    // escorridos no começo dele, então o corpo é encolhido de um jeito que a parte lisa
    // fique com a altura certa, e os escorridos dele são cortados fora por cima.
    // Assim a emenda cai SEMPRE no mesmo ponto do desenho — exatamente onde a Georgia
    // cortou as duas peças. Antes a emenda caía num lugar qualquer do corpo e só batia
    // certo na vela do tamanho máximo; por isso o topo ficava estranho nos outros tamanhos.
    //
    // Um pedaço da cera fica escondido atrás do suporte (por isso o "escondido").
    private var corpoComArte: some View {
        let s = escalaArte
        let larguraDesenho = ArteVela.larguraDesenho * s
        let escondido = ArteVela.escondido * s
        let topo = (ArteVela.topoBaixo - ArteVela.corpoTopo) * s        // a peça dos escorridos
        let inteiro = (ArteVela.corpoBaixo - ArteVela.corpoTopo) * s    // o desenho do corpo todo
        let liso = (ArteVela.corpoBaixo - ArteVela.topoBaixo) * s       // só a parte lisa dele

        let visivel = alturaCera + escondido
        let corpo = max(0, visivel - topo)
        // Encolhe o desenho todo na medida em que a parte lisa fique com "corpo" de altura
        let alturaDesenho = liso > 0 ? corpo * inteiro / liso : 0

        return VStack(spacing: 0) {
            if arteExiste(CeraView.quadros[0]) {
                // Topo liso da própria vela; a cera animada vai por cima (overlay abaixo)
                Image("velaCorpo")
                    .resizable()
                    .frame(width: larguraDesenho, height: inteiro)
                    .frame(width: larguraDesenho, height: topo, alignment: .top)
                    .clipped()
            } else {
                Image("velaTopo")
                    .resizable()
                    .frame(width: larguraDesenho, height: topo)
            }
            if corpo > 0 {
                Image("velaCorpo")
                    .resizable()
                    .frame(width: larguraDesenho, height: alturaDesenho)
                    .frame(width: larguraDesenho, height: corpo, alignment: .bottom)   // corta os escorridos de cima
                    .clipped()
            }
        }
        // Cera derretendo por cima do topo (os escorridos podem descer pelo corpo)
        .overlay(alignment: .top) {
            if arteExiste(CeraView.quadros[0]) {
                CeraView(progresso: progresso, acesa: acesa, escala: ArteVela.k * s,
                         fim: visivel / (ArteVela.k * s))
                    .frame(width: ArteVela.ceraLargura * s, height: ArteVela.ceraAltura * s)
                    .frame(width: larguraDesenho, height: 0, alignment: .top)
            }
        }
        // No fim da vela a cera fica mais baixa que os escorridos: aí eles vão sumindo
        // por baixo, derretendo dentro do suporte.
        .frame(width: larguraDesenho, height: visivel, alignment: .top)
        // Corta só em cima/embaixo: a cera é mais larga que o corpo e não pode perder as beiradas
        .mask { Rectangle().frame(width: larguraDesenho * 2) }
        .offset(y: escondido)
    }
}

// Escorridos de cera no topo da vela
private struct Escorridos: View {
    var largura: CGFloat
    var body: some View {
        HStack(alignment: .top, spacing: largura * 0.12) {
            ForEach([0.55, 0.3, 0.75, 0.4], id: \.self) { comprimento in
                Capsule()
                    .stroke(Cores.tinta.opacity(0.6), lineWidth: 1.5)
                    .frame(width: largura * 0.1, height: largura * CGFloat(comprimento))
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .clipped()
    }
}

// Alfinete (espetado de lado) ou penduricalho (estrelinha pendurada).
// O desenho é feito para o lado ESQUERDO da vela: cabeça para fora, agulha apontando para a vela.
// Os alfinetes são os da Georgia (estrela, coração e bolinha), deitados.
struct EnfeiteView: View {
    var tipo: TipoEnfeite
    var lado: Double = 1
    var largura: CGFloat
    var estilo: Int = 0

    // Medidas dos desenhos "alfinete1/2/3", em pixels da Georgia (mesma escala da vela).
    // ponta = onde a agulha termina; cabeca = de onde até onde vai a cabeça (de cima para baixo).
    private static let alfinetes: [(tamanho: CGSize, ponta: CGPoint, cabeca: ClosedRange<CGFloat>)] = [
        (CGSize(width: 143, height: 61), CGPoint(x: 135, y: 28.5), 6...54),   // estrela
        (CGSize(width: 153, height: 59), CGPoint(x: 147, y: 15), 7...50),     // coração
        (CGSize(width: 140, height: 38), CGPoint(x: 133, y: 18.5), 6...31),   // bolinha
    ]

    private static var usaArte: Bool { arteExiste("alfinete1") }

    // Medidas do desenho de um alfinete, em pixels da Georgia (usado nas almofadas do ateliê)
    static func desenhoDoAlfinete(_ estilo: Int) -> (tamanho: CGSize, ponta: CGPoint) {
        let m = medidas(estilo)
        return (m.tamanho, m.ponta)
    }
    private static func escala(_ largura: CGFloat) -> CGFloat { largura / ArteVela.largura * ArteVela.k }

    // Cor e grossura da agulha dos desenhos (lidas dos próprios alfinete1/2/3: um cinza quase
    // preto, com uns 4 pixels de grossura). Usadas no fio que continua a agulha dentro da vela.
    static let corDaAgulha = Color(red: 25 / 255, green: 28 / 255, blue: 29 / 255)
    static func espessuraDaAgulha(largura: CGFloat) -> CGFloat {
        usaArte ? 4 * escala(largura) : 2
    }
    private static func medidas(_ estilo: Int) -> (tamanho: CGSize, ponta: CGPoint, cabeca: ClosedRange<CGFloat>) {
        alfinetes[((estilo % alfinetes.count) + alfinetes.count) % alfinetes.count]
    }

    // Tamanho do desenho inteiro
    static func tamanho(_ tipo: TipoEnfeite, estilo: Int = 0, largura: CGFloat) -> CGSize {
        let haste = largura * 0.55
        switch tipo {
        case .alfinete:
            guard usaArte else { return CGSize(width: haste + 10, height: 10) }
            let m = medidas(estilo).tamanho, f = escala(largura)
            return CGSize(width: m.width * f, height: m.height * f)
        case .penduricalho:
            return CGSize(width: haste * 0.7 + 7, height: largura * 0.35 + 23)
        }
    }

    // Onde fica a ponta da agulha dentro do desenho (do canto de cima à esquerda)
    static func ponta(_ tipo: TipoEnfeite, estilo: Int = 0, largura: CGFloat) -> CGPoint {
        let t = tamanho(tipo, estilo: estilo, largura: largura)
        switch tipo {
        case .alfinete:
            guard usaArte else { return CGPoint(x: t.width, y: 5) }
            let p = medidas(estilo).ponta, f = escala(largura)
            return CGPoint(x: p.x * f, y: p.y * f)
        case .penduricalho:
            return CGPoint(x: t.width, y: 3.5)
        }
    }

    // Quanto da agulha fica enterrado na cera (o resto aparece)
    static func enterrado(_ tipo: TipoEnfeite, estilo: Int = 0, largura: CGFloat) -> CGFloat {
        switch tipo {
        case .alfinete:
            return usaArte ? tamanho(tipo, estilo: estilo, largura: largura).width * 0.22 : largura * 0.55 * 0.3
        case .penduricalho:
            return largura * 0.55 * 0.7 * 0.3
        }
    }

    // Altura do desenho inteiro
    static func alturaDesenho(_ tipo: TipoEnfeite, estilo: Int = 0, largura: CGFloat) -> CGFloat {
        tamanho(tipo, estilo: estilo, largura: largura).height
    }

    // Distância entre a parte de baixo do desenho e a linha do alfinete (onde ele espeta)
    static func alturaDoAlfinete(_ tipo: TipoEnfeite, estilo: Int = 0, largura: CGFloat) -> CGFloat {
        alturaDesenho(tipo, estilo: estilo, largura: largura) - ponta(tipo, estilo: estilo, largura: largura).y
    }

    // Quanto o desenho sobe acima da linha onde ele espeta...
    static func acima(_ tipo: TipoEnfeite, estilo: Int = 0, largura: CGFloat) -> CGFloat {
        ponta(tipo, estilo: estilo, largura: largura).y
    }

    // ...e quanto ele desce abaixo dela (o penduricalho fica pendurado, então desce bastante)
    static func abaixo(_ tipo: TipoEnfeite, estilo: Int = 0, largura: CGFloat) -> CGFloat {
        alturaDoAlfinete(tipo, estilo: estilo, largura: largura)
    }

    // O que conta para um enfeite não ficar EM CIMA do outro: só a cabeça espetada.
    // (Vale para todos os desenhos de alfinete: usa o maior deles.)
    static func ocupaAcima(_ tipo: TipoEnfeite, largura: CGFloat) -> CGFloat {
        guard tipo == .alfinete else { return 3.5 }
        guard usaArte else { return 5 }
        return (alfinetes.map { $0.ponta.y - $0.cabeca.lowerBound }.max() ?? 0) * escala(largura)
    }

    static func ocupaAbaixo(_ tipo: TipoEnfeite, largura: CGFloat) -> CGFloat {
        guard tipo == .alfinete else { return 3.5 }
        guard usaArte else { return 5 }
        return (alfinetes.map { $0.cabeca.upperBound - $0.ponta.y }.max() ?? 0) * escala(largura)
    }

    var body: some View {
        let haste = largura * 0.55
        let tamanho = EnfeiteView.tamanho(tipo, estilo: estilo, largura: largura)
        Group {
            switch tipo {
            case .alfinete:
                if EnfeiteView.usaArte {
                    Image("alfinete\(((estilo % 3) + 3) % 3 + 1)")
                        .resizable()
                        .frame(width: tamanho.width, height: tamanho.height)
                } else {
                    HStack(spacing: 0) {
                        Circle().fill(Cores.cortina).frame(width: 10, height: 10)
                        Capsule().fill(Cores.tinta.opacity(0.8)).frame(width: haste, height: 2)
                    }
                    .frame(width: tamanho.width, height: tamanho.height)
                }
            case .penduricalho:
                Arte("penduricalho") {
                    VStack(spacing: 0) {
                        HStack(spacing: 0) {
                            Circle().fill(Cores.dourado).frame(width: 7, height: 7)
                            Capsule().fill(Cores.tinta.opacity(0.8)).frame(width: haste * 0.7, height: 2)
                        }
                        Rectangle().fill(Cores.tinta.opacity(0.6)).frame(width: 1, height: largura * 0.35)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 3)
                        Estrela().fill(Cores.dourado)
                            .overlay(Estrela().stroke(Cores.tinta, lineWidth: 1))
                            .frame(width: 16, height: 16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, -5)
                    }
                    .frame(width: haste * 0.7 + 7)
                }
                .frame(width: tamanho.width, height: tamanho.height, alignment: .top)
            }
        }
        // O desenho é feito para o lado esquerdo; do lado direito espelhamos
        .scaleEffect(x: lado < 0 ? 1 : -1, y: 1)
        .accessibilityHidden(true)
    }
}

// MARK: - Borda da cera
//
// Onde fica a borda da vela em cada altura, lida dos próprios desenhos da Georgia
// ("velaTopo" e "velaCorpo"). A vela não é um retângulo: ela é meio torta e a cera de cima
// é mais larga. Os enfeites e os furinhos usam isso para ficarem na borda de verdade.
// A leitura é feita uma vez só (na primeira vez que precisa) e fica guardada.
enum PerfilDaVela {
    struct Linhas {
        let largura: CGFloat                                        // largura da imagem, em pixels
        let bordas: [(esquerda: CGFloat, direita: CGFloat)?]        // uma por linha (nil = linha vazia)
    }

    static let topo = ler("velaTopo")
    static let corpo = ler("velaCorpo")

    private static func ler(_ nome: String) -> Linhas? {
        #if canImport(UIKit)
        guard let imagem = UIImage(named: nome)?.cgImage else { return nil }
        let w = imagem.width, h = imagem.height
        guard w > 0, h > 0 else { return nil }
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        let desenhou = pixels.withUnsafeMutableBytes { bytes -> Bool in
            guard let contexto = CGContext(data: bytes.baseAddress, width: w, height: h,
                                           bitsPerComponent: 8, bytesPerRow: w * 4,
                                           space: CGColorSpaceCreateDeviceRGB(),
                                           bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return false }
            contexto.draw(imagem, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        guard desenhou else { return nil }

        var bordas: [(esquerda: CGFloat, direita: CGFloat)?] = []
        bordas.reserveCapacity(h)
        for y in 0..<h {
            let linha = y * w * 4
            var esquerda = -1
            for x in 0..<w where pixels[linha + x * 4 + 3] > 128 { esquerda = x; break }
            guard esquerda >= 0 else { bordas.append(nil); continue }
            var direita = esquerda
            for x in stride(from: w - 1, through: esquerda, by: -1) where pixels[linha + x * 4 + 3] > 128 {
                direita = x; break
            }
            bordas.append((CGFloat(esquerda), CGFloat(direita + 1)))
        }
        return Linhas(largura: CGFloat(w), bordas: bordas)
        #else
        return nil
        #endif
    }

    // Borda na altura "fracao" do desenho (0 = topo, 1 = fim), em pixels a partir do meio da imagem.
    // Se a linha estiver vazia, usa a linha com desenho mais perto.
    static func borda(_ linhas: Linhas, fracao: CGFloat, lado: Double) -> CGFloat? {
        let n = linhas.bordas.count
        guard n > 0, fracao.isFinite else { return nil }
        let alvo = min(n - 1, max(0, Int(fracao * CGFloat(n))))
        for distancia in 0..<n {
            for y in [alvo + distancia, alvo - distancia] where y >= 0 && y < n {
                if let b = linhas.bordas[y] {
                    return (lado < 0 ? b.esquerda : b.direita) - linhas.largura / 2
                }
            }
        }
        return nil
    }
}

// Chama em forma de gota que tremula. Se receber o Movimento, fica sempre para cima.
struct ChamaView: View {
    var tamanho: CGFloat
    var movimento: Movimento? = nil
    var ancora: UnitPoint = .bottom
    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento

    // A ponta vai para a direita, volta pelo centro e repete para a esquerda.
    private static let sequencia = [3, 1, 2, 1, 3, 6, 4, 5, 4, 6]

    var body: some View {
        TimelineView(.animation) { contexto in
            let t = contexto.date.timeIntervalSinceReferenceDate
            let imagem = quadroDaChama(em: t)
            let tremor = reduzirMovimento ? 0 : 0.06 * sin(t * 11) + 0.04 * sin(t * 17.3)
            let f = 1 + tremor
            let angulo = (movimento?.angulo ?? 0) + (reduzirMovimento ? 0 : 0.04 * sin(t * 7))

            ZStack(alignment: .bottom) {
                if arteExiste(imagem) {
                    Image(imagem)
                        .resizable()
                        .frame(width: tamanho * ArteVela.chamaLargura / ArteVela.chamaAltura, height: tamanho)
                } else {
                    Gota()
                        .fill(LinearGradient(colors: [Color(red: 1, green: 0.86, blue: 0.42),
                                                      Color(red: 0.96, green: 0.46, blue: 0.12)],
                                             startPoint: .top, endPoint: .bottom))
                        .frame(width: tamanho * 0.42, height: tamanho)
                    Gota()
                        .fill(Color(red: 1, green: 0.98, blue: 0.85))
                        .frame(width: tamanho * 0.2, height: tamanho * 0.45)
                        .padding(.bottom, tamanho * 0.04)
                }
            }
            .scaleEffect(x: 1 / sqrt(f), y: f, anchor: ancora)
            .rotationEffect(.radians(angulo), anchor: ancora)
        }
        .frame(width: tamanho, height: tamanho, alignment: .bottom)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func quadroDaChama(em t: TimeInterval) -> String {
        guard !reduzirMovimento else { return "velaChama" }
        let passo = Int(max(0, t) * ArteAnimada.fpsPadrao) % Self.sequencia.count
        let nome = "velaChama_\(Self.sequencia[passo])"
        return arteExiste(nome) ? nome : "velaChama"
    }
}

// Suporte (o prato da Georgia). Fica embaixo da vela e esconde a parte de baixo dela.
// As alças sobem acima da borda do prato, então o MEIO do desenho não fica logo abaixo da base:
// use desvioX/desvioY a partir do pé da vela (centroX, baseY).
struct SuporteView: View {
    var largura: CGFloat   // largura da VELA (o suporte segue a mesma escala)

    private static func escala(_ largura: CGFloat) -> CGFloat { largura / ArteVela.largura }
    static func altura(largura: CGFloat) -> CGFloat { PosicaoArte.suporte.height * escala(largura) }
    static func desvioX(largura: CGFloat) -> CGFloat { (PosicaoArte.suporte.midX - ArteVela.centroX) * escala(largura) }
    static func desvioY(largura: CGFloat) -> CGFloat { (PosicaoArte.suporte.midY - ArteVela.baseY) * escala(largura) }

    var body: some View {
        let s = SuporteView.escala(largura)
        Arte("velaSuporte") {
            VStack {
                Capsule().fill(Cores.papel).overlay(Capsule().stroke(Cores.tinta, lineWidth: 2))
                    .frame(width: largura * 1.9, height: 16)
                Spacer()
            }
        }
        .frame(width: PosicaoArte.suporte.width * s, height: PosicaoArte.suporte.height * s)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// O tamanho dos enfeites traduzido para "fração da altura da vela",
// que é como a VelaConfig raciocina na hora de empurrar um enfeite para não sobrepor.
extension TamanhoEnfeite {
    static func daVela(largura: CGFloat, alturaCheia: CGFloat) -> TamanhoEnfeite {
        let altura = max(alturaCheia, 1)
        func fracao(_ pontos: CGFloat) -> Double { Double(pontos / altura) }
        return TamanhoEnfeite(
            alfineteAcima: fracao(EnfeiteView.ocupaAcima(.alfinete, largura: largura)),
            alfineteAbaixo: fracao(EnfeiteView.ocupaAbaixo(.alfinete, largura: largura)),
            penduricalhoAcima: fracao(EnfeiteView.ocupaAcima(.penduricalho, largura: largura)),
            penduricalhoAbaixo: fracao(EnfeiteView.ocupaAbaixo(.penduricalho, largura: largura))
        )
    }
}

// MARK: - Previews
//
// A vela fica sempre em cima do suporte, como no palco: o suporte esconde o pé da vela.

// A vela mais curta, a do meio e a mais longa. Serve para conferir a emenda do topo em todos os tamanhos.
#Preview("VelaView: tamanhos") {
    let largura: CGFloat = 40
    HStack(alignment: .bottom, spacing: 100) {
        ForEach([0.0, 0.4, 1.0], id: \.self) { posicao in
            VStack(spacing: 0) {
                VelaView(alturaCheia: GeometriaVela.alturaCheia(posicao: posicao, alturaMaxima: 420),
                         largura: largura, acesa: true)
                    .overlay(alignment: .bottom) {
                        SuporteView(largura: largura)
                            .offset(x: SuporteView.desvioX(largura: largura),
                                    y: SuporteView.desvioY(largura: largura))
                    }
                    .padding(.bottom, SuporteView.altura(largura: largura) / 2 + SuporteView.desvioY(largura: largura))
                Text("\(VelaConfig.minutos(para: posicao)) min")
                    .adaFont(.caption)
                    .foregroundStyle(Cores.papel)
                    .padding(.top, 8)
            }
        }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Cores.fundoEscuro)
}

// Arraste o slider: a cera desce e cada enfeite cai quando a cera chega nele (mesma regra da Sessao).
// "Apagar" mostra a fumaça.
#Preview("VelaView: queimando") {
    @Previewable @State var progresso = 0.0
    @Previewable @State var acesa = true
    @Previewable @State var apagouEm: Date? = nil
    @Previewable @State var enfeites = [
        Enfeite(tipo: .alfinete, altura: 0.8, lado: -1),
        Enfeite(tipo: .penduricalho, altura: 0.6, lado: 1),
        Enfeite(tipo: .alfinete, altura: 0.35, lado: 1),
        Enfeite(tipo: .penduricalho, altura: 0.25, lado: -1),
    ]
    @Previewable @State var marcas = [Marca(altura: 0.5, lado: -1)]
    let largura: CGFloat = 60
    let caidos = Set(enfeites.filter { $0.altura >= 1 - progresso }.map(\.id))

    VStack {
        Spacer()
        VStack(spacing: 0) {
            VelaView(alturaCheia: 320, largura: largura, progresso: progresso, acesa: acesa,
                     apagouEm: apagouEm, enfeites: enfeites, caidos: caidos, marcas: marcas)
                .overlay(alignment: .bottom) {
                    SuporteView(largura: largura)
                        .offset(x: SuporteView.desvioX(largura: largura),
                                y: SuporteView.desvioY(largura: largura))
                }
                .padding(.bottom, SuporteView.altura(largura: largura) / 2 + SuporteView.desvioY(largura: largura))
        }
        Spacer()
        VStack {
            Slider(value: $progresso, in: 0...1) { Text("Progresso da vela") }
            Button(acesa ? "Apagar" : "Acender") {
                if acesa { apagouEm = .now }
                acesa.toggle()
            }
            .buttonStyle(.borderedProminent)
            .tint(Cores.tinta)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding()
    }
    .frame(maxWidth: .infinity)
    .background(Cores.fundoEscuro)
}

// Só aparece na vela provisória (quando "velaCorpo" não está no Assets)
#Preview("Provisório: Escorridos", traits: .sizeThatFitsLayout) {
    Escorridos(largura: 80)
        .frame(width: 80, height: 56)
        .background(Cores.cera)
        .padding(30)
        .background(Cores.fundoEscuro)
}

// Em cima: lado esquerdo da vela. Embaixo: lado direito (espelhado).
#Preview("EnfeiteView", traits: .sizeThatFitsLayout) {
    HStack(alignment: .top, spacing: 40) {
        ForEach(TipoEnfeite.allCases, id: \.self) { tipo in
            VStack(spacing: 20) {
                EnfeiteView(tipo: tipo, lado: -1, largura: 60)
                EnfeiteView(tipo: tipo, lado: 1, largura: 60)
                Text(tipo.nome).adaFont(.caption)
            }
        }
    }
    .padding(30)
    .background(Cores.papel)
}

#Preview("ChamaView", traits: .sizeThatFitsLayout) {
    HStack(alignment: .bottom, spacing: 30) {
        ChamaView(tamanho: 40)
        ChamaView(tamanho: 80)
        ChamaView(tamanho: 140)
    }
    .padding(30)
    .background(Cores.fundoEscuro)
}


#Preview("SuporteView", traits: .sizeThatFitsLayout) {
    SuporteView(largura: 80)
        .padding(30)
        .background(Cores.fundoEscuro)
}
