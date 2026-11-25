//  Dobradica.swift
//  iPhone Duo (dobrável): lê a dobradiça e diz em qual postura o aparelho está.
//
//  ISOLAMENTO: tudo do modo Duo depende de `ehDuo`. Ele só fica true quando o sistema
//  informa uma dobradiça (UIHingeInteraction, iOS 27.1+). No iPhone comum e no iPad
//  a dobradiça nunca aparece, então nada muda para eles.
//
//  Posturas (combinadas com a Sofia):
//  A aberto   180°                      → só a vela, dentro da caixa
//  B abrindo  entre 180° e 90°          → zoom contínuo: a vela vai para a esquerda e a borda da caixa aparece
//  C laptop   90° ou menos, até fechar  → vela embaixo, teatro de sombras em cima
//  D fechado  tela externa              → travado no teatro de sombras
//  E tenda    "V" invertido, tela externa acesa com o aparelho entreaberto → troca manual (botão e pinça)

import SwiftUI
import Combine
#if canImport(UIKit)
import UIKit
#endif

enum PosturaDuo: Equatable {
    case aberto
    case abrindo(Double)    // 0 = acabou de sair dos 180°, 1 = chegou nos 90°
    case laptop
    case fechado
    case tenda

    // A postura sem o ângulo: é o que muda a tela (o ângulo só mexe no zoom)
    enum Tipo { case aberto, abrindo, laptop, fechado, tenda }

    var tipo: Tipo {
        switch self {
        case .aberto: .aberto
        case .abrindo: .abrindo
        case .laptop: .laptop
        case .fechado: .fechado
        case .tenda: .tenda
        }
    }
}

final class Dobradica: ObservableObject {
    static let compartilhada = Dobradica()

    // ⚙️ Abaixo disto (graus) é modo laptop; acima, transição de zoom.
    static let anguloDoLaptop: Double = 90
    // ⚙️ Folga em volta dos 90°, para a tela não ficar pulando entre B e C com o aparelho parado ali.
    static let folgaDoLaptop: Double = 3
    // ⚙️ Sem tamanho guardado da tela externa: janela com o lado menor abaixo disto conta como tela externa.
    static let ladoMenorDaTelaExterna: CGFloat = 560

    @Published private(set) var ehDuo = false
    @Published private(set) var postura: PosturaDuo = .aberto
    // Para a floresta e o sopro: a janela está em pé (mais alta que larga)?
    @Published private(set) var telaEmPe = true

    #if canImport(UIKit)
    // Orientação da janela onde o app está (o Movimento usa no Duo, em vez da do app inteiro)
    private(set) var orientacao: UIInterfaceOrientation = .portrait
    #endif

    // O que a dobradiça real informou
    private enum Status { case desconhecido, fechado, entreaberto, aberto }
    private var temDobradica = false
    private var status = Status.desconhecido
    private var angulo: Double = 180          // graus
    private var tamanhoDaJanela: CGSize = .zero
    private var tamanhoDaTelaExterna: CGSize?  // guardado quando o aparelho fecha

    #if DEBUG
    private var observador: AnyCancellable?
    #endif

    private init() {
        #if DEBUG
        // Configurações → "Para testar" → Simular iPhone Duo
        observador = NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.recalcular() }
        recalcular()
        #endif
    }

    // MARK: Leituras (vêm do LeitorDaDobradica)

    #if canImport(UIKit)
    fileprivate func dobradicaMudou(status bruto: Int?, angulo radianos: Double?) {
        guard let bruto, let radianos else {
            temDobradica = false
            recalcular()
            return
        }
        temDobradica = true
        switch bruto {
        case 1: status = .fechado
        case 2: status = .entreaberto
        case 3: status = .aberto
        default: status = .desconhecido
        }
        angulo = radianos * 180 / .pi
        recalcular()
    }

    fileprivate func janelaMudou(_ tamanho: CGSize, orientacao: UIInterfaceOrientation) {
        guard tamanho.width > 0, tamanho.height > 0 else { return }
        self.orientacao = orientacao
        guard tamanho != tamanhoDaJanela else { return }
        tamanhoDaJanela = tamanho
        recalcular()
    }
    #endif

    // MARK: Postura

    private func recalcular() {
        var duo = temDobradica
        var st = status
        var graus = angulo
        var externa = naTelaExterna

        #if DEBUG
        let padrao = UserDefaults.standard
        if padrao.bool(forKey: Chaves.simularDuo) {
            duo = true
            graus = padrao.object(forKey: Chaves.anguloSimulado) as? Double ?? 180
            st = graus <= 0 ? .fechado : graus >= 180 ? .aberto : .entreaberto
            externa = st == .fechado || (st == .entreaberto && padrao.bool(forKey: Chaves.tendaSimulada))
        }
        #endif

        if st == .fechado, tamanhoDaJanela != .zero { tamanhoDaTelaExterna = tamanhoDaJanela }

        let nova: PosturaDuo
        switch st {
        case .fechado: nova = .fechado
        case .aberto, .desconhecido: nova = .aberto
        case .entreaberto:
            if externa {
                nova = .tenda
            } else {
                // Folga nos 90°: quem já está no laptop só sai um pouco acima, e vice-versa
                let limite = postura.tipo == .laptop ? Dobradica.anguloDoLaptop + Dobradica.folgaDoLaptop
                                                     : Dobradica.anguloDoLaptop - Dobradica.folgaDoLaptop
                if graus <= limite {
                    nova = .laptop
                } else {
                    let fracao = (180 - graus) / (180 - Dobradica.anguloDoLaptop)
                    nova = .abrindo(min(1, max(0, fracao)))
                }
            }
        }

        if ehDuo != duo { ehDuo = duo }
        if postura != nova { postura = nova }
        let emPe = tamanhoDaJanela == .zero || tamanhoDaJanela.height >= tamanhoDaJanela.width
        if telaEmPe != emPe { telaEmPe = emPe }
    }

    // A janela está na tela externa (a de fora)? Usado para separar a tenda do laptop.
    // As duas telas do Duo têm quase a mesma proporção, então a conta é pelo tamanho.
    private var naTelaExterna: Bool {
        guard tamanhoDaJanela != .zero else { return false }
        let menor = min(tamanhoDaJanela.width, tamanhoDaJanela.height)
        let maior = max(tamanhoDaJanela.width, tamanhoDaJanela.height)
        if let externa = tamanhoDaTelaExterna {
            let menorExterna = min(externa.width, externa.height)
            let maiorExterna = max(externa.width, externa.height)
            return abs(menor - menorExterna) < 2 && abs(maior - maiorExterna) < 2
        }
        return menor < Dobradica.ladoMenorDaTelaExterna
    }
}

#if canImport(UIKit)
// Vista invisível que fica no fundo do app só para ouvir a dobradiça e o tamanho da janela.
struct LeitorDaDobradica: UIViewRepresentable {
    func makeUIView(context: Context) -> VistaDaDobradica { VistaDaDobradica() }
    func updateUIView(_ uiView: VistaDaDobradica, context: Context) {}
}

final class VistaDaDobradica: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        if #available(iOS 27.1, *) {
            addInteraction(UIHingeInteraction { [weak self] _, update in
                // Vista saindo da tela: o "sem dobradiça" dela não vale para o app
                guard let self, self.window != nil || update.hinge != nil else { return }
                let hinge = update.hinge
                let status = hinge.map { $0.status.rawValue }
                let angulo = hinge.map { Double($0.angle) }
                // Depois do desenho da tela: mudar a postura no meio dele dá erro no SwiftUI
                DispatchQueue.main.async {
                    Dobradica.compartilhada.dobradicaMudou(status: status, angulo: angulo)
                }
            })
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) não é usado") }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        avisarJanela()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        avisarJanela()
    }

    private func avisarJanela() {
        guard let window else { return }
        let orientacao = window.windowScene?.effectiveGeometry.interfaceOrientation ?? .portrait
        let tamanho = window.bounds.size
        // layoutSubviews roda no meio do desenho do SwiftUI: avisa logo depois
        DispatchQueue.main.async {
            Dobradica.compartilhada.janelaMudou(tamanho, orientacao: orientacao)
        }
    }
}
#endif
