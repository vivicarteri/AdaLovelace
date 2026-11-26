//  ContentView.swift
//  Raiz do app: abre direto no palco (home). Configurações abrem por cima, de qualquer tela.
//  (O onboarding saiu do fluxo. O arquivo OnboardingView.swift pode ser apagado.)

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var sessao: Sessao
    @AppStorage(Chaves.somAmbiente) private var somAmbiente = true
    @AppStorage(Chaves.somFosforoEChama) private var somFosforoEVela = true
    @AppStorage(Chaves.movimento) private var movimentoLigado = true
    @AppStorage(Chaves.apagarSoprando) private var apagarSoprando = true
    @Environment(\.scenePhase) private var scenePhase
    @State private var mostrarConfiguracoes = false

    var body: some View {
        PalcoView(abrirConfiguracoes: { mostrarConfiguracoes = true })
            // relativeTo: o texto acompanha o tamanho de texto escolhido nos Ajustes (Dynamic Type)
            .environment(\.font, .custom("ViaodaLibre-Regular", size: 17, relativeTo: .body))
            .sheet(isPresented: $mostrarConfiguracoes) {
                ConfiguracoesView()
            }
            .onChange(of: scenePhase, initial: true) { _, fase in sessao.mudouFase(fase) }
            .onChange(of: apagarSoprando) { _, _ in sessao.atualizarSopro() }
            .onChange(of: somAmbiente) { _, _ in sessao.atualizarAmbiente() }
            .onChange(of: somFosforoEVela) { _, _ in sessao.atualizarAmbiente() }   // o pavio queimando
            .onChange(of: movimentoLigado) { _, _ in sessao.atualizarMovimento() }
            // Sem relógio na tela: a pessoa sente o tempo pela vela, não pelos números
            .statusBarHidden(true)
    }
}

#Preview {
    ContentView()
        .environmentObject(Sessao())
}
