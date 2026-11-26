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
    // Com o VoiceOver não dá para fazer pinça: a dica não aparece (o botão já se explica).
    @Parameter static var voiceOverLigado: Bool = false

    var title: Text { Text("Veja o teatro de sombras").font(ADAFont.font(for: .tipTitle)) }
    var message: Text? { Text("Toque no botão no canto de cima ou junte dois dedos na tela, como uma pinça, para ver o teatro de sombras.").font(ADAFont.font(for: .tipMessage)) }
    var image: Image? { Image(systemName: "hand.pinch") }
    var rules: [Rule] {
        #Rule(Self.$podeSair) { $0 }
        #Rule(Self.$voiceOverLigado) { !$0 }
    }
}

// Teatro de sombras → dentro da caixa
struct DicaEntrarNaCaixa: Tip {
    // Ligado pela PalcoView: só vale enquanto a pessoa está fora da caixa.
    @Parameter static var estaForaDaCaixa: Bool = false
    @Parameter static var voiceOverLigado: Bool = false

    var title: Text { Text("Volte para a vela").font(ADAFont.font(for: .tipTitle)) }
    var message: Text? { Text("Toque no botão no canto de cima ou afaste dois dedos na tela, como uma pinça, para voltar para a vela.").font(ADAFont.font(for: .tipMessage)) }
    var image: Image? { Image(systemName: "hand.pinch") }
    var rules: [Rule] {
        #Rule(Self.$estaForaDaCaixa) { $0 }
        #Rule(Self.$voiceOverLigado) { !$0 }
    }
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

// Quem acendeu a vela 2 vezes só tocando no fósforo (ele risca sozinho) ganha a dica de
// riscar à mão. Aparece na próxima vez que a caixa abrir, apontando o fósforo.
// Some quando a pessoa risca à mão. Com o VoiceOver não aparece (lá a caixa acende direto).
struct DicaRiscarOFosforo: Tip {
    static let acendeuPeloToque = Event(id: "acendeuPeloToque")
    @Parameter static var caixaAberta: Bool = false
    @Parameter static var voiceOverLigado: Bool = false

    var title: Text { Text("Outro jeito de acender").font(ADAFont.font(for: .tipTitle)) }
    var message: Text? { Text("Você também pode acender a vela riscando o palito na caixa e arrastando até o pavio.").font(ADAFont.font(for: .tipMessage)) }
    var image: Image? { Image(systemName: "hand.draw") }
    var rules: [Rule] {
        #Rule(Self.acendeuPeloToque) { $0.donations.count >= 2 }
        #Rule(Self.$caixaAberta) { $0 }
        #Rule(Self.$voiceOverLigado) { !$0 }
    }
}

// MARK: - Balão

// Balão de dica com a ponta saindo do botão de onde a dica vem (e não do meio do balão,
// como a seta do TipView faz). O fundo do TipView fica transparente e o balão desenha
// o próprio fundo, com a ponta, numa forma só.
struct BalaoDeDica: View {
    var dica: (any Tip)?
    var pontaX: CGFloat? = nil       // onde fica a ponta, a partir da borda esquerda do balão (nil = sem ponta)
    var pontaEmCima = true           // true = o botão está acima do balão; false = abaixo

    static let alturaDaPonta: CGFloat = 10

    var body: some View {
        TipView(dica)
            .tipBackground(Color.clear)
            .padding(pontaEmCima ? .top : .bottom, pontaX == nil ? 0 : Self.alturaDaPonta)
            .background(
                FormaDoBalao(pontaX: pontaX, pontaEmCima: pontaEmCima, alturaDaPonta: Self.alturaDaPonta)
                    .fill(.regularMaterial)
                    .shadow(color: .black.opacity(0.18), radius: 6, y: 2)
            )
    }
}

private struct FormaDoBalao: Shape {
    var pontaX: CGFloat?
    var pontaEmCima: Bool
    var alturaDaPonta: CGFloat
    var raio: CGFloat = 13
    var larguraDaPonta: CGFloat = 22

    func path(in rect: CGRect) -> Path {
        var corpo = rect
        if pontaX != nil {
            corpo = pontaEmCima
                ? CGRect(x: rect.minX, y: rect.minY + alturaDaPonta, width: rect.width, height: rect.height - alturaDaPonta)
                : CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height - alturaDaPonta)
        }
        var caminho = Path(roundedRect: corpo, cornerRadius: raio, style: .continuous)
        guard let pontaX else { return caminho }
        // A ponta não passa das curvas dos cantos
        let meio = larguraDaPonta / 2
        let x = min(max(rect.minX + pontaX, corpo.minX + raio + meio), corpo.maxX - raio - meio)
        var ponta = Path()
        if pontaEmCima {
            ponta.move(to: CGPoint(x: x - meio, y: corpo.minY + 1))
            ponta.addLine(to: CGPoint(x: x, y: rect.minY))
            ponta.addLine(to: CGPoint(x: x + meio, y: corpo.minY + 1))
        } else {
            ponta.move(to: CGPoint(x: x - meio, y: corpo.maxY - 1))
            ponta.addLine(to: CGPoint(x: x, y: rect.maxY))
            ponta.addLine(to: CGPoint(x: x + meio, y: corpo.maxY - 1))
        }
        ponta.closeSubpath()
        caminho.addPath(ponta)
        return caminho
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
