//  Movimento.swift
//  Core Motion: perceber quando o celular gira ou fica de cabeça para baixo.
//
//  Duas coisas SEPARADAS saem daqui:
//  - angulo: para onde fica "para cima" no mundo. A chama usa isso para ficar sempre em pé.
//            Vai de -180° a +180°, SEM limite, senão a chama não consegue se endireitar.
//  - inclinacao: 0 (celular em pé) a 1 (deitado). A vela usa isso para derreter mais rápido.

import Foundation
import Combine
#if os(iOS)
import CoreMotion
#endif

final class Movimento: ObservableObject {
    // ⚙️ A partir de quantos graus a vela derrete na velocidade máxima.
    // 90° = deitado de lado. (Valor provisório: o time ainda vai decidir.)
    static let anguloDaInclinacaoMaxima: Double = .pi / 2

    // De cabeça para baixo (por mais de meio segundo) → a vela apaga
    @Published private(set) var invertido = false

    // Para onde fica "para cima" no mundo, em radianos (-π a π).
    // Não é @Published de propósito: muda 30 vezes por segundo e só a chama precisa ler.
    private(set) var angulo: Double = 0

    // 0 = em pé, 1 = deitado. Quem lê é a Sessao, para acelerar a vela.
    var inclinacao: Double {
        min(1, abs(angulo) / Movimento.anguloDaInclinacaoMaxima)
    }

    #if os(iOS)
    private let manager = CMMotionManager()
    private var mudouEm: Date?
    #endif

    func iniciar() {
        #if os(iOS)
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 30.0

        manager.startDeviceMotionUpdates(to: .main) { [weak self] dados, _ in
            guard let self, let g = dados?.gravity else { return }

            // Em pé, a gravidade puxa para a base do celular: g = (0, -1, 0) → ângulo 0.
            let alvo = atan2(-g.x, -g.y)

            // Suavizado, para a chama não dar pulos.
            // A diferença é ajustada para o caminho curto: assim o giro não dá a volta
            // ao passar de +180° para -180° (celular de cabeça para baixo).
            self.angulo = Movimento.aproximar(de: self.angulo, para: alvo, passo: 0.2)

            // Em pé: g.y ≈ -1. De cabeça para baixo: g.y ≈ +1.
            let estaInvertido = g.y > 0.8

            // Só muda depois de meio segundo, para um giro sem querer não apagar a vela
            if estaInvertido != self.invertido {
                if self.mudouEm == nil { self.mudouEm = Date() }
                if let mudouEm = self.mudouEm, Date().timeIntervalSince(mudouEm) > 0.5 {
                    self.invertido = estaInvertido
                    self.mudouEm = nil
                }
            } else {
                self.mudouEm = nil
            }
        }
        #endif
    }

    func parar() {
        #if os(iOS)
        manager.stopDeviceMotionUpdates()
        #endif
    }

    // Caminha um pouquinho do ângulo atual até o alvo, sempre pelo lado mais curto do círculo.
    // O resultado fica sempre entre -π e π.
    static func aproximar(de atual: Double, para alvo: Double, passo: Double) -> Double {
        var diferenca = (alvo - atual).truncatingRemainder(dividingBy: 2 * .pi)
        if diferenca > .pi { diferenca -= 2 * .pi }
        if diferenca < -.pi { diferenca += 2 * .pi }

        var novo = (atual + diferenca * passo).truncatingRemainder(dividingBy: 2 * .pi)
        if novo > .pi { novo -= 2 * .pi }
        if novo < -.pi { novo += 2 * .pi }
        return novo
    }
}
