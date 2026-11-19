import Foundation
import OSLog

#if os(iOS)
import CoreHaptics
import AVFoundation

final class Haptics {
    let suportado = CHHapticEngine.capabilitiesForHardware().supportsHaptics

    // Tempo que o alfinete leva para cair. Tem que ser igual ao "Time": 0.45 do Prego.ahap.
    static let tempoQueda: TimeInterval = 0.45

    private let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "AdaLovelace", category: "Haptics")
    private var engine: CHHapticEngine?
    private var precisaLigar = true
    private var players: [String: CHHapticPatternPlayer] = [:]
    private var chama: CHHapticAdvancedPatternPlayer?
    private var chamaTocando = false   // para religar a chama se o sistema reiniciar o motor
    private var segurar: CHHapticAdvancedPatternPlayer?
    private var audioPrego: AVAudioPlayer?

    init() {
        criarMotor()
    }

    // MARK: Motor

    private func criarMotor() {
        // .ambient: o som do app não para a música da pessoa
        try? AVAudioSession.sharedInstance().setCategory(.ambient)
        carregarAudioDoPrego()
        guard suportado else { return }
        do {
            let motor = try CHHapticEngine(audioSession: .sharedInstance())

            // Se o motor parar (app em segundo plano, ligação…), lembramos de ligar de novo
            motor.stoppedHandler = { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.precisaLigar = true
                }
            }

            // Se o sistema reiniciar o motor, os players antigos não valem mais: carregamos tudo de novo
            motor.resetHandler = { [weak self] in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.precisaLigar = true
                    self.carregarPadroes()
                    if self.chamaTocando { self.iniciarChama() }
                }
            }

            engine = motor
            try ligarSePreciso()
            carregarPadroes()
        } catch {
            log.error("Erro ao criar o motor de vibração: \(error.localizedDescription)")
        }
    }

    private func carregarAudioDoPrego() {
        guard let url = Bundle.main.url(forResource: "Prego", withExtension: "wav") else {
            print("Não achei Prego.wav no bundle do app")
            return
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            audioPrego = player
        } catch {
            print("Erro ao carregar Prego.wav: \(error)")
        }
    }

    // O enfeite leva 0,45 s para cair. Agenda o WAV original para tocar ao atingir o pote.
    private func tocarAudioDoPrego(forca: Float) {
        guard Chaves.ligado(Chaves.somObjetos), let player = audioPrego else { return }
        player.stop()
        player.currentTime = 0
        player.volume = max(0, min(1, forca))
        player.prepareToPlay()
        player.play(atTime: player.deviceCurrentTime + Self.tempoQueda)
    }

    private func ligarSePreciso() throws {
        guard let engine, precisaLigar else { return }
        try engine.start()
        precisaLigar = false
    }

    func ligarMotor() {
        try? ligarSePreciso()
    }

    func desligarMotor() {
        pararChama()
        cancelarSegurar()
        precisaLigar = true
        engine?.stop { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.precisaLigar = true
            }
        }
    }

    // MARK: Arquivos .ahap

    private func carregarPadroes() {
        guard let engine else { return }
        for nome in ["Acender", "Prego", "Apagar", "Fim"] {
            if let padrao = padrao(nome) {
                players[nome] = try? engine.makePlayer(with: padrao)
            }
        }
        if let padrao = padrao("Chama") {
            chama = try? engine.makeAdvancedPlayer(with: padrao)
            chama?.loopEnabled = true
        }
    }

    private func padrao(_ nome: String) -> CHHapticPattern? {
        guard let url = Bundle.main.url(forResource: nome, withExtension: "ahap") else {
            log.warning("Arquivo \(nome, privacy: .public).ahap não encontrado no bundle.")
            return nil
        }
        do {
            let dados = try Data(contentsOf: url)
            let json = try JSONSerialization.jsonObject(with: dados)
            guard let dicionario = json as? [CHHapticPattern.Key: Any] else { return nil }
            return try CHHapticPattern(dictionary: dicionario)
        } catch {
            log.error("Erro ao ler \(nome, privacy: .public).ahap: \(error.localizedDescription)")
            return nil
        }
    }

    // Toca um .ahap. "forca" muda a vibração e "volume" muda o som (os dois de 0 a 1).
    private func tocar(_ nome: String, forca: Float = 1, volume: Float = 1) {
        guard suportado, let player = players[nome] else { return }
        let f = max(0, min(1, forca))
        let v = max(0, min(1, volume))
        do {
            try ligarSePreciso()
            try player.sendParameters([
                CHHapticDynamicParameter(parameterID: .hapticIntensityControl, value: f, relativeTime: 0),
                CHHapticDynamicParameter(parameterID: .audioVolumeControl, value: v, relativeTime: 0)
            ], atTime: CHHapticTimeImmediate)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            log.error("Erro ao tocar \(nome, privacy: .public): \(error.localizedDescription)")
        }
    }

    // Vibração curtinha feita no código
    private func toque(forca: Float, nitidez: Float) {
        guard suportado, let engine else { return }
        do {
            try ligarSePreciso()
            let evento = CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: max(0, min(1, forca))),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: max(0, min(1, nitidez)))
            ], relativeTime: 0)
            try engine.makePlayer(with: CHHapticPattern(events: [evento], parameters: []))
                .start(atTime: CHHapticTimeImmediate)
        } catch {
            log.error("Erro na vibração curta: \(error.localizedDescription)")
        }
    }

    // MARK: Momentos da vela

    func acender() { tocar("Acender") }

    func apagar() { tocar("Apagar") }

    func fim() { tocar("Fim") }

    // forca: 0 a 1 (enfeite mais alto = cai de mais alto = batida mais forte e som mais alto)
    func prego(forca: Float) {
        let f = max(0, min(1, forca))
        tocar("Prego", forca: 0.5 + 0.5 * f, volume: 0)
        tocarAudioDoPrego(forca: 0.4 + 0.6 * f)
    }

    // Enfeite que não encostou na vela e caiu no pote
    func caiuNoPote() {
        tocar("Prego", forca: 0.3, volume: 0)
        tocarAudioDoPrego(forca: 0.25)
    }

    // Batidinha leve (slider, encaixar enfeite…)
    func tique() { toque(forca: 0.5, nitidez: 0.5) }

    // Fósforo riscando na caixa: batida seca e áspera
    func riscar() { toque(forca: 0.9, nitidez: 0.2) }

    // Fósforo raspando na lixa (antes de acender): batidinhas fracas e ásperas
    func raspar() { toque(forca: 0.35, nitidez: 0.05) }

    // MARK: Segurar para descartar (vibração que vai crescendo durante 1 segundo)

    func iniciarSegurar(duracao: TimeInterval) {
        guard suportado, duracao > 0, let engine else { return }
        cancelarSegurar()
        do {
            try ligarSePreciso()
            let continua = CHHapticEvent(eventType: .hapticContinuous, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
            ], relativeTime: 0, duration: duracao)
            let crescendo = CHHapticParameterCurve(parameterID: .hapticIntensityControl, controlPoints: [
                .init(relativeTime: 0, value: 0.1),
                .init(relativeTime: duracao, value: 1)
            ], relativeTime: 0)
            let player = try engine.makeAdvancedPlayer(with: CHHapticPattern(events: [continua], parameterCurves: [crescendo]))
            try player.start(atTime: CHHapticTimeImmediate)
            segurar = player
        } catch {
            log.error("Erro na vibração de segurar: \(error.localizedDescription)")
        }
    }

    func cancelarSegurar() {
        try? segurar?.stop(atTime: CHHapticTimeImmediate)
        segurar = nil
    }

    // MARK: Textura da chama (em loop)

    func iniciarChama() {
        guard suportado, let chama else { return }
        do {
            try ligarSePreciso()
            try chama.sendParameters([
                CHHapticDynamicParameter(parameterID: .hapticIntensityControl, value: 0.35, relativeTime: 0)
            ], atTime: 0)
            try chama.start(atTime: CHHapticTimeImmediate)
            chamaTocando = true
        } catch {
            log.error("Erro na chama: \(error.localizedDescription)")
        }
    }

    // inclinacao: 0 (em pé) a 1 (bem inclinado). Mais inclinado = chama mais forte.
    func atualizarChama(inclinacao: Float) {
        guard suportado, chamaTocando, let chama else { return }
        let forca = 0.35 + 0.45 * max(0, min(1, inclinacao))
        try? chama.sendParameters([
            CHHapticDynamicParameter(parameterID: .hapticIntensityControl, value: forca, relativeTime: 0)
        ], atTime: 0)
    }

    func pararChama() {
        chamaTocando = false
        try? chama?.stop(atTime: CHHapticTimeImmediate)
    }
}

#else

// Fora do iPhone/iPad (Mac, Vision Pro) o app funciona, só sem vibração
final class Haptics {
    let suportado = false
    static let tempoQueda: TimeInterval = 0.45
    func ligarMotor() {}
    func desligarMotor() {}
    func acender() {}
    func apagar() {}
    func fim() {}
    func prego(forca: Float) {}
    func caiuNoPote() {}
    func tique() {}
    func riscar() {}
    func raspar() {}
    func iniciarSegurar(duracao: TimeInterval) {}
    func cancelarSegurar() {}
    func iniciarChama() {}
    func atualizarChama(inclinacao: Float) {}
    func pararChama() {}
}

#endif
