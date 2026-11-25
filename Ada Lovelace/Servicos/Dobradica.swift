//  Dobradica.swift
//  iPhone Duo (dobrável): junta o que a dobradiça e a tela informam e diz em qual postura o aparelho está.
//
//  ISOLAMENTO: tudo do modo Duo depende de `ehDuo`. Ele só fica true quando o sistema
//  informa uma dobradiça (onHingeChange, iOS 27.1+). No iPhone comum e no iPad
//  a dobradiça nunca aparece, então nada muda para eles.
//
//  Como a Apple pede ("Don't use hinge updates for layout"):
//  - a DOBRADIÇA é só entrada: abrir e fechar troca de cena, e o ângulo decide quando é laptop;
//  - o LAYOUT vem da tela: a região da dobra (reservedRegions .division) diz em que tela o app
//    está e para que lado a dobra corre; o tamanho da janela diz se ela está em pé.
//
//  Posturas (combinadas com a Sofia):
//  A/B aberto  de 180° até 100°, tela interna        → a caixa inteira, travada em paisagem
//  C   laptop  100° ou menos e a dobra na horizontal  → vela embaixo, teatro de sombras em cima
//  D   fechado o sistema passou para a tela externa   → travado no teatro de sombras, em pé ou deitado
//  E   tenda   entreaberto com a tela externa acesa   → troca manual (botão e pinça), em paisagem

import SwiftUI
import Combine
#if canImport(UIKit)
import UIKit
#endif

enum PosturaDuo: Equatable {
    case aberto     // A e B: é a mesma tela
    case laptop     // C
    case fechado    // D
    case tenda      // E
}

final class Dobradica: ObservableObject {
    static let compartilhada = Dobradica()

    // ⚙️ Fechando até este ângulo (graus), a dobra conta como laptop.
    static let entraNoLaptop: Double = 100
    // ⚙️ Abrindo, só deixa de ser laptop acima deste ângulo (o respiro para a tela não piscar).
    static let saiDoLaptop: Double = 105
    // ⚙️ Tempo para confirmar o modo tenda: abrindo o aparelho fechado, a tela externa fica acesa
    // um instante antes de o app passar para a interna, e isso não pode virar tenda.
    static let esperaDaTenda: Duration = .milliseconds(400)

    @Published private(set) var ehDuo = false
    @Published private(set) var postura: PosturaDuo = .aberto
    // Para a floresta: a janela está em pé (mais alta que larga)?
    @Published private(set) var telaEmPe = true

    // O que a dobradiça informou
    private enum Status { case fechado, entreaberto, aberto }
    private var temDobradica = false
    private var status = Status.aberto
    private var angulo: Double = 180          // graus
    private var laptopPeloAngulo = false

    // O que a tela informou (região da dobra)
    private var naTelaInterna = true          // existe uma dobra na tela (ativa ou não)
    private var dobraDeitada = false          // a dobra ativa corre na horizontal (laptop)

    private var confirmacaoDaTenda: Task<Void, Never>?

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

    // MARK: Leituras

    // Da dobradiça (onHingeChange). nil = este aparelho não tem dobradiça.
    @available(iOS 27.1, *)
    func dobradicaMudou(_ hinge: DeviceHinge?) {
        guard let hinge else {
            temDobradica = false
            recalcular()
            return
        }
        temDobradica = true
        switch hinge.status {
        case .closed: status = .fechado
        case .partiallyOpen: status = .entreaberto
        default: status = .aberto
        }
        angulo = hinge.angle.degrees
        recalcular()
    }

    // Da tela (PalcoView): a região da dobra e o tamanho da janela
    func telaMudou(temDobra: Bool, dobraDeitada: Bool, tamanho: CGSize) {
        guard tamanho.width > 0, tamanho.height > 0 else { return }
        let emPe = tamanho.height >= tamanho.width
        guard temDobra != naTelaInterna || dobraDeitada != self.dobraDeitada || emPe != telaEmPe else { return }
        naTelaInterna = temDobra
        self.dobraDeitada = dobraDeitada
        if telaEmPe != emPe { telaEmPe = emPe }
        recalcular()
    }

    // MARK: Postura

    private func recalcular() {
        var duo = temDobradica
        var st = status
        var graus = angulo
        var interna = naTelaInterna
        var deitada = dobraDeitada

        #if DEBUG
        let padrao = UserDefaults.standard
        if padrao.bool(forKey: Chaves.simularDuo) {
            duo = true
            graus = padrao.object(forKey: Chaves.anguloSimulado) as? Double ?? 180
            st = graus <= 0 ? .fechado : graus >= 180 ? .aberto : .entreaberto
            interna = !(st == .entreaberto && padrao.bool(forKey: Chaves.tendaSimulada))
            deitada = telaEmPe   // sem dobra de verdade: em pé conta como a dobra na horizontal
        }
        #endif

        // Respiro: quem já está no laptop só sai acima de 105°; quem não está, só entra em 100°
        laptopPeloAngulo = st == .entreaberto
            && graus <= (laptopPeloAngulo ? Dobradica.saiDoLaptop : Dobradica.entraNoLaptop)

        let nova: PosturaDuo
        switch st {
        case .fechado: nova = .fechado
        case .aberto: nova = .aberto
        case .entreaberto:
            if !interna { nova = .tenda }
            else if laptopPeloAngulo && deitada { nova = .laptop }
            else { nova = .aberto }
        }

        if ehDuo != duo { ehDuo = duo }
        mudarPostura(para: nova)
        atualizarOrientacoes()
    }

    private func mudarPostura(para nova: PosturaDuo) {
        guard nova != .tenda || postura == .tenda else {
            // Tenda só vale se continuar assim por um instante
            guard confirmacaoDaTenda == nil else { return }
            confirmacaoDaTenda = Task { [weak self] in
                try? await Task.sleep(for: Dobradica.esperaDaTenda)
                guard let self, !Task.isCancelled else { return }
                self.confirmacaoDaTenda = nil
                self.postura = .tenda
                self.atualizarOrientacoes()
            }
            return
        }
        confirmacaoDaTenda?.cancel()
        confirmacaoDaTenda = nil
        if postura != nova { postura = nova }
    }

    // MARK: Orientação (só no Duo)

    #if canImport(UIKit)
    // nil = o app segue o Info.plist, como sempre (iPhone comum em pé, iPad em todas).
    var orientacoesDoDuo: UIInterfaceOrientationMask? {
        guard ehDuo else { return nil }
        switch postura {
        case .fechado: return .allButUpsideDown         // D: tela externa, em pé ou deitada (teste)
        case .tenda: return .landscape                  // E: tela externa, deitada
        case .laptop: return .allButUpsideDown          // C
        case .aberto:
            // Abaixo de 100° o app solta o em pé, para a pessoa poder virar para o laptop.
            // Segurando como livro, o sistema continua em paisagem e a tela continua a caixa inteira.
            return laptopPeloAngulo ? .allButUpsideDown : .landscape   // A e B: só paisagem
        }
    }

    private var ultimasOrientacoes: UIInterfaceOrientationMask?

    // Pede ao sistema para perguntar de novo as orientações (AppDelegate) e girar se precisar
    private func atualizarOrientacoes() {
        let agora = orientacoesDoDuo
        guard agora != ultimasOrientacoes else { return }
        ultimasOrientacoes = agora
        for cena in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {
            for janela in cena.windows {
                janela.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            }
        }
    }
    #else
    private func atualizarOrientacoes() {}
    #endif
}

#if canImport(UIKit)
// Só existe para o iPhone Duo trocar as orientações conforme a postura.
// Fora do Duo devolve exatamente o que está no Info.plist, então nada muda no iPhone e no iPad.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        Dobradica.compartilhada.orientacoesDoDuo ?? AppDelegate.orientacoesDoInfoPlist
    }

    // As mesmas chaves que o sistema lê quando o app não responde a pergunta acima
    private static let orientacoesDoInfoPlist: UIInterfaceOrientationMask = {
        let info = Bundle.main.infoDictionary ?? [:]
        let sufixo = UIDevice.current.userInterfaceIdiom == .pad ? "~ipad" : "~iphone"
        let lista = info["UISupportedInterfaceOrientations" + sufixo] as? [String]
            ?? info["UISupportedInterfaceOrientations"] as? [String]
            ?? []
        var mascara: UIInterfaceOrientationMask = []
        for nome in lista {
            switch nome {
            case "UIInterfaceOrientationPortrait": mascara.insert(.portrait)
            case "UIInterfaceOrientationPortraitUpsideDown": mascara.insert(.portraitUpsideDown)
            case "UIInterfaceOrientationLandscapeLeft": mascara.insert(.landscapeLeft)
            case "UIInterfaceOrientationLandscapeRight": mascara.insert(.landscapeRight)
            default: break
            }
        }
        return mascara.isEmpty ? .allButUpsideDown : mascara
    }()
}
#endif

// Ouve a dobradiça (só no iOS 27.1+, onde ela existe)
struct OuvirADobradica: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 27.1, *) {
            content.onHingeChange { _, novo in
                Dobradica.compartilhada.dobradicaMudou(novo.hinge)
            }
        } else {
            content
        }
    }
}
