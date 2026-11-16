//  ConfiguracoesView.swift
//  Abre de qualquer tela pela engrenagem (também com a vela acesa).

import SwiftUI

struct ConfiguracoesView: View {
    @AppStorage(Chaves.somAmbiente) private var somAmbiente = true
    @AppStorage(Chaves.apagarSoprando) private var apagarSoprando = true
    #if DEBUG
    @AppStorage(Chaves.acelerarTempo) private var acelerarTempo = false
    @AppStorage(Chaves.velocidadeDoTempo) private var velocidadeDoTempo = 2.0
    #endif
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Som ambiente", isOn: $somAmbiente)
                } footer: {
                    Text("Som de fundo enquanto a vela está acesa. As vibrações e os sons da vela continuam.")
                }
                Section {
                    Toggle("Apagar soprando", isOn: $apagarSoprando)
                } footer: {
                    Text("Sopre na direção da chama com a vela acesa. Se necessário, permita o acesso ao microfone nos Ajustes do aparelho.")
                }
                #if DEBUG
                // Só para o time testar: não aparece no app de verdade (Release)
                Section {
                    Toggle("Acelerar o tempo", isOn: $acelerarTempo)
                    if acelerarTempo {
                        VStack(alignment: .leading) {
                            Text("Velocidade: \(Int(velocidadeDoTempo))x")
                            Slider(value: $velocidadeDoTempo, in: 2...20, step: 1) {
                                Text("Velocidade")
                            } minimumValueLabel: {
                                Text("2x")
                            } maximumValueLabel: {
                                Text("20x")
                            }
                            .accessibilityValue("\(Int(velocidadeDoTempo)) vezes mais rápido")
                        }
                    }
                } header: {
                    Text("Teste")
                } footer: {
                    Text(acelerarTempo
                         ? "A vela queima \(Int(velocidadeDoTempo)) vezes mais rápido. Só aparece rodando pelo Xcode."
                         : "Para testar a vela sem esperar. Só aparece rodando pelo Xcode.")
                }
                #endif
            }
            .navigationTitle("Configurações")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
        }
        .tint(Cores.cortina)
    }
}
