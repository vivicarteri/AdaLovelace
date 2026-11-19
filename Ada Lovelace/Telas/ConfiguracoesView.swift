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
    #if DEBUG
    @AppStorage(Chaves.acelerarTempo) private var acelerarTempo = false
    @AppStorage(Chaves.velocidadeDoTempo) private var velocidadeDoTempo = 2.0
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
                        .adaFont(.footnote)
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
                    #if DEBUG
                    // Só para o time testar: não aparece no app de verdade (Release)
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
                    #endif
                } header: {
                    Text("Para testar")
                } footer: {
                    Text("As dicas voltam a aparecer depois de fechar e abrir o app. Acelerar o tempo só aparece rodando pelo Xcode.")
                }
            }
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
}

#Preview {
    ConfiguracoesView()
}
