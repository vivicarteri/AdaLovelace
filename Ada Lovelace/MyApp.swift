//  MyApp.swift
//  A porta de entrada do app.

import SwiftUI
import TipKit

@main struct MyApp: App {
    @StateObject private var sessao = Sessao()

    init() {
        // Liga o TipKit. SEM esta linha as dicas da pinça nunca aparecem.
        // .immediate = a dica aparece assim que o lugar dela entra na tela.
        // Para ver as dicas de novo durante o teste, troquem por: try? Tips.resetDatastore()
        try? Tips.configure([
            .displayFrequency(.immediate),
            .datastoreLocation(.applicationDefault)
        ])
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(sessao)
                .preferredColorScheme(.dark)
        }
    }
}
