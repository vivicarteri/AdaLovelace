//  Dicas.swift
//  Dicas do TipKit: ensinam o movimento de pinça para trocar de tela.
//
//  Cada dica some sozinha quando a pessoa usa a pinça (ou fecha a dica).
//  As "regras" (rules) abaixo também fazem a dica sumir quando o botão dela sai da tela:
//  sem isso, o balãozinho fica preso apontando para um botão que não existe mais
//  (acontecia quando a vela acabava e a cortina descia).

import SwiftUI
import TipKit

// Dentro da caixa → teatro de sombras
struct DicaSairDaCaixa: Tip {
    // Ligado pela PalcoView: só dá para sair da caixa com a vela acesa ou apagada.
    @Parameter static var podeSair: Bool = false

    var title: Text { Text("Veja o teatro de sombras") }
    var message: Text? { Text("Junte dois dedos na tela (pinça) para sair da caixa.") }
    var image: Image? { Image(systemName: "hand.pinch") }
    var rules: [Rule] { #Rule(Self.$podeSair) { $0 } }
}

// Teatro de sombras → dentro da caixa
struct DicaEntrarNaCaixa: Tip {
    // Ligado pela PalcoView: só vale enquanto a pessoa está fora da caixa.
    @Parameter static var estaForaDaCaixa: Bool = false

    var title: Text { Text("Volte para a vela") }
    var message: Text? { Text("Afaste dois dedos na tela (pinça) para entrar na caixa.") }
    var image: Image? { Image(systemName: "hand.pinch") }
    var rules: [Rule] { #Rule(Self.$estaForaDaCaixa) { $0 } }
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
