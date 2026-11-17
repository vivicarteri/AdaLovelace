//  Sessao.swift
//  O "cérebro" do app: estado da vela, tempo queimando, alfinetes caindo,
//  movimento do celular, vibrações e salvar tudo para quando o app abrir de novo.

import SwiftUI
import Combine
import TipKit

// Jeitos de apagar a vela (para a dica "outro jeito de apagar").
enum JeitoDeApagar: String {
    case toque, virar, sopro
}

enum EstadoVela: String, Codable {
    case nova      // vela inteira, ainda não acesa (home)
    case acesa
    case apagada   // apagou antes de acabar (virou o celular). Acender continua de onde parou.
    case acabou
}

enum Chaves {
    static let viuOnboarding = "viuOnboarding"
    static let somAmbiente = "somAmbiente"
    static let apagarSoprando = "apagarSoprando"
    static let acelerarTempo = "acelerarTempo"            // só para teste (Configurações, rodando pelo Xcode)
    static let velocidadeDoTempo = "velocidadeDoTempo"    // 2 a 20: quantas vezes mais rápido
    static let sessaoSalva = "sessaoSalva"
    static let somObjetos = "somObjetos"          // sons dos alfinetes e penduricalhos caindo
    static let movimento = "movimentoLigado"      // Core Motion: inclinar e virar o aparelho
    static let resetarDicas = "resetarDicas"      // mostra as dicas de novo na próxima abertura

    // Lê uma chave de liga/desliga (quando nunca foi mexida, vale o padrão)
    static func ligado(_ chave: String, padrao: Bool = true) -> Bool {
        UserDefaults.standard.object(forKey: chave) as? Bool ?? padrao
    }
}

final class Sessao: ObservableObject {

    // ⚙️ Para testar rápido: nas Configurações dá para acelerar o tempo de 2x a 20x
    // (20x = cada minuto da vela dura 3 segundos). Isso só existe rodando pelo Xcode (Debug):
    // no app de verdade (Release) o tempo é sempre normal, então não tem como esquecer ligado.
    static var velocidadeDeTeste: Double {
        #if DEBUG
        let padrao = UserDefaults.standard
        guard padrao.bool(forKey: Chaves.acelerarTempo) else { return 1 }
        let escolhida = padrao.double(forKey: Chaves.velocidadeDoTempo)
        return min(20, max(2, escolhida == 0 ? 2 : escolhida))
        #else
        return 1
        #endif
    }

    static var velocidade: Double { velocidadeDeTeste }

    // ⚙️ Girar o celular faz a vela derreter mais rápido (regra de negócio).
    // 2 = bem inclinada derrete até 2x mais rápido. (Valor provisório: o time ainda vai decidir.)
    // 1 = girar não muda o tempo.
    static let aceleracaoAoGirar: Double = 2

    // ⚙️ Vibração da chama: com o aparelho parado por este tempo, a vibração "descansa"
    // (poupa bateria e esquenta menos). Ela volta no instante em que a pessoa mexe.
    static let descansoDaVibracao: TimeInterval = 15

    // ⚙️ Quanto a inclinação precisa mudar para valer a pena mandar um valor novo ao motor.
    static let mudancaMinimaDaChama: Double = 0.02

    // MARK: Estado que as telas leem

    @Published var config = VelaConfig() { didSet { salvar() } }
    @Published private(set) var estado: EstadoVela = .nova { didSet { atualizarSopro() } }
    @Published private(set) var progresso: Double = 0          // 0 = inteira, 1 = acabou
    @Published private(set) var caidos: Set<UUID> = []         // enfeites que já caíram
    @Published private(set) var apagouEm: Date?                // para desenhar a fumaça
    @Published var foraDaCaixa = false                         // true = teatro de sombras (zoom out)
    @Published private(set) var derretendoRapido = false       // a pessoa está segurando o Descartar

    // ⚙️ Segurando o Descartar, uma vela INTEIRA derrete em 4 segundos (uma pela metade, em 2).
    static let segundosParaDerreterTudo: Double = 4

    let movimento = Movimento()
    let haptics = Haptics()
    private let ambiente = SomAmbiente()
    private let sopro = Sopro()
    private var cenaAtiva = false

    // MARK: Tempo

    private var queimado: TimeInterval = 0     // quanto da vela já queimou (em segundos de vela)
    private var ultimoTique: Date?
    private var ultimoSalvo = Date.distantPast
    private var ativo = false
    private var observadores = Set<AnyCancellable>()
    private var relogio: AnyCancellable?      // o tique de 0,1 s: só existe com a vela acesa

    // MARK: Vibração da chama (controle de bateria)

    private var chamaVibrando = false                 // o loop da chama está tocando agora?
    private var ultimaInclinacaoEnviada: Double = -1  // último valor que o motor recebeu
    private var chamaLigadaEm = Date.distantPast      // acender também conta como "mexeu"

    init() {
        carregar()

        // Celular de cabeça para baixo → a vela apaga.
        // Desvirar NÃO acende de novo: a pessoa precisa acender com o fósforo.
        movimento.$invertido
            .removeDuplicates()
            .sink { [weak self] invertido in
                if invertido { self?.apagar(jeito: .virar) }
            }
            .store(in: &observadores)
    }

    // O relógio só roda com o app na tela E a vela acesa.
    // Assim o app não acorda 10 vezes por segundo à toa (bateria).
    private func atualizarRelogio() {
        let precisa = ativo && (estado == .acesa || (derretendoRapido && estado == .apagada))
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
        movimento.fixarReferencia()
        ligarVibracaoDaChama()
        if somAmbienteLigado { ambiente.tocar() }
        anunciar("Vela acesa")
        atualizarRelogio()
        salvar()
    }

    func apagar(jeito: JeitoDeApagar) {
        guard estado == .acesa else { return }
        contar(jeito)
        tique()                       // guarda o tempo que queimou até agora
        guard estado == .acesa else { return }   // pode ter acabado nesse último tique
        estado = .apagada
        // Se a pessoa está segurando o Descartar, a vela continua derretendo mesmo apagada
        ultimoTique = derretendoRapido ? Date() : nil
        apagouEm = Date()
        movimento.soltarReferencia()
        desligarVibracaoDaChama()
        haptics.apagar()
        ambiente.parar()
        anunciar("Vela apagada. Para continuar, acenda de novo.")
        atualizarRelogio()
        salvar()
    }
    
    // TipKit: 3 vezes seguidas do mesmo jeito → sugere outro jeito de apagar.
    // Quando a pessoa usa o jeito sugerido, a dica some de vez (aprendeu).
    private func contar(_ jeito: JeitoDeApagar) {
        let padrao = UserDefaults.standard
        let mesmo = padrao.string(forKey: "ultimoJeitoDeApagar") == jeito.rawValue
        let vezes = mesmo ? padrao.integer(forKey: "vezesDoMesmoJeito") + 1 : 1
        padrao.set(jeito.rawValue, forKey: "ultimoJeitoDeApagar")
        padrao.set(vezes, forKey: "vezesDoMesmoJeito")

        let sugerido: JeitoDeApagar? = DicaOutroJeitoDeApagar.sugestao == 1 ? .toque
            : DicaOutroJeitoDeApagar.sugestao == 2 ? .virar : nil
        if sugerido == jeito {
            DicaOutroJeitoDeApagar().invalidate(reason: .actionPerformed)
            DicaOutroJeitoDeApagar.sugestao = 0
        } else if vezes >= 3 {
            switch jeito {
            case .toque:
                // Só sugere virar se o movimento estiver ligado nas Configurações
                if movimentoLigado { DicaOutroJeitoDeApagar.sugestao = 2 }
            case .virar, .sopro:
                DicaOutroJeitoDeApagar.sugestao = 1
            }
        }
    }

    // DESCARTE CONTÍNUO (regra de negócio): enquanto a pessoa segura o botão, a vela derrete
    // rápido. Soltou, para. Se chegar no fim, a vela acaba (estado .acabou, "Finalizada").
    func comecarADerreter() {
        guard estado == .acesa || estado == .apagada, !derretendoRapido else { return }
        tique()                                   // guarda o tempo normal até aqui
        derretendoRapido = true
        if ultimoTique == nil { ultimoTique = Date() }   // vela apagada também derrete
        let falta = max(0.3, (1 - progresso) * Sessao.segundosParaDerreterTudo)
        haptics.iniciarSegurar(duracao: falta)    // vibração que vai crescendo
        atualizarRelogio()
    }

    func pararDeDerreter() {
        guard derretendoRapido else { return }
        tique()
        derretendoRapido = false
        haptics.cancelarSegurar()
        if estado == .apagada { ultimoTique = nil }   // apagada, o tempo volta a ficar parado
        atualizarRelogio()
        salvar()
    }

    // VoiceOver (não dá para segurar): derrete tudo de uma vez, depois de confirmar
    func derreterAteOFim() {
        guard estado == .acesa || estado == .apagada else { return }
        derretendoRapido = false
        haptics.cancelarSegurar()
        queimado = config.duracao
        atualizarProgresso(comSom: true)
    }

    // Joga a vela fora e coloca uma vela nova, no tamanho padrão e sem enfeites
    func descartar() {
        movimento.soltarReferencia()
        desligarVibracaoDaChama()
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
        cenaAtiva = fase == .active
        defer { atualizarSopro() }
        switch fase {
        case .active:
            guard !ativo else { return }
            ativo = true
            if movimentoLigado { movimento.iniciar() }
            haptics.ligarMotor()
            tique()                   // conta o tempo que passou com o app fechado
            if estado == .acesa {
                movimento.fixarReferencia()
                ligarVibracaoDaChama()
                if somAmbienteLigado { ambiente.tocar() }
            }
            atualizarRelogio()
        case .background:
            pararDeDerreter()
            ativo = false
            atualizarRelogio()
            tique()
            salvar()
            movimento.parar()
            ambiente.parar()
            desligarVibracaoDaChama()
            haptics.desligarMotor()
        default:
            break
        }
    }

    // Chamado quando a pessoa liga ou desliga o movimento (Core Motion) nas Configurações.
    // Desligado: inclinar não acelera a vela, virar não apaga e a chama fica parada em pé.
    func atualizarMovimento() {
        if movimentoLigado && ativo {
            movimento.iniciar()
        } else {
            movimento.parar()
            movimento.zerar()
        }
    }

    private var movimentoLigado: Bool { Chaves.ligado(Chaves.movimento) }
    func atualizarSopro() {
        let habilitado = UserDefaults.standard.object(forKey: Chaves.apagarSoprando) as? Bool ?? true
        if cenaAtiva && estado == .acesa && habilitado {
            sopro.iniciar { [weak self] in self?.apagar(jeito: .sopro) }
        } else {
            sopro.parar()
        }
    }

    // Chamado pela PalcoView quando a chama muda de lugar na tela (0 = embaixo, 1 = em cima).
    // O sopro usa isso para ouvir pelo microfone mais perto da chama.
    func chamaMudouDeLugar(_ altura: Double) {
        sopro.alturaDaChama = altura
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
        let derretendo = derretendoRapido && estado == .apagada
        guard estado == .acesa || derretendo, let ultimo = ultimoTique else { return }
        let agora = Date()
        let passou = agora.timeIntervalSince(ultimo)
        if derretendoRapido {
            // Segurando o Descartar: derrete rápido (a vela inteira em poucos segundos)
            queimado += passou * config.duracao / Sessao.segundosParaDerreterTudo
        } else {
            let fator = 1 + (Sessao.aceleracaoAoGirar - 1) * movimento.inclinacao
            queimado += passou * Sessao.velocidade * fator
        }
        ultimoTique = agora

        if estado == .acesa { cuidarDaVibracaoDaChama(agora: agora) }
        atualizarProgresso(comSom: true)

        if agora.timeIntervalSince(ultimoSalvo) > 2 { salvar() }
    }

    private func atualizarProgresso(comSom: Bool) {
        progresso = min(1, queimado / config.duracao)

        // Um enfeite cai quando a cera chega na altura dele
        // Cai quando a CERA chega no enfeite (e não a ponta do pavio)
        let novos = config.enfeites.filter { !caidos.contains($0.id) && config.caiu($0, progresso: progresso) }
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
        if derretendoRapido {
            derretendoRapido = false
            haptics.cancelarSegurar()
        }
        atualizarRelogio()
        // Se estava nas sombras, a tela (PalcoView) entra na caixa com a animação da cortina
        movimento.soltarReferencia()
        desligarVibracaoDaChama()
        ambiente.parar()
        if comSom {
            haptics.fim()
            anunciar("A vela acabou")
        }
        salvar()
    }

    // MARK: Vibração da chama

    // Liga o loop da chama. Acender conta como "mexeu": o descanso começa a contar daqui.
    private func ligarVibracaoDaChama() {
        chamaLigadaEm = Date()
        chamaVibrando = true
        ultimaInclinacaoEnviada = movimento.inclinacao
        haptics.iniciarChama()
        haptics.atualizarChama(inclinacao: Float(movimento.inclinacao))
    }

    // Desliga de vez (vela apagou, acabou, foi descartada ou o app saiu da tela).
    private func desligarVibracaoDaChama() {
        chamaVibrando = false
        ultimaInclinacaoEnviada = -1
        haptics.pararChama()
    }

    // Chamado a cada tique (10x por segundo), mas quase sempre não faz nada:
    // - aparelho parado há "descansoDaVibracao" segundos → o loop da chama descansa;
    // - a pessoa mexeu → o loop volta na hora;
    // - só manda valor novo ao motor quando a inclinação muda de verdade.
    private func cuidarDaVibracaoDaChama(agora: Date) {
        let ultimaMexida = max(movimento.mexeuEm, chamaLigadaEm)
        let deveVibrar = agora.timeIntervalSince(ultimaMexida) < Sessao.descansoDaVibracao

        if deveVibrar && !chamaVibrando {
            chamaVibrando = true
            ultimaInclinacaoEnviada = -1      // força mandar a força certa logo abaixo
            haptics.iniciarChama()
        } else if !deveVibrar && chamaVibrando {
            chamaVibrando = false
            ultimaInclinacaoEnviada = -1
            haptics.pararChama()
        }

        guard chamaVibrando else { return }
        let inclinacao = movimento.inclinacao
        if abs(inclinacao - ultimaInclinacaoEnviada) >= Sessao.mudancaMinimaDaChama {
            ultimaInclinacaoEnviada = inclinacao
            haptics.atualizarChama(inclinacao: Float(inclinacao))
        }
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
            queimado += Date().timeIntervalSince(antes) * Sessao.velocidade
            ultimoTique = Date()
        }
        progresso = min(1, queimado / config.duracao)
        caidos.formUnion(config.enfeites.filter { config.caiu($0, progresso: progresso) }.map(\.id))
        if progresso >= 1 && estado == .acesa {
            estado = .acabou
            ultimoTique = nil
        }
        if estado == .apagada { apagouEm = .distantPast }
    }
}
