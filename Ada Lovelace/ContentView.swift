//  ContentView.swift
//  Raiz do app: abre direto no palco (home). Configurações abrem por cima, de qualquer tela.
//  (O onboarding saiu do fluxo. O arquivo OnboardingView.swift pode ser apagado.)

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var sessao: Sessao
    @AppStorage(Chaves.somAmbiente) private var somAmbiente = true
    @AppStorage(Chaves.apagarSoprando) private var apagarSoprando = true
    @Environment(\.scenePhase) private var scenePhase
    @State private var mostrarConfiguracoes = false

    var body: some View {
        PalcoView(abrirConfiguracoes: { mostrarConfiguracoes = true })
            .sheet(isPresented: $mostrarConfiguracoes) {
                ConfiguracoesView()
            }
            .onChange(of: scenePhase, initial: true) { _, fase in sessao.mudouFase(fase) }
            .onChange(of: apagarSoprando) { _, _ in sessao.atualizarSopro() }
            .onChange(of: somAmbiente) { _, _ in sessao.atualizarAmbiente() }
    }
}

#Preview {
    ContentView()
        .environmentObject(Sessao())
}
