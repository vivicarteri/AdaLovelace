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
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverLigado
    @Namespace private var rotorDaCena
    @AccessibilityFocusState private var focoNoFim: Bool
    @State private var confirmarDerreter = false   // balão "Derreter a vela até o fim?" (botão ou ações da vela)

    @State private var personalizando = false
    @AppStorage(Chaves.iluminacaoDramatica) private var iluminacaoDramatica = true
    @State private var cortinaFechada = false
    @State private var trocando = false        // animação de descartar
    @State private var afundando = false       // vela descendo pelo alçapão
    @State private var velaNovaVisivel = true  // a vela nova aparece devagar (na troca de vela)
    @State private var conjuntoEscondido = false   // prato + vela lá embaixo, fora da tela (a vela nova sobe do chão)
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
        DicaRiscarOFosforo()   // primeiro: só vale com a caixa aberta, e aí é a dica que importa
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
            let g = LayoutPalco(geo: geo)
            let caixa = MedidasCaixa(tela: geo.size, margens: geo.safeAreaInsets)
            ZStack {
                if sessao.foraDaCaixa || cameraAtiva {
                    // Vista de fora. A "câmera" (EfeitoCamera) aproxima ou afasta da caixa.
                    TeatroSombrasView(entrar: entrarNaCaixa,
                                      aberturaCaixa: aberturaCaixa,
                                      conteudoDaCaixa: mostrarMiniatura ? miniaturaDoPalco(g, geo, caixa) : nil,
                                      // As sombras continuam andando durante o zoom. Antes elas
                                      // paravam e voltavam a andar de uma vez no fim do zoom out
                                      // (era a "travadinha" quando a tela de sombras terminava).
                                      congelado: false,
                                      mostrarCamadas: !trocandoCena,
                                      margens: geo.safeAreaInsets)
                        .modifier(EfeitoCamera(z: camera, zoomFinal: caixa.zoomFinal,
                                               alvo: caixa.alvoDaCamera, tela: geo.size))
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
            // Smart Invert: a arte de papel, a vela e as sombras não ficam em negativo
            .accessibilityIgnoresInvertColors()
            .onChange(of: alturaDaChamaNaTela(g, caixa, geo), initial: true) { _, altura in
                sessao.chamaMudouDeLugar(altura)
            }
        }
        // A caixa de fósforos fica lá embaixo, encostada na borda: riscando o fósforo, o dedo
        // passava pela barrinha de baixo do iPhone e trocava de app sem querer (teste da Sofia).
        // Assim o primeiro deslize na borda de baixo fica com o app; para sair, desliza de novo.
        .defersSystemGestures(on: .bottom)
        .onAppear {
            // Vela nova (ainda não acesa) ou que acabou: a cortina está fechada
            cortinaFechada = sessao.estado == .acabou || sessao.estado == .nova
            // A vela acabou com o app fechado: já coloca a vela nova (não tem mais tela de "Fim")
            if sessao.estado == .acabou {
                Task {
                    try? await Task.sleep(for: .seconds(0.6))
                    if sessao.estado == .acabou { descartar() }
                }
            }
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
        // Com o VoiceOver não dá para fazer pinça nem riscar à mão: essas dicas não aparecem
        .onChange(of: voiceOverLigado, initial: true) { _, ligado in
            DicaSairDaCaixa.voiceOverLigado = ligado
            DicaEntrarNaCaixa.voiceOverLigado = ligado
            DicaRiscarOFosforo.voiceOverLigado = ligado
        }
        .onChange(of: etapa != .guardado, initial: true) { _, aberta in
            DicaRiscarOFosforo.caixaAberta = aberta
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
            // Acendeu: a cortina abre e mostra a floresta
            if novo == .acesa && cortinaFechada {
                withAnimation(.easeInOut(duration: 1.6)) { cortinaFechada = false }
            }
            if novo == .acabou && sessao.foraDaCaixa {
                entrarNaCaixa()   // a vela acabou nas sombras: entra na caixa
            }
            if novo == .acabou {
                Task {
                    try? await Task.sleep(for: .seconds(1.5))
                    withAnimation(.easeInOut(duration: 1.6)) { cortinaFechada = true }
                    // Não tem mais tela de "Fim" (teste da Sofia: ficava anticlimático e era um
                    // toque a mais): com a cortina fechada, a vela nova já sobe sozinha do prato.
                    try? await Task.sleep(for: .seconds(1.8))
                    if sessao.estado == .acabou { descartar() }
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

    // O palco em miniatura que aparece dentro da caixa durante o zoom: o MESMO palco, desenhado
    // na tela inteira (com as margens da área segura), para bater certinho com o palco de verdade
    // quando a câmera chega.
    private func miniaturaDoPalco(_ g: LayoutPalco, _ geo: GeometryProxy, _ caixa: MedidasCaixa) -> AnyView {
        guard caixa.usaArte else { return AnyView(dentroDaCaixa(g, miniatura: true)) }
        return AnyView(
            dentroDaCaixa(g, miniatura: true)
                .frame(width: geo.size.width, height: geo.size.height)
                .safeAreaPadding(geo.safeAreaInsets)
        )
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
            // A floresta aparece com a vela ACESA e continua aparecendo (no escuro) quando a pessoa
            // APAGA a vela no meio: o cenário fica pausado e escuro, não preto. Com a vela nova ou
            // que acabou, a cortina fechada cobre tudo.
            CenarioView(acesa: acesa, progresso: sessao.progresso,
                        mostrarPersonagens: estado == .acesa || estado == .apagada, quadro: g.quadro)
                .accessibilityHint(acesa ? "Use o rotor Camadas de papel para explorar a cena" : "")

            // VoiceOver: uma camada de papel por vez (rotor "Camadas de papel"). Fica embaixo
            // da vela e dos botões, para o toque do VoiceOver achar eles primeiro.
            if !miniatura {
                CamadasDaCenaAcessiveis(camadas: camadasDoRotor, rotor: rotorDaCena)
            }

            // Cortina lateral (arte "Cortina_Horizontal" da Georgia), ATRÁS da vela: fecha dos lados
            // para o meio quando a vela acaba e só reabre quando a vela é ACESA.
            CortinaLateralView(fechada: cortinaFechada)

            // Vela apagada = tudo escuro, só a vela e os botões em destaque.
            // Vela acesa = o cenário fica só um pouco mais escuro, para a vela aparecer mais.
            // O MESMO escuro vale para o cenário pausado e para a cortina fechada (fica por cima dos dois).
            // Acendendo, o escuro sai rápido; apagando, ele desce devagar.
            Color.black.opacity(acesa ? MedidasDoPalco.escuroComVelaAcesa : MedidasDoPalco.escuroComVelaApagada)
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
                         destaque: acesa,
                         apagouEm: fumacaDaTroca ?? sessao.apagouEm,
                         movimento: sessao.movimento,
                         enfeites: sessao.config.enfeites,
                         caidos: sessao.caidos)
                    .accessibilityHidden(true)   // o VoiceOver usa o alvo "vela + prato" (velaAcessivel)
                    .position(x: g.centroX,
                              y: g.baseY - (alturaCheia + espacoChama) / 2 + (afundando ? alturaCheia + espacoChama : 0))
            }
            .frame(width: g.tamanho.width, height: g.tamanho.height)
            .mask(alignment: .top) { Rectangle().frame(height: g.baseY + 2) }
            .opacity(velaNovaVisivel ? 1 : 0)
            .offset(y: conjuntoEscondido ? g.fundoDaTela : 0)

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
                          y: g.baseY + SuporteView.desvioY(largura: g.larguraVela))
                .offset(y: conjuntoEscondido ? g.fundoDaTela : 0)

            if !miniatura {
                botoesInferiores(g)
                    .opacity(mostrarBotoes ? 1 : 0)

                if etapa != .guardado {
                    fosforo(g)
                        .opacity(mostrarBotoes ? 1 : 0)
                }

                if let dica = dicaAtual as? DicaRiscarOFosforo {
                    dicaDoFosforo(dica, g)
                        .opacity(mostrarBotoes ? 1 : 0)
                }
            }
        }
        .coordinateSpace(.named("palco"))
        .accessibilityElement(children: .contain)
        .rotorCamadasDePapel(miniatura ? [] : camadasDoRotor, in: rotorDaCena)
    }

    private var camadasDoRotor: [CamadaDescrita] {
        sessao.estado == .acesa ? DescricaoDaCena.camadas(sombra: false) : []
    }

    // VoiceOver: a vela e o prato são UM elemento só (antes a moldura pegava só a vela).
    // Vai do alto da chama até o fim do prato. O toque duplo acende ou apaga;
    // o resto fica nas ações. É também o "Verificar estado da vela" do rotor Camadas de papel.
    private func velaAcessivel(_ g: LayoutPalco, topoCera: CGFloat, espacoChama: CGFloat) -> some View {
        let estado = sessao.estado
        let alto = topoCera - espacoChama
        let baixo = g.baseY + SuporteView.desvioY(largura: g.larguraVela) + SuporteView.altura(largura: g.larguraVela) / 2
        // Na largura, só um pouco mais que a vela: o prato vai quase de ponta a ponta no iPhone
        // e a moldura cobriria os botões de baixo no toque do VoiceOver.
        let largura = g.larguraVela * 2
        let hint: String
        switch estado {
        case .acesa: hint = "Toque duas vezes para apagar"
        case .nova, .apagada: hint = "Toque duas vezes para acender"
        case .acabou: hint = ""
        }
        return AlvoAcessivel()
            .frame(width: largura, height: max(44, baixo - alto))
            .position(x: g.centroX + SuporteView.desvioX(largura: g.larguraVela), y: (alto + baixo) / 2)
            .allowsHitTesting(false)
            .accessibilityElement()
            .accessibilityLabel("Vela")
            .accessibilityValue(sessao.descricaoDaVela)
            .accessibilityHint(trocando ? "" : hint)
            .accessibilityAction { acaoPrincipalDaVela(g) }
            .accessibilityActions { atalhos(g) }
            .accessibilityRotorEntry(id: CamadasDaCenaAcessiveis.idDaVela, in: rotorDaCena)
            .accessibilitySortPriority(3)   // ordem: vela, botão de baixo, caixa de fósforos, cenário
            .accessibilityHidden(estado == .acabou && cortinaFechada)   // aí quem fala é o "Fim"
    }

    // A dica de riscar à mão, logo acima do fósforo, com a ponta apontando para ele
    private func dicaDoFosforo(_ dica: DicaRiscarOFosforo, _ g: LayoutPalco) -> some View {
        let margem: CGFloat = 16
        let largura = min(340, g.tamanho.width - margem * 2)
        let esquerda = g.tamanho.width - margem - largura
        // O alto do fósforo em pé (a cabeça fica em repousoDoFosforo)
        let altoDoFosforo = g.repousoDoFosforo.y - FosforoView.posicaoCabeca(tamanho: tamanhoFosforo) - 8
        return VStack(spacing: 0) {
            Spacer(minLength: 0)
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                BalaoDeDica(dica: dica, pontaX: g.repousoDoFosforo.x - esquerda, pontaEmCima: false)
                    .frame(width: largura)
            }
            .padding(.trailing, margem)
        }
        .frame(width: g.tamanho.width, height: max(0, altoDoFosforo))
        .position(x: g.tamanho.width / 2, y: max(0, altoDoFosforo) / 2)
        .transition(.opacity)
    }

    // Toque duplo do VoiceOver na vela
    private func acaoPrincipalDaVela(_ g: LayoutPalco) {
        guard !trocando else { return }
        switch sessao.estado {
        case .acesa: apagarTocandoNaChama()
        case .nova, .apagada: acenderSozinho(g)
        case .acabou: break
        }
    }

    // Atalhos do VoiceOver (menu de ações da vela). São também a alternativa a virar o aparelho,
    // soprar, riscar o fósforo e segurar o botão: nenhum gesto físico é o único caminho.
    // Só ações da vela: os botões da tela (configurações, afastar…) já se encontram deslizando.
    //   nova:            Acender vela, Personalizar vela
    //   acesa:           Apagar chama, Acelerar derretimento (ou Voltar ao ritmo normal)
    //   apagada no meio: Acender vela, Derreter a vela até o fim
    @ViewBuilder
    private func atalhos(_ g: LayoutPalco) -> some View {
        if !trocando {
            switch sessao.estado {
            case .nova:
                Button("Acender vela") { acenderSozinho(g) }
                Button("Personalizar vela") { abrirPersonalizacao() }
            case .acesa:
                Button("Apagar chama") { apagarTocandoNaChama() }
                Button(sessao.derretimentoAcelerado ? "Voltar ao ritmo normal da vela" : "Acelerar derretimento da vela") {
                    sessao.alternarDerretimentoAcelerado()
                }
            case .apagada:
                Button("Acender vela") { acenderSozinho(g) }
                Button("Derreter a vela até o fim") { confirmarDerreter = true }
            case .acabou:
                EmptyView()
            }
        }
    }

    private func abrirPersonalizacao() {
        etapa = .guardado
        trocarComCortina { personalizando = true }
    }

    // MARK: Botões

    private var barraSuperior: some View {
        // A dica do fósforo aparece lá embaixo, perto da caixa (dicaDoFosforo)
        let dica = dicaAtual is DicaRiscarOFosforo ? nil : dicaAtual
        let mostraSeta = dica is DicaSairDaCaixa || dica is DicaEntrarNaCaixa

        return VStack {
            HStack {
                if sessao.foraDaCaixa {
                    BotaoRedondo(icone: "arrow.up.left.and.arrow.down.right", rotulo: "Aproximar a caixa",
                                 tamanho: MedidasBarraDoPalco.diametro,
                                 comandosDeVoz: ["Entrar na caixa", "Voltar para a vela", "Aproximar"],
                                 dica: "Volta para a vela dentro da caixa", acao: entrarNaCaixa)
                } else if podeSairDaCaixa {
                    BotaoRedondo(icone: "arrow.down.right.and.arrow.up.left", rotulo: "Afastar a caixa",
                                 tamanho: MedidasBarraDoPalco.diametro,
                                 comandosDeVoz: ["Teatro de sombras", "Afastar", "Sair da caixa"],
                                 dica: "Mostra as sombras da vela na parede", acao: sairDaCaixa)
                        .transition(.opacity)
                }
                Spacer()
                BotaoRedondo(icone: "gearshape", rotulo: "Configurações", tamanho: MedidasBarraDoPalco.diametro,
                             comandosDeVoz: ["Abrir configurações", "Ajustes"], acao: abrirConfiguracoes)
            }
            .animation(.spring(duration: 0.6), value: podeSairDaCaixa)

            // As duas cenas compartilham o mesmo espaço para dicas, inclusive durante o zoom.
            // A ponta sai do centro do botão de cima à esquerda
            if dica != nil {
                BalaoDeDica(dica: dica, pontaX: mostraSeta ? MedidasBarraDoPalco.diametro / 2 : nil)
                    .frame(maxWidth: 340)
                    .frame(maxWidth: .infinity, alignment: mostraSeta ? .leading : .center)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, MedidasBarraDoPalco.margemSuperior)
    }

    private func botoesInferiores(_ g: LayoutPalco) -> some View {
        let estado = sessao.estado

        return ZStack {
            // Embaixo à esquerda: personalizar (vela nova) ou derreter (depois de acender).
            // Continua na tela com a caixa aberta (a gaveta e o fósforo ficam do outro lado).
            ZStack {
                if estado == .nova && !trocando {
                    BotaoRedondo(icone: "paintbrush.pointed", rotulo: "Personalizar vela", tamanho: 60,
                                 comandosDeVoz: ["Abrir personalização", "Personalizar", "Ateliê"]) {
                        abrirPersonalizacao()
                    }
                    .transition(entradaPelaEsquerda)
                } else if estado != .nova && estado != .acabou && !trocando {
                    // (Quando a vela acaba não tem botão aqui: o "Fim" no meio da cortina é o toque)
                    // Acesa ou apagada: segurar derrete a vela rápido; soltar para
                    BotaoDescartar(tamanho: 60, haptics: sessao.haptics,
                                   anel: sessao.progresso,
                                   derreter: { segurando in
                                       if segurando { sessao.comecarADerreter() } else { sessao.pararDeDerreter() }
                                   },
                                   pedirConfirmacao: { confirmarDerreter = true },
                                   descartar: { sessao.derreterAteOFim() })
                        .transition(entradaPelaEsquerda)
                }
            }
            .accessibilitySortPriority(2)
            .confirmationDialog("Derreter a vela até o fim?", isPresented: $confirmarDerreter,
                                titleVisibility: .visible) {
                BotoesDeDerreter { sessao.derreterAteOFim() }
            }
            .position(x: g.botaoBaixoX, y: g.botaoBaixoY)

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
                    .accessibilitySortPriority(2)
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
                    .onEnded { valor in soltarFosforo(valor, g) }
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

    private func esquecerArraste() {
        inicioArraste = nil
        toqueDoArraste = nil
        zerarRisco()   // o risco na lixa (física da Sofia) também recomeça do zero
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
            zerarRisco()
        }
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
                DicaRiscarOFosforo().invalidate(reason: .actionPerformed)   // aprendeu a riscar à mão
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

    // ⚙️ Até quanto o dedo pode andar (pontos) para o gesto no fósforo contar como um toque
    private let distanciaDeUmToque: CGFloat = 8

    private func soltarFosforo(_ valor: DragGesture.Value, _ g: LayoutPalco) {
        inicioArraste = nil
        toqueDoArraste = nil
        zerarRisco()
        if etapa == .fora {
            sessao.haptics.cancelarSomRiscoFosforo()
        }
        guard etapa != .guardado else { return }
        // Um toque no fósforo (sem arrastar): ele risca sozinho e acende a vela
        if hypot(valor.translation.width, valor.translation.height) < distanciaDeUmToque {
            acenderSozinho(g, peloToque: true)
            return
        }
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
    // peloToque: a pessoa tocou no fósforo (sem VoiceOver). Conta para a dica de riscar à mão.
    private func acenderSozinho(_ g: LayoutPalco, peloToque: Bool = false) {
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
            if peloToque { DicaRiscarOFosforo.acendeuPeloToque.sendDonation() }
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
            if peloToque { await DicaRiscarOFosforo.acendeuPeloToque.donate() }
        }
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
              !trocando, !trocandoCena, !acendendoSozinho, !sessao.foraDaCaixa else { return }
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

            // 3. A câmera se afasta e a cortina da caixa fecha JUNTO, no mesmo ritmo: os panos
            //    entram pelas beiradas da tela desde o primeiro instante e vão se encontrando no
            //    meio. (Antes a cortina só começava a fechar depois, e por um instante aparecia a
            //    caixa aberta com o palco bem fininho no meio, "do nada".)
            withAnimation(.easeInOut(duration: 1.5)) {
                camera = 0
                aberturaCaixa = 0
            }
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

            // A câmera entra e a cortina vai abrindo JUNTO, no mesmo ritmo: quando a câmera
            // chega, os panos acabaram de sair pelas beiradas da tela
            withAnimation(.easeInOut(duration: 1.5)) {
                aberturaCaixa = 1
                camera = 1
            }
            try? await Task.sleep(for: .seconds(1.6))

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
        // A vela já acabou: não tem o que afundar e a cortina já está fechada.
        // Pula direto para a vela nova subindo (sem esperar à toa).
        let jaAcabou = sessao.estado == .acabou
        trocando = true
        etapa = .guardado
        sessao.haptics.pararChama()
        if estavaAcesa {
            sessao.haptics.apagar()
            fumacaDaTroca = Date()
        }
        Task {
            if estavaAcesa { try? await Task.sleep(for: .seconds(0.8)) }
            if jaAcabou {
                // A vela já acabou e a cortina já está fechada: não tem o que afundar
                var semAnimacao = Transaction()
                semAnimacao.disablesAnimations = true
                withTransaction(semAnimacao) { cortinaFechada = true }
            } else {
                // A vela velha afunda pelo alçapão do prato e a cortina fecha
                if !reduzirMovimento {
                    withAnimation(.easeIn(duration: 0.9)) { afundando = true }
                }
                try? await Task.sleep(for: .seconds(0.9))
                withAnimation(.easeInOut(duration: 0.9)) { cortinaFechada = true }
                try? await Task.sleep(for: .seconds(1.0))
            }

            if reduzirMovimento {
                // Com "Reduzir movimento" a vela nova só aparece devagar, sem subir
                sessao.descartar()
                fumacaDaTroca = nil
                var semAnimacao = Transaction()
                semAnimacao.disablesAnimations = true
                withTransaction(semAnimacao) {
                    velaNovaVisivel = false
                    afundando = false
                }
                withAnimation(.easeOut(duration: 0.6)) { velaNovaVisivel = true }
                try? await Task.sleep(for: .seconds(0.6))
            } else {
                // A vela nova SOBE DO CHÃO já INTEIRA, em pé no prato: o prato vazio desce para
                // baixo do palco e volta subindo com a vela nova. Antes ela saía de dentro do
                // prato e, por um instante, parecia uma vela cortada "crescendo".
                withAnimation(.easeIn(duration: 0.45)) { conjuntoEscondido = true }
                try? await Task.sleep(for: .seconds(0.45))
                sessao.descartar()
                fumacaDaTroca = nil
                var semAnimacao = Transaction()
                semAnimacao.disablesAnimations = true
                withTransaction(semAnimacao) { afundando = false }
                // Uma pausinha, para a vela nova ser desenhada lá embaixo antes de subir
                try? await Task.sleep(for: .milliseconds(50))
                withAnimation(.easeOut(duration: 1.1)) { conjuntoEscondido = false }
                try? await Task.sleep(for: .seconds(1.1))
            }
            trocando = false
        }
    }

    private var podeSairDaCaixa: Bool {
        !sessao.foraDaCaixa && !trocando && (sessao.estado == .acesa || sessao.estado == .apagada)
    }

    // A caixa de fósforos está na tela e dá para pegar um fósforo
    private var podePegarFosforo: Bool {
        (sessao.estado == .nova || sessao.estado == .apagada) && !trocando && !sessao.foraDaCaixa
            && etapa == .guardado && !personalizando
    }

    private var podeApagarNaCaixa: Bool {
        podeSairDaCaixa && sessao.estado == .acesa
    }

    private var dicaAtual: (any Tip)? {
        guard !trocandoCena else { return nil }
        // O contexto da tela muda antes de o TipKit reavaliar as regras.
        switch dicas.currentTip {
        case let dica as DicaRiscarOFosforo where etapa != .guardado && !voiceOverLigado && !sessao.foraDaCaixa:
            return dica
        case let dica as DicaEntrarNaCaixa where sessao.foraDaCaixa && !voiceOverLigado:
            return dica
        case let dica as DicaSairDaCaixa where podeSairDaCaixa && !voiceOverLigado:
            return dica
        case let dica as DicaOutroJeitoDeApagar where podeApagarNaCaixa:
            return dica
        default:
            return nil
        }
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

    let fundoDaTela: CGFloat   // a borda de baixo do aparelho (passa da área segura)

    init(geo: GeometryProxy) {
        tamanho = geo.size
        quadro = Quadro(geo: geo)
        fundoDaTela = geo.size.height + geo.safeAreaInsets.bottom
    }

    var centroX: CGFloat { quadro.x(ArteVela.centroX) }
    // O prato fica encostado na borda de baixo do aparelho, em qualquer tela:
    // a base da vela (borda de cima do prato) é calculada a partir do fundo do prato.
    var baseY: CGFloat { fundoDaTela - (PosicaoArte.suporte.maxY - ArteVela.baseY) * quadro.escala }
    // Onde começam as alças do prato (o ponto mais alto dele)
    var topoDoPrato: CGFloat { baseY + (PosicaoArte.suporte.minY - ArteVela.baseY) * quadro.escala }
    var alturaMaxima: CGFloat { ArteVela.alturaMaxima * quadro.escala }
    var larguraVela: CGFloat { ArteVela.largura * quadro.escala }
    var larguraCaixa: CGFloat { min(tamanho.width * 0.34, 150) }
    var alturaCaixa: CGFloat { CaixaFosforoView.altura(largura: larguraCaixa) }

    // Caixa de fósforos no canto de baixo à direita, meio para fora da tela
    var caixa: CGPoint {
        CGPoint(x: tamanho.width - larguraCaixa * 0.34, y: tamanho.height - alturaCaixa * 0.30)
    }

    // Botão de baixo à esquerda (personalizar / acabar com a vela).
    // No iPhone o prato da vela vai quase de ponta a ponta: aí o botão sobe para ficar
    // acima da alça esquerda do prato, em vez de ficar por cima dela.
    // No iPad o prato fica longe do botão e ele continua no lugar de sempre.
    var botaoBaixoX: CGFloat { tamanho.width * 0.17 }
    var botaoBaixoY: CGFloat {
        let normal = tamanho.height * 0.92
        let raio: CGFloat = 30   // o botão tem 60 de tamanho
        // A alça esquerda ocupa mais ou menos o primeiro quarto da largura do prato
        let alcaComeca = quadro.x(PosicaoArte.suporte.minX)
        let alcaTermina = alcaComeca + PosicaoArte.suporte.width * quadro.escala * 0.26
        let encosta = botaoBaixoX + raio > alcaComeca && botaoBaixoX - raio < alcaTermina
        guard encosta else { return normal }
        return min(normal, topoDoPrato - raio - 10)
    }

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


enum MedidasDoPalco {
    // ⚙️ Quanto o palco escurece com a vela apagada (cenário pausado ou cortina fechada).
    // 0 = nada, 1 = preto.
    static let escuroComVelaApagada: Double = 0.58
    static let escuroComVelaAcesa: Double = 0.2   // escurece o cenário de leve, a vela fica em destaque
}
