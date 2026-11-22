//  SomAmbiente.swift
//  Som de fundo em loop enquanto a vela está acesa.
//
//  Para funcionar, coloquem um arquivo chamado "Ambiente" (.m4a, .mp3 ou .wav)
//  na pasta Recursos. Enquanto não tiver arquivo, o app fica em silêncio.

import Foundation
import AVFoundation
import OSLog

final class SomAmbiente {
    private let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "AdaLovelace", category: "SomAmbiente")
    private var player: AVAudioPlayer?
    private var procurouArquivo = false
    private var deveTocar = false
    private var observadorInterrupcao: NSObjectProtocol?

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
                if tipo == .ended && self.deveTocar {
                    self.player?.play()
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

    func tocar() {
        deveTocar = true
        if player == nil && !procurouArquivo {
            procurouArquivo = true
            for extensao in ["m4a", "mp3", "wav"] {
                if let url = Bundle.main.url(forResource: "Ambiente", withExtension: extensao) {
                    do {
                        let novoPlayer = try AVAudioPlayer(contentsOf: url)
                        novoPlayer.numberOfLoops = -1   // repete para sempre
                        novoPlayer.volume = 0.5
                        novoPlayer.prepareToPlay()
                        player = novoPlayer
                    } catch {
                        log.error("Erro ao carregar Ambiente.\(extensao, privacy: .public): \(error.localizedDescription)")
                    }
                    break
                }
            }
        }
        player?.play()
    }

    func parar() {
        deveTocar = false
        player?.pause()
    }
}
