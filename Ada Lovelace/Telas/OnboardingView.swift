//  OnboardingView.swift
//  3 passos na primeira vez que abre o app (e em Configurações › Rever onboarding).
//  "Pular" e "Começar" levam para a home.

import SwiftUI
import Foundation

struct OnboardingView: View {
    var terminar: () -> Void

    @State private var passo = 0
    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento

    private struct Passo {
        let titulo: String
        let texto: String
    }

    // O texto é sugestão: o time pode trocar à vontade
    private static let lista = [
        Passo(titulo: "O tamanho da vela é o tempo",
              texto: "No ateliê, escolha o tamanho: vela maior dura mais. Nada de números na tela."),
        Passo(titulo: "Alfinetes marcam pontos da cera",
              texto: "Eles caem quando a cera chega neles, com som e vibração. Quanto mais alto, mais forte a queda."),
        Passo(titulo: "Vire o celular para apagar",
              texto: "De cabeça para baixo a chama apaga, com fumaça, som e vibração. Para continuar, acenda de novo."),
    ]

    private var passos: [Passo] { OnboardingView.lista }

    var body: some View {
        ZStack {
            Cores.fundoEscuro.ignoresSafeArea()

            VStack(spacing: 24) {
                HStack {
                    Spacer()
                    Button("Pular", action: terminar)
                        .foregroundStyle(Cores.papel)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .overlay(Capsule().stroke(Cores.papel, lineWidth: 1.5))
                }

                Spacer()

                ilustracao
                    .frame(height: 280)
                    .id(passo)
                    .transition(.opacity)
                    .accessibilityHidden(true)

                VStack(spacing: 12) {
                    Text(passos[passo].titulo)
                        .font(.system(.title2, design: .serif).bold())
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                    Text(passos[passo].texto)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .opacity(0.85)
                }
                .foregroundStyle(Cores.papel)
                .frame(maxWidth: 420)
                .id("texto\(passo)")
                .transition(.opacity)

                Spacer()

                // Indicador de página
                HStack(spacing: 8) {
                    ForEach(passos.indices, id: \.self) { i in
                        Circle()
                            .fill(Cores.papel.opacity(i == passo ? 1 : 0.3))
                            .frame(width: 8, height: 8)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Passo \(passo + 1) de \(passos.count)")

                Button {
                    if passo < passos.count - 1 {
                        withAnimation(.easeInOut) { passo += 1 }
                    } else {
                        terminar()
                    }
                } label: {
                    Text(passo < passos.count - 1 ? "Próximo" : "Começar")
                        .font(.headline)
                        .foregroundStyle(Cores.tinta)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(Cores.dourado))
                }
                .buttonStyle(.plain)
            }
            .padding(24)
        }
        // Arrastar para os lados também troca de passo
        .gesture(
            DragGesture(minimumDistance: 30).onEnded { valor in
                withAnimation(.easeInOut) {
                    if valor.translation.width < -50 { passo = min(passos.count - 1, passo + 1) }
                    if valor.translation.width > 50 { passo = max(0, passo - 1) }
                }
            }
        )
    }

    // Ilustrações provisórias (a Georgia pode trocar por animações)
    @ViewBuilder private var ilustracao: some View {
        switch passo {
        case 0:
            HStack(alignment: .bottom, spacing: 28) {
                VelaView(alturaCheia: 70, largura: 30, acesa: true)
                VelaView(alturaCheia: 130, largura: 30, acesa: true)
                VelaView(alturaCheia: 200, largura: 30, acesa: true)
            }
        case 1:
            VelaView(alturaCheia: 200, largura: 40, acesa: true,
                     enfeites: [Enfeite(tipo: .alfinete, altura: 0.7, lado: -1),
                                Enfeite(tipo: .penduricalho, altura: 0.45, lado: 1),
                                Enfeite(tipo: .alfinete, altura: 0.25, lado: -1)])
        default:
            TimelineView(.animation(minimumInterval: 1 / 30, paused: reduzirMovimento)) { contexto in
                let t = contexto.date.timeIntervalSinceReferenceDate
                let virar = reduzirMovimento ? 1 : (sin(t * 1.2) + 1) / 2   // 0 = em pé, 1 = de cabeça para baixo
                Image(systemName: "iphone")
                    .font(.system(size: 140, weight: .thin))
                    .foregroundStyle(Cores.papel)
                    .rotationEffect(.degrees(180 * virar))
            }
        }
    }
}
