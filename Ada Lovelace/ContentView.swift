//  ContentView.swift
//  Raiz do app: abre direto no palco (home). Configurações abrem por cima, de qualquer tela.
//  (O onboarding saiu do fluxo. O arquivo OnboardingView.swift pode ser apagado.)

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var sessao: Sessao
    @AppStorage(Chaves.somAmbiente) private var somAmbiente = true
    @AppStorage(Chaves.movimento) private var movimentoLigado = true
    @AppStorage(Chaves.apagarSoprando) private var apagarSoprando = true
    @Environment(\.scenePhase) private var scenePhase
    @State private var mostrarConfiguracoes = false
    @ObservedObject private var dobradica = Dobradica.compartilhada

    var body: some View {
        // ZStack, e não Group: no Group o .background abaixo iria para CADA tela, e o leitor
        // da dobradiça nascia e morria a cada troca (a tela ficava piscando entre Duo e normal).
        ZStack {
            if dobradica.ehDuo {
                // iPhone Duo: configurações num botão nativo, sempre no canto de cima à direita
                // (o palco não desenha a engrenagem dele nesse modo)
                NavigationStack {
                    palco
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button { mostrarConfiguracoes = true } label: {
                                    // ⚙️ Ícone provisório: depois troca pelo asset próprio aqui
                                    Label("Configurações", systemImage: "gearshape")
                                }
                                .accessibilityInputLabels(["Abrir configurações", "Ajustes", "Configurações"])
                            }
                        }
                        .toolbarBackground(.hidden, for: .navigationBar)
                }
            } else {
                palco
            }
        }
        #if canImport(UIKit)
        // Ouve a dobradiça do iPhone Duo (nos outros aparelhos ela nunca responde)
        .background(LeitorDaDobradica().allowsHitTesting(false).accessibilityHidden(true))
        #endif
    }

    private var palco: some View {
        PalcoView(abrirConfiguracoes: { mostrarConfiguracoes = true })
            // relativeTo: o texto acompanha o tamanho de texto escolhido nos Ajustes (Dynamic Type)
            .environment(\.font, .custom("ViaodaLibre-Regular", size: 17, relativeTo: .body))
            .sheet(isPresented: $mostrarConfiguracoes) {
                ConfiguracoesView()
            }
            .onChange(of: scenePhase, initial: true) { _, fase in sessao.mudouFase(fase) }
            .onChange(of: apagarSoprando) { _, _ in sessao.atualizarSopro() }
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
