//  SomAmbiente.swift
//  Os sons de fundo enquanto a vela está acesa:
//  - MÚSICA (MusicaFundo.mp3), em loop. Interruptor "Tocar música".
//  - PAVIO queimando (FirePlace.m4a), baixinho e em loop. Interruptor "Sons do fósforo e da vela".
//  Quem decide quando cada um toca é a Sessao; aqui só fica o "como".

import Foundation
import AVFoundation
import OSLog

final class SomAmbiente {
    // ⚙️ Volume da música (0 a 1)
    static let volumeDaMusica: Float = 0.5

    private let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "AdaLovelace", category: "SomAmbiente")
    private var player: AVAudioPlayer?
    private var procurouArquivo = false
    private var deveTocar = false
    private var observadorInterrupcao: NSObjectProtocol?

    let pavio = SomDoPavio()

    init() {
        #if os(iOS)
        observadorInterrupcao = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notificacao in
            let tipoRaw = notificacao.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            Task { @MainActor [weak self] in
                guard let self, let tipoRaw,
                      let tipo = AVAudioSession.InterruptionType(rawValue: tipoRaw) else { return }
                if tipo == .ended {
                    if self.deveTocar { self.player?.play() }
                    self.pavio.religar()
                }
            }
        }
        #endif
    }

    deinit {
        if let observadorInterrupcao {
            NotificationCenter.default.removeObserver(observadorInterrupcao)
        }
    }

    // MARK: Música

    func tocarMusica() {
        deveTocar = true
        if player == nil && !procurouArquivo {
            procurouArquivo = true
            if let url = Bundle.main.url(forResource: "MusicaFundo", withExtension: "mp3") {
                do {
                    let novoPlayer = try AVAudioPlayer(contentsOf: url)
                    novoPlayer.numberOfLoops = -1   // repete para sempre
                    novoPlayer.volume = Self.volumeDaMusica
                    novoPlayer.prepareToPlay()
                    player = novoPlayer
                } catch {
                    log.error("Erro ao carregar MusicaFundo.mp3: \(error.localizedDescription)")
                }
            } else {
                log.warning("Não achei MusicaFundo.mp3 no bundle do app")
            }
        }
        player?.play()
    }

    func pararMusica() {
        deveTocar = false
        player?.pause()
    }

    // App em segundo plano, vela apagou, acabou ou foi descartada
    func pararTudo() {
        pararMusica()
        pavio.parar()
    }
}

// MARK: - Pavio queimando

/// O pavio queimando ao fundo, em loop sem emenda: o fim do áudio se mistura com o começo
/// (o mesmo jeito do som do risco do fósforo). Entra e sai devagar, e fica mais baixo
/// quando a caixa está afastada (teatro de sombras), como se a vela estivesse longe.
final class SomDoPavio {
    // ⚙️ Volume com a vela perto (dentro da caixa) e longe (teatro de sombras)
    static let volumePerto: Float = 0.15
    static let volumeLonge: Float = 0.06
    // ⚙️ Tempo para o volume mudar ao afastar/aproximar, entrar e sair (segundos)
    static let duracaoDaRampa: Double = 0.6
    static let duracaoDaEntrada: Double = 1.0
    static let duracaoDaSaida: Double = 0.4
    // ⚙️ Emenda do loop: o fim se mistura com o começo por este tempo (segundos)
    static let duracaoDaEmenda: Double = 1.5

    private let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "AdaLovelace", category: "SomDoPavio")
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var buffer: AVAudioPCMBuffer?
    private var carregando = false
    private var deveTocar = false
    private var volumeAlvo: Float = volumePerto
    private var rampa: Task<Void, Never>?
    private var observadorDeConfiguracao: NSObjectProtocol?

    init() {
        engine.attach(player)
        // O sistema pode reiniciar o áudio (o sopro liga o microfone, fone conectado…): religa
        observadorDeConfiguracao = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.religar() }
        }
    }

    deinit {
        if let observadorDeConfiguracao {
            NotificationCenter.default.removeObserver(observadorDeConfiguracao)
        }
    }

    /// Começa a tocar (ou só muda o volume, se já está tocando).
    func tocar(longe: Bool) {
        volumeAlvo = longe ? Self.volumeLonge : Self.volumePerto
        if deveTocar {
            rampa(para: volumeAlvo, duracao: Self.duracaoDaRampa)
            return
        }
        deveTocar = true
        if let buffer { comecar(buffer) } else { carregar() }
    }

    func parar() {
        guard deveTocar else { return }
        deveTocar = false
        rampa(para: 0, duracao: Self.duracaoDaSaida) { [weak self] in
            guard let self, !self.deveTocar else { return }
            self.player.stop()
            self.engine.stop()
        }
    }

    /// Depois de uma interrupção ou de o sistema reiniciar o áudio
    func religar() {
        guard deveTocar, let buffer else { return }
        player.stop()
        comecar(buffer)
    }

    // Lê e prepara o loop fora da thread principal (são 94 s de áudio)
    private func carregar() {
        guard !carregando else { return }
        guard let url = Bundle.main.url(forResource: "FirePlace", withExtension: "m4a") else {
            log.warning("Não achei FirePlace.m4a no bundle do app")
            return
        }
        carregando = true
        let emenda = Self.duracaoDaEmenda
        Task.detached(priority: .utility) { [weak self] in
            let loop = PreparoDeAudio.lerLoop(url, emenda: emenda)
            await self?.montar(loop)
        }
    }

    private func montar(_ loop: (amostras: [Float], taxa: Double)?) {
        carregando = false
        guard let loop, !loop.amostras.isEmpty,
              let formato = AVAudioFormat(standardFormatWithSampleRate: loop.taxa, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: formato, frameCapacity: AVAudioFrameCount(loop.amostras.count)),
              let canal = buffer.floatChannelData?[0] else {
            log.error("Não consegui preparar o loop do pavio")
            return
        }
        buffer.frameLength = AVAudioFrameCount(loop.amostras.count)
        loop.amostras.withUnsafeBufferPointer { origem in
            if let base = origem.baseAddress { canal.update(from: base, count: origem.count) }
        }
        engine.connect(player, to: engine.mainMixerNode, format: formato)
        self.buffer = buffer
        if deveTocar { comecar(buffer) }
    }

    private func comecar(_ buffer: AVAudioPCMBuffer) {
        do {
            if !engine.isRunning { try engine.start() }
        } catch {
            log.error("Erro ao ligar o som do pavio: \(error.localizedDescription)")
            return
        }
        if !player.isPlaying {
            player.volume = 0
            player.scheduleBuffer(buffer, at: nil, options: .loops)
            player.play()
        }
        rampa(para: volumeAlvo, duracao: Self.duracaoDaEntrada)
    }

    // O volume anda em linha reta até o alvo (de 20 em 20 ms)
    private func rampa(para alvo: Float, duracao: Double, depois: (() -> Void)? = nil) {
        rampa?.cancel()
        let inicio = player.volume
        let passos = max(1, Int(duracao / 0.02))
        rampa = Task { [weak self] in
            for i in 1...passos {
                try? await Task.sleep(for: .seconds(0.02))
                guard !Task.isCancelled, let self else { return }
                self.player.volume = inicio + (alvo - inicio) * Float(i) / Float(passos)
            }
            depois?()
        }
    }
}

// MARK: - Preparar áudio em loop

/// Ferramentas para ler um áudio e fazer o loop sem estalo na emenda.
/// Usadas pelo som do risco do fósforo (Haptics.swift) e pelo pavio.
nonisolated enum PreparoDeAudio {
    static func lerEmMono(_ arquivo: AVAudioFile) -> [Float]? {
        let quadros = AVAudioFrameCount(arquivo.length)
        guard quadros > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: arquivo.processingFormat, frameCapacity: quadros),
              (try? arquivo.read(into: buffer)) != nil,
              let canais = buffer.floatChannelData else { return nil }
        let n = Int(buffer.frameLength)
        let numeroDeCanais = Int(buffer.format.channelCount)
        var mono = [Float](repeating: 0, count: n)
        for canal in 0..<numeroDeCanais {
            let dados = canais[canal]
            for i in 0..<n { mono[i] += dados[i] / Float(numeroDeCanais) }
        }
        return mono
    }

    // O fim do áudio entra no começo com um cruzamento suave (mesma potência),
    // assim o loop não tem estalo nem buraco na emenda.
    static func fazerLoop(_ amostras: [Float], emenda: Int) -> [Float] {
        let n = amostras.count
        let x = min(emenda, n / 4)
        guard x > 0 else { return amostras }
        var saida = Array(amostras[0..<(n - x)])
        for i in 0..<x {
            let t = Float(i) / Float(x)
            let entra = sin(t * .pi / 2)
            let sai = cos(t * .pi / 2)
            saida[i] = amostras[i] * entra + amostras[n - x + i] * sai
        }
        return saida
    }

    /// Lê o arquivo inteiro em mono e já devolve o loop pronto. emenda: em segundos.
    static func lerLoop(_ url: URL, emenda: Double) -> (amostras: [Float], taxa: Double)? {
        guard let arquivo = try? AVAudioFile(forReading: url),
              let mono = lerEmMono(arquivo) else { return nil }
        let taxa = arquivo.processingFormat.sampleRate
        return (fazerLoop(mono, emenda: Int(emenda * taxa)), taxa)
    }
}
