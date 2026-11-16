//  Detecta sopros pelo microfone superior usando o filtro do TestesVela.

import AVFoundation
import Foundation
import OSLog

@MainActor
final class Sopro {
    private let sessaoAudio = AVAudioSession.sharedInstance()
    private let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "AdaLovelace", category: "Sopro")
    private var motor: AVAudioEngine?
    private var observador: NSObjectProtocol?
    private var categoriaAnterior: (AVAudioSession.Category, AVAudioSession.Mode, AVAudioSession.CategoryOptions)?
    private var fonteAnterior: (AVAudioSessionPortDescription, AVAudioSessionDataSourceDescription?)?
    private var capturaID: UUID?
    private var solicitandoPermissao = false
    private var aoSoprar: (() -> Void)?
    private var tempoSoprando = 0.0
    private var tempoQuieto = 0.0

    func iniciar(aoSoprar: @escaping () -> Void) {
        self.aoSoprar = aoSoprar
        guard capturaID == nil, !solicitandoPermissao else { return }

        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            iniciarCaptura()
        case .undetermined:
            solicitandoPermissao = true
            Task { [weak self] in
                let permitiu = await AVAudioApplication.requestRecordPermission()
                guard let self else { return }
                solicitandoPermissao = false
                if permitiu, self.aoSoprar != nil { iniciarCaptura() }
            }
        default:
            break
        }
    }

    func parar() {
        aoSoprar = nil
        pararCaptura()
    }

    private func iniciarCaptura() {
        let id = UUID()
        capturaID = id
        tempoSoprando = 0
        tempoQuieto = 0
        categoriaAnterior = (sessaoAudio.category, sessaoAudio.mode, sessaoAudio.categoryOptions)

        do {
            // O modo measurement preserva o vento que bate no microfone.
            try sessaoAudio.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .mixWithOthers])
            try sessaoAudio.setAllowHapticsAndSystemSoundsDuringRecording(true)
            try sessaoAudio.setActive(true)

            guard let microfone = sessaoAudio.availableInputs?.first(where: { $0.portType == .builtInMic }),
                  let superior = microfone.dataSources?.first(where: {
                      $0.location == .upper && $0.orientation == .front
                  }) ?? microfone.dataSources?.first(where: { $0.orientation == .top }) else {
                log.notice("Microfone superior indisponível para detectar sopro.")
                pararCaptura()
                return
            }

            fonteAnterior = (microfone, microfone.preferredDataSource)
            if superior.supportedPolarPatterns?.contains(.omnidirectional) == true {
                try superior.setPreferredPolarPattern(.omnidirectional)
            }
            try microfone.setPreferredDataSource(superior)
            try sessaoAudio.setPreferredInput(microfone)
            try sessaoAudio.setPreferredInputNumberOfChannels(1)
            let fonteID = superior.dataSourceID.intValue

            let motor = AVAudioEngine()
            let entrada = motor.inputNode
            let formato = entrada.outputFormat(forBus: 0)
            guard formato.sampleRate > 0, formato.channelCount == 1 else {
                pararCaptura()
                return
            }

            let analisador = AnalisadorSopro(taxa: formato.sampleRate, canais: Int(formato.channelCount))
            entrada.installTap(onBus: 0, bufferSize: 1024, format: formato,
                               block: analisador.blocoDoTap { [weak self] detectou, duracao in
                Task { @MainActor [weak self] in
                    guard let self, self.capturaID == id else { return }
                    let entradaAtiva = self.sessaoAudio.currentRoute.inputs.first
                    let usaMicrofoneSuperior = entradaAtiva?.portType == .builtInMic
                        && entradaAtiva?.selectedDataSource?.dataSourceID.intValue == fonteID
                    self.receber(detectou && usaMicrofoneSuperior, duracao: duracao)
                }
            })
            self.motor = motor
            try motor.start()

            observador = NotificationCenter.default.addObserver(
                forName: .AVAudioEngineConfigurationChange, object: motor, queue: nil
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self, self.capturaID == id, self.aoSoprar != nil else { return }
                    self.pararCaptura()
                    self.iniciarCaptura()
                }
            }
        } catch {
            pararCaptura()
            log.error("Falha ao iniciar o microfone: \(error.localizedDescription)")
        }
    }

    private func pararCaptura() {
        capturaID = nil
        if let observador {
            NotificationCenter.default.removeObserver(observador)
            self.observador = nil
        }
        motor?.stop()
        motor?.inputNode.removeTap(onBus: 0)
        motor = nil

        if let (microfone, fonte) = fonteAnterior {
            try? microfone.setPreferredDataSource(fonte)
            fonteAnterior = nil
        }
        if let (categoria, modo, opcoes) = categoriaAnterior {
            try? sessaoAudio.setCategory(categoria, mode: modo, options: opcoes)
            categoriaAnterior = nil
        }
    }

    private func receber(_ detectou: Bool, duracao: Double) {
        if detectou {
            tempoQuieto = 0
            tempoSoprando += duracao
        } else {
            tempoQuieto += duracao
            if tempoQuieto > 0.08 { tempoSoprando = 0 }
        }

        if tempoSoprando >= 0.15 { aoSoprar?() }
    }
}

private nonisolated final class AnalisadorSopro: @unchecked Sendable {
    private let taxa: Double
    private let coeficiente: Float
    // O estado do filtro é usado apenas pelo tap de áudio, um valor por canal.
    private var filtro: [Float]

    init(taxa: Double, canais: Int) {
        self.taxa = taxa
        coeficiente = Float(exp(-2 * Double.pi * 300 / taxa))
        filtro = Array(repeating: 0, count: canais)
    }

    func blocoDoTap(_ entregar: @escaping @Sendable (Bool, Double) -> Void) -> AVAudioNodeTapBlock {
        { [self] buffer, _ in
            guard let dados = buffer.floatChannelData, buffer.frameLength > 0 else { return }
            let quadros = Int(buffer.frameLength)
            var detectou = false

            for canal in filtro.indices {
                let amostras = dados[canal]
                var grave = filtro[canal]
                var energia: Float = 0
                var energiaGrave: Float = 0
                for quadro in 0..<quadros {
                    let amostra = amostras[quadro * buffer.stride]
                    grave = (1 - coeficiente) * amostra + coeficiente * grave
                    energia += amostra * amostra
                    energiaGrave += grave * grave
                }
                filtro[canal] = grave
                let rms = (energia / Float(quadros)).squareRoot()
                let db = 20 * log10(max(rms, 0.000_001))
                let proporcaoGrave = energia > 0 ? (energiaGrave / energia).squareRoot() : 0
                if db >= -30, proporcaoGrave > 0.45 { detectou = true }
            }

            entregar(detectou, Double(quadros) / taxa)
        }
    }
}
