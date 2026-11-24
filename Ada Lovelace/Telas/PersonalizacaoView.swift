//  PersonalizacaoView.swift
//  O ateliê: escolher o tamanho da vela (= tempo) e espetar alfinetes e penduricalhos.
//
//  Regras:
//  - Fechar: perde tudo o que mudou. Confirmar: salva e o modal desce para a home.
//  - Até 6 alfinetes e 6 penduricalhos (o limite é o que tem na caixinha), para qualquer tamanho de vela.
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

    private enum Aba { case tempo, alfinete, penduricalho }
    @State private var aba: Aba = .tempo

    // Enfeite sendo arrastado (da caixinha ou tirado da vela)
    private struct Arrastando {
        var tipo: TipoEnfeite
        var ponto: CGPoint          // onde o alfinete vai espetar
        var tiradoDe: Enfeite?      // se veio da vela
        var caindo = false
    }
    @State private var arrastando: Arrastando?

    // Para o enfeite ficar visível acima do dedo
    private let acimaDoDedo: CGFloat = 36

    @Namespace private var rotorEnfeites   // VoiceOver: rotor "Enfeites"

    init(config: VelaConfig, haptics: Haptics, fechar: @escaping () -> Void, confirmar: @escaping (VelaConfig) -> Void) {
        self.haptics = haptics
        self.fechar = fechar
        self.confirmar = confirmar
        _rascunho = State(initialValue: config)
        original = config
    }

    var body: some View {
        GeometryReader { geo in
            let g = LayoutAtelie(tamanho: geo.size)
            ZStack {
                fundo

                barraDeCima

                velaEmEdicao(g)

                if aba == .tempo {
                    slider(g)
                        .transition(.opacity)
                }

                caixinha(g)

                abas(g)

                // Enfeite voando com o dedo (ou caindo no pote)
                if let arrastando {
                    EnfeiteView(tipo: arrastando.tipo,
                                lado: arrastando.ponto.x < g.centroX ? -1 : 1,
                                largura: g.larguraVela)
                        .position(x: arrastando.ponto.x,
                                  y: arrastando.ponto.y
                                     + EnfeiteView.alturaDesenho(arrastando.tipo, largura: g.larguraVela) / 2
                                     - EnfeiteView.alturaDoAlfinete(arrastando.tipo, largura: g.larguraVela))
                        .allowsHitTesting(false)
                }
            }
            .coordinateSpace(.named("atelie"))
            .animation(.easeInOut(duration: 0.25), value: aba)
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
    }

    // MARK: Partes da tela

    // Fundo: estou num ateliê (mesa de madeira)
    private var fundo: some View {
        Arte("atelie") {
            LinearGradient(colors: [Cores.madeira.opacity(0.85), Cores.madeira], startPoint: .top, endPoint: .bottom)
        }
        .ignoresSafeArea()
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

        return ZStack {
            VelaView(alturaCheia: alturaCheia,
                     largura: g.larguraVela,
                     enfeites: rascunho.enfeites.filter { $0.id != movendo },
                     marcas: rascunho.marcas)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Vela")
                .accessibilityValue("\(DescricaoDaDuracao.texto(minutos: rascunho.minutos)). \(rascunho.quantos(.alfinete)) alfinetes e \(rascunho.quantos(.penduricalho)) penduricalhos")
                .accessibilityHint("Use as ações para inserir enfeites, e o rotor Enfeites para visitar cada um")
                .accessibilityActions {
                    ForEach(LugarNaVela.allCases, id: \.self) { lugar in
                        Button("Inserir alfinete \(lugar.texto)") { colocarPeloVoiceOver(.alfinete, lugar, g) }
                    }
                    ForEach(LugarNaVela.allCases, id: \.self) { lugar in
                        Button("Inserir penduricalho \(lugar.texto)") { colocarPeloVoiceOver(.penduricalho, lugar, g) }
                    }
                    if let ultimo = rascunho.enfeites.last {
                        Button("Tirar o último enfeite") { remover(ultimo) }
                    }
                }
                .position(x: g.centroX, y: g.baseY - (alturaCheia + espacoChama) / 2)
                .animation(.spring(duration: 0.3), value: rascunho.posicaoSlider)

            SuporteView(largura: g.larguraVela)
                .position(x: g.centroX + SuporteView.desvioX(largura: g.larguraVela),
                          y: g.baseY + SuporteView.altura(largura: g.larguraVela) / 2)

            // Áreas de toque em cima de cada enfeite, para tirar e reposicionar.
            // Elas ficam em cima do DESENHO (o penduricalho pendura para baixo, então
            // a área acompanha a estrelinha em vez de ficar só na linha do alfinete).
            ForEach(rascunho.enfeites) { enfeite in
                let acima = EnfeiteView.acima(enfeite.tipo, largura: g.larguraVela)
                let abaixo = EnfeiteView.abaixo(enfeite.tipo, largura: g.larguraVela)
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
                    .position(x: g.centroX + CGFloat(enfeite.lado) * g.larguraVela * 0.62,
                              y: g.baseY - CGFloat(enfeite.altura) * alturaCheia + (abaixo - acima) / 2)
            }
        }
    }

    // Slider vertical ao lado da vela. A bolinha fica na altura do topo da vela.
    private func slider(_ g: LayoutAtelie) -> some View {
        let x = g.tamanho.width * 0.85
        let yMin = g.baseY - g.alturaCheia(0)    // vela mais curta
        let yMax = g.baseY - g.alturaCheia(1)    // vela mais longa
        let yAtual = g.baseY - g.alturaCheia(rascunho.posicaoSlider)
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
                        .offset(y: (g.baseY - g.alturaCheia(p)) - yMax + folga - 1.5)
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
                        // Converte a altura do dedo em posição do slider (0 a 1)
                        let fracao = (g.baseY - valor.location.y) / g.alturaMaxima
                        mudarTamanho(Double((fracao - 0.35) / 0.65))
                    }
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Tamanho da vela")
            // Sem números, como na tela: só a sensação da duração
            .accessibilityValue(DescricaoDaDuracao.texto(minutos: rascunho.minutos))
            .accessibilityHint("Deslize para cima ou para baixo com um dedo para mudar a duração")
            .accessibilityInputLabels(["Tamanho da vela", "Duração", "Tempo da vela"])
            .accessibilityAdjustableAction { direcao in
                switch direcao {
                case .increment: mudarTamanho(rascunho.posicaoSlider + 0.05)
                case .decrement: mudarTamanho(rascunho.posicaoSlider - 0.05)
                @unknown default: break
                }
            }
            .position(x: x, y: (yMin + yMax) / 2)
        }
    }

    // Caixinha com os enfeites que sobram (o limite é o que tem nela)
    private func caixinha(_ g: LayoutAtelie) -> some View {
        let tipo: TipoEnfeite? = aba == .alfinete ? .alfinete : aba == .penduricalho ? .penduricalho : nil
        let sobram = tipo.map { rascunho.sobram($0) } ?? 0
        let arrastandoDaCaixinha = arrastando != nil && arrastando?.tiradoDe == nil

        return ZStack {
            Arte("caixinha") {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Cores.papel)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Cores.tinta, lineWidth: 2))
            }
            .frame(width: g.caixinha.width, height: g.caixinha.height)

            if let tipo {
                HStack(spacing: 4) {
                    ForEach(0..<VelaConfig.limitePorTipo, id: \.self) { i in
                        let tem = i < sobram
                        EnfeiteView(tipo: tipo, lado: -1, largura: g.larguraVela * 0.7)
                            .rotationEffect(.degrees(tipo == .alfinete ? -60 : 0))
                            .frame(width: g.caixinha.width / 7, height: g.caixinha.height * 0.8)
                            .contentShape(Rectangle())
                            // O que está sendo arrastado some da caixinha (mas continua aqui para o gesto não parar)
                            .opacity(tem && !(arrastandoDaCaixinha && i == sobram - 1) ? 1 : 0)
                            .allowsHitTesting(tem)
                            .gesture(arrasto(tipo: tipo, tiradoDe: nil, g))
                    }
                }
            } else {
                Text("Arraste a bolinha para mudar o tamanho")
                    .adaFont(.smallNote)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.6)   // a caixinha tem altura fixa: o texto encolhe em vez de cortar
                    .foregroundStyle(Cores.tinta.opacity(0.7))
                    .padding(.horizontal)
            }
        }
        .position(x: g.centroX, y: g.caixinhaY)
        // VoiceOver: a caixinha vira um item com as ações de inserir (o arraste não é obrigatório)
        .accessibilityElement(children: .ignore)
        .accessibilityHidden(tipo == nil)
        .accessibilityLabel(tipo == .penduricalho ? "Caixinha de penduricalhos" : "Caixinha de alfinetes")
        .accessibilityValue(textoDaCaixinha(sobram))
        .accessibilityActions {
            if let tipo {
                ForEach(LugarNaVela.allCases, id: \.self) { lugar in
                    Button("Inserir \(tipo.nome) \(lugar.texto)") { colocarPeloVoiceOver(tipo, lugar, g) }
                }
            }
        }
    }

    private func abas(_ g: LayoutAtelie) -> some View {
        HStack(spacing: 28) {
            botaoAba(.tempo, icone: "clock", rotulo: "Tempo", voz: ["Duração", "Tamanho"])
            botaoAba(.alfinete, icone: "pin", rotulo: "Alfinetes", voz: ["Alfinete"])
            botaoAba(.penduricalho, icone: "star", rotulo: "Penduricalhos", voz: ["Penduricalho"])
        }
        .position(x: g.centroX, y: g.abasY)
    }

    private func botaoAba(_ qual: Aba, icone: String, rotulo: String, voz: [String]) -> some View {
        Button {
            aba = qual
            haptics.tique()
        } label: {
            Image(systemName: icone)
                .adaFont(.sectionTitle)
                .foregroundStyle(Cores.tinta)
                .frame(width: 56, height: 56)
                .background(Circle().fill(aba == qual ? Cores.dourado : Cores.papel))
                .overlay(Circle().stroke(Cores.tinta, lineWidth: aba == qual ? 3 : 2))
                // A aba escolhida não depende só da cor: ela também fica maior
                .scaleEffect(aba == qual ? 1.12 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(rotulo)
        .accessibilityInputLabels([rotulo] + voz)
        .accessibilityAddTraits(aba == qual ? .isSelected : [])
    }

    // MARK: Arrastar e soltar

    private func arrasto(tipo: TipoEnfeite, tiradoDe: Enfeite?, _ g: LayoutAtelie) -> some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .named("atelie"))
            .onChanged { valor in
                let ponto = CGPoint(x: valor.location.x, y: valor.location.y - acimaDoDedo)
                if arrastando == nil {
                    arrastando = Arrastando(tipo: tipo, ponto: ponto, tiradoDe: tiradoDe)
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
        let lugar = encostou ? nova.acomodar(item.tipo, altura: altura, lado: lado, tamanho: tamanho) : nil

        if let lugar {
            // Se saiu do lugar de antes, fica o furinho na cera
            if let antigo = item.tiradoDe,
               abs(antigo.altura - lugar) > 0.02 || (antigo.lado < 0) != (lado < 0) {
                nova.marcas.append(Marca(altura: antigo.altura, lado: antigo.lado))
            }
            nova.enfeites.append(Enfeite(tipo: item.tipo, altura: lugar, lado: lado))
            rascunho = nova
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
            }
            rascunho = nova
            item.caindo = true
            arrastando = item
            withAnimation(.easeIn(duration: Haptics.tempoQueda)) {
                arrastando?.ponto = CGPoint(x: g.centroX, y: g.caixinhaY)
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
        rascunho.enfeites.append(Enfeite(tipo: tipo, altura: escolhido.altura, lado: escolhido.lado))
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
}

private struct LayoutAtelie {
    let tamanho: CGSize
    var centroX: CGFloat { tamanho.width / 2 }
    var baseY: CGFloat { tamanho.height * 0.64 }
    var alturaMaxima: CGFloat { larguraVela * ArteVela.alturaMaxima / ArteVela.largura }   // mesma proporção da arte
    var larguraVela: CGFloat { min(tamanho.width * 0.17, tamanho.height * 0.48 * ArteVela.largura / ArteVela.alturaMaxima) }
    var caixinha: CGSize { CGSize(width: min(tamanho.width * 0.9, 420), height: tamanho.height * 0.11) }
    var caixinhaY: CGFloat { tamanho.height * 0.78 }
    var abasY: CGFloat { tamanho.height * 0.92 }

    func alturaCheia(_ posicao: Double) -> CGFloat {
        GeometriaVela.alturaCheia(posicao: posicao, alturaMaxima: alturaMaxima)
    }
}
