//  ConfiguracoesView.swift
//  Abre de qualquer tela pela engrenagem (também com a vela acesa).

import SwiftUI

struct ConfiguracoesView: View {
    @AppStorage(Chaves.somAmbiente) private var somAmbiente = true
    @AppStorage(Chaves.apagarSoprando) private var apagarSoprando = true
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
                    Text("Sopre perto do topo do aparelho com a vela acesa. Se necessário, permita o acesso ao microfone nos Ajustes do aparelho.")
                }
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
