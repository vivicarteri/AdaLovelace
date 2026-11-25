//  Dicas.swift
//  Dicas do TipKit: ensinam a acender (pegar e riscar o fósforo), os gestos de pinça
//  e os jeitos de apagar a vela.
//  As regras definem quando cada dica faz sentido. A PalcoView exibe uma por vez.

import SwiftUI
import TipKit

// Vela apagada: como pegar um fósforo (teste do Guilherme: não dava para saber o que tocar)
struct DicaPegarFosforo: Tip {
    // Ligado pela PalcoView: vela nova ou apagada, com a caixa de fósforos na tela
    @Parameter static var podePegar: Bool = false

    var title: Text { Text("Acenda a vela").font(ADAFont.font(for: .tipTitle)) }
    var message: Text? { Text("Toque na caixa de fósforos, no canto de baixo, para pegar um fósforo.").font(ADAFont.font(for: .tipMessage)) }
    var image: Image? { Image(systemName: "hand.tap") }
    var rules: [Rule] { #Rule(Self.$podePegar) { $0 } }
}

// Fósforo na mão: como riscar (teste do Guilherme: pediu uma dica de como riscar)
struct DicaRiscarFosforo: Tip {
    // Ligado pela PalcoView: o fósforo saiu da caixa e ainda não acendeu
    @Parameter static var fosforoNaMao: Bool = false

    var title: Text { Text("Risque o fósforo").font(ADAFont.font(for: .tipTitle)) }
    var message: Text? { Text("Arraste a cabeça do fósforo de lado, rápido, na lixa da caixinha. Depois leve a chama até o pavio.").font(ADAFont.font(for: .tipMessage)) }
    var image: Image? { Image(systemName: "hand.draw") }
    var rules: [Rule] { #Rule(Self.$fosforoNaMao) { $0 } }
}

// Dentro da caixa → teatro de sombras
struct DicaSairDaCaixa: Tip {
    // Ligado pela PalcoView: só dá para sair da caixa com a vela acesa ou apagada.
    @Parameter static var podeSair: Bool = false

    var title: Text { Text("Veja o teatro de sombras").font(ADAFont.font(for: .tipTitle)) }
    var message: Text? { Text("Toque no botão no canto de cima ou junte dois dedos na tela, como uma pinça, para ver o teatro de sombras.").font(ADAFont.font(for: .tipMessage)) }
    var image: Image? { Image(systemName: "hand.pinch") }
    var rules: [Rule] { #Rule(Self.$podeSair) { $0 } }
}

// Teatro de sombras → dentro da caixa
struct DicaEntrarNaCaixa: Tip {
    // Ligado pela PalcoView: só vale enquanto a pessoa está fora da caixa.
    @Parameter static var estaForaDaCaixa: Bool = false

    var title: Text { Text("Volte para a vela").font(ADAFont.font(for: .tipTitle)) }
    var message: Text? { Text("Toque no botão no canto de cima ou afaste dois dedos na tela, como uma pinça, para voltar para a vela.").font(ADAFont.font(for: .tipMessage)) }
    var image: Image? { Image(systemName: "hand.pinch") }
    var rules: [Rule] { #Rule(Self.$estaForaDaCaixa) { $0 } }
}

// Quem apaga a vela do MESMO jeito 3 vezes seguidas ganha a dica de um jeito diferente
// (regra de negócio do TipKit). Quem decide a sugestão é a Sessao.
struct DicaOutroJeitoDeApagar: Tip {
    // 0 = nada a sugerir, 1 = tocar na chama, 2 = virar o aparelho de cabeça para baixo
    @Parameter static var sugestao: Int = 0
    // Só aparece com a vela acesa (é quando dá para experimentar)
    @Parameter static var velaAcesa: Bool = false

    var title: Text { Text("Outro jeito de apagar").font(ADAFont.font(for: .tipTitle)) }
    var message: Text? {
        Text(Self.sugestao == 2 ? "Vire o aparelho de cabeça para baixo e a chama apaga."
                                : "Toque na chama para apagar a vela.")
            .font(ADAFont.font(for: .tipMessage))
    }
    var image: Image? { Image(systemName: Self.sugestao == 2 ? "arrow.uturn.down" : "hand.tap") }
    var rules: [Rule] {
        #Rule(Self.$sugestao) { $0 != 0 }
        #Rule(Self.$velaAcesa) { $0 }
    }
}

// MARK: - Previews
//
// Nas previews o app não roda o MyApp.init(), então o TipKit é ligado aqui.
// resetDatastore() faz a dica aparecer de novo toda vez, mesmo se já foi fechada antes.

#Preview("DicaSairDaCaixa") {
    TipView(DicaSairDaCaixa())
        .padding()
        .task {
            try? Tips.resetDatastore()
            try? Tips.configure([.displayFrequency(.immediate)])
            DicaSairDaCaixa.podeSair = true
        }
}

#Preview("DicaEntrarNaCaixa") {
    TipView(DicaEntrarNaCaixa())
        .padding()
        .task {
            try? Tips.resetDatastore()
            try? Tips.configure([.displayFrequency(.immediate)])
            DicaEntrarNaCaixa.estaForaDaCaixa = true
        }
}

// Do jeito que aparece no app: um balão apontando para o botão
#Preview("Dica no botão") {
    VStack {
        HStack {
            BotaoRedondo(icone: "arrow.down.right.and.arrow.up.left", rotulo: "Ver o teatro de sombras",
                         tamanho: 44) {}
                .popoverTip(DicaSairDaCaixa(), arrowEdge: .top)
            Spacer()
        }
        Spacer()
    }
    .padding(20)
    .background(Cores.fundoEscuro)
    .task {
        try? Tips.resetDatastore()
        try? Tips.configure([.displayFrequency(.immediate)])
        DicaSairDaCaixa.podeSair = true
    }
}
