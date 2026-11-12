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

    init(config: VelaConfig, haptics: Haptics, fechar: @escaping () -> Void, confirmar: @escaping (VelaConfig) -> Void) {
        self.haptics = haptics
        self.fechar = fechar
        self.confirmar = confirmar
        _rascunho = State(initialValue: config)
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
                BotaoRedondo(icone: "xmark", rotulo: "Fechar sem salvar", tamanho: 44, acao: fechar)
                Spacer()
                BotaoRedondo(icone: "checkmark", rotulo: "Confirmar", tamanho: 44) {
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
                .accessibilityValue("\(rascunho.quantos(.alfinete)) alfinetes e \(rascunho.quantos(.penduricalho)) penduricalhos")
                .accessibilityAction(named: "Espetar alfinete") { colocarPeloVoiceOver(.alfinete, g) }
                .accessibilityAction(named: "Pendurar penduricalho") { colocarPeloVoiceOver(.penduricalho, g) }
                .accessibilityAction(named: "Tirar o último enfeite") {
                    if !rascunho.enfeites.isEmpty { rascunho.enfeites.removeLast() }
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
                Color.clear
                    .frame(width: 44, height: max(36, acima + abaixo))
                    .contentShape(Rectangle())
                    .gesture(arrasto(tipo: enfeite.tipo, tiradoDe: enfeite, g))
                    .accessibilityHidden(true)
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
                    .fill(Cores.papel.opacity(0.5))
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
            .accessibilityValue("\(rascunho.minutos) minutos")
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
                    .font(.footnote)
                    .foregroundStyle(Cores.tinta.opacity(0.7))
                    .padding(.horizontal)
            }
        }
        .position(x: g.centroX, y: g.caixinhaY)
        .accessibilityHidden(true)
    }

    private func abas(_ g: LayoutAtelie) -> some View {
        HStack(spacing: 28) {
            botaoAba(.tempo, icone: "clock", rotulo: "Tempo")
            botaoAba(.alfinete, icone: "pin", rotulo: "Alfinetes")
            botaoAba(.penduricalho, icone: "star", rotulo: "Penduricalhos")
        }
        .position(x: g.centroX, y: g.abasY)
    }

    private func botaoAba(_ qual: Aba, icone: String, rotulo: String) -> some View {
        Button {
            aba = qual
            haptics.tique()
        } label: {
            Image(systemName: icone)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Cores.tinta)
                .frame(width: 56, height: 56)
                .background(Circle().fill(aba == qual ? Cores.dourado : Cores.papel))
                .overlay(Circle().stroke(Cores.tinta, lineWidth: aba == qual ? 3 : 2))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(rotulo)
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

    private func colocarPeloVoiceOver(_ tipo: TipoEnfeite, _ g: LayoutAtelie) {
        let alturaCheia = g.alturaCheia(rascunho.posicaoSlider)
        let tamanho = TamanhoEnfeite.daVela(largura: g.larguraVela, alturaCheia: alturaCheia)

        // Começa pelo lado que tem menos coisa, para a vela ficar equilibrada
        let naEsquerda = rascunho.enfeites.filter { $0.lado < 0 }.count
        let naDireita = rascunho.enfeites.count - naEsquerda
        let lados: [Double] = naEsquerda <= naDireita ? [-1, 1] : [1, -1]

        for lado in lados {
            if let altura = rascunho.primeiroLugarLivre(tipo, lado: lado, tamanho: tamanho) {
                rascunho.enfeites.append(Enfeite(tipo: tipo, altura: altura, lado: lado))
                haptics.tique()
                return
            }
        }
        AccessibilityNotification.Announcement("Não cabe mais nenhum \(tipo.nome)").post()
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
