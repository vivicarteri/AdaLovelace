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
    // iPhone Duo: a postura do aparelho (aberto, abrindo, laptop, fechado, tenda)
    @ObservedObject private var dobradica = Dobradica.compartilhada
    @State private var dicas = TipGroup(.firstAvailable) {
        DicaDobrarODuo()
        DicaSairDaCaixa()
        DicaEntrarNaCaixa()
        DicaOutroJeitoDeApagar()
    }

    // Fósforo: 1) toca na caixa → o fósforo sai  2) risca na caixa → acende  3) arrasta até o pavio
    private enum EtapaFosforo { case guardado, fora, aceso }
    @State private var etapa: EtapaFosforo = .guardado
    @State private var posFosforo: CGPoint = .zero   // onde está a cabeça do fósforo
    @State private var inicioArraste: CGPoint?
    // Risco do fósforo na lixa (a física está em riscarNaLixa)
    @State private var ultimoPontoRisco: CGPoint?
    @State private var ultimoInstanteRisco: TimeInterval?
    @State private var ancoraDoRisco: CGFloat?          // x onde começou o risco rápido de agora
    @State private var velocidadeDoRisco: CGFloat = 0   // pontos por segundo, na horizontal, suavizada
    @State private var caminhoNaLixa: CGFloat = 0       // caminho total, para a vibração a cada pedacinho
    @State private var vigiaDoRiscoParado: Task<Void, Never>?
    @State private var acendendoSozinho = false   // VoiceOver / Controle por Voz: "Acender vela"

    private var tamanhoFosforo: CGFloat { FosforoView.tamanhoNoPalco }

    // ⚙️ Quanto tempo o fósforo aceso dura antes de apagar sozinho (como um de verdade).
    // Depois disso ele volta para a caixa e a pessoa pega outro.
    private let duracaoDoFosforo: TimeInterval = 10

    // ⚙️ Risco do fósforo (valores para ir testando)
    // Quanto da largura da lixa é preciso riscar, num sentido só, para acender.
    private let fracaoDaLixaParaAcender: CGFloat = 0.55
    // Sem movimento por este tempo = dedo parado: o som de riscar para.
    private let tempoParaConsiderarParado: Duration = .milliseconds(60)
    // Abaixo desta velocidade (pontos por segundo) o dedo conta como parado.
    private let velocidadeDeDedoParado: CGFloat = 20
    // Suavização da velocidade (segundos): tira os tremidos do toque.
    private let suavizacaoDaVelocidade: TimeInterval = 0.04
    // A cada este tanto de caminho na lixa, uma vibração áspera.
    private let caminhoPorVibracao: CGFloat = 26

    var body: some View {
        GeometryReader { geo in
            let regioes = regioesDoDuo(geo)
            let g = layoutDoPalco(geo, cameras: regioes.cameras)
            let caixa = MedidasCaixa(tela: geo.size)
            ZStack {
                if sessao.foraDaCaixa || cameraAtiva {
                    // Vista de fora. A "câmera" (EfeitoCamera) aproxima ou afasta da caixa.
                    TeatroSombrasView(entrar: { if trocaManual { entrarNaCaixa() } },
                                      aberturaCaixa: aberturaCaixa,
                                      conteudoDaCaixa: mostrarMiniatura ? AnyView(dentroDaCaixa(g, miniatura: true)) : nil,
                                      congelado: trocandoCena,
                                      mostrarCamadas: !trocandoCena,
                                      podeEntrar: trocaManual)
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
                } else if dobradica.ehDuo {
                    palcoDoDuo(g, geo, divisao: regioes.divisao)
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
                // iPhone Duo: a pinça só vale no modo tenda (no resto, quem troca é a dobra)
                guard !personalizando, !trocandoCena, !trocando, trocaManual else { return }
                if sessao.foraDaCaixa && valor.magnification > 1.3 {
                    DicaEntrarNaCaixa().invalidate(reason: .actionPerformed)
                    entrarNaCaixa()
                } else if podeSairDaCaixa && valor.magnification < 0.75 {
                    DicaSairDaCaixa().invalidate(reason: .actionPerformed)
                    sairDaCaixa()
                }
            })
            .allowsHitTesting(!trocandoCena)
            // Smart Invert: a arte de papel, a vela e as sombras não ficam em negativo
            .accessibilityIgnoresInvertColors()
            .onChange(of: alturaDaChamaNaTela(g, caixa, geo), initial: true) { _, altura in
                sessao.chamaMudouDeLugar(altura)
            }
            // iPhone Duo: conta para a Dobradica em que tela o app está e para que lado a dobra corre
            .onChange(of: regioes.leitura(tamanho: geo.size), initial: true) { _, tela in
                guard dobradica.ehDuo else { return }
                dobradica.telaMudou(temDobra: tela.temDobra, dobraDeitada: tela.dobraDeitada, tamanho: tela.tamanho)
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
        // iPhone Duo: a dobra decide se a tela é a vela ou o teatro de sombras
        .onChange(of: dobradica.postura, initial: true) { antes, agora in
            mudouPostura(de: antes, para: agora)
        }
        .onChange(of: sessao.estado) { _, novo in
            if novo != .nova && novo != .apagada { etapa = .guardado }
            // A vela acabou nas sombras: entra na caixa (menos no Duo fechado, que fica preso nas sombras)
            if novo == .acabou && sessao.foraDaCaixa && !(dobradica.ehDuo && dobradica.postura == .fechado) {
                entrarNaCaixa()
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
                .accessibilityHint(acesa ? "Use o rotor Camadas de papel para explorar a cena" : "")
                .accessibilityActions { atalhos(g) }

            // VoiceOver: uma camada de papel por vez (rotor "Camadas de papel"). Fica embaixo
            // da vela e dos botões, para o toque do VoiceOver achar eles primeiro.
            if !miniatura {
                CamadasDaCenaAcessiveis(camadas: estado == .acesa ? DescricaoDaCena.camadas(sombra: false) : [],
                                        estadoDaVela: sessao.descricaoDaVela)
            }

            // Vela apagada = tudo escuro, só a vela e os botões em destaque.
            // Acendendo, o escuro sai rápido; apagando, ele desce devagar.
            Color.black.opacity(acesa ? 0 : 0.55)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .animation(.easeInOut(duration: acesa ? 0.1 : 1.2), value: acesa)

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
                    .accessibilityValue(sessao.descricaoDaVela)
                    .accessibilityHint(acesa ? "Para apagar, toque na chama ou use as ações" : "Use as ações para atalhos")
                    .accessibilityActions { atalhos(g) }
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
        .accessibilityElement(children: .contain)
    }

    // Atalhos do VoiceOver (menu de ações). São também a alternativa a virar o aparelho,
    // soprar, riscar o fósforo e segurar o botão: nenhum gesto físico é o único caminho.
    @ViewBuilder
    private func atalhos(_ g: LayoutPalco) -> some View {
        let estado = sessao.estado
        if (estado == .nova || estado == .apagada) && !trocando {
            Button("Acender vela") { acenderSozinho(g) }
        }
        if estado == .acesa && !trocando {
            Button("Apagar chama") { apagarTocandoNaChama() }
            Button(sessao.derretimentoAcelerado ? "Voltar ao ritmo normal da vela" : "Acelerar derretimento da vela") {
                sessao.alternarDerretimentoAcelerado()
            }
        }
        if podeSairDaCaixa && trocaManual {
            Button("Ver o teatro de sombras") { sairDaCaixa() }
        }
        if estado == .nova && !trocando {
            Button("Abrir personalização") { trocarComCortina { personalizando = true } }
        }
        Button("Abrir configurações") { abrirConfiguracoes() }
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
                    .adaFont(.screenTitle)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(Cores.tinta)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Cores.papel))
                    .overlay(Capsule().stroke(Cores.tinta, lineWidth: 2))
                Text("Toque para acender uma vela nova")
                    .adaFont(.body)
                    .foregroundStyle(Cores.papel)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: max(0, g.tamanho.width - 48))
            .position(x: g.tamanho.width / 2, y: g.tamanho.height * 0.42)
            .allowsHitTesting(false)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Fim. A vela acabou")
        .accessibilityHint("Toque duas vezes para colocar uma vela nova")
        .accessibilityInputLabels(["Vela nova", "Acender vela nova", "Fim"])
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { descartar() }
    }

    // MARK: Botões

    private var barraSuperior: some View {
        let dica = dicaAtual
        let mostraSeta = dica is DicaSairDaCaixa || dica is DicaEntrarNaCaixa

        return VStack {
            HStack {
                // iPhone Duo: sem botão de trocar de cena (quem troca é a dobra), menos no modo tenda
                if sessao.foraDaCaixa && trocaManual {
                    BotaoRedondo(icone: "arrow.up.left.and.arrow.down.right", rotulo: "Entrar na caixa",
                                 tamanho: MedidasBarraDoPalco.diametro,
                                 comandosDeVoz: ["Voltar para a vela", "Aproximar"], acao: entrarNaCaixa)
                } else if podeSairDaCaixa && trocaManual {
                    BotaoRedondo(icone: "arrow.down.right.and.arrow.up.left", rotulo: "Ver o teatro de sombras",
                                 tamanho: MedidasBarraDoPalco.diametro,
                                 comandosDeVoz: ["Teatro de sombras", "Afastar", "Sair da caixa"], acao: { sairDaCaixa() })
                        .transition(.opacity)
                }
                Spacer()
                // iPhone Duo: a engrenagem é o botão nativo da barra de navegação (ContentView)
                if !dobradica.ehDuo {
                    BotaoRedondo(icone: "gearshape", rotulo: "Configurações", tamanho: MedidasBarraDoPalco.diametro,
                                 comandosDeVoz: ["Abrir configurações", "Ajustes"], acao: abrirConfiguracoes)
                }
            }
            .frame(minHeight: MedidasBarraDoPalco.diametro)
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
                    BotaoRedondo(icone: "paintbrush.pointed", rotulo: "Personalizar vela", tamanho: 60,
                                 comandosDeVoz: ["Abrir personalização", "Personalizar", "Ateliê"]) {
                        trocarComCortina { personalizando = true }
                    }
                    .transition(entradaPelaEsquerda)
                } else if estado == .acabou && !trocando {
                    // Vela que acabou: segurar 1 segundo coloca uma vela nova
                    BotaoDescartar(tamanho: 60, haptics: sessao.haptics, descartar: descartar)
                        .transition(entradaPelaEsquerda)
                } else if estado != .nova && !trocando && etapa == .guardado {
                    // Acesa ou apagada: segurar derrete a vela rápido; soltar para
                    BotaoDescartar(tamanho: 60, haptics: sessao.haptics,
                                   anel: sessao.progresso,
                                   derreter: { segurando in
                                       if segurando { sessao.comecarADerreter() } else { sessao.pararDeDerreter() }
                                   },
                                   descartar: { sessao.derreterAteOFim() })
                        .transition(entradaPelaEsquerda)
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
                    .accessibilityLabel("Acender vela")
                    .accessibilityValue(estado == .nova ? "Vela nova, apagada" : "Vela apagada")
                    .accessibilityHint("Abre a caixa de fósforos, risca um fósforo e acende o pavio")
                    .accessibilityInputLabels(["Acender vela", "Acender fósforo", "Caixa de fósforos", "Acender"])
                    .accessibilityAddTraits(.isButton)
                    // VoiceOver e Controle por Voz: o fósforo faz o caminho todo sozinho
                    .accessibilityAction { acenderSozinho(g) }
                    .position(g.caixa)
                    .transition(entradaPelaDireita)
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
        guard !acendendoSozinho else { return }
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
            sessao.haptics.cancelarSomRiscoFosforo()
            zerarRisco()
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
            .allowsHitTesting(!acendendoSozinho)
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
                sessao.haptics.cancelarSomRiscoFosforo()
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
                riscarNaLixa(ponto, g)
            } else {
                // Saiu da lixa: o atrito para e o risco recomeça do zero
                zerarRisco()
                sessao.haptics.silenciarSomRiscoFosforo()
            }
        case .aceso:
            // Encostar no pavio: acende a vela
            let pavio = pontaDoPavio(g)
            if hypot(ponto.x - pavio.x, ponto.y - pavio.y) < max(40, g.larguraVela * 0.6) {
                inicioArraste = nil
                sessao.haptics.cancelarSomRiscoFosforo()
                withAnimation(.easeOut(duration: 0.3)) { etapa = .guardado }
                withAnimation(.easeInOut(duration: 0.4).delay(0.1)) { caixaAberta = CaixaFosforoView.emRepouso }
                sessao.acender()
            }
        case .guardado:
            break
        }
    }

    // FÍSICA DO RISCO (como um fósforo de verdade):
    // - Parado: silêncio.
    // - Devagar: só o som de atrito (Riscando), que some com fade de 20 ms quando o dedo para.
    //   O fósforo NÃO acende, por mais longe que a pessoa risque.
    // - Rápido: a distância conta a partir de onde o risco rápido começou, num sentido só
    //   (ir 30% e voltar 30% = de volta ao zero). Desacelerou abaixo da velocidade mínima: zera.
    //   Chegou a 55% da lixa: o fósforo acende, com o som e a vibração do Acender.
    // Velocidade mínima = 55% da lixa no tempo do áudio Riscando. Assim o áudio nunca é esticado:
    // quem risca rápido o bastante percorre a distância antes de o som de atrito terminar.
    private func riscarNaLixa(_ ponto: CGPoint, _ g: LayoutPalco) {
        let agora = ProcessInfo.processInfo.systemUptime
        let distanciaParaAcender = g.lixa.width * fracaoDaLixaParaAcender
        let velocidadeMinima = distanciaParaAcender / CGFloat(max(0.1, sessao.haptics.duracaoDoRisco))

        guard let ultimo = ultimoPontoRisco, let instanteAnterior = ultimoInstanteRisco else {
            // Encostou na lixa agora
            sessao.haptics.prepararSomRiscoFosforo()
            ultimoPontoRisco = ponto
            ultimoInstanteRisco = agora
            vigiarRiscoParado()
            return
        }

        let intervalo = max(agora - instanteAnterior, 1.0 / 240.0)
        let andouNaHorizontal = ponto.x - ultimo.x
        let caminho = hypot(andouNaHorizontal, ponto.y - ultimo.y)
        let instantanea = abs(andouNaHorizontal) / CGFloat(intervalo)
        if velocidadeDoRisco == 0 {
            velocidadeDoRisco = instantanea   // primeiro movimento: sem esperar a média subir
        } else {
            let peso = CGFloat(min(1, intervalo / suavizacaoDaVelocidade))
            velocidadeDoRisco += (instantanea - velocidadeDoRisco) * peso
        }
        ultimoPontoRisco = ponto
        ultimoInstanteRisco = agora

        // 0 = parado, 1 = na velocidade de acender (ou mais rápido)
        let proporcao = Float(min(1, velocidadeDoRisco / max(1, velocidadeMinima)))

        // Vibração áspera a cada pedacinho: quanto mais devagar, mais forte
        let antes = caminhoNaLixa
        caminhoNaLixa += caminho
        if Int(caminhoNaLixa / caminhoPorVibracao) > Int(antes / caminhoPorVibracao) {
            sessao.haptics.raspar(lentidao: 1 - proporcao)
        }

        // Som de atrito: o volume acompanha a velocidade
        if velocidadeDoRisco < velocidadeDeDedoParado {
            sessao.haptics.silenciarSomRiscoFosforo()
        } else {
            sessao.haptics.tocarSomRiscoFosforo(volume: 0.35 + 0.65 * proporcao)
        }

        // Distância: só conta enquanto está rápido, num sentido só
        if velocidadeDoRisco >= velocidadeMinima {
            let ancora = ancoraDoRisco ?? ultimo.x
            ancoraDoRisco = ancora
            if abs(ponto.x - ancora) >= distanciaParaAcender {
                zerarRisco()
                etapa = .aceso
                sessao.haptics.acenderFosforo()
                return
            }
        } else {
            ancoraDoRisco = nil
        }

        vigiarRiscoParado()
    }

    // O DragGesture não avisa quando o dedo para em cima da lixa: se nenhum movimento
    // chegar neste tempo, o dedo está parado. O som para e o risco rápido zera.
    private func vigiarRiscoParado() {
        vigiaDoRiscoParado?.cancel()
        vigiaDoRiscoParado = Task {
            try? await Task.sleep(for: tempoParaConsiderarParado)
            guard !Task.isCancelled else { return }
            velocidadeDoRisco = 0
            ancoraDoRisco = nil
            sessao.haptics.silenciarSomRiscoFosforo()
        }
    }

    private func zerarRisco() {
        vigiaDoRiscoParado?.cancel()
        vigiaDoRiscoParado = nil
        ultimoPontoRisco = nil
        ultimoInstanteRisco = nil
        ancoraDoRisco = nil
        velocidadeDoRisco = 0
        caminhoNaLixa = 0
    }

    private func soltarFosforo(_ g: LayoutPalco) {
        inicioArraste = nil
        zerarRisco()
        if etapa == .fora {
            sessao.haptics.cancelarSomRiscoFosforo()
        }
        guard etapa != .guardado else { return }
        withAnimation(.spring(duration: 0.5)) { posFosforo = repousoFosforo(g) }
    }

    private func pontaDoPavio(_ g: LayoutPalco) -> CGPoint {
        let alturaCheia = g.alturaCheia(sessao.config.posicaoSlider)
        return CGPoint(x: g.centroX, y: g.baseY - alturaCheia * CGFloat(1 - sessao.progresso))
    }

    // "ACENDER VELA" (VoiceOver e Controle por Voz): o fósforo faz o caminho sozinho.
    // A gaveta abre, o fósforo sobe, risca na lixa, acende e vai até o pavio,
    // com as mesmas vibrações de quando a pessoa faz com o dedo.
    // Com "Reduzir movimento", a vela só acende (sem o fósforo voando pela tela).
    private func acenderSozinho(_ g: LayoutPalco) {
        guard sessao.estado == .nova || sessao.estado == .apagada,
              !acendendoSozinho, !trocando, !trocandoCena else { return }
        sessao.haptics.cancelarSomRiscoFosforo()
        inicioArraste = nil
        zerarRisco()

        if reduzirMovimento {
            etapa = .guardado
            caixaAberta = CaixaFosforoView.emRepouso
            sessao.haptics.acenderFosforo()   // a chama pegando toca, mesmo sem a animação
            sessao.acender()
            return
        }

        acendendoSozinho = true
        Task {
            // 1. A gaveta abre e o fósforo sobe
            if etapa == .guardado {
                posFosforo = g.saidaDoFosforo
                etapa = .fora
                sessao.haptics.tique()
                withAnimation(.easeOut(duration: 0.35)) { caixaAberta = 1 }
                withAnimation(.spring(duration: 0.55, bounce: 0.25).delay(0.12)) {
                    posFosforo = g.repousoDoFosforo
                }
                try? await Task.sleep(for: .seconds(0.75))
            }

            // 2. Risca a cabeça do fósforo na lixa, para lá e para cá
            if etapa == .fora {
                let lixa = g.lixa
                let esquerda = CGPoint(x: lixa.minX + lixa.width * 0.15, y: lixa.midY)
                let direita = CGPoint(x: lixa.maxX - lixa.width * 0.15, y: lixa.midY)
                withAnimation(.easeInOut(duration: 0.3)) { posFosforo = esquerda }
                try? await Task.sleep(for: .seconds(0.3))
                for passada in 0..<3 {
                    sessao.haptics.raspar()
                    withAnimation(.easeInOut(duration: 0.22)) {
                        posFosforo = passada.isMultiple(of: 2) ? direita : esquerda
                    }
                    try? await Task.sleep(for: .seconds(0.22))
                }
                // Sem o som de atrito: só a chama pegando (o padrão Acender, som + vibração)
                etapa = .aceso
                sessao.haptics.acenderFosforo()
                try? await Task.sleep(for: .seconds(0.35))
            }

            // 3. Leva o fósforo aceso até o pavio
            if etapa == .aceso {
                withAnimation(.easeInOut(duration: 0.8)) { posFosforo = pontaDoPavio(g) }
                try? await Task.sleep(for: .seconds(0.85))
            }

            // 4. A vela acende e o fósforo volta para a caixa
            withAnimation(.easeOut(duration: 0.3)) { etapa = .guardado }
            withAnimation(.easeInOut(duration: 0.4).delay(0.1)) { caixaAberta = CaixaFosforoView.emRepouso }
            sessao.acender()
            acendendoSozinho = false
        }
    }

    // MARK: Ações

    // ZOOM OUT: a câmera sai de dentro do teatro — o palco vai encolhendo até virar
    // a caixa lá embaixo — e, no finalzinho, a cortina da caixa fecha.
    //
    // O segredo para ficar liso: é UMA animação só do começo ao fim (a cortina entra
    // com .delay, não com espera no meio), os botões saem de cena antes de começar
    // (senão cresceriam junto com o zoom) e as sombras ficam paradas durante o caminho.
    // forcar: iPhone Duo fechando. Sai da caixa em qualquer estado da vela.
    private func sairDaCaixa(forcar: Bool = false) {
        guard forcar || sessao.estado == .acesa || sessao.estado == .apagada,
              forcar || (!trocando && !acendendoSozinho),
              !trocandoCena, !sessao.foraDaCaixa else { return }
        etapa = .guardado
        if forcar { zerarRisco(); sessao.haptics.cancelarSomRiscoFosforo() }
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
            conferirPostura()   // iPhone Duo: o aparelho pode ter aberto no meio da animação
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
            conferirPostura()   // iPhone Duo: o aparelho pode ter fechado no meio da animação
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
            if !reduzirMovimento {
                withAnimation(.easeIn(duration: 0.9)) { afundando = true }
            }
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
        case let dica as DicaDobrarODuo where dobradica.ehDuo && !trocaManual:
            return dica
        case let dica as DicaEntrarNaCaixa where sessao.foraDaCaixa && trocaManual:
            return dica
        case let dica as DicaSairDaCaixa where podeSairDaCaixa && trocaManual:
            return dica
        case let dica as DicaOutroJeitoDeApagar where podeApagarNaCaixa:
            return dica
        default:
            return nil
        }
    }

    // MARK: - iPhone Duo
    // Tudo aqui só roda com dobradica.ehDuo. No iPhone comum e no iPad, trocaManual é sempre true.

    // Dá para trocar de cena pelo botão, pela pinça e pelo VoiceOver?
    // No Duo, só no modo tenda: no resto, quem troca é abrir e fechar o aparelho.
    private var trocaManual: Bool {
        !dobradica.ehDuo || dobradica.postura == .tenda
    }

    // Dentro da caixa no Duo. Aberto (A) e meio aberto (B) são a caixa inteira, igual ao iPad.
    // Só o laptop (C) muda a tela, com uma animação curta (com Reduzir Movimento, só esmaece).
    private func palcoDoDuo(_ g: LayoutPalco, _ geo: GeometryProxy, divisao: CGRect?) -> some View {
        let laptop = dobradica.postura == .laptop
        return ZStack {
            if laptop {
                vistaLaptop(geo, divisao: divisao)
                    .transition(reduzirMovimento ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            } else {
                dentroDaCaixa(g)
                    .transition(.opacity)
            }
        }
        .animation(reduzirMovimento ? .easeInOut(duration: 0.3) : .spring(duration: 0.6), value: laptop)
    }

    // A tela inteira, contando as áreas fora da área segura (a arte vai até a borda)
    private func telaCheia(_ geo: GeometryProxy) -> CGRect {
        let i = geo.safeAreaInsets
        return CGRect(x: -i.leading, y: -i.top,
                      width: geo.size.width + i.leading + i.trailing,
                      height: geo.size.height + i.top + i.bottom)
    }

    // C: modo laptop. Embaixo da dobra, a caixa do teatro com a cortina aberta e a vela de
    // verdade dentro (com os botões de sempre). Em cima, o teatro de sombras, acompanhando a
    // vela em tempo real. A dobra (região .division) separa as duas metades; sem ela (simulação),
    // a tela é dividida no meio.
    private func vistaLaptop(_ geo: GeometryProxy, divisao: CGRect?) -> some View {
        let cheia = telaCheia(geo)
        let dobra = divisao ?? CGRect(x: cheia.minX, y: cheia.midY, width: cheia.width, height: 0)
        let cima = CGRect(x: cheia.minX, y: cheia.minY, width: cheia.width, height: max(1, dobra.minY - cheia.minY))
        let baixo = CGRect(x: cheia.minX, y: dobra.maxY, width: cheia.width, height: max(1, cheia.maxY - dobra.maxY))
        let lado = min(baixo.width, baixo.height)
        let moldura = (coluna: lado * 0.07, telhado: lado * 0.16, palco: lado * 0.08)
        let margem: CGFloat = 8
        let abertura = CGSize(width: max(1, (baixo.width - margem * 2) / 1.14 - moldura.coluna * 2),
                              height: max(1, baixo.height - moldura.telhado - moldura.palco - margem * 2))
        let medidas = MedidasCaixa(tela: abertura, aberturaFixa: abertura, molduraFixa: moldura)
        let centroDaCaixa = CGPoint(x: baixo.midX, y: baixo.midY)
        let centroDaAbertura = CGPoint(x: centroDaCaixa.x,
                                       y: centroDaCaixa.y - medidas.caixa.height / 2 + moldura.telhado + abertura.height / 2)
        let acesa = sessao.estado == .acesa && !trocando

        return ZStack {
            Cores.fundoEscuro
                .ignoresSafeArea()
                .accessibilityHidden(true)

            // Metade de cima: as sombras na parede (a caixa delas fica de fora: é a de baixo)
            TeatroSombrasView(entrar: {}, mostrarCaixa: false, podeEntrar: false)
                .frame(width: cima.width, height: cima.height)
                .clipped()
                .position(x: cima.midX, y: cima.midY)

            // Metade de baixo: a caixa grande, aberta
            CaixaTeatroView(medidas: medidas, acesa: acesa, aberturaCortina: 1)
                .position(centroDaCaixa)
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            dentroDaCaixa(LayoutPalco(tamanho: abertura))
                .frame(width: abertura.width, height: abertura.height)
                .clipped()
                .position(centroDaAbertura)
        }
    }

    // O que a tela do Duo informa: a dobra (ativa ou não) e onde a câmera cobre a tela.
    // Fora do Duo não pergunta nada, para o iPhone e o iPad ficarem como sempre.
    private func regioesDoDuo(_ geo: GeometryProxy) -> RegioesDoDuo {
        guard dobradica.ehDuo else { return RegioesDoDuo() }
        if #available(iOS 27.1, *) {
            let dobras = geo.reservedRegions(kind: .division, options: .includeInactive)
            return RegioesDoDuo(temDobra: !dobras.isEmpty,
                                divisao: dobras.first { $0.isActive }?.frame,
                                cameras: geo.reservedRegions(kind: .occlusion).map(\.frame))
        }
        return RegioesDoDuo()
    }

    // O palco, com a caixa de fósforos afastada da câmera (só no Duo, só o necessário).
    // A câmera externa fica num canto: na tenda, deitada, ela pode cair em cima da caixa.
    private func layoutDoPalco(_ geo: GeometryProxy, cameras: [CGRect]) -> LayoutPalco {
        var g = LayoutPalco(geo: geo)
        guard dobradica.ehDuo, !cameras.isEmpty else { return g }
        let tela = CGRect(origin: .zero, size: g.tamanho)
        var desvio = CGSize.zero
        for camera in cameras {
            let inteira = CGRect(x: g.caixa.x - g.larguraCaixa / 2 + desvio.width,
                                 y: g.caixa.y - g.alturaCaixa / 2 + desvio.height,
                                 width: g.larguraCaixa, height: g.alturaCaixa)
            // Só conta a parte da caixa que aparece (ela fica meio para fora da tela)
            guard inteira.intersection(tela).intersects(camera) else { continue }
            // O menor caminho para sair de baixo da câmera: para cima ou para a esquerda
            let subir = inteira.maxY - camera.minY
            let irParaEsquerda = inteira.maxX - camera.minX
            if subir <= irParaEsquerda { desvio.height -= subir } else { desvio.width -= irParaEsquerda }
        }
        g.desvioDaCaixa = desvio
        return g
    }

    private func mudouPostura(de antes: PosturaDuo, para agora: PosturaDuo) {
        let duo = dobradica.ehDuo
        DicaSairDaCaixa.pincaPermitida = trocaManual
        DicaEntrarNaCaixa.pincaPermitida = trocaManual
        DicaDobrarODuo.ehDuo = duo && agora != .tenda
        DicaDobrarODuo.fechado = duo && agora == .fechado
        guard duo else { return }

        // Abriu o app (ou a tela foi montada de novo): já começa no lugar certo, sem animação
        if antes == agora {
            if agora == .fechado { sessao.foraDaCaixa = true }
            else if agora != .tenda { sessao.foraDaCaixa = false }
            return
        }

        // A dica do Duo já cumpriu o papel quando a pessoa abre ou fecha o aparelho
        if antes == .fechado || agora == .fechado {
            DicaDobrarODuo().invalidate(reason: .actionPerformed)
        }
        anunciarPostura(agora)
        conferirPostura()
    }

    // Leva a tela para onde a dobra manda. Só abrir e fechar por completo fazem o zoom:
    // fechado = sai da caixa para as sombras; aberto e laptop = entra na caixa.
    private func conferirPostura() {
        guard dobradica.ehDuo, !personalizando, !trocandoCena else { return }
        switch dobradica.postura {
        case .fechado:
            if !sessao.foraDaCaixa { sairDaCaixa(forcar: true) }
        case .tenda:
            break
        case .aberto, .laptop:
            if sessao.foraDaCaixa { entrarNaCaixa() }
        }
    }

    // VoiceOver: diz a tela nova na hora (interrompe a fala, porque é o que está na tela agora)
    private func anunciarPostura(_ postura: PosturaDuo) {
        let texto: String
        switch postura {
        case .aberto: texto = "Dentro da caixa, com a vela"
        case .laptop: texto = "Vela embaixo e teatro de sombras em cima"
        case .fechado: texto = "Teatro de sombras"
        case .tenda: texto = "Modo tenda. Use o botão ou a pinça para trocar de cena"
        }
        var fala = AttributedString(texto)
        fala.accessibilitySpeechAnnouncementPriority = .high
        AccessibilityNotification.Announcement(fala).post()
    }

    private var entradaPelaEsquerda: AnyTransition {
        reduzirMovimento ? .opacity : .move(edge: .leading).combined(with: .opacity)
    }

    private var entradaPelaDireita: AnyTransition {
        reduzirMovimento ? .opacity : .move(edge: .trailing).combined(with: .opacity)
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

    // iPhone Duo, modo laptop: o palco dentro da abertura da caixa grande
    init(tamanho: CGSize) {
        self.tamanho = tamanho
        quadro = Quadro(tela: tamanho)
    }

    var centroX: CGFloat { quadro.x(ArteVela.centroX) }
    var baseY: CGFloat { quadro.y(ArteVela.baseY) }
    var alturaMaxima: CGFloat { ArteVela.alturaMaxima * quadro.escala }
    var larguraVela: CGFloat { ArteVela.largura * quadro.escala }
    var larguraCaixa: CGFloat { min(tamanho.width * 0.34, 150) }
    var alturaCaixa: CGFloat { CaixaFosforoView.altura(largura: larguraCaixa) }
    // iPhone Duo: quanto a caixa de fósforos sai do lugar para a câmera não ficar na frente
    // (a lixa e o fósforo vão junto, porque são contados a partir da caixa)
    var desvioDaCaixa: CGSize = .zero

    // Caixa de fósforos no canto de baixo à direita, meio para fora da tela
    var caixa: CGPoint {
        CGPoint(x: tamanho.width - larguraCaixa * 0.34 + desvioDaCaixa.width,
                y: tamanho.height - alturaCaixa * 0.30 + desvioDaCaixa.height)
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

// iPhone Duo: o que a tela informa (reservedRegions). Fora do Duo fica vazio.
private struct RegioesDoDuo {
    var temDobra = true          // existe uma dobra na tela, ativa ou não (= tela interna)
    var divisao: CGRect?         // a dobra ativa (aparelho meio aberto)
    var cameras: [CGRect] = []   // onde a câmera cobre a tela

    struct Leitura: Equatable {
        var temDobra: Bool
        var dobraDeitada: Bool
        var tamanho: CGSize
    }

    // A dobra deitada (mais larga que alta) é o laptop: uma metade em cima e outra embaixo
    func leitura(tamanho: CGSize) -> Leitura {
        Leitura(temDobra: temDobra,
                dobraDeitada: divisao.map { $0.width > $0.height } ?? false,
                tamanho: tamanho)
    }
}
