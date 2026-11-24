//  ConfiguracoesView.swift
//  Abre de qualquer tela pela engrenagem (também com a vela acesa).
//
//  Regras de negócio (Configurações): ligar/desligar sons dos objetos, música de fundo,
//  apagar com sopro e sensores de movimento (Core Motion).

import SwiftUI

struct ConfiguracoesView: View {
    @AppStorage(Chaves.somAmbiente) private var somAmbiente = true
    @AppStorage(Chaves.somObjetos) private var somObjetos = true
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
                    Toggle("Música de fundo", isOn: $somAmbiente)
                    Toggle("Sons dos objetos", isOn: $somObjetos)
                } header: {
                    Text("Som")
                } footer: {
                    Text("A música toca enquanto a vela está acesa. Os sons dos objetos são os alfinetes e penduricalhos caindo. As vibrações continuam.")
                }

                Section {
                    Toggle("Apagar soprando", isOn: $apagarSoprando)
                    Toggle("Usar o movimento do aparelho", isOn: $movimento)
                } header: {
                    Text("Jeitos de apagar")
                } footer: {
                    Text("Sopre na direção da chama com a vela acesa (se precisar, permita o microfone nos Ajustes do aparelho). Com o movimento ligado, inclinar faz a vela derreter mais rápido e virar de cabeça para baixo apaga. Tocar na chama sempre apaga.")
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
            .toolbar {
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
