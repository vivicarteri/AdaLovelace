//  Sessao.swift
//  O "cérebro" do app: estado da vela, tempo queimando, alfinetes caindo,
//  movimento do celular, vibrações e salvar tudo para quando o app abrir de novo.

import SwiftUI
import Combine

enum EstadoVela: String, Codable {
    case nova      // vela inteira, ainda não acesa (home)
    case acesa
    case apagada   // apagou antes de acabar (virou o celular). Acender continua de onde parou.
    case acabou
}

enum Chaves {
    static let viuOnboarding = "viuOnboarding"
    static let somAmbiente = "somAmbiente"
    static let sessaoSalva = "sessaoSalva"
}

final class Sessao: ObservableObject {

    // ⚙️ Para testar rápido: 60 = cada minuto da vela dura 1 segundo. Voltem para 1 antes de entregar!
    static let velocidadeDeTeste: Double = 1

    // ⚙️ Girar o celular faz a vela derreter mais rápido (regra de negócio).
    // 2 = bem inclinada derrete até 2x mais rápido. (Valor provisório: o time ainda vai decidir.)
    // 1 = girar não muda o tempo.
    static let aceleracaoAoGirar: Double = 2

    // MARK: Estado que as telas leem

    @Published var config = VelaConfig() { didSet { salvar() } }
    @Published private(set) var estado: EstadoVela = .nova
    @Published private(set) var progresso: Double = 0          // 0 = inteira, 1 = acabou
    @Published private(set) var caidos: Set<UUID> = []         // enfeites que já caíram
    @Published private(set) var apagouEm: Date?                // para desenhar a fumaça
    @Published var foraDaCaixa = false                         // true = teatro de sombras (zoom out)

    let movimento = Movimento()
    let haptics = Haptics()
    private let ambiente = SomAmbiente()

    // MARK: Tempo

    private var queimado: TimeInterval = 0     // quanto da vela já queimou (em segundos de vela)
    private var ultimoTique: Date?
    private var ultimoSalvo = Date.distantPast
    private var ativo = false
    private var observadores = Set<AnyCancellable>()
    private var relogio: AnyCancellable?      // o tique de 0,1 s: só existe com a vela acesa

    init() {
        carregar()

        // Celular de cabeça para baixo → a vela apaga.
        // Desvirar NÃO acende de novo: a pessoa precisa acender com o fósforo.
        movimento.$invertido
            .removeDuplicates()
            .sink { [weak self] invertido in
                if invertido { self?.apagar() }
            }
            .store(in: &observadores)
    }

    // O relógio só roda com o app na tela E a vela acesa.
    // Assim o app não acorda 10 vezes por segundo à toa (bateria).
    private func atualizarRelogio() {
        let precisa = ativo && estado == .acesa
        if precisa {
            guard relogio == nil else { return }
            relogio = Timer.publish(every: 0.1, on: .main, in: .common)
                .autoconnect()
                .sink { [weak self] _ in self?.tique() }
        } else if let velho = relogio {
            relogio = nil
            // Solta o relógio só no instante seguinte: quem desliga o relógio pode ser
            // o próprio tique (quando a vela acaba), e ele não pode sumir no meio do caminho.
            DispatchQueue.main.async { velho.cancel() }
        }
    }

    // MARK: Ações

    func acender() {
        guard estado == .nova || estado == .apagada else { return }
        estado = .acesa
        apagouEm = nil
        ultimoTique = Date()
        haptics.acender()
        haptics.iniciarChama()
        if somAmbienteLigado { ambiente.tocar() }
        anunciar("Vela acesa")
        atualizarRelogio()
        salvar()
    }

    func apagar() {
        guard estado == .acesa else { return }
        tique()                       // guarda o tempo que queimou até agora
        guard estado == .acesa else { return }   // pode ter acabado nesse último tique
        estado = .apagada
        ultimoTique = nil
        apagouEm = Date()
        haptics.pararChama()
        haptics.apagar()
        ambiente.parar()
        anunciar("Vela apagada. Para continuar, acenda de novo.")
        atualizarRelogio()
        salvar()
    }

    // Joga a vela fora e coloca uma vela nova, no tamanho padrão e sem enfeites
    func descartar() {
        haptics.pararChama()
        ambiente.parar()
        estado = .nova
        queimado = 0
        progresso = 0
        caidos = []
        ultimoTique = nil
        apagouEm = nil
        foraDaCaixa = false
        config = VelaConfig()         // vela padrão do início do app (também salva)
        atualizarRelogio()
        anunciar("Vela nova")
    }

    // MARK: Ciclo do app (aberto, em segundo plano…)

    func mudouFase(_ fase: ScenePhase) {
        switch fase {
        case .active:
            guard !ativo else { return }
            ativo = true
            movimento.iniciar()
            haptics.ligarMotor()
            tique()                   // conta o tempo que passou com o app fechado
            if estado == .acesa {
                haptics.iniciarChama()
                if somAmbienteLigado { ambiente.tocar() }
            }
            atualizarRelogio()
        case .background:
            ativo = false
            atualizarRelogio()
            tique()
            salvar()
            movimento.parar()
            ambiente.parar()
            haptics.desligarMotor()
        default:
            break
        }
    }

    // Chamado quando a pessoa liga ou desliga o som ambiente nas Configurações
    func atualizarAmbiente() {
        if estado == .acesa && somAmbienteLigado { ambiente.tocar() } else { ambiente.parar() }
    }

    private var somAmbienteLigado: Bool {
        UserDefaults.standard.object(forKey: Chaves.somAmbiente) as? Bool ?? true
    }

    // MARK: Relógio

    // O tempo é somado a cada tique pela diferença de datas, e não contando tiques.
    // Assim a vela continua certa mesmo se o app travar ou ficar fechado.
    private func tique() {
        guard estado == .acesa, let ultimo = ultimoTique else { return }
        let agora = Date()
        let fator = 1 + (Sessao.aceleracaoAoGirar - 1) * movimento.inclinacao
        queimado += agora.timeIntervalSince(ultimo) * Sessao.velocidadeDeTeste * fator
        ultimoTique = agora

        haptics.atualizarChama(inclinacao: Float(movimento.inclinacao))
        atualizarProgresso(comSom: true)

        if agora.timeIntervalSince(ultimoSalvo) > 2 { salvar() }
    }

    private func atualizarProgresso(comSom: Bool) {
        progresso = min(1, queimado / config.duracao)

        // Um enfeite cai quando a cera chega na altura dele
        let topoDaCera = 1 - progresso
        let novos = config.enfeites.filter { !caidos.contains($0.id) && $0.altura >= topoDaCera }
        if !novos.isEmpty {
            caidos.formUnion(novos.map(\.id))
            if comSom, let maisAlto = novos.map(\.altura).max() {
                // Vela grande + enfeite alto = cai de mais alto = som e batida mais fortes
                let forca = maisAlto * (0.5 + 0.5 * config.posicaoSlider)
                haptics.prego(forca: Float(forca))
            }
        }

        if progresso >= 1 { terminar(comSom: comSom) }
    }

    private func terminar(comSom: Bool) {
        guard estado != .acabou else { return }
        estado = .acabou
        ultimoTique = nil
        atualizarRelogio()
        // Se estava nas sombras, a tela (PalcoView) entra na caixa com a animação da cortina
        haptics.pararChama()
        ambiente.parar()
        if comSom {
            haptics.fim()
            anunciar("A vela acabou")
        }
        salvar()
    }

    private func anunciar(_ texto: String) {
        AccessibilityNotification.Announcement(texto).post()
    }

    // MARK: Salvar e carregar

    private struct Salvo: Codable {
        var config: VelaConfig
        var estado: EstadoVela
        var queimado: TimeInterval
        var ultimoTique: Date?
        var caidos: [UUID]
    }

    private func salvar() {
        ultimoSalvo = Date()
        let salvo = Salvo(config: config, estado: estado, queimado: queimado,
                          ultimoTique: ultimoTique, caidos: Array(caidos))
        if let dados = try? JSONEncoder().encode(salvo) {
            UserDefaults.standard.set(dados, forKey: Chaves.sessaoSalva)
        }
    }

    private func carregar() {
        guard let dados = UserDefaults.standard.data(forKey: Chaves.sessaoSalva),
              let salvo = try? JSONDecoder().decode(Salvo.self, from: dados) else { return }
        config = salvo.config
        estado = salvo.estado
        queimado = salvo.queimado
        caidos = Set(salvo.caidos)

        // Se a vela ficou acesa com o app fechado, ela continuou queimando
        if estado == .acesa, let antes = salvo.ultimoTique {
            queimado += Date().timeIntervalSince(antes) * Sessao.velocidadeDeTeste
            ultimoTique = Date()
        }
        progresso = min(1, queimado / config.duracao)
        let topoDaCera = 1 - progresso
        caidos.formUnion(config.enfeites.filter { $0.altura >= topoDaCera }.map(\.id))
        if progresso >= 1 && estado == .acesa {
            estado = .acabou
            ultimoTique = nil
        }
        if estado == .apagada { apagouEm = .distantPast }
    }
}
