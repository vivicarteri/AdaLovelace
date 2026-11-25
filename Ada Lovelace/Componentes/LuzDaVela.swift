//  LuzDaVela.swift
//  ILUMINAÇÃO DRAMÁTICA (teste pedido pela Georgia): a chama é a única luz do palco.
//
//  Perto da chama o cenário fica claro e quente; longe dela, vai escurecendo até as bordas.
//  E muda ao longo da vela: no começo a luz alcança quase a tela toda; conforme a vela queima,
//  o círculo de luz fica menor, as bordas mais escuras (a noite fecha) e a luz desce junto com
//  a chama. A luz respira de leve, como uma chama de verdade.
//  Pode ser desligada em Configurações → "Iluminação dramática", para comparar.

import SwiftUI

struct LuzDaVela: View {
    var chama: CGPoint          // onde a chama está (coordenadas do palco)
    var tela: CGSize
    var progresso: Double       // 0 = vela nova, 1 = acabou

    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento

    // ⚙️ Ajustes
    static let corDoEscuro = Color(red: 0.03, green: 0.02, blue: 0.09)   // azul-noite quase preto
    static let alcanceNoComeco: CGFloat = 0.8    // raio da luz (fração do maior lado da tela)
    static let alcanceNoFim: CGFloat = 0.46
    static let escuroNoComeco: Double = 0.52      // quão escuras ficam as bordas
    static let escuroNoFim: Double = 0.82
    static let calorPerto: Double = 0.16          // brilho dourado em volta da chama

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 20, paused: reduzirMovimento)) { contexto in
            let t = contexto.date.timeIntervalSinceReferenceDate
            let p = CGFloat(min(1, max(0, progresso)))
            // Respiração da chama: bem leve e irregular
            let tremor = reduzirMovimento ? 0 : CGFloat(sin(t * 7.3) * 0.5 + sin(t * 11.9) * 0.3 + sin(t * 2.1) * 0.2)
            let maior = max(tela.width, tela.height)
            let alcance = maior * (LuzDaVela.alcanceNoComeco + (LuzDaVela.alcanceNoFim - LuzDaVela.alcanceNoComeco) * p)
                * (1 + 0.02 * tremor)
            let escuro = (LuzDaVela.escuroNoComeco + (LuzDaVela.escuroNoFim - LuzDaVela.escuroNoComeco) * Double(p))
                * (1 - 0.04 * Double(tremor))
            // Um quadrado bem maior que a tela, centrado na chama: além do raio, a cor do fim continua,
            // então os cantos ficam sempre escuros, em qualquer tela.
            let lado = maior * 3.2
            ZStack {
                RadialGradient(stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .clear, location: 0.16),
                    .init(color: LuzDaVela.corDoEscuro.opacity(escuro * 0.5), location: 0.55),
                    .init(color: LuzDaVela.corDoEscuro.opacity(escuro), location: 1)
                ], center: .center, startRadius: 0, endRadius: alcance)
                RadialGradient(colors: [Cores.dourado.opacity(LuzDaVela.calorPerto * (1 + 0.1 * Double(tremor))), .clear],
                               center: .center, startRadius: 0, endRadius: alcance * 0.45)
            }
            .frame(width: lado, height: lado)
            .position(chama)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
