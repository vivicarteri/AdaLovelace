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
