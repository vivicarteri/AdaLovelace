//  ContentView.swift
//  Raiz do app: abre direto no palco (home). Configurações abrem por cima, de qualquer tela.
//  (O onboarding saiu do fluxo. O arquivo OnboardingView.swift pode ser apagado.)

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var sessao: Sessao
    @AppStorage(Chaves.somAmbiente) private var somAmbiente = true
    @AppStorage(Chaves.movimento) private var movimentoLigado = true
    @Environment(\.scenePhase) private var scenePhase
    @State private var mostrarConfiguracoes = false

    var body: some View {
        PalcoView(abrirConfiguracoes: { mostrarConfiguracoes = true })
            .sheet(isPresented: $mostrarConfiguracoes) {
                ConfiguracoesView()
            }
            .onAppear { sessao.mudouFase(.active) }
            .onChange(of: scenePhase) { _, fase in sessao.mudouFase(fase) }
            .onChange(of: somAmbiente) { _, _ in sessao.atualizarAmbiente() }
            .onChange(of: movimentoLigado) { _, _ in sessao.atualizarMovimento() }
            // Sem relógio na tela: a pessoa sente o tempo pela vela, não pelos números
            .statusBarHidden(true)
    }
}

#Preview {
    ContentView()
        .environmentObject(Sessao())
}
