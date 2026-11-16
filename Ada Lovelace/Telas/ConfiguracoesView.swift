//  ConfiguracoesView.swift
//  Abre de qualquer tela pela engrenagem (também com a vela acesa).
//
//  Regras de negócio (Configurações): ligar/desligar sons dos objetos, música de fundo,
//  apagar com sopro e sensores de movimento (Core Motion).
//  ⚠️ "Apagar com sopro" entra aqui quando o código do Luca (microfone) chegar no projeto.

import SwiftUI

struct ConfiguracoesView: View {
    @AppStorage(Chaves.somAmbiente) private var somAmbiente = true
    @AppStorage(Chaves.somObjetos) private var somObjetos = true
    @AppStorage(Chaves.movimento) private var movimento = true
    @AppStorage(Chaves.tempoAcelerado) private var tempoAcelerado = false
    @AppStorage(Chaves.resetarDicas) private var resetarDicas = false
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
                    Toggle("Usar o movimento do aparelho", isOn: $movimento)
                } header: {
                    Text("Movimento")
                } footer: {
                    Text("Inclinar o aparelho faz a vela derreter mais rápido e virar de cabeça para baixo apaga a chama. Desligado, apague tocando na chama.")
                }

                Section {
                    Toggle("Tempo acelerado", isOn: $tempoAcelerado)
                    Button(resetarDicas ? "As dicas voltam quando o app abrir de novo" : "Mostrar as dicas de novo") {
                        resetarDicas = true
                    }
                    .disabled(resetarDicas)
                } header: {
                    Text("Para testar")
                } footer: {
                    Text("Tempo acelerado: a vela queima bem mais rápido, para ver a história inteira em poucos minutos. As dicas voltam a aparecer depois de fechar e abrir o app.")
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

#Preview {
    ConfiguracoesView()
}
