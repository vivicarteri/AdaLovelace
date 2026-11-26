//  PersonalizacaoView.swift
//  O ateliê: escolher o tamanho da vela (= tempo) e espetar alfinetes e penduricalhos.
//
//  Regras:
//  - Fechar: perde tudo o que mudou. Confirmar: salva e o modal desce para a home.
//  - Até 6 alfinetes (o limite é o que tem nas almofadas), para qualquer tamanho de vela.
//  - Sem abas (ideia da Sofia, mais "dentro da cena"): o slider do tamanho fica sempre ao lado
//    da vela e as almofadas com os alfinetes ficam sempre à mostra, embaixo.
//    Os penduricalhos saíram da tela, mas o código deles continua (VelaView/VelaConfig).
//  - Arrastar da caixinha até a vela. Se não encostar na vela, cai no pote, faz barulho e volta para a caixinha.
//  - Dá para tirar e reposicionar: fica um furinho onde ele estava.
//  - Slider exponencial de 10 a 180 minutos. Na tela não aparece nenhum número.

import SwiftUI
import Foundation

struct PersonalizacaoView: View {
    var haptics: Haptics
    var fechar: () -> Void
    var confirmar: (VelaConfig) -> Void

    @State private var rascunho: VelaConfig
    private let original: VelaConfig                 // como a vela estava ao entrar
    @State private var confirmarSaida = false        // "sair sem salvar?"


    // Enfeite sendo arrastado (da caixinha ou tirado da vela)
    private struct Arrastando {
        var tipo: TipoEnfeite
        var ponto: CGPoint          // onde o alfinete vai espetar
        var tiradoDe: Enfeite?      // se veio da vela
        var daCaixinha: Int? = nil  // qual peça da caixinha está na mão (a que a pessoa pegou)
        var estilo = 0              // qual desenho de alfinete (estrela, coração ou bolinha)
        var caindo = false
    }
    @State private var arrastando: Arrastando?

    // A ordem das peças na caixinha (cada peça tem um número que não muda). Assim, quando uma sai,
    // as outras andam para fechar o buraco, com animação, em vez de sumir sempre a última.
    @State private var pecasNaCaixinha: [TipoEnfeite: [Int]] = [:]

    // Quais alfinetes já saíram das almofadas (o número é a vaga, veja ArteAtelie.vagas).
    // Cada alfinete tem o seu lugar: quando um sai, os outros não mudam de lugar.
    @State private var vagasUsadas: Set<Int>

    // Para o enfeite ficar visível acima do dedo
    private let acimaDoDedo: CGFloat = 36

    @Namespace private var rotorEnfeites   // VoiceOver: rotor "Enfeites"
    @AccessibilityFocusState private var focoNaVela: Bool
    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento

    init(config: VelaConfig, haptics: Haptics, fechar: @escaping () -> Void, confirmar: @escaping (VelaConfig) -> Void) {
        self.haptics = haptics
        self.fechar = fechar
        self.confirmar = confirmar
        _rascunho = State(initialValue: config)
        _vagasUsadas = State(initialValue: PersonalizacaoView.vagasOcupadas(por: config))
        original = config
    }

    var body: some View {
        GeometryReader { geo in
            let g = LayoutAtelie(tamanho: geo.size)
            ZStack {
                fundo

                barraDeCima

                velaEmEdicao(g)

                // O slider do tamanho, sempre ao lado da vela
                slider(g)

                // As almofadas com os alfinetes, sempre à mostra
                caixinha(g)

                // Enfeite voando com o dedo (ou caindo no pote)
                if let arrastando {
                    EnfeiteView(tipo: arrastando.tipo,
                                lado: arrastando.ponto.x < g.centroX ? -1 : 1,
                                largura: g.larguraVela,
                                estilo: arrastando.estilo)
                        // A linha do alfinete fica EXATAMENTE onde ele vai espetar (igual na vela).
                        // Antes a conta estava invertida: no penduricalho, o que ficava no ponto era a
                        // estrelinha, e ao soltar ele subia (não ficava onde a pessoa escolheu).
                        .position(x: arrastando.ponto.x,
                                  y: arrastando.ponto.y
                                     + EnfeiteView.alturaDoAlfinete(arrastando.tipo, estilo: arrastando.estilo, largura: g.larguraVela)
                                     - EnfeiteView.alturaDesenho(arrastando.tipo, estilo: arrastando.estilo, largura: g.larguraVela) / 2)
                        .allowsHitTesting(false)
                }
            }
            .coordinateSpace(.named("atelie"))
            // Smart Invert: o ateliê é arte de papel e madeira, não inverte
            .accessibilityIgnoresInvertColors()
            .accessibilityElement(children: .contain)
            // VoiceOver: pula de enfeite em enfeite espetado na vela
            .accessibilityRotor("Enfeites") {
                ForEach(rascunho.enfeites) { enfeite in
                    AccessibilityRotorEntry(Text(rotulo(enfeite)), id: enfeite.id, in: rotorEnfeites)
                }
            }
        }
        // Ao entrar, o VoiceOver começa na vela (antes ficava no lugar do toque anterior, no Confirmar).
        // Espera a cortina subir; com Reduzir movimento a tela só aparece, sem cortina.
        .task {
            if !reduzirMovimento { try? await Task.sleep(for: .seconds(1.6)) }
            focoNaVela = true
        }
    }

    private var dicaDaVela: String {
        switch arrastando?.tipo {
        case .alfinete: "Use as ações para inserir alfinetes, e o rotor Enfeites para visitar cada um"
        case .penduricalho: "Use as ações para inserir penduricalhos, e o rotor Enfeites para visitar cada um"
        case nil: ""
        }
    }

    // MARK: Partes da tela

    // Fundo: estou num ateliê (mesa de madeira)
    // Fundo: a mesma cortina fechada (e o mesmo escuro) da tela da vela, porque a vela
    // ainda não foi acesa. Antes era a mesa de madeira do ateliê.
    private var fundo: some View {
        ZStack {
            Cores.fundoEscuro.ignoresSafeArea()
            CortinaLateralView(fechada: true)
            Color.black.opacity(MedidasDoPalco.escuroComVelaApagada)
                .ignoresSafeArea()
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var barraDeCima: some View {
        VStack {
            HStack {
                // Se a pessoa mudou alguma coisa, pergunta antes de jogar fora (dupla confirmação)
                BotaoRedondo(icone: "xmark", rotulo: "Fechar sem salvar", tamanho: 44,
                             comandosDeVoz: ["Fechar", "Cancelar", "Sair"]) {
                    if rascunho == original { fechar() } else { confirmarSaida = true }
                }
                .confirmationDialog("Sair sem salvar?", isPresented: $confirmarSaida, titleVisibility: .visible) {
                    Button("Descartar alterações", role: .destructive, action: fechar)
                    Button("Continuar editando", role: .cancel) {}
                } message: {
                    Text("As mudanças que você fez na vela vão se perder.")
                }
                Spacer()
                BotaoRedondo(icone: "checkmark", rotulo: "Confirmar", tamanho: 44,
                             comandosDeVoz: ["Salvar", "Pronto"]) {
                    haptics.tique()
                    confirmar(rascunho)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private func velaEmEdicao(_ g: LayoutAtelie) -> some View {
        let alturaCheia = g.alturaCheia(rascunho.posicaoSlider)
        let espacoChama = VelaView.espacoChama(largura: g.larguraVela)
        let movendo = arrastando?.tiradoDe?.id
        let tipo = arrastando?.tipo ?? .alfinete

        return ZStack {
            VelaView(alturaCheia: alturaCheia,
                     largura: g.larguraVela,
                     enfeites: rascunho.enfeites.filter { $0.id != movendo },
                     marcas: rascunho.marcas)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Vela")
                .accessibilityValue("\(DescricaoDaDuracao.texto(minutos: rascunho.minutos)). \(rascunho.quantos(.alfinete)) alfinetes e \(rascunho.quantos(.penduricalho)) penduricalhos")
                .accessibilityHint(dicaDaVela)
                // As ações seguem a aba: na Duração não tem nenhuma (a duração fica no ajustável);
                // em Alfinetes e Penduricalhos, só as daquele tipo.
                .accessibilityActions {
                    ForEach(LugarNaVela.allCases, id: \.self) { lugar in
                        Button("Inserir \(tipo.nome) \(lugar.texto)") { colocarPeloVoiceOver(tipo, lugar, g) }
                    }
                    if let ultimo = rascunho.enfeites.last(where: { $0.tipo == tipo }) {
                        Button("Tirar o último \(tipo.nome)") { remover(ultimo) }
                    }
                }
                .accessibilityFocused($focoNaVela)
                // A vela muda de tamanho junto com o dedo (antes uma mola deixava a vela atrasada
                // em relação à bolinha)
                .position(x: g.centroX, y: g.baseY - (alturaCheia + espacoChama) / 2)

            SuporteView(largura: g.larguraVela)
                .position(x: g.centroX + SuporteView.desvioX(largura: g.larguraVela),
                          y: g.baseY + SuporteView.desvioY(largura: g.larguraVela))

            // Áreas de toque em cima de cada enfeite, para tirar e reposicionar.
            // Elas ficam em cima do DESENHO (o penduricalho pendura para baixo, então
            // a área acompanha a estrelinha em vez de ficar só na linha do alfinete).
            ForEach(rascunho.enfeites) { enfeite in
                let acima = EnfeiteView.acima(enfeite.tipo, estilo: enfeite.desenho, largura: g.larguraVela)
                let abaixo = EnfeiteView.abaixo(enfeite.tipo, estilo: enfeite.desenho, largura: g.larguraVela)
                // O enfeite fica espetado na borda da cera (que muda com a altura): a área de toque vai junto
                let meio = VelaView.meioDoEnfeite(enfeite.tipo, estilo: enfeite.desenho, lado: enfeite.lado,
                                                  altura: CGFloat(enfeite.altura) * alturaCheia,
                                                  largura: g.larguraVela, alturaCera: alturaCheia)
                // Quase transparente (e não .clear), para o VoiceOver enxergar o enfeite
                Color.black.opacity(0.001)
                    .frame(width: 44, height: max(36, acima + abaixo))
                    .contentShape(Rectangle())
                    .gesture(arrasto(tipo: enfeite.tipo, tiradoDe: enfeite, g))
                    // VoiceOver: cada enfeite é um item, com a ação de remover
                    .accessibilityElement()
                    .accessibilityLabel(rotulo(enfeite))
                    .accessibilityAction(named: "Remover") { remover(enfeite) }
                    .accessibilityRotorEntry(id: enfeite.id, in: rotorEnfeites)
                    .position(x: g.centroX + meio.x,
                              y: g.baseY - CGFloat(enfeite.altura) * alturaCheia + (abaixo - acima) / 2)
            }
        }
    }

    // Slider vertical ao lado da vela. A bolinha fica na altura do topo da CERA
    // (o desenho da vela termina na ponta do pavio, que fica um pouco acima).
    private func slider(_ g: LayoutAtelie) -> some View {
        let x = g.tamanho.width * 0.85
        let yMin = g.topoDaCera(0)    // vela mais curta
        let yMax = g.topoDaCera(1)    // vela mais longa
        let yAtual = g.topoDaCera(rascunho.posicaoSlider)
        let altura = yMin - yMax
        let folga: CGFloat = 24                  // área de toque um pouco maior que o trilho

        return ZStack {
            // Linha tracejada ligando o topo da vela à bolinha (só enfeite, não recebe toque)
            Path { p in
                p.move(to: CGPoint(x: g.centroX + g.larguraVela, y: yAtual))
                p.addLine(to: CGPoint(x: x - 18, y: yAtual))
            }
            .stroke(Cores.papel.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
            .allowsHitTesting(false)

            // O slider em si, numa área pequena ao lado da vela
            ZStack(alignment: .top) {
                Capsule()
                    .fill(Cores.papel.opacity(0.6))   // 0,6: contraste mínimo de 3:1 com a madeira
                    .frame(width: 6, height: altura)
                    .offset(y: folga)

                // Marcos sem números (meia hora, uma hora e duas horas)
                ForEach([30.0, 60.0, 120.0], id: \.self) { minutos in
                    let p = log(minutos / VelaConfig.minimoMinutos) / log(VelaConfig.maximoMinutos / VelaConfig.minimoMinutos)
                    Capsule()
                        .fill(Cores.papel)
                        .frame(width: 16, height: 3)
                        .offset(y: g.topoDaCera(p) - yMax + folga - 1.5)
                }

                Circle()
                    .fill(Cores.dourado)
                    .overlay(Circle().stroke(Cores.tinta, lineWidth: 2))
                    .frame(width: 30, height: 30)
                    .offset(y: yAtual - yMax + folga - 15)
            }
            .frame(width: 60, height: altura + folga * 2, alignment: .top)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named("atelie"))
                    .onChanged { valor in
                        // Converte a altura do dedo (= topo da cera) em posição do slider (0 a 1)
                        let fracao = (g.baseY - valor.location.y + g.pavio) / g.alturaMaxima
                        mudarTamanho(Double((fracao - 0.35) / 0.65))
                    }
            )
            .accessibilityElement(children: .ignore)
            // Sem dica: o próprio VoiceOver já fala "ajustável, deslize para cima ou para baixo"
            .accessibilityLabel("Duração da vela")
            // Sem minutos, como na tela: a faixa e onde a vela está nela ("2 de 4, Duração curta")
            .accessibilityValue(DescricaoDaDuracao.valorAcessivel(minutos: rascunho.minutos))
            .accessibilityInputLabels(["Duração da vela", "Tamanho da vela", "Duração", "Tempo da vela"])
            // No VoiceOver cada deslize anda 5 minutos (antes andava 1/20 do slider, e o valor
            // muitas vezes não mudava). O arraste com o dedo continua com a conta de sempre.
            .accessibilityAdjustableAction { direcao in
                let passo = DescricaoDaDuracao.passoDoVoiceOver
                switch direcao {
                case .increment: mudarDuracao(rascunho.minutos + passo)
                case .decrement: mudarDuracao(rascunho.minutos - passo)
                @unknown default: break
                }
            }
            .position(x: x, y: (yMin + yMax) / 2)
        }
    }

    // Caixinha com os enfeites que sobram (o limite é o que tem nela)
    private func caixinha(_ g: LayoutAtelie) -> some View {
        let tipo: TipoEnfeite? = .alfinete
        let sobram = tipo.map { rascunho.sobram($0) } ?? 0
        let arrastandoDaCaixinha = arrastando != nil && arrastando?.tiradoDe == nil

        return ZStack {
            if tipo == .alfinete && arteExiste("almofada1") {
                almofadas(g)
            } else if tipo == .penduricalho && arteExiste("bandejaPenduricalhos") {
                bandeja(g, sobram: sobram)
            } else {
            Arte("caixinha") {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Cores.papel)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Cores.tinta, lineWidth: 2))
            }
            .frame(width: g.caixinha.width, height: g.caixinha.height)

            if let tipo {
                let pecas = pecasVisiveis(tipo, sobram: sobram)
                HStack(spacing: 4) {
                    ForEach(pecas, id: \.self) { peca in
                        EnfeiteView(tipo: tipo, lado: -1, largura: g.larguraVela * 0.7,
                                    estilo: peca % Enfeite.quantosEstilos)
                            .rotationEffect(.degrees(tipo == .alfinete ? -60 : 0))
                            .frame(width: g.caixinha.width / 7, height: g.caixinha.height * 0.8)
                            .contentShape(Rectangle())
                            // A peça que a pessoa PEGOU some da caixinha (mas continua aqui para o gesto
                            // não parar); quando ela é espetada na vela, as outras andam para fechar o buraco
                            .opacity(arrastandoDaCaixinha && arrastando?.daCaixinha == peca ? 0 : 1)
                            .gesture(arrasto(tipo: tipo, tiradoDe: nil, daCaixinha: peca, g))
                            .transition(.opacity)
                    }
                }
                .frame(width: g.caixinha.width, alignment: .center)
            } else {
                Text("Arraste a bolinha para mudar o tamanho")
                    .adaFont(.smallNote)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.6)   // a caixinha tem altura fixa: o texto encolhe em vez de cortar
                    .foregroundStyle(Cores.tinta.opacity(0.7))
                    .padding(.horizontal)
            }
            }
        }
        .position(x: g.centroX, y: g.caixinhaY)
        // VoiceOver: a caixinha vira um item com as ações de inserir (o arraste não é obrigatório)
        .accessibilityElement(children: .ignore)
        .accessibilityHidden(tipo == nil)
        .accessibilityLabel(tipo == .penduricalho ? "Bandeja de penduricalhos" : "Almofadas de alfinetes")
        .accessibilityValue(textoDaCaixinha(sobram))
        .accessibilityActions {
            if let tipo {
                ForEach(LugarNaVela.allCases, id: \.self) { lugar in
                    Button("Inserir \(tipo.nome) \(lugar.texto)") { colocarPeloVoiceOver(tipo, lugar, g) }
                }
            }
        }
    }

    // AS ALMOFADAS DA GEORGIA: os alfinetes que sobram ficam espetados nelas.
    // Os alfinetes são desenhados ATRÁS da almofada: a ponta da agulha some dentro dela.
    private func almofadas(_ g: LayoutAtelie) -> some View {
        let a = ArteAtelie.self
        let larguraArte = a.almofada1.width + a.vaoEntreAlmofadas + a.almofada2.width
        let alturaArte = a.almofada2.height + a.alturaDosAlfinetes
        // Mesma escala do desenho da vela: os alfinetes da almofada ficam do tamanho dos que vão
        // para a vela, e a almofada fica do tamanho que a Georgia desenhou perto da vela
        // (antes elas eram esticadas para encher a caixinha e ficavam grandes demais).
        // ⚙️ 1,4: um pouco maiores que na escala da vela (pedido do time), sem passar da largura da tela
        let larguraComBandeja = arteExiste("bandejaPenduricalhos") ? max(larguraArte, a.bandeja.width) : larguraArte
        let f = min(1.4 * ArteVela.k * g.larguraVela / ArteVela.largura, g.tamanho.width * 0.94 / larguraComBandeja)
        let w = larguraArte * f, h = alturaArte * f
        // As almofadas ficam apoiadas lá embaixo, longe do prato da vela
        // (com a bandeja, a borda da frente dela é que fica no "apoio")
        let sobraDaBandeja = arteExiste("bandejaPenduricalhos")
            ? (a.bandeja.height - a.fundoDasAlmofadasNaBandeja) * f : 0
        let apoio = g.apoioDasAlmofadas - sobraDaBandeja
        let origem1 = CGPoint(x: 0, y: h - a.almofada1.height * f)
        let origem2 = CGPoint(x: (a.almofada1.width + a.vaoEntreAlmofadas) * f, y: h - a.almofada2.height * f)
        let naMao = arrastando?.tiradoDe == nil && arrastando?.tipo == .alfinete ? arrastando?.daCaixinha : nil

        // A bandeja da Georgia fica atrás das almofadas (as almofadas apoiam dentro dela)
        let usaBandeja = arteExiste("bandejaPenduricalhos")
        let bandejaW = a.bandeja.width * f, bandejaH = a.bandeja.height * f
        let bandejaX = (w - bandejaW) / 2                          // centrada nas almofadas
        let bandejaY = h - (a.fundoDasAlmofadasNaBandeja * f)      // as almofadas "afundam" nela

        return ZStack(alignment: .topLeading) {
            // 0) A bandeja (atrás de tudo)
            if usaBandeja {
                Image("bandejaPenduricalhos").resizable()
                    .frame(width: bandejaW, height: bandejaH)
                    .offset(x: bandejaX, y: bandejaY)
                    .allowsHitTesting(false)
            }

            // 1) Os alfinetes (atrás)
            ForEach(a.vagas.indices, id: \.self) { i in
                if !vagasUsadas.contains(i) {
                    let vaga = a.vagas[i]
                    let origem = vaga.almofada == 0 ? origem1 : origem2
                    let desenho = EnfeiteView.desenhoDoAlfinete(vaga.estilo)
                    let tamanho = CGSize(width: desenho.tamanho.width * f, height: desenho.tamanho.height * f)
                    let ponta = CGPoint(x: desenho.ponta.x * f, y: desenho.ponta.y * f)
                    Image("alfinete\(vaga.estilo + 1)")
                        .resizable()
                        .frame(width: tamanho.width, height: tamanho.height)
                        // Deitado ele aponta para a direita; girando 90° fica de cabeça para cima
                        .rotationEffect(.degrees(90 + vaga.giro),
                                        anchor: UnitPoint(x: ponta.x / tamanho.width, y: ponta.y / tamanho.height))
                        .offset(x: origem.x + vaga.ponto.x * f - ponta.x, y: origem.y + vaga.ponto.y * f - ponta.y)
                        .opacity(naMao == i ? 0 : 1)
                        .transition(.opacity)
                }
            }

            // 2) As almofadas (na frente)
            Image("almofada1").resizable()
                .frame(width: a.almofada1.width * f, height: a.almofada1.height * f)
                .offset(x: origem1.x, y: origem1.y)
            Image("almofada2").resizable()
                .frame(width: a.almofada2.width * f, height: a.almofada2.height * f)
                .offset(x: origem2.x, y: origem2.y)

            // 2b) A borda da frente da bandeja, por cima do pé das almofadas
            if usaBandeja {
                Image("bandejaFrente").resizable()
                    .frame(width: a.bandejaFrente.width * f, height: a.bandejaFrente.height * f)
                    .offset(x: bandejaX + a.frenteX * f, y: bandejaY + a.frenteY * f)
                    .allowsHitTesting(false)
            }

            // 3) Onde tocar para pegar cada alfinete: na cabeça dele
            ForEach(a.vagas.indices, id: \.self) { i in
                if !vagasUsadas.contains(i) {
                    let vaga = a.vagas[i]
                    let origem = vaga.almofada == 0 ? origem1 : origem2
                    let desenho = EnfeiteView.desenhoDoAlfinete(vaga.estilo)
                    let comprimento = (desenho.ponta.x - a.meioDaCabeca) * f
                    let angulo = (90 + vaga.giro) * .pi / 180
                    let cabeca = CGPoint(x: origem.x + vaga.ponto.x * f - comprimento * cos(angulo),
                                         y: origem.y + vaga.ponto.y * f - comprimento * sin(angulo))
                    Color.black.opacity(0.001)
                        .frame(width: 40, height: 40)
                        .contentShape(Circle())
                        .gesture(arrasto(tipo: .alfinete, tiradoDe: nil, daCaixinha: i, g))
                        .offset(x: cabeca.x - 20, y: cabeca.y - 20)
                }
            }
        }
        .frame(width: w, height: h, alignment: .topLeading)
        // (Esta vista fica centrada em caixinhaY: desce até a base das almofadas ficar no "apoio")
        .offset(y: apoio - g.caixinhaY - h / 2)
        .animation(.easeInOut(duration: 0.25), value: vagasUsadas)
    }

    // A BANDEJA DA GEORGIA com os penduricalhos que sobram. A parte da frente da bandeja
    // é desenhada de novo por cima, para eles ficarem DENTRO dela.
    private func bandeja(_ g: LayoutAtelie, sobram: Int) -> some View {
        let a = ArteAtelie.self
        let f = min(g.caixinha.width / a.bandeja.width, g.caixinha.height * 1.3 / a.bandeja.height)
        let w = a.bandeja.width * f, h = a.bandeja.height * f
        let pecas = pecasVisiveis(.penduricalho, sobram: sobram)
        let larguraDaPeca = g.larguraVela * 0.7
        let alturaDaPeca = EnfeiteView.alturaDesenho(.penduricalho, largura: larguraDaPeca)
        let fundoDaPeca = (a.frenteY + 6) * f            // a estrelinha encosta atrás da borda da frente
        let naMao = arrastando?.tiradoDe == nil && arrastando?.tipo == .penduricalho ? arrastando?.daCaixinha : nil

        return ZStack(alignment: .topLeading) {
            Image("bandejaPenduricalhos").resizable()
                .frame(width: w, height: h)

            HStack(spacing: 4) {
                ForEach(pecas, id: \.self) { peca in
                    EnfeiteView(tipo: .penduricalho, lado: -1, largura: larguraDaPeca)
                        .frame(width: w * 0.8 / CGFloat(VelaConfig.limitePorTipo), height: alturaDaPeca)
                        .contentShape(Rectangle())
                        .opacity(naMao == peca ? 0 : 1)
                        .gesture(arrasto(tipo: .penduricalho, tiradoDe: nil, daCaixinha: peca, g))
                        .transition(.opacity)
                }
            }
            .frame(width: w, height: alturaDaPeca)
            .offset(y: fundoDaPeca - alturaDaPeca)

            Image("bandejaFrente").resizable()
                .frame(width: a.bandejaFrente.width * f, height: a.bandejaFrente.height * f)
                .offset(x: a.frenteX * f, y: a.frenteY * f)
                .allowsHitTesting(false)
        }
        .frame(width: w, height: h, alignment: .topLeading)
        .offset(y: (g.caixinha.height - h) / 2)
    }

    // MARK: Arrastar e soltar

    // As peças que estão na caixinha agora, na ordem (sempre "sobram" peças)
    private func pecasVisiveis(_ tipo: TipoEnfeite, sobram: Int) -> [Int] {
        var pecas = pecasNaCaixinha[tipo] ?? Array(0..<VelaConfig.limitePorTipo)
        if pecas.count > sobram { pecas = Array(pecas.prefix(sobram)) }
        var proxima = (pecas.max() ?? -1) + 1
        while pecas.count < sobram { pecas.append(proxima); proxima += 1 }
        return pecas
    }

    private func arrasto(tipo: TipoEnfeite, tiradoDe: Enfeite?, daCaixinha: Int? = nil, _ g: LayoutAtelie) -> some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .named("atelie"))
            .onChanged { valor in
                let ponto = CGPoint(x: valor.location.x, y: valor.location.y - acimaDoDedo)
                if arrastando == nil {
                    arrastando = Arrastando(tipo: tipo, ponto: ponto, tiradoDe: tiradoDe, daCaixinha: daCaixinha,
                                            estilo: tiradoDe?.desenho ?? PersonalizacaoView.estiloDaPeca(tipo, daCaixinha))
                } else if arrastando?.caindo == false {
                    arrastando?.ponto = ponto
                }
            }
            .onEnded { _ in soltar(g) }
    }

    private func soltar(_ g: LayoutAtelie) {
        guard var item = arrastando, !item.caindo else { return }
        var nova = rascunho
        let alturaCheia = g.alturaCheia(nova.posicaoSlider)

        // Se veio da vela, sai de lá e deixa um furinho
        if let antigo = item.tiradoDe {
            nova.enfeites.removeAll { $0.id == antigo.id }
        }

        let encostou = abs(item.ponto.x - g.centroX) <= g.larguraVela * 0.5 + 24
            && item.ponto.y >= g.baseY - alturaCheia - 6
            && item.ponto.y <= g.baseY
        let altura = Double((g.baseY - item.ponto.y) / alturaCheia)
        let lado: Double = item.ponto.x < g.centroX ? -1 : 1

        // Se soltou em cima de outro enfeite, o app empurra um pouquinho para cima
        // ou para baixo. Só devolve nil quando não tem mesmo onde caber.
        let tamanho = TamanhoEnfeite.daVela(largura: g.larguraVela, alturaCheia: alturaCheia)
        // Só empurra um pouquinho (mais ou menos o tamanho de duas cabeças de alfinete)
        let empurraoMaximo = 2.5 * (tamanho.acima(item.tipo) + tamanho.abaixo(item.tipo))
        let lugar = encostou ? nova.acomodar(item.tipo, altura: altura, lado: lado, tamanho: tamanho,
                                             distanciaMaxima: empurraoMaximo) : nil

        if let lugar {
            // Se saiu do lugar de antes, fica o furinho na cera
            if let antigo = item.tiradoDe,
               abs(antigo.altura - lugar) > 0.02 || (antigo.lado < 0) != (lado < 0) {
                nova.marcas.append(Marca(altura: antigo.altura, lado: antigo.lado))
            }
            nova.enfeites.append(Enfeite(tipo: item.tipo, altura: lugar, lado: lado, estilo: item.estilo))
            // O alfinete pego da almofada deixa a vaga dele vazia (os outros não saem do lugar)
            if item.tipo == .alfinete, let vaga = item.daCaixinha {
                vagasUsadas.insert(vaga)
                rascunho = nova
            } else if let peca = item.daCaixinha {
            // A peça pega sai da caixinha e as outras deslizam para o lugar dela
                let antes = pecasVisiveis(item.tipo, sobram: rascunho.sobram(item.tipo))
                withAnimation(.spring(duration: 0.35)) {
                    pecasNaCaixinha[item.tipo] = antes.filter { $0 != peca }
                    rascunho = nova
                }
            } else {
                rascunho = nova
            }
            arrastando = nil
            haptics.tique()
            // O app empurrou o enfeite para não ficar em cima de outro
            if abs(lugar - altura) > 0.02 {
                anunciar("Objeto reorganizado para evitar sobreposição")
            }
        } else {
            // Não encostou (ou não cabe ali): cai no pote e volta para a caixinha
            if let antigo = item.tiradoDe {
                nova.marcas.append(Marca(altura: antigo.altura, lado: antigo.lado))
                if antigo.tipo == .alfinete { devolverAlfinete(antigo.desenho) }
            }
            rascunho = nova
            item.caindo = true
            arrastando = item
            withAnimation(.easeIn(duration: Haptics.tempoQueda)) {
                arrastando?.ponto = CGPoint(x: g.centroX, y: g.apoioDasAlmofadas - 30)
            }
            haptics.caiuNoPote()
            anunciar("Objeto retornado à caixinha")
            Task {
                try? await Task.sleep(for: .seconds(Haptics.tempoQueda))
                arrastando = nil
            }
        }
    }

    // MARK: Ajudantes

    private func mudarTamanho(_ nova: Double) {
        let antes = rascunho.minutos
        rascunho.posicaoSlider = max(0, min(1, nova))
        if rascunho.minutos != antes { haptics.tique() }

        // Se a vela ficou menor, os enfeites continuam na mesma altura relativa (não precisa mexer)
    }

    private func mudarDuracao(_ minutos: Int) {
        let limitado = min(max(minutos, Int(VelaConfig.minimoMinutos)), Int(VelaConfig.maximoMinutos))
        mudarTamanho(DescricaoDaDuracao.posicao(paraMinutos: limitado))
    }

    // VoiceOver e Controle por Voz: coloca o enfeite perto do lugar pedido (topo, metade ou base).
    // Tenta os dois lados da vela e fica com o lugar livre mais perto do pedido.
    private func colocarPeloVoiceOver(_ tipo: TipoEnfeite, _ lugar: LugarNaVela, _ g: LayoutAtelie) {
        guard rascunho.sobram(tipo) > 0 else {
            anunciar("Não sobrou nenhum \(tipo.nome) na caixinha")
            return
        }
        let alturaCheia = g.alturaCheia(rascunho.posicaoSlider)
        let tamanho = TamanhoEnfeite.daVela(largura: g.larguraVela, alturaCheia: alturaCheia)

        // Em caso de empate, o lado que tem menos coisa, para a vela ficar equilibrada
        let naEsquerda = rascunho.enfeites.filter { $0.lado < 0 }.count
        let naDireita = rascunho.enfeites.count - naEsquerda
        let lados: [Double] = naEsquerda <= naDireita ? [-1, 1] : [1, -1]

        var escolhido: (altura: Double, lado: Double)? = nil
        for lado in lados {
            guard let altura = rascunho.acomodar(tipo, altura: lugar.altura, lado: lado, tamanho: tamanho) else { continue }
            let distancia = abs(altura - lugar.altura)
            if let atual = escolhido, abs(atual.altura - lugar.altura) <= distancia + 0.0001 { continue }
            escolhido = (altura, lado)
        }

        guard let escolhido else {
            anunciar("Não cabe mais nenhum \(tipo.nome) na vela")
            return
        }
        // Alfinete: sai da primeira vaga livre das almofadas (e fica com o desenho dela)
        var estilo = rascunho.quantos(tipo) % Enfeite.quantosEstilos
        if tipo == .alfinete, let vaga = ArteAtelie.vagas.indices.first(where: { !vagasUsadas.contains($0) }) {
            vagasUsadas.insert(vaga)
            estilo = ArteAtelie.vagas[vaga].estilo
        }
        rascunho.enfeites.append(Enfeite(tipo: tipo, altura: escolhido.altura, lado: escolhido.lado, estilo: estilo))
        haptics.tique()
        let onde = "\(DescricaoDoEnfeite.altura(escolhido.altura)), \(DescricaoDoEnfeite.lado(escolhido.lado))"
        if abs(escolhido.altura - lugar.altura) > 0.03 {
            anunciar("Objeto reorganizado para evitar sobreposição. \(DescricaoDoEnfeite.nome(tipo)) \(onde)")
        } else {
            anunciar("\(DescricaoDoEnfeite.nome(tipo)) colocado \(onde)")
        }
    }

    // Tira o enfeite da vela (fica o furinho na cera) e ele volta para a caixinha
    private func remover(_ enfeite: Enfeite) {
        rascunho.enfeites.removeAll { $0.id == enfeite.id }
        if enfeite.tipo == .alfinete { devolverAlfinete(enfeite.desenho) }
        rascunho.marcas.append(Marca(altura: enfeite.altura, lado: enfeite.lado))
        haptics.tique()
        anunciar("Objeto retornado à caixinha")
    }

    // "Alfinete, lado esquerdo, perto do topo"
    private func rotulo(_ enfeite: Enfeite) -> String {
        "\(DescricaoDoEnfeite.nome(enfeite.tipo)), \(DescricaoDoEnfeite.lado(enfeite.lado)), \(DescricaoDoEnfeite.altura(enfeite.altura))"
    }

    private func textoDaCaixinha(_ sobram: Int) -> String {
        switch sobram {
        case 0: return "Vazia"
        case 1: return "Sobra um"
        default: return "Sobram \(sobram)"
        }
    }

    private func anunciar(_ texto: String) {
        AccessibilityNotification.Announcement(texto).post()
    }

    // Qual desenho tem a peça pega da almofada (alfinete) ou da caixinha
    private static func estiloDaPeca(_ tipo: TipoEnfeite, _ peca: Int?) -> Int {
        guard let peca else { return 0 }
        if tipo == .alfinete && arteExiste("almofada1") && ArteAtelie.vagas.indices.contains(peca) {
            return ArteAtelie.vagas[peca].estilo
        }
        return peca % Enfeite.quantosEstilos
    }

    // Um alfinete voltou para as almofadas: volta para uma vaga do desenho dele
    private func devolverAlfinete(_ estilo: Int) {
        let usadas = vagasUsadas.sorted()
        if let vaga = usadas.last(where: { ArteAtelie.vagas[$0].estilo == estilo }) ?? usadas.last {
            vagasUsadas.remove(vaga)
        }
    }

    // Ao abrir o ateliê: as vagas dos alfinetes que já estão na vela começam vazias
    private static func vagasOcupadas(por config: VelaConfig) -> Set<Int> {
        var usadas = Set<Int>()
        for enfeite in config.enfeites where enfeite.tipo == .alfinete {
            let livres = ArteAtelie.vagas.indices.filter { !usadas.contains($0) }
            if let vaga = livres.first(where: { ArteAtelie.vagas[$0].estilo == enfeite.desenho }) ?? livres.first {
                usadas.insert(vaga)
            }
        }
        return usadas
    }
}

// Medidas das almofadas e da bandeja da Georgia (em pixels dos recortes dela)
private enum ArteAtelie {
    static let almofada1 = CGSize(width: 267, height: 231)
    static let almofada2 = CGSize(width: 408, height: 301)
    static let vaoEntreAlmofadas: CGFloat = 40
    static let alturaDosAlfinetes: CGFloat = 125     // quanto os alfinetes sobem acima das almofadas
    static let meioDaCabeca: CGFloat = 22            // x do meio da cabeça nos desenhos dos alfinetes

    // As 6 vagas (2 de cada desenho): estilo, almofada (0 ou 1), onde a ponta entra e o giro
    static let vagas: [(estilo: Int, almofada: Int, ponto: CGPoint, giro: Double)] = [
        (0, 0, CGPoint(x: 93, y: 40), -20),    // estrela
        (0, 0, CGPoint(x: 174, y: 44), 22),    // estrela
        (1, 1, CGPoint(x: 118, y: 92), -22),   // coração
        (2, 1, CGPoint(x: 184, y: 86), -6),    // bolinha
        (1, 1, CGPoint(x: 250, y: 86), 10),    // coração
        (2, 1, CGPoint(x: 314, y: 92), 26),    // bolinha
    ]

    static let bandeja = CGSize(width: 925, height: 210)
    static let bandejaFrente = CGSize(width: 920, height: 78)
    static let frenteX: CGFloat = 3                  // onde a parte da frente fica, dentro da bandeja
    static let frenteY: CGFloat = 132
    // Onde o pé das almofadas fica dentro da bandeja (um pouco atrás da borda da frente)
    static let fundoDasAlmofadasNaBandeja: CGFloat = 165
}

private struct LayoutAtelie {
    let tamanho: CGSize
    var centroX: CGFloat { tamanho.width / 2 }
    var baseY: CGFloat { tamanho.height * 0.68 }   // (era 0,64: a vela e o prato desceram um pouco)
    var alturaMaxima: CGFloat { larguraVela * ArteVela.alturaMaxima / ArteVela.largura }   // mesma proporção da arte
    var larguraVela: CGFloat { min(tamanho.width * 0.17, tamanho.height * 0.48 * ArteVela.largura / ArteVela.alturaMaxima) }
    var caixinha: CGSize { CGSize(width: min(tamanho.width * 0.9, 420), height: tamanho.height * 0.11) }
    var caixinhaY: CGFloat { tamanho.height * 0.78 }
    var apoioDasAlmofadas: CGFloat { tamanho.height - 24 }   // onde as almofadas apoiam (embaixo)

    func alturaCheia(_ posicao: Double) -> CGFloat {
        GeometriaVela.alturaCheia(posicao: posicao, alturaMaxima: alturaMaxima)
    }

    // O pavio (da ponta até onde a cera começa), na mesma escala da vela
    var pavio: CGFloat { larguraVela * ArteVela.pavio / ArteVela.largura }

    // Onde fica o topo da CERA na tela para cada posição do slider
    func topoDaCera(_ posicao: Double) -> CGFloat {
        baseY - alturaCheia(posicao) + pavio
    }
}
