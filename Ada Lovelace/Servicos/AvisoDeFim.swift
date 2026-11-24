//  AvisoDeFim.swift
//  Aviso (notificação) quando a vela acaba com o app fechado.
//
//  Antes: a vela acabava em segundo plano e ninguém avisava; ao abrir o app, ela "acabava na hora".
//  Agora: quando o app vai para o segundo plano com a vela ACESA, agendamos um aviso para o
//  momento em que ela vai acabar. Se a pessoa voltar antes, o aviso é cancelado.
//  A permissão é pedida na primeira vez que a pessoa acende uma vela.

import Foundation
import UserNotifications

enum AvisoDeFim {
    private static let identificador = "velaAcabou"

    static func pedirPermissao() {
        Task {
            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        }
    }

    // segundos: quanto tempo falta para a vela acabar
    static func agendar(daquiA segundos: TimeInterval) {
        guard segundos >= 1 else { return }
        let conteudo = UNMutableNotificationContent()
        conteudo.title = "A vela acabou"
        conteudo.body = "Sua vela terminou de queimar. Abra o teatro para acender uma nova."
        conteudo.sound = .default
        let gatilho = UNTimeIntervalNotificationTrigger(timeInterval: segundos, repeats: false)
        let pedido = UNNotificationRequest(identifier: identificador, content: conteudo, trigger: gatilho)
        Task {
            try? await UNUserNotificationCenter.current().add(pedido)
        }
    }

    static func cancelar() {
        let central = UNUserNotificationCenter.current()
        central.removePendingNotificationRequests(withIdentifiers: [identificador])
        central.removeDeliveredNotifications(withIdentifiers: [identificador])
    }
}
