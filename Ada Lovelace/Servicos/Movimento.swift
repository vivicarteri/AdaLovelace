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
import UIKit
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

    // ⚙️ Quanto a gravidade precisa mudar para contar como "a pessoa mexeu" (0,03 ≈ 1,7°).
    static let mexidaMinima: Double = 0.03

    // Última vez que o aparelho mexeu de verdade. A Sessao usa para deixar a vibração
    // da chama descansar quando o aparelho fica parado. Não é @Published (muda a toda hora).
    private(set) var mexeuEm = Date()

    #if os(iOS)
    private let manager = CMMotionManager()
    private var mudouEm: Date?
    // Gravidade da última vez que contou como "mexeu". Usamos a gravidade inteira (x, y, z),
    // e não o ângulo: com o celular deitado na mesa o ângulo vira ruído, a gravidade não.
    private var gravidadeDeReferencia: CMAcceleration?
    #endif

    func iniciar() {
        #if os(iOS)
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        mexeuEm = Date()
        gravidadeDeReferencia = nil
        manager.deviceMotionUpdateInterval = 1.0 / 30.0

        manager.startDeviceMotionUpdates(to: .main) { [weak self] dados, _ in
            guard let self, let g = dados?.gravity else { return }

            // Em pé, a gravidade puxa para a base do celular: g = (0, -1, 0) → ângulo 0.
            // O sensor mede em relação ao aparelho EM PÉ. Com a tela deitada (iPad),
            // descontamos o giro da tela, senão a chama ficaria torta 90°.
            let tela = Movimento.orientacaoDaTela()
            let alvo = atan2(-g.x, -g.y) - Movimento.giroDaTela(tela)

            // Suavizado, para a chama não dar pulos.
            // A diferença é ajustada para o caminho curto: assim o giro não dá a volta
            // ao passar de +180° para -180° (celular de cabeça para baixo).
            self.angulo = Movimento.aproximar(de: self.angulo, para: alvo, passo: 0.2)

            // Mexeu de verdade? (distância entre a gravidade de agora e a de referência)
            if let ref = self.gravidadeDeReferencia {
                let dx = g.x - ref.x, dy = g.y - ref.y, dz = g.z - ref.z
                if (dx * dx + dy * dy + dz * dz).squareRoot() >= Movimento.mexidaMinima {
                    self.gravidadeDeReferencia = g
                    self.mexeuEm = Date()
                }
            } else {
                self.gravidadeDeReferencia = g
            }

            // De cabeça para baixo = a gravidade puxa para o TOPO da tela.
            // (Com a tela em pé, o topo é +y do aparelho: g.y ≈ +1.)
            let topo = Movimento.topoDaTela(tela)
            let estaInvertido = g.x * topo.x + g.y * topo.y > 0.8

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

    #if os(iOS)
    // A orientação da tela agora (em pé, deitada para um lado ou para o outro).
    // No iPhone é sempre em pé; no iPad, deitada.
    private static func orientacaoDaTela() -> UIInterfaceOrientation {
        let cenas = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let ativa = cenas.first { $0.activationState == .foregroundActive } ?? cenas.first
        return ativa?.effectiveGeometry.interfaceOrientation ?? .portrait
    }

    // Em que ângulo (na conta do sensor) fica o "para cima" da tela.
    private static func giroDaTela(_ o: UIInterfaceOrientation) -> Double {
        switch o {
        // landscapeLeft = botão de início à esquerda: o topo do aparelho fica à direita,
        // e o "para cima" da tela é o lado ESQUERDO do aparelho em pé (-x).
        case .landscapeLeft: return -.pi / 2
        case .landscapeRight: return .pi / 2    // o contrário: lado direito do aparelho (+x)
        case .portraitUpsideDown: return .pi
        default: return 0
        }
    }

    // O "para cima" da tela, nos eixos do aparelho (x = direita, y = topo do aparelho em pé).
    private static func topoDaTela(_ o: UIInterfaceOrientation) -> (x: Double, y: Double) {
        switch o {
        case .landscapeLeft: return (-1, 0)
        case .landscapeRight: return (1, 0)
        case .portraitUpsideDown: return (0, -1)
        default: return (0, 1)
        }
    }
    #endif
}
