//  SomAmbiente.swift
//  Som de fundo em loop enquanto a vela está acesa.
//
//  Para funcionar, coloquem um arquivo chamado "Ambiente" (.m4a, .mp3 ou .wav)
//  na pasta Recursos. Enquanto não tiver arquivo, o app fica em silêncio.

import Foundation
import AVFoundation

final class SomAmbiente {
    private var player: AVAudioPlayer?

    func tocar() {
        if player == nil {
            for extensao in ["m4a", "mp3", "wav"] {
                if let url = Bundle.main.url(forResource: "Ambiente", withExtension: extensao) {
                    player = try? AVAudioPlayer(contentsOf: url)
                    player?.numberOfLoops = -1   // repete para sempre
                    player?.volume = 0.5
                    break
                }
            }
        }
        player?.play()
    }

    func parar() {
        player?.pause()
    }
}
