//  MyApp.swift
//  A porta de entrada do app.

import SwiftUI
import TipKit
import CoreText

@main struct MyApp: App {
    @StateObject private var sessao = Sessao()
    // Só o iPhone Duo usa: troca as orientações conforme a dobra (no resto vale o Info.plist)
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    init() {
        // Registra a fonte incluída em Recursos para poder experimentá-la nas telas.
        if let url = Bundle.main.url(forResource: "ViaodaLibre-Regular", withExtension: "ttf") {
            if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil) {
                print("Não foi possível registrar ViaodaLibre-Regular.ttf")
            }
        }

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
                .environment(\.font, ADAFont.font(for: .body))
        }
    }
}
