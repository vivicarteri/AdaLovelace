import Foundation
import OSLog

#if os(iOS)
import CoreHaptics
import AVFoundation

// MARK: - Som do fósforo raspando na lixa

/// Atrito do fósforo na lixa (Riscando.m4a) tocando em loop, sem emenda.
/// O áudio NUNCA é esticado: só o volume acompanha a velocidade do dedo,
/// e o som entra e sai com um fade de 20 ms (parar o dedo = silêncio quase na hora).
private final class SomRiscoFosforo {
    // ⚙️ O arquivo original é muito baixo: ele é normalizado até este pico (0 a 1).
    static let picoDesejado: Float = 0.5
    // ⚙️ Fade de entrada e saída
    static let duracaoDoFade: Double = 0.02
    // ⚙️ Emenda do loop: o fim do áudio se mistura com o começo por este tempo
    static let duracaoDaEmenda: Double = 0.04

    private let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "AdaLovelace", category: "SomRiscoFosforo")
    private let engine = AVAudioEngine()
    private var loop: LoopDoRisco?

    /// Duração do arquivo original. É o tempo que a pessoa tem para riscar a distância mínima.
    private(set) var duracao: TimeInterval = 0

    init() {
        guard let url = Bundle.main.url(forResource: "Riscando", withExtension: "m4a") else {
            log.warning("Não achei Riscando.m4a no bundle do app")
            return
        }
        do {
            let arquivo = try AVAudioFile(forReading: url)
            let taxa = arquivo.processingFormat.sampleRate
            guard let mono = Self.lerEmMono(arquivo) else { return }
            duracao = Double(mono.count) / taxa
            let amostras = Self.fazerLoop(Self.normalizar(mono), emenda: Int(Self.duracaoDaEmenda * taxa))
            let loop = LoopDoRisco(amostras: amostras, passoDoFade: Float(1 / (Self.duracaoDoFade * taxa)))
            guard let formato = AVAudioFormat(standardFormatWithSampleRate: taxa, channels: 1) else { return }
            let fonte = Self.criarFonte(loop)
            engine.attach(fonte)
            engine.connect(fonte, to: engine.mainMixerNode, format: formato)
            self.loop = loop
        } catch {
            log.error("Erro ao preparar Riscando.m4a: \(error.localizedDescription)")
        }
    }

    func preparar() {
        guard loop != nil, !engine.isRunning else { return }
        do {
            try engine.start()
        } catch {
            log.error("Erro ao ligar o som do risco: \(error.localizedDescription)")
        }
    }

    /// volume: 0 a 1. Muda com fade, então pode ser chamado a cada movimento do dedo.
    func tocar(volume: Float) {
        preparar()
        loop?.volumeAlvo = max(0, min(1, volume))
    }

    /// Fade de 20 ms até o silêncio. O loop continua de onde parou na próxima vez.
    func silenciar() {
        loop?.volumeAlvo = 0
    }

    /// Silencia e desliga o motor de áudio depois do fade (o fósforo saiu da lixa de vez).
    func desligar() {
        silenciar()
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(0.1))
            guard let self, (self.loop?.volumeAlvo ?? 0) == 0 else { return }
            self.engine.stop()
        }
    }

    // MARK: Preparar o áudio

    private static func lerEmMono(_ arquivo: AVAudioFile) -> [Float]? {
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

    private static func normalizar(_ amostras: [Float]) -> [Float] {
        let pico = amostras.reduce(0) { max($0, abs($1)) }
        guard pico > 0 else { return amostras }
        let ganho = picoDesejado / pico
        return amostras.map { $0 * ganho }
    }

    // O fim do áudio entra no começo com um cruzamento suave (mesma potência),
    // assim o loop não tem estalo nem buraco na emenda.
    private static func fazerLoop(_ amostras: [Float], emenda: Int) -> [Float] {
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

    // Fora do ator principal: este bloco roda na thread de áudio.
    private nonisolated static func criarFonte(_ loop: LoopDoRisco) -> AVAudioSourceNode {
        AVAudioSourceNode { silencio, _, quadros, listaDeBuffers in
            loop.preencher(quadros: Int(quadros), listaDeBuffers: listaDeBuffers, silencio: silencio)
        }
    }
}

/// As amostras do loop e o volume, lidos pela thread de áudio.
/// O volume muda em linha reta até o alvo (fade), amostra por amostra.
private nonisolated final class LoopDoRisco: @unchecked Sendable {
    private let amostras: [Float]
    private let passoDoFade: Float
    private var posicao = 0
    private var volume: Float = 0
    var volumeAlvo: Float = 0   // escrito pela tela, lido pela thread de áudio

    init(amostras: [Float], passoDoFade: Float) {
        self.amostras = amostras
        self.passoDoFade = passoDoFade
    }

    func preencher(quadros: Int, listaDeBuffers: UnsafeMutablePointer<AudioBufferList>,
                   silencio: UnsafeMutablePointer<ObjCBool>) -> OSStatus {
        let buffers = UnsafeMutableAudioBufferListPointer(listaDeBuffers)
        let alvo = volumeAlvo
        if volume == 0 && alvo == 0 {
            for buffer in buffers {
                if let dados = buffer.mData { memset(dados, 0, Int(buffer.mDataByteSize)) }
            }
            silencio.pointee = true
            return noErr
        }
        let total = amostras.count
        for quadro in 0..<quadros {
            if volume < alvo { volume = min(alvo, volume + passoDoFade) }
            else if volume > alvo { volume = max(alvo, volume - passoDoFade) }
            let valor = total > 0 ? amostras[posicao] * volume : 0
            if total > 0 { posicao = (posicao + 1) % total }
            for buffer in buffers {
                buffer.mData?.assumingMemoryBound(to: Float.self)[quadro] = valor
            }
        }
        return noErr
    }
}

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
    private let somRiscoFosforo = SomRiscoFosforo()

    init() {
        criarMotor()
    }

    // MARK: Motor

    private func criarMotor() {
        // .playback: o app toca mesmo com o iPhone no silencioso.
        // .mixWithOthers: o som do app não para a música da pessoa.
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
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

    // Interruptor "Sons do fósforo e da chama": riscar, o fósforo acendendo,
    // a chama da vela aparecendo e a chama apagando. As vibrações continuam sempre.
    private var volumeFosforoEChama: Float {
        Chaves.ligado(Chaves.somFosforoEChama) ? 1 : 0
    }

    // A chama da vela aparece. Ainda não tem som próprio: só a vibração.
    // Quando chegar um som, ele deve usar volumeFosforoEChama.
    func acender() { tocar("Acender", volume: 0) }

    func apagar() { tocar("Apagar", volume: volumeFosforoEChama) }

    func fim() { tocar("Fim") }

    // forca: 0 a 1 (enfeite mais alto = cai de mais alto = batida mais forte e som mais alto)
    func prego(forca: Float) {
        let f = max(0, min(1, forca))
        // Vibração mais forte que antes (pedido da mentora); o som vem do Prego.wav (Sofia)
        tocar("Prego", forca: 0.7 + 0.3 * f, volume: 0)
        tocarAudioDoPrego(forca: 0.4 + 0.6 * f)
    }

    // Enfeite que não encostou na vela e caiu no pote
    func caiuNoPote() {
        tocar("Prego", forca: 0.55, volume: 0)
        tocarAudioDoPrego(forca: 0.25)
    }

    // ⚙️ As batidas foram reforçadas (pedido da mentora: os haptics podiam ser mais intensos).
    // A vibração contínua da chama NÃO mudou (ela já tinha sido suavizada a pedido do time).
    // Batidinha (slider, encaixar enfeite…)
    func tique() { toque(forca: 0.7, nitidez: 0.55) }

    // MARK: Fósforo

    /// Duração do som de riscar. Riscar a distância mínima neste tempo (ou menos) acende o fósforo.
    var duracaoDoRisco: TimeInterval { somRiscoFosforo.duracao }

    func prepararSomRiscoFosforo() { somRiscoFosforo.preparar() }

    /// Atrito na lixa. volume: 0 a 1 (acompanha a velocidade do dedo).
    func tocarSomRiscoFosforo(volume: Float) {
        guard volumeFosforoEChama > 0 else { somRiscoFosforo.silenciar(); return }
        somRiscoFosforo.tocar(volume: volume)
    }

    /// O dedo parou ou saiu da lixa: o atrito some com fade de 20 ms.
    func silenciarSomRiscoFosforo() { somRiscoFosforo.silenciar() }

    /// O fósforo voltou para a caixa ou acendeu: silencia e desliga o motor de áudio.
    func cancelarSomRiscoFosforo() { somRiscoFosforo.desligar() }

    /// O fósforo acende: o padrão Acender, com a vibração e o som da chama pegando juntos.
    func acenderFosforo() {
        somRiscoFosforo.silenciar()
        tocar("Acender", volume: volumeFosforoEChama)
    }

    // ⚙️ Vibração do fósforo raspando na lixa: bem perceptível enquanto risca.
    // lentidao: 0 = na velocidade de acender (ou mais rápido), 1 = bem devagar.
    // Rápido = mais suave (força 0,65, um pouco mais nítida).
    // Devagar = mais forte e arrastada (força até 0,9, nitidez zero = batida grossa).
    func raspar(lentidao: Float = 0) {
        let l = max(0, min(1, lentidao))
        toque(forca: 0.65 + 0.25 * l, nitidez: 0.2 * (1 - l))
    }

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
    var duracaoDoRisco: TimeInterval { 0.68 }
    func prepararSomRiscoFosforo() {}
    func tocarSomRiscoFosforo(volume: Float) {}
    func silenciarSomRiscoFosforo() {}
    func cancelarSomRiscoFosforo() {}
    func acenderFosforo() {}
    func apagar() {}
    func fim() {}
    func prego(forca: Float) {}
    func caiuNoPote() {}
    func tique() {}
    func raspar(lentidao: Float = 0) {}
    func iniciarSegurar(duracao: TimeInterval) {}
    func cancelarSegurar() {}
    func iniciarChama() {}
    func atualizarChama(inclinacao: Float) {}
    func pararChama() {}
}

#endif
