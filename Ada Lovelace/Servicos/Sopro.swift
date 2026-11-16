//  Detecta sopros pelo microfone usando o filtro do TestesVela.
//
//  O microfone segue a chama: com a chama na parte de cima da tela, o app ouve pelo
//  microfone de cima do iPhone. Quando a vela derrete e a chama passa para a parte de baixo
//  (ou a vela está na caixa do teatro de sombras), ele troca para o microfone de baixo.
//  Assim o sopro, que vai na direção da chama, cai no microfone mais perto dela.

import AVFoundation
import Foundation
import OSLog
import UIKit

@MainActor
final class Sopro {

    // ⚙️ Altura da tela onde o microfone troca: 0 = embaixo, 1 = em cima.
    static let alturaDaTroca = 0.5

    // ⚙️ Folga em volta da troca, para o microfone não ficar trocando com a chama bem no meio.
    static let folgaDaTroca = 0.05

    private enum Lado { case cima, baixo }

    private let sessaoAudio = AVAudioSession.sharedInstance()
    private let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "AdaLovelace", category: "Sopro")
    private var motor: AVAudioEngine?
    private var analisador: AnalisadorSopro?
    private var fonteIDAtiva: Int?
    private var ignorarMudancaConfiguracao = false
    private var observador: NSObjectProtocol?
    private var categoriaAnterior: (AVAudioSession.Category, AVAudioSession.Mode, AVAudioSession.CategoryOptions)?
    private var fonteAnterior: (AVAudioSessionPortDescription, AVAudioSessionDataSourceDescription?)?
    private var capturaID: UUID?
    private var solicitandoPermissao = false
    private var aoSoprar: (() -> Void)?
    private var tempoSoprando = 0.0
    private var tempoQuieto = 0.0
    private var lado = Lado.cima

    // Onde a chama está na tela (0 = embaixo, 1 = em cima). Quem sabe é a PalcoView.
    // Se o lado mudar com o microfone ligado, ele troca para a cápsula nova sem derrubar a sessão de áudio.
    var alturaDaChama = 1.0 {
        didSet {
            // No iPad a tela fica deitada: "em cima" da tela não é onde ficam os microfones de cima
            guard UIDevice.current.userInterfaceIdiom == .phone else { return }
            let novo: Lado
            switch lado {
            case .cima:  novo = alturaDaChama < Sopro.alturaDaTroca - Sopro.folgaDaTroca ? .baixo : .cima
            case .baixo: novo = alturaDaChama > Sopro.alturaDaTroca + Sopro.folgaDaTroca ? .cima : .baixo
            }
            guard novo != lado else { return }
            lado = novo
            log.info("Chama a \(Int(self.alturaDaChama * 100))% da tela: microfone de \(novo == .cima ? "cima" : "baixo").")
            if capturaID != nil {
                trocarCapsulaAtiva()
            }
        }
    }

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
        pararCaptura(restaurarSessao: true)
    }

    private func escolherFonte(em microfone: AVAudioSessionPortDescription) -> (Lado, AVAudioSessionDataSourceDescription)? {
        let ladoAlternativo: Lado = lado == .cima ? .baixo : .cima
        if let preferido = fonte(lado, em: microfone) {
            return (lado, preferido)
        } else if let alternativo = fonte(ladoAlternativo, em: microfone) {
            return (ladoAlternativo, alternativo)
        }
        return nil
    }

    private func trocarCapsulaAtiva() {
        guard let microfone = sessaoAudio.availableInputs?.first(where: { $0.portType == .builtInMic }),
              let (ladoEscolhido, escolhido) = escolherFonte(em: microfone) else {
            return
        }
        do {
            ignorarMudancaConfiguracao = true
            defer { ignorarMudancaConfiguracao = false }
            if escolhido.supportedPolarPatterns?.contains(.omnidirectional) == true {
                try escolhido.setPreferredPolarPattern(.omnidirectional)
            }
            try microfone.setPreferredDataSource(escolhido)
            fonteIDAtiva = escolhido.dataSourceID.intValue
            analisador?.definirLimiteDB(ladoEscolhido == .baixo ? -36.0 : -30.0)
            log.info("Ouvindo o sopro pelo microfone \(escolhido.dataSourceName, privacy: .public).")
        } catch {
            log.warning("Reiniciando captura para concluir troca de cápsula: \(error.localizedDescription)")
            pararCaptura(restaurarSessao: false)
            iniciarCaptura()
        }
    }

    private func iniciarCaptura() {
        let id = UUID()
        capturaID = id
        tempoSoprando = 0
        tempoQuieto = 0
        if categoriaAnterior == nil {
            categoriaAnterior = (sessaoAudio.category, sessaoAudio.mode, sessaoAudio.categoryOptions)
        }

        do {
            // O modo measurement preserva o vento que bate no microfone.
            try sessaoAudio.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .mixWithOthers])
            try sessaoAudio.setAllowHapticsAndSystemSoundsDuringRecording(true)
            try sessaoAudio.setActive(true)

            // Se o aparelho não tiver o microfone do lado da chama, usa o do outro lado
            guard let microfone = sessaoAudio.availableInputs?.first(where: { $0.portType == .builtInMic }),
                  let (ladoEscolhido, escolhido) = escolherFonte(em: microfone) else {
                log.notice("Nenhum microfone embutido disponível para detectar sopro.")
                pararCaptura(restaurarSessao: true)
                return
            }

            if fonteAnterior == nil {
                fonteAnterior = (microfone, microfone.preferredDataSource)
            }
            if escolhido.supportedPolarPatterns?.contains(.omnidirectional) == true {
                try escolhido.setPreferredPolarPattern(.omnidirectional)
            }
            try microfone.setPreferredDataSource(escolhido)
            try sessaoAudio.setPreferredInput(microfone)
            try sessaoAudio.setPreferredInputNumberOfChannels(1)
            fonteIDAtiva = escolhido.dataSourceID.intValue
            log.info("Ouvindo o sopro pelo microfone \(escolhido.dataSourceName, privacy: .public).")

            let motor = AVAudioEngine()
            let entrada = motor.inputNode
            let formato = entrada.outputFormat(forBus: 0)
            guard formato.sampleRate > 0, formato.channelCount >= 1 else {
                log.warning("Formato de áudio inválido na entrada (taxa: \(formato.sampleRate), canais: \(formato.channelCount)).")
                pararCaptura(restaurarSessao: true)
                return
            }

            let limiteDB = ladoEscolhido == .baixo ? -36.0 : -30.0
            let analisador = AnalisadorSopro(
                taxa: formato.sampleRate,
                canais: Int(formato.channelCount),
                limiteDB: limiteDB
            )
            self.analisador = analisador
            entrada.installTap(onBus: 0, bufferSize: 1024, format: formato,
                               block: analisador.blocoDoTap { [weak self] detectou, duracao in
                Task { @MainActor [weak self] in
                    guard let self, self.capturaID == id else { return }
                    let entradaAtiva = self.sessaoAudio.currentRoute.inputs.first
                    let usaMicrofoneEscolhido = entradaAtiva?.portType == .builtInMic
                        && (self.fonteIDAtiva == nil || entradaAtiva?.selectedDataSource?.dataSourceID.intValue == self.fonteIDAtiva)
                    self.receber(detectou && usaMicrofoneEscolhido, duracao: duracao)
                }
            })
            self.motor = motor
            try motor.start()

            observador = NotificationCenter.default.addObserver(
                forName: .AVAudioEngineConfigurationChange, object: motor, queue: nil
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self, self.capturaID == id, self.aoSoprar != nil, !self.ignorarMudancaConfiguracao else { return }
                    self.pararCaptura(restaurarSessao: false)
                    self.iniciarCaptura()
                }
            }
        } catch {
            pararCaptura(restaurarSessao: true)
            log.error("Falha ao iniciar o microfone: \(error.localizedDescription)")
        }
    }

    private func pararCaptura(restaurarSessao: Bool = true) {
        capturaID = nil
        fonteIDAtiva = nil
        analisador = nil
        if let observador {
            NotificationCenter.default.removeObserver(observador)
            self.observador = nil
        }
        motor?.stop()
        motor?.inputNode.removeTap(onBus: 0)
        motor = nil

        guard restaurarSessao else { return }

        if let (microfone, fonte) = fonteAnterior {
            try? microfone.setPreferredDataSource(fonte)
            fonteAnterior = nil
        }
        if let (categoria, modo, opcoes) = categoriaAnterior {
            try? sessaoAudio.setCategory(categoria, mode: modo, options: opcoes)
            categoriaAnterior = nil
        }
    }

    // Cima: o microfone do alto, do lado da tela (perto do alto-falante de ligação).
    // Baixo: o microfone do lado do conector.
    private func fonte(_ lado: Lado, em microfone: AVAudioSessionPortDescription) -> AVAudioSessionDataSourceDescription? {
        let fontes = microfone.dataSources ?? []
        switch lado {
        case .cima:
            return fontes.first { $0.location == .upper && $0.orientation == .front }
                ?? fontes.first { $0.orientation == .top }
        case .baixo:
            return fontes.first { $0.orientation == .bottom }
                ?? fontes.first { $0.location == .lower }
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

        if tempoSoprando >= 0.15 {
            tempoSoprando = 0
            tempoQuieto = 0
            aoSoprar?()
        }
    }
}

private nonisolated final class AnalisadorSopro: @unchecked Sendable {
    private let taxa: Double
    private let coeficiente: Float
    private let lock = NSLock()
    private var limiteDB: Float
    // O estado do filtro é usado apenas pelo tap de áudio, um valor por canal.
    private var filtro: [Float]

    init(taxa: Double, canais: Int, limiteDB: Double) {
        let taxaSegura = max(1, taxa)
        self.taxa = taxaSegura
        coeficiente = Float(exp(-2 * Double.pi * 300 / taxaSegura))
        self.limiteDB = Float(limiteDB)
        filtro = Array(repeating: 0, count: max(1, canais))
    }

    func definirLimiteDB(_ novoLimite: Double) {
        lock.lock()
        limiteDB = Float(novoLimite)
        lock.unlock()
    }

    func blocoDoTap(_ entregar: @escaping @Sendable (Bool, Double) -> Void) -> AVAudioNodeTapBlock {
        { [self] buffer, _ in
            guard let dados = buffer.floatChannelData, buffer.frameLength > 0, taxa > 0 else { return }
            let quadros = Int(buffer.frameLength)
            let canaisDisponiveis = min(filtro.count, Int(buffer.format.channelCount))
            guard canaisDisponiveis > 0 else { return }

            lock.lock()
            let limiteAtual = limiteDB
            lock.unlock()

            var detectou = false

            for canal in 0..<canaisDisponiveis {
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
                if db >= limiteAtual, proporcaoGrave > 0.45 { detectou = true }
            }

            entregar(detectou, Double(quadros) / taxa)
        }
    }
}
