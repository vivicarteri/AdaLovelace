//  PalcoView.swift
//  A tela principal: a home E a vela queimando (é a mesma tela, muda a luz e os botões).
//
//  Antes de acender:            personalizar, acender (caixa de fósforos) e configurações
//  Depois de acender:           descartar (segurar = derrete rápido), zoom out e configurações
//  Apagou antes de acabar:      descartar (segurar = derrete rápido), acender, zoom out e configurações
//  Depois de acabar:            vela nova (segurar 1 s) e configurações (a cortina desce)

import SwiftUI
import TipKit

enum MedidasBarraDoPalco {
    static let margemSuperior: CGFloat = 8
    static let diametro: CGFloat = 44
}

struct PalcoView: View {
    @EnvironmentObject private var sessao: Sessao
    var abrirConfiguracoes: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento

    @State private var personalizando = false
    @AppStorage(Chaves.iluminacaoDramatica) private var iluminacaoDramatica = true
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
    @State private var dicas = TipGroup(.firstAvailable) {
        DicaSairDaCaixa()
        DicaEntrarNaCaixa()
        DicaOutroJeitoDeApagar()
    }

    // Fósforo: 1) toca na caixa → o fósforo sai  2) risca na caixa → acende  3) arrasta até o pavio
    private enum EtapaFosforo { case guardado, fora, aceso }
    @State private var etapa: EtapaFosforo = .guardado
    @State private var posFosforo: CGPoint = .zero   // onde está a cabeça do fósforo
    @State private var inicioArraste: CGPoint?
    @State private var toqueDoArraste: CGPoint?    // onde o dedo encostou (reconhece um gesto novo)
    @State private var riscado: CGFloat = 0
    @State private var ultimoPontoRisco: CGPoint?

    private var tamanhoFosforo: CGFloat { FosforoView.tamanhoNoPalco }

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
                                      aberturaCaixa: aberturaCaixa,
                                      conteudoDaCaixa: mostrarMiniatura ? AnyView(dentroDaCaixa(g, miniatura: true)) : nil,
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

                if !personalizando {
                    barraSuperior
                        .opacity(mostrarBotoes ? 1 : 0)
                        .transition(.opacity)
                }

                // Cortina que desce para trocar de tela
                CortinaView(fechada: cortinaTela)
            }
            .simultaneousGesture(MagnifyGesture().onEnded { valor in
                guard !personalizando, !trocandoCena, !trocando else { return }
                if sessao.foraDaCaixa && valor.magnification > 1.3 {
                    DicaEntrarNaCaixa().invalidate(reason: .actionPerformed)
                    entrarNaCaixa()
                } else if podeSairDaCaixa && valor.magnification < 0.75 {
                    DicaSairDaCaixa().invalidate(reason: .actionPerformed)
                    sairDaCaixa()
                }
            })
            .allowsHitTesting(!trocandoCena)
            .onChange(of: alturaDaChamaNaTela(g, caixa, geo), initial: true) { _, altura in
                sessao.chamaMudouDeLugar(altura)
            }
        }
        .onAppear {
            cortinaFechada = sessao.estado == .acabou
        }
        .onChange(of: podeSairDaCaixa, initial: true) { _, podeSair in
            DicaSairDaCaixa.podeSair = podeSair
        }
        .onChange(of: sessao.foraDaCaixa, initial: true) { _, fora in
            DicaEntrarNaCaixa.estaForaDaCaixa = fora
        }
        .onChange(of: podeApagarNaCaixa, initial: true) { _, podeApagar in
            DicaOutroJeitoDeApagar.velaAcesa = podeApagar
        }
        // O fósforo voltou para a caixa (por qualquer caminho): esquece o arraste que estava
        // no meio e fecha a gaveta. Se a vista do fósforo some no meio de um arraste (a vela
        // acendeu, ele queimou até o fim), o fim do gesto não chega; sem isto, o próximo fósforo
        // começava do lugar antigo e ficava "flutuando" longe da caixa.
        .onChange(of: etapa) { _, nova in
            guard nova == .guardado else { return }
            esquecerArraste()
            if caixaAberta != CaixaFosforoView.emRepouso {
                withAnimation(.easeInOut(duration: 0.4).delay(0.1)) { caixaAberta = CaixaFosforoView.emRepouso }
            }
        }
        .onChange(of: sessao.estado) { _, novo in
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

    // Onde a chama está na tela: 0 = embaixo, 1 = em cima.
    // O sopro usa isso para escolher o microfone mais perto da chama.
    // Conta a tela inteira (com a barra de status e a de baixo), porque os microfones
    // ficam nas pontas do aparelho, e não nas pontas da área segura.
    private func alturaDaChamaNaTela(_ g: LayoutPalco, _ caixa: MedidasCaixa, _ geo: GeometryProxy) -> Double {
        let y: CGFloat
        if sessao.foraDaCaixa {
            y = caixa.centroDaAbertura.y   // nas sombras a vela fica dentro da caixa, lá embaixo
        } else {
            let topoCera = g.baseY - g.alturaCheia(sessao.config.posicaoSlider) * CGFloat(1 - sessao.progresso)
            y = topoCera + VelaView.centroDaChama(largura: g.larguraVela).y
        }
        let margens = geo.safeAreaInsets
        let alturaDaTela = max(geo.size.height + margens.top + margens.bottom, 1)
        return min(1, max(0, Double(1 - (y + margens.top) / alturaDaTela)))
    }

    // MARK: - Dentro da caixa (zoom in)

    // miniatura = o mesmo palco, sem botões, desenhado dentro da caixa durante o zoom
    private func dentroDaCaixa(_ g: LayoutPalco, miniatura: Bool = false) -> some View {
        let estado = sessao.estado
        let acesa = estado == .acesa && !trocando
        let alturaCheia = g.alturaCheia(sessao.config.posicaoSlider)
        let espacoChama = VelaView.espacoChama(largura: g.larguraVela)
        let topoCera = g.baseY - alturaCheia * CGFloat(1 - sessao.progresso)
        let centroChama = VelaView.centroDaChama(largura: g.larguraVela)
        let alvoChama = max(64, VelaView.alturaDaChama(largura: g.larguraVela) * 0.9)

        return ZStack {
            // As peças do cenário (lua, passarinho…) só aparecem com a vela ACESA
            CenarioView(acesa: acesa, progresso: sessao.progresso, mostrarPersonagens: estado == .acesa, quadro: g.quadro)

            // Vela apagada = tudo escuro, só a vela e os botões em destaque.
            // Acendendo, o escuro sai rápido; apagando, ele desce devagar.
            Color.black.opacity(acesa ? 0 : 0.55)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .animation(.easeInOut(duration: acesa ? 0.1 : 1.2), value: acesa)

            // Iluminação dramática: longe da chama o palco escurece, cada vez mais com o tempo
            if acesa && iluminacaoDramatica {
                LuzDaVela(chama: CGPoint(x: g.centroX, y: topoCera - g.larguraVela * 0.7),
                          tela: g.tamanho, progresso: sessao.progresso)
                    .transition(.opacity.animation(.easeOut(duration: 0.1)))
            }

            // Luz da vela (entra junto com a chama, sem esperar a animação do palco)
            if acesa {
                RadialGradient(colors: [Cores.dourado.opacity(0.55), .clear],
                               center: .center, startRadius: 4, endRadius: g.larguraVela * 4)
                    .frame(width: g.larguraVela * 8, height: g.larguraVela * 8)
                    .position(x: g.centroX, y: topoCera - g.larguraVela * 0.7)
                    .allowsHitTesting(false)
                    .transition(.opacity.animation(.easeOut(duration: 0.1)))
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
                    .accessibilityHint(acesa ? "Toque duas vezes na chama para apagar" : "")
                    .accessibilityActions {
                        if acesa {
                            Button("Apagar a vela") { apagarTocandoNaChama() }
                        }
                    }
                    .position(x: g.centroX,
                              y: g.baseY - (alturaCheia + espacoChama) / 2 + (afundando ? alturaCheia + espacoChama : 0))
            }
            .frame(width: g.tamanho.width, height: g.tamanho.height)
            .mask(alignment: .top) { Rectangle().frame(height: g.baseY + 2) }

            // Tocar na chama apaga a vela.
            // É também o jeito de apagar SEM virar o aparelho: importante para quem não pode
            // virar o celular e para quando o Core Motion estiver desligado nas configurações.
            if acesa && !miniatura {
                Color.clear
                    .frame(width: alvoChama, height: alvoChama)
                    .contentShape(Circle())
                    .position(x: g.centroX + centroChama.x, y: topoCera + centroChama.y)
                    .onTapGesture { apagarTocandoNaChama() }
                    .accessibilityHidden(true)   // a ação fica na própria vela, para o VoiceOver
            }

            // Suporte da vela
            SuporteView(largura: g.larguraVela)
                .position(x: g.centroX + SuporteView.desvioX(largura: g.larguraVela),
                          y: g.baseY + SuporteView.altura(largura: g.larguraVela) / 2)

            CortinaView(fechada: cortinaFechada)

            // A vela acabou e a cortina fechou: letreiro de "Fim" e a cortina inteira vira
            // um botão para começar de novo (antes não tinha nenhuma pista e parecia travado).
            if estado == .acabou && cortinaFechada && !trocando && !miniatura {
                fimDoEspetaculo(g)
                    .transition(.opacity)
            }

            if !miniatura {
                botoesInferiores(g)
                    .opacity(mostrarBotoes ? 1 : 0)

                if etapa != .guardado {
                    fosforo(g)
                        .opacity(mostrarBotoes ? 1 : 0)
                }
            }
        }
        .coordinateSpace(.named("palco"))
    }

    // Letreiro pendurado na cortina fechada. Tocar em qualquer lugar da cortina abre uma vela nova.
    private func fimDoEspetaculo(_ g: LayoutPalco) -> some View {
        ZStack {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    sessao.haptics.tique()
                    descartar()
                }
            VStack(spacing: 14) {
                Text("Fim")
                    .font(.system(size: 34, weight: .bold, design: .serif).italic())
                    .foregroundStyle(Cores.tinta)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Cores.papel))
                    .overlay(Capsule().stroke(Cores.tinta, lineWidth: 2))
                Text("Toque para acender uma vela nova")
                    .font(.system(size: 17, weight: .semibold, design: .serif))
                    .foregroundStyle(Cores.papel)
                    .multilineTextAlignment(.center)
            }
            .position(x: g.tamanho.width / 2, y: g.tamanho.height * 0.42)
            .allowsHitTesting(false)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Fim. A vela acabou")
        .accessibilityHint("Toque duas vezes para colocar uma vela nova")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { descartar() }
    }

    // MARK: Botões

    private var barraSuperior: some View {
        let dica = dicaAtual
        let mostraSeta = dica is DicaSairDaCaixa || dica is DicaEntrarNaCaixa

        return VStack {
            HStack {
                if sessao.foraDaCaixa {
                    BotaoRedondo(icone: "arrow.up.left.and.arrow.down.right", rotulo: "Entrar na caixa",
                                 tamanho: MedidasBarraDoPalco.diametro, acao: entrarNaCaixa)
                } else if podeSairDaCaixa {
                    BotaoRedondo(icone: "arrow.down.right.and.arrow.up.left", rotulo: "Ver o teatro de sombras",
                                 tamanho: MedidasBarraDoPalco.diametro, acao: sairDaCaixa)
                        .transition(.opacity)
                }
                Spacer()
                BotaoRedondo(icone: "gearshape", rotulo: "Configurações", tamanho: MedidasBarraDoPalco.diametro, acao: abrirConfiguracoes)
            }
            .animation(.spring(duration: 0.6), value: podeSairDaCaixa)

            // As duas cenas compartilham o mesmo espaço para dicas, inclusive durante o zoom.
            TipView(dica, arrowEdge: mostraSeta ? .top : nil)
                .frame(maxWidth: 340)
                .frame(maxWidth: .infinity, alignment: mostraSeta ? .leading : .center)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, MedidasBarraDoPalco.margemSuperior)
    }

    private func botoesInferiores(_ g: LayoutPalco) -> some View {
        let estado = sessao.estado

        return ZStack {
            // Embaixo à esquerda: personalizar (vela nova) ou descartar (depois de acender).
            // Some enquanto o fósforo está fora (a lixa aparece nesse lugar).
            Group {
                if estado == .nova && !trocando && etapa == .guardado {
                    BotaoRedondo(icone: "paintbrush.pointed", rotulo: "Personalizar vela", tamanho: 60) {
                        trocarComCortina { personalizando = true }
                    }
                    .transition(.move(edge: .leading).combined(with: .opacity))
                } else if estado == .acabou && !trocando {
                    // Vela que acabou: segurar 1 segundo coloca uma vela nova
                    BotaoDescartar(tamanho: 60, haptics: sessao.haptics, descartar: descartar)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                } else if estado != .nova && !trocando && etapa == .guardado {
                    // Acesa ou apagada: segurar derrete a vela rápido; soltar para
                    BotaoDescartar(tamanho: 60, haptics: sessao.haptics,
                                   anel: sessao.progresso,
                                   derreter: { segurando in
                                       if segurando { sessao.comecarADerreter() } else { sessao.pararDeDerreter() }
                                   },
                                   descartar: { sessao.derreterAteOFim() })
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
            esquecerArraste()
            // Sem animação: o fósforo novo nasce na boca da caixa (e não no lugar do anterior)
            var semAnimacao = Transaction()
            semAnimacao.disablesAnimations = true
            withTransaction(semAnimacao) { posFosforo = g.saidaDoFosforo }
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
            .rotationEffect(FosforoView.inclinacao, anchor: pivo)
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

    private func esquecerArraste() {
        inicioArraste = nil
        toqueDoArraste = nil
        ultimoPontoRisco = nil
        riscado = 0
    }

    private func arrastarFosforo(_ valor: DragGesture.Value, _ g: LayoutPalco) {
        // O fósforo já foi guardado (acendeu a vela ou queimou): o resto do gesto é ignorado
        guard etapa != .guardado else { return }
        // Gesto novo (o dedo encostou em outro lugar): começa do lugar ATUAL do fósforo.
        // Se o sistema cancelou o gesto anterior, o "fim" dele não chegou; sem esta conferência
        // o fósforo pulava para o lugar antigo e ficava flutuando longe da mão.
        if inicioArraste == nil || toqueDoArraste != valor.startLocation {
            inicioArraste = posFosforo
            toqueDoArraste = valor.startLocation
            ultimoPontoRisco = nil
        }
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
        toqueDoArraste = nil
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

    // Tocar na chama apaga a vela. Ela continua de onde parou: para acender de novo,
    // a pessoa precisa do fósforo, igual a virar o aparelho de cabeça para baixo.
    private func apagarTocandoNaChama() {
        guard sessao.estado == .acesa, !trocando, !trocandoCena else { return }
        sessao.apagar(jeito: .toque)
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
            // A vela nova já fica INTEIRA no lugar enquanto a cortina está fechada (sem animação).
            // Antes ela subia de dentro do suporte depois que a cortina abria: por um instante
            // aparecia só o topo e um pedaço do corpo, parecendo uma vela cortada "crescendo".
            var semAnimacao = Transaction()
            semAnimacao.disablesAnimations = true
            withTransaction(semAnimacao) { afundando = false }
            try? await Task.sleep(for: .seconds(0.5))   // a vela termina de se ajeitar ainda atrás da cortina
            withAnimation(.easeInOut(duration: 0.9)) { cortinaFechada = false }
            try? await Task.sleep(for: .seconds(1.0))
            trocando = false
        }
    }

    private var podeSairDaCaixa: Bool {
        !sessao.foraDaCaixa && !trocando && (sessao.estado == .acesa || sessao.estado == .apagada)
    }

    private var podeApagarNaCaixa: Bool {
        podeSairDaCaixa && sessao.estado == .acesa
    }

    private var dicaAtual: (any Tip)? {
        guard !trocandoCena else { return nil }
        // O contexto da tela muda antes de o TipKit reavaliar as regras.
        switch dicas.currentTip {
        case let dica as DicaEntrarNaCaixa where sessao.foraDaCaixa:
            return dica
        case let dica as DicaSairDaCaixa where podeSairDaCaixa:
            return dica
        case let dica as DicaOutroJeitoDeApagar where podeApagarNaCaixa:
            return dica
        default:
            return nil
        }
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

    // O fósforo espera EM PÉ dentro da gaveta aberta: o pé fica no meio da parte da gaveta
    // que saiu da caixa, e a cabeça fica para fora. Assim ele nunca fica solto no ar.
    // (A conta usa a cabeça, porque é ela que segue o dedo.)
    var repousoDoFosforo: CGPoint {
        let bordaEsquerda = caixa.x - larguraCaixa / 2
        let pe = CGPoint(x: bordaEsquerda - CaixaFosforoView.corrida(largura: larguraCaixa) * 0.5,
                         y: caixa.y)
        let desvio = FosforoView.peDesdeACabeca(tamanho: FosforoView.tamanhoNoPalco)
        return CGPoint(x: pe.x - desvio.width, y: pe.y - desvio.height)
    }

    // De onde o fósforo sai: um pouco mais para baixo, ainda deitado dentro da gaveta.
    // Ele sobe reto até ficar em pé (repousoDoFosforo).
    var saidaDoFosforo: CGPoint {
        CGPoint(x: repousoDoFosforo.x, y: repousoDoFosforo.y + alturaCaixa * 0.35)
    }

    func alturaCheia(_ posicao: Double) -> CGFloat {
        GeometriaVela.alturaCheia(posicao: posicao, alturaMaxima: alturaMaxima)
    }
}
