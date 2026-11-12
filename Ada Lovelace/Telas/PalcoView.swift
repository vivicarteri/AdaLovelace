//  PalcoView.swift
//  A tela principal: a home E a vela queimando (é a mesma tela, muda a luz e os botões).
//
//  Antes de acender:            personalizar, acender (caixa de fósforos) e configurações
//  Depois de acender:           descartar, zoom out e configurações
//  Apagou antes de acabar:      descartar, acender, zoom out e configurações
//  Depois de acabar:            descartar e configurações (a cortina desce)

import SwiftUI
import TipKit

struct PalcoView: View {
    @EnvironmentObject private var sessao: Sessao
    var abrirConfiguracoes: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento

    @State private var personalizando = false
    @State private var cortinaFechada = false
    @State private var trocando = false        // animação de descartar
    @State private var afundando = false       // vela descendo pelo alçapão
    @State private var fumacaDaTroca: Date?

    // Transições
    @State private var trocandoCena = false     // bloqueia toques durante as animações
    @State private var camera: CGFloat = 0      // 0 = vista de fora, 1 = câmera colada na caixa (palco na tela toda)
    @State private var aberturaCaixa: CGFloat = 0   // cortina da caixa: 0 = fechada, 1 = aberta
    @State private var cameraAtiva = false      // mostra a vista de fora durante a animação
    @State private var mostrarMiniatura = false // palco em miniatura dentro da caixa (só na animação)
    @State private var cortinaTela = false      // cortina que desce para trocar de tela (personalização)
    @State private var mostrarBotoes = true     // os botões saem de cena durante o zoom
    @State private var caixaAberta: CGFloat = CaixaFosforoView.emRepouso   // gaveta da caixa de fósforos

    // Fósforo: 1) toca na caixa → o fósforo sai  2) risca na caixa → acende  3) arrasta até o pavio
    private enum EtapaFosforo { case guardado, fora, aceso }
    @State private var etapa: EtapaFosforo = .guardado
    @State private var posFosforo: CGPoint = .zero   // onde está a cabeça do fósforo
    @State private var inicioArraste: CGPoint?
    @State private var riscado: CGFloat = 0
    @State private var ultimoPontoRisco: CGPoint?

    private var tamanhoFosforo: CGFloat { 70 }

    // ⚙️ Quanto tempo o fósforo aceso dura antes de apagar sozinho (como um de verdade).
    // Depois disso ele volta para a caixa e a pessoa pega outro.
    private let duracaoDoFosforo: TimeInterval = 10

    var body: some View {
        GeometryReader { geo in
            let g = LayoutPalco(geo: geo)
            let caixa = MedidasCaixa(tela: geo.size)
            ZStack {
                if sessao.foraDaCaixa || cameraAtiva {
                    // Vista de fora. A "câmera" (EfeitoCamera) aproxima ou afasta da caixa.
                    TeatroSombrasView(entrar: entrarNaCaixa,
                                      abrirConfiguracoes: abrirConfiguracoes,
                                      aberturaCaixa: aberturaCaixa,
                                      conteudoDaCaixa: mostrarMiniatura ? AnyView(dentroDaCaixa(g, miniatura: true)) : nil,
                                      mostrarBotoes: mostrarBotoes,
                                      congelado: trocandoCena)
                        .modifier(EfeitoCamera(z: camera, zoomFinal: caixa.zoomFinal,
                                               alvo: caixa.centroDaAbertura, tela: geo.size))
                        .transition(.opacity)
                } else if personalizando {
                    PersonalizacaoView(config: sessao.config, haptics: sessao.haptics) {
                        trocarComCortina { personalizando = false }               // fechar: perde tudo
                    } confirmar: { nova in
                        trocarComCortina { sessao.config = nova; personalizando = false }
                    }
                    .transition(.opacity)
                } else {
                    dentroDaCaixa(g)
                        .transition(.opacity)
                }

                // Cortina que desce para trocar de tela
                CortinaView(fechada: cortinaTela)
            }
            .allowsHitTesting(!trocandoCena)
        }
        .onAppear {
            cortinaFechada = sessao.estado == .acabou
            atualizarDicas()
        }
        .onChange(of: sessao.foraDaCaixa) { _, _ in atualizarDicas() }
        .onChange(of: sessao.estado) { _, novo in
            atualizarDicas()
            if novo != .nova && novo != .apagada { etapa = .guardado }
            if novo == .acabou && sessao.foraDaCaixa {
                entrarNaCaixa()   // a vela acabou nas sombras: entra na caixa
            }
            if novo == .acabou {
                Task {
                    try? await Task.sleep(for: .seconds(1.5))
                    withAnimation(.easeInOut(duration: 1.6)) { cortinaFechada = true }
                }
            }
        }
    }

    // MARK: - Dentro da caixa (zoom in)

    // miniatura = o mesmo palco, sem botões, desenhado dentro da caixa durante o zoom
    private func dentroDaCaixa(_ g: LayoutPalco, miniatura: Bool = false) -> some View {
        let estado = sessao.estado
        let acesa = estado == .acesa && !trocando
        let alturaCheia = g.alturaCheia(sessao.config.posicaoSlider)
        let espacoChama = VelaView.espacoChama(largura: g.larguraVela)
        let topoCera = g.baseY - alturaCheia * CGFloat(1 - sessao.progresso)

        return ZStack {
            CenarioView(acesa: acesa, progresso: sessao.progresso, mostrarPersonagens: estado != .nova, quadro: g.quadro)

            // Vela apagada = tudo escuro, só a vela e os botões em destaque
            Color.black.opacity(acesa ? 0 : 0.55)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .animation(.easeInOut(duration: 1.2), value: acesa)

            // Luz da vela
            if acesa {
                RadialGradient(colors: [Cores.dourado.opacity(0.55), .clear],
                               center: .center, startRadius: 4, endRadius: g.larguraVela * 4)
                    .frame(width: g.larguraVela * 8, height: g.larguraVela * 8)
                    .position(x: g.centroX, y: topoCera - g.larguraVela * 0.7)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }

            // Vela (cortada no palco, para ela poder afundar pelo alçapão)
            ZStack {
                VelaView(alturaCheia: alturaCheia,
                         largura: g.larguraVela,
                         progresso: sessao.progresso,
                         acesa: acesa,
                         apagouEm: fumacaDaTroca ?? sessao.apagouEm,
                         movimento: sessao.movimento,
                         enfeites: sessao.config.enfeites,
                         caidos: sessao.caidos)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Vela")
                    .accessibilityValue(descricaoVela)
                    .position(x: g.centroX,
                              y: g.baseY - (alturaCheia + espacoChama) / 2 + (afundando ? alturaCheia + espacoChama : 0))
            }
            .frame(width: g.tamanho.width, height: g.tamanho.height)
            .mask(alignment: .top) { Rectangle().frame(height: g.baseY + 2) }

            // Suporte da vela
            SuporteView(largura: g.larguraVela)
                .position(x: g.centroX + SuporteView.desvioX(largura: g.larguraVela),
                          y: g.baseY + SuporteView.altura(largura: g.larguraVela) / 2)

            CortinaView(fechada: cortinaFechada)

            if !miniatura {
                botoes(g)
                    .opacity(mostrarBotoes ? 1 : 0)

                if etapa != .guardado {
                    fosforo(g)
                        .opacity(mostrarBotoes ? 1 : 0)
                }
            }
        }
        .coordinateSpace(.named("palco"))
        .gesture(
            MagnifyGesture().onEnded { valor in
                if valor.magnification < 0.75 {
                    DicaSairDaCaixa().invalidate(reason: .actionPerformed)   // já aprendeu a pinça
                    sairDaCaixa()
                }
            }
        )
    }

    // MARK: Botões

    private func botoes(_ g: LayoutPalco) -> some View {
        let estado = sessao.estado
        let podeSair = (estado == .acesa || estado == .apagada) && !trocando

        return ZStack {
            // Em cima: zoom out (esquerda) e configurações (direita)
            VStack {
                HStack {
                    if podeSair {
                        BotaoRedondo(icone: "arrow.down.right.and.arrow.up.left", rotulo: "Ver o teatro de sombras",
                                     tamanho: 44, acao: sairDaCaixa)
                            .popoverTip(DicaSairDaCaixa(), arrowEdge: .top)
                            .transition(.opacity)
                    }
                    Spacer()
                    BotaoRedondo(icone: "gearshape", rotulo: "Configurações", tamanho: 44, acao: abrirConfiguracoes)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            // Embaixo à esquerda: personalizar (vela nova) ou descartar (depois de acender).
            // Some enquanto o fósforo está fora (a lixa aparece nesse lugar).
            Group {
                if estado == .nova && !trocando && etapa == .guardado {
                    BotaoRedondo(icone: "paintbrush.pointed", rotulo: "Personalizar vela", tamanho: 60) {
                        trocarComCortina { personalizando = true }
                    }
                    .transition(.move(edge: .leading).combined(with: .opacity))
                } else if estado != .nova && !trocando && etapa == .guardado {
                    BotaoDescartar(tamanho: 60, haptics: sessao.haptics, descartar: descartar)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }
            }
            .position(x: g.tamanho.width * 0.17, y: g.botaoBaixoY)

            // Canto inferior direito: a caixa de fósforos, meio para fora da tela
            // (só aparece quando dá para acender). A lixa vai junto com ela, na borda de cima.
            if (estado == .nova || estado == .apagada) && !trocando {
                CaixaFosforoView(largura: g.larguraCaixa, aberta: caixaAberta)
                    .contentShape(Rectangle())
                    .onTapGesture { tocarNaCaixa(g) }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Caixa de fósforos")
                    .accessibilityHint("Acende a vela")
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction { sessao.acender() }   // VoiceOver: um toque duplo já acende
                    .position(g.caixa)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.6), value: estado)
        .animation(.spring(duration: 0.6), value: trocando)
        .animation(.spring(duration: 0.5, bounce: 0.35), value: etapa)
    }

    // MARK: Fósforo
    // 1) Toca na caixa: ela gira, um fósforo voa para cima e a lixa aparece embaixo
    // 2) Arrasta a cabeça do fósforo na lixa até acender
    // 3) Arrasta o fósforo aceso até o pavio
    // (Tocar na caixa de novo guarda o fósforo.)

    private func repousoFosforo(_ g: LayoutPalco) -> CGPoint { g.repousoDoFosforo }

    // A caixa ABRE (a gaveta desliza para fora) e um fósforo sobe de dentro dela.
    // Nada gira e nada se separa: a gaveta continua encaixada na luva.
    private func tocarNaCaixa(_ g: LayoutPalco) {
        if etapa == .guardado {
            posFosforo = g.saidaDoFosforo
            etapa = .fora
            sessao.haptics.tique()
            withAnimation(.easeOut(duration: 0.35)) { caixaAberta = 1 }
            withAnimation(.spring(duration: 0.55, bounce: 0.25).delay(0.12)) {
                posFosforo = g.repousoDoFosforo
            }
        } else {
            // Guarda o fósforo de volta e fecha a gaveta
            withAnimation(.easeIn(duration: 0.3)) { etapa = .guardado }
            withAnimation(.easeInOut(duration: 0.4).delay(0.1)) { caixaAberta = CaixaFosforoView.emRepouso }
        }
    }

    private func fosforo(_ g: LayoutPalco) -> some View {
        // Inclinado, como na mão de alguém. A cabeça fica em posFosforo.
        let pivo = UnitPoint(x: 0.5, y: FosforoView.posicaoCabeca(tamanho: tamanhoFosforo) / tamanhoFosforo)
        return FosforoView(aceso: etapa == .aceso, tamanho: tamanhoFosforo)
            .rotationEffect(.degrees(-30), anchor: pivo)
            .contentShape(Rectangle().inset(by: -16))   // um pouco mais fácil de pegar
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named("palco"))
                    .onChanged { valor in arrastarFosforo(valor, g) }
                    .onEnded { _ in soltarFosforo(g) }
            )
            // posiciona a vista para a CABEÇA ficar em posFosforo
            .position(x: posFosforo.x,
                      y: posFosforo.y - FosforoView.posicaoCabeca(tamanho: tamanhoFosforo) + tamanhoFosforo / 2)
            .transition(.scale(scale: 0.3, anchor: .bottom).combined(with: .opacity))
            // O fósforo aceso queima até o fim e apaga sozinho (antes ele ficava aceso para sempre)
            .task(id: etapa) {
                guard etapa == .aceso else { return }
                try? await Task.sleep(for: .seconds(duracaoDoFosforo))
                guard !Task.isCancelled, etapa == .aceso else { return }
                sessao.haptics.tique()   // TODO: som do fósforo apagando, quando chegar
                withAnimation(.easeOut(duration: 0.4)) { etapa = .guardado }
                withAnimation(.easeInOut(duration: 0.4).delay(0.1)) { caixaAberta = CaixaFosforoView.emRepouso }
            }
            .accessibilityHidden(true)   // com VoiceOver, a caixa acende direto
    }

    private func arrastarFosforo(_ valor: DragGesture.Value, _ g: LayoutPalco) {
        if inicioArraste == nil { inicioArraste = posFosforo }
        guard let inicio = inicioArraste else { return }
        let ponto = CGPoint(x: inicio.x + valor.translation.width, y: inicio.y + valor.translation.height)
        posFosforo = ponto

        switch etapa {
        case .fora:
            // Riscar: esfregar a cabeça do fósforo na lixa
            if g.lixa.insetBy(dx: -10, dy: -14).contains(ponto) {
                if let ultimo = ultimoPontoRisco {
                    let antes = riscado
                    riscado += hypot(ponto.x - ultimo.x, ponto.y - ultimo.y)
                    // Uma vibração áspera a cada pedacinho riscado
                    if Int(riscado / 26) > Int(antes / 26) { sessao.haptics.raspar() }
                }
                ultimoPontoRisco = ponto
                if riscado > g.lixa.width * 0.55 {
                    etapa = .aceso
                    riscado = 0
                    sessao.haptics.riscar()
                }
            } else {
                ultimoPontoRisco = nil
            }
        case .aceso:
            // Encostar no pavio: acende a vela
            let alturaCheia = g.alturaCheia(sessao.config.posicaoSlider)
            let pavio = CGPoint(x: g.centroX,
                                y: g.baseY - alturaCheia * CGFloat(1 - sessao.progresso))
            if hypot(ponto.x - pavio.x, ponto.y - pavio.y) < max(40, g.larguraVela * 0.6) {
                inicioArraste = nil
                withAnimation(.easeOut(duration: 0.3)) { etapa = .guardado }
                withAnimation(.easeInOut(duration: 0.4).delay(0.1)) { caixaAberta = CaixaFosforoView.emRepouso }
                sessao.acender()
            }
        case .guardado:
            break
        }
    }

    private func soltarFosforo(_ g: LayoutPalco) {
        inicioArraste = nil
        ultimoPontoRisco = nil
        if etapa == .fora { riscado = 0 }
        guard etapa != .guardado else { return }
        withAnimation(.spring(duration: 0.5)) { posFosforo = repousoFosforo(g) }
    }

    // MARK: Ações

    // ZOOM OUT: a câmera sai de dentro do teatro — o palco vai encolhendo até virar
    // a caixa lá embaixo — e, no finalzinho, a cortina da caixa fecha.
    //
    // O segredo para ficar liso: é UMA animação só do começo ao fim (a cortina entra
    // com .delay, não com espera no meio), os botões saem de cena antes de começar
    // (senão cresceriam junto com o zoom) e as sombras ficam paradas durante o caminho.
    private func sairDaCaixa() {
        guard sessao.estado == .acesa || sessao.estado == .apagada,
              !trocando, !trocandoCena, !sessao.foraDaCaixa else { return }
        etapa = .guardado
        if reduzirMovimento {
            aberturaCaixa = 0
            camera = 0
            withAnimation(.easeInOut(duration: 0.5)) { sessao.foraDaCaixa = true }
            return
        }
        trocandoCena = true
        Task {
            // 1. Os botões saem
            withAnimation(.easeOut(duration: 0.18)) { mostrarBotoes = false }
            try? await Task.sleep(for: .seconds(0.22))

            // 2. Troca para a vista de fora com a câmera COLADA na caixa.
            //    A imagem é exatamente a mesma, então a troca não aparece.
            camera = 1
            aberturaCaixa = 1
            mostrarMiniatura = true
            cameraAtiva = true
            try? await Task.sleep(for: .seconds(0.03))

            // 3. A câmera se afasta e a cortina da caixa fecha no fim do caminho
            withAnimation(.easeInOut(duration: 1.5)) { camera = 0 }
            withAnimation(.easeInOut(duration: 0.55).delay(1.15)) { aberturaCaixa = 0 }
            try? await Task.sleep(for: .seconds(1.75))

            // 4. Daqui para a frente é a tela das sombras de verdade
            sessao.foraDaCaixa = true
            mostrarMiniatura = false
            cameraAtiva = false
            trocandoCena = false
            withAnimation(.easeIn(duration: 0.3)) { mostrarBotoes = true }
        }
    }

    // ZOOM IN: a cortina da caixa abre e a câmera entra até o palco ocupar a tela toda
    private func entrarNaCaixa() {
        guard sessao.foraDaCaixa, !trocandoCena else { return }
        if reduzirMovimento {
            withAnimation(.easeInOut(duration: 0.5)) { sessao.foraDaCaixa = false }
            return
        }
        trocandoCena = true
        Task {
            withAnimation(.easeOut(duration: 0.18)) { mostrarBotoes = false }
            try? await Task.sleep(for: .seconds(0.22))

            camera = 0
            aberturaCaixa = 0
            mostrarMiniatura = true
            cameraAtiva = true
            try? await Task.sleep(for: .seconds(0.03))

            // A cortina abre e a câmera já começa a entrar atrás dela
            withAnimation(.easeInOut(duration: 0.55)) { aberturaCaixa = 1 }
            withAnimation(.easeInOut(duration: 1.5).delay(0.4)) { camera = 1 }
            try? await Task.sleep(for: .seconds(2.0))

            // Troca a miniatura pelo palco de verdade (de novo, a imagem é a mesma)
            sessao.foraDaCaixa = false
            cameraAtiva = false
            mostrarMiniatura = false
            camera = 0
            aberturaCaixa = 0
            trocandoCena = false
            withAnimation(.easeIn(duration: 0.3)) { mostrarBotoes = true }
        }
    }

    // A cortina desce, a tela troca por trás dela e a cortina sobe (usado na personalização)
    private func trocarComCortina(_ mudanca: @escaping () -> Void) {
        guard !trocandoCena else { return }
        if reduzirMovimento {
            withAnimation(.easeInOut(duration: 0.4)) { mudanca() }
            return
        }
        trocandoCena = true
        Task {
            withAnimation(.easeIn(duration: 0.7)) { cortinaTela = true }
            try? await Task.sleep(for: .seconds(0.75))
            mudanca()
            try? await Task.sleep(for: .seconds(0.15))
            withAnimation(.easeOut(duration: 0.7)) { cortinaTela = false }
            try? await Task.sleep(for: .seconds(0.7))
            trocandoCena = false
        }
    }

    // A chama apaga, a vela afunda pelo alçapão, a cortina desce e sobe uma vela nova
    private func descartar() {
        guard !trocando else { return }
        let estavaAcesa = sessao.estado == .acesa
        trocando = true
        etapa = .guardado
        sessao.haptics.pararChama()
        if estavaAcesa {
            sessao.haptics.apagar()
            fumacaDaTroca = Date()
        }
        Task {
            if estavaAcesa { try? await Task.sleep(for: .seconds(0.8)) }
            withAnimation(.easeIn(duration: 0.9)) { afundando = true }
            try? await Task.sleep(for: .seconds(0.9))
            withAnimation(.easeInOut(duration: 0.9)) { cortinaFechada = true }
            try? await Task.sleep(for: .seconds(1.0))
            sessao.descartar()
            fumacaDaTroca = nil
            try? await Task.sleep(for: .seconds(0.2))
            withAnimation(.easeInOut(duration: 0.9)) { cortinaFechada = false }
            withAnimation(.easeOut(duration: 1.0).delay(0.5)) { afundando = false }
            try? await Task.sleep(for: .seconds(1.5))
            trocando = false
        }
    }

    // Avisa o TipKit quais dicas fazem sentido agora.
    // Quando a regra deixa de valer, a dica que está na tela some junto com o botão dela.
    private func atualizarDicas() {
        DicaSairDaCaixa.podeSair = sessao.estado == .acesa || sessao.estado == .apagada
        DicaEntrarNaCaixa.estaForaDaCaixa = sessao.foraDaCaixa
    }

    // O que o VoiceOver fala sobre a vela (sem números, como na tela)
    private var descricaoVela: String {
        let p = sessao.progresso
        let quanto: String
        switch p {
        case ..<0.05: quanto = "inteira"
        case ..<0.25: quanto = "quase inteira"
        case ..<0.5: quanto = "chegando na metade"
        case ..<0.75: quanto = "passou da metade"
        case ..<1: quanto = "quase no fim"
        default: quanto = "acabou"
        }
        switch sessao.estado {
        case .nova: return "Vela nova, apagada"
        case .acesa: return "Acesa, \(quanto)"
        case .apagada: return "Apagada, \(quanto)"
        case .acabou: return "A vela acabou"
        }
    }
}

// Onde fica cada coisa na tela. A vela segue a posição da arte da Georgia (Quadro).
private struct LayoutPalco {
    let tamanho: CGSize
    let quadro: Quadro

    init(geo: GeometryProxy) {
        tamanho = geo.size
        quadro = Quadro(geo: geo)
    }

    var centroX: CGFloat { quadro.x(ArteVela.centroX) }
    var baseY: CGFloat { quadro.y(ArteVela.baseY) }
    var alturaMaxima: CGFloat { ArteVela.alturaMaxima * quadro.escala }
    var larguraVela: CGFloat { ArteVela.largura * quadro.escala }
    var larguraCaixa: CGFloat { min(tamanho.width * 0.34, 150) }
    var alturaCaixa: CGFloat { CaixaFosforoView.altura(largura: larguraCaixa) }

    // Caixa de fósforos no canto de baixo à direita, meio para fora da tela
    var caixa: CGPoint {
        CGPoint(x: tamanho.width - larguraCaixa * 0.34, y: tamanho.height - alturaCaixa * 0.30)
    }

    var botaoBaixoY: CGFloat { tamanho.height * 0.92 }

    // A lixa é a faixa da própria caixa: a conta abaixo leva a faixa de dentro
    // da caixa para as coordenadas da tela.
    var lixa: CGRect {
        let faixa = CaixaFosforoView.faixaDaLixa(largura: larguraCaixa)
        return faixa.offsetBy(dx: caixa.x - larguraCaixa / 2, dy: caixa.y - alturaCaixa / 2)
    }

    // De onde o fósforo sai (de dentro da gaveta) e onde ele fica esperando, logo acima da caixa
    var saidaDoFosforo: CGPoint {
        CGPoint(x: caixa.x - CaixaFosforoView.corrida(largura: larguraCaixa) * 0.6, y: caixa.y)
    }

    var repousoDoFosforo: CGPoint {
        CGPoint(x: caixa.x - larguraCaixa * 0.55, y: caixa.y - alturaCaixa * 1.25)
    }

    func alturaCheia(_ posicao: Double) -> CGFloat {
        GeometriaVela.alturaCheia(posicao: posicao, alturaMaxima: alturaMaxima)
    }
}
