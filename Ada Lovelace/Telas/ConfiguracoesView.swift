//  ConfiguracoesView.swift
//  Abre de qualquer tela pela engrenagem (também com a vela acesa).
//
//  Regras de negócio (Configurações): ligar/desligar sons dos objetos, sons do fósforo e da chama, música de fundo,
//  apagar com sopro e sensores de movimento (Core Motion).

import SwiftUI

struct ConfiguracoesView: View {
    @AppStorage(Chaves.somAmbiente) private var somAmbiente = true
    @AppStorage(Chaves.somObjetos) private var somObjetos = true
    @AppStorage(Chaves.somFosforoEChama) private var somFosforoEChama = true
    @AppStorage(Chaves.apagarSoprando) private var apagarSoprando = true
    @AppStorage(Chaves.movimento) private var movimento = true
    @AppStorage(Chaves.resetarDicas) private var resetarDicas = false
    @AppStorage(Chaves.iluminacaoDramatica) private var iluminacaoDramatica = true
    #if DEBUG
    @AppStorage(Chaves.acelerarTempo) private var acelerarTempo = false
    @AppStorage(Chaves.velocidadeDoTempo) private var velocidadeDoTempo = 2.0
    @AppStorage(Chaves.acelerarCenario) private var acelerarCenario = false
    @AppStorage(Chaves.velocidadeDoCenario) private var velocidadeDoCenario = 2.0
    #endif
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    // Os nomes dizem exatamente o que muda na experiência
                    // Música de fundo
                    Toggle("Tocar música", isOn: $somAmbiente)
                        .accessibilityInputLabels(["Tocar música", "Música de fundo", "Música"])
                    Toggle("Sons dos alfinetes e penduricalhos caindo", isOn: $somObjetos)
                        .accessibilityInputLabels(["Sons dos objetos", "Sons"])
                    // Riscar, acender, apagar e o pavio queimando ao fundo
                    Toggle("Sons do fósforo e da vela", isOn: $somFosforoEChama)
                        .accessibilityInputLabels(["Sons do fósforo e da vela", "Sons do fósforo", "Sons da vela", "Sons da chama"])
                } header: {
                    Text("Som")
                } footer: {
                    Text("Desligar os sons não desliga as vibrações.")
                        .adaFont(.footnote)
                }

                Section {
                    Toggle("Apagar a vela com um sopro (usa o microfone)", isOn: $apagarSoprando)
                        .accessibilityInputLabels(["Apagar soprando", "Sopro", "Microfone"])
                    Toggle("Inclinar e virar o aparelho mexem na vela (sensores de movimento)", isOn: $movimento)
                        .accessibilityInputLabels(["Usar o movimento do aparelho", "Movimento", "Sensores"])
                } header: {
                    Text("Jeitos de apagar")
                } footer: {
                    Text("Sopre na direção da chama com a vela acesa (se precisar, permita o microfone nos Ajustes do aparelho). Com o movimento ligado, inclinar faz a vela derreter mais rápido e virar de cabeça para baixo apaga. Tocar na chama sempre apaga. Com o VoiceOver, as ações da vela também apagam a chama e aceleram o derretimento.")
                        .adaFont(.footnote)
                }

                Section {
                    Button(resetarDicas ? "As dicas voltam quando o app abrir de novo" : "Mostrar as dicas de novo") {
                        resetarDicas = true
                    }
                    .disabled(resetarDicas)
                    Toggle("Iluminação dramática", isOn: $iluminacaoDramatica)
                    #if DEBUG
                    Toggle("Acelerar a vela", isOn: $acelerarTempo)
                    if acelerarTempo {
                        controleDeVelocidade("Velocidade da vela", valor: $velocidadeDoTempo)
                    }
                    Toggle("Acelerar o cenário", isOn: $acelerarCenario)
                    if acelerarCenario {
                        controleDeVelocidade("Velocidade do cenário", valor: $velocidadeDoCenario)
                    }
                    #endif
                } header: {
                    Text("Para testar")
                } footer: {
                    Text("As dicas voltam a aparecer depois de fechar e abrir o app.")
                }
            }
            #if DEBUG
            .onChange(of: acelerarCenario) { RelogioDaHistoria.atualizarVelocidadeDeTeste() }
            .onChange(of: velocidadeDoCenario) { RelogioDaHistoria.atualizarVelocidadeDeTeste() }
            #endif
            .navigationTitle("Configurações")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Configurações").adaFont(.sectionTitle)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
        }
        .tint(Cores.cortina)
    }

    #if DEBUG
    private func controleDeVelocidade(_ titulo: LocalizedStringKey, valor: Binding<Double>) -> some View {
        let multiplicador = Int(valor.wrappedValue)
        return VStack(alignment: .leading) {
            Text("\(Text(titulo)) (\(multiplicador)×)")
            Slider(value: valor, in: 2...100, step: 1) {
                Text(titulo)
            } minimumValueLabel: {
                Text("2×")
            } maximumValueLabel: {
                Text("100×")
            }
            .accessibilityValue("\(multiplicador) vezes mais rápido")
        }
    }
    #endif
}

#Preview {
    ConfiguracoesView()
}
