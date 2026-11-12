//  ConfiguracoesView.swift
//  Abre de qualquer tela pela engrenagem (também com a vela acesa).

import SwiftUI

struct ConfiguracoesView: View {
    @AppStorage(Chaves.somAmbiente) private var somAmbiente = true
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Som ambiente", isOn: $somAmbiente)
                } footer: {
                    Text("Som de fundo enquanto a vela está acesa. As vibrações e os sons da vela continuam.")
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
