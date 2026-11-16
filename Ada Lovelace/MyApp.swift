//  MyApp.swift
//  A porta de entrada do app.

import SwiftUI
import TipKit

@main struct MyApp: App {
    @StateObject private var sessao = Sessao()

    init() {
        // Liga o TipKit. SEM esta linha as dicas da pinça nunca aparecem.
        // .immediate = a dica aparece assim que o lugar dela entra na tela.
        // Para ver as dicas de novo durante o teste: Configurações → "Mostrar as dicas de novo".
        // "Mostrar as dicas de novo" (Configurações): o TipKit só deixa apagar o histórico
        // ANTES de ligar, então isso acontece aqui, na abertura seguinte do app.
        if UserDefaults.standard.bool(forKey: Chaves.resetarDicas) {
            try? Tips.resetDatastore()
            UserDefaults.standard.set(false, forKey: Chaves.resetarDicas)
        }
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
