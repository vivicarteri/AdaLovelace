//  Acessibilidade.swift
//  Textos e peças que só existem para o VoiceOver e o Controle por Voz.
//
//  - Descrição da vela e da duração SEM números (a pessoa sente o tempo, não conta).
//  - Rotor "Camadas de papel": a pessoa escolhe uma camada da cena e ouve a descrição
//    daquela camada. Assim o VoiceOver não lê tudo de uma vez, mas tudo pode ser descoberto.
//
//  COMO ACRESCENTAR UMA CAMADA (ex.: os coelhos, quando a arte chegar):
//  escreva um CamadaDescrita novo em DescricaoDaCena.camadas(...) — título curto e descrição.
//  A ordem da lista é a ordem do rotor, de cima para baixo na cena.

import SwiftUI

// MARK: - Vela e duração

extension Sessao {
    // O que o VoiceOver fala sobre a vela (sem números, como na tela)
    var descricaoDaVela: String {
        let quanto: String
        switch progresso {
        case ..<0.05: quanto = "inteira"
        case ..<0.25: quanto = "quase inteira"
        case ..<0.5: quanto = "chegando na metade"
        case ..<0.75: quanto = "passou da metade"
        case ..<1: quanto = "quase no fim"
        default: quanto = "acabou"
        }
        let ritmo = derretimentoAcelerado ? ", derretendo mais rápido" : ""
        let presos = config.enfeites.filter { !caidos.contains($0.id) }.count
        let enfeites: String
        switch (config.enfeites.isEmpty, presos) {
        case (true, _): enfeites = ""
        case (false, 0): enfeites = ". Todos os enfeites já caíram"
        case (false, 1): enfeites = ". Ainda resta um enfeite preso na cera"
        default: enfeites = ". Ainda restam \(presos) enfeites presos na cera"
        }
        switch estado {
        case .nova: return "Vela nova, apagada" + enfeites
        case .acesa: return "Acesa, \(quanto)\(ritmo)" + enfeites
        case .apagada: return "Apagada, \(quanto)" + enfeites
        case .acabou: return "A vela acabou"
        }
    }
}

enum DescricaoDaDuracao {
    // Faixas combinadas com o time (o slider vai de 10 minutos a 3 horas)
    static func texto(minutos: Int) -> String {
        switch minutos {
        case ...Int(VelaConfig.minimoMinutos): return "Duração mínima"
        case ...30: return "Duração curta"
        case ...60: return "Duração curta a média"
        case ...120: return "Duração média"
        case ...150: return "Duração longa"
        default: return "Duração extra longa"
        }
    }
}

// Onde o enfeite está na vela, em palavras
enum DescricaoDoEnfeite {
    static func altura(_ altura: Double) -> String {
        switch altura {
        case 0.66...: return "perto do topo"
        case 0.34...: return "na metade"
        default: return "perto da base"
        }
    }

    static func lado(_ lado: Double) -> String {
        lado < 0 ? "lado esquerdo" : "lado direito"
    }

    static func nome(_ tipo: TipoEnfeite) -> String {
        tipo == .alfinete ? "Alfinete" : "Penduricalho"
    }
}

// Os três lugares que o VoiceOver oferece para espetar um enfeite
enum LugarNaVela: CaseIterable {
    case topo, metade, base

    var altura: Double {
        switch self {
        case .topo: 0.85
        case .metade: 0.5
        case .base: 0.15
        }
    }

    var texto: String {
        switch self {
        case .topo: "perto do topo da vela"
        case .metade: "na metade da vela"
        case .base: "perto da base da vela"
        }
    }
}

// MARK: - Camadas de papel (rotor)

struct CamadaDescrita: Identifiable {
    let id: String
    let titulo: String      // o que o rotor mostra
    let descricao: String   // o que o VoiceOver lê ao chegar na camada
    let faixa: ClosedRange<CGFloat>   // onde a camada fica na tela (fração da altura), para o toque do VoiceOver
}

@MainActor
enum DescricaoDaCena {
    // sombra: true = teatro de sombras (zoom out); false = as peças coloridas dentro da caixa
    static func camadas(sombra: Bool) -> [CamadaDescrita] {
        Floresta.ligada ? floresta(sombra: sombra) : circo(sombra: sombra)
    }

    private static func floresta(sombra: Bool) -> [CamadaDescrita] {
        if sombra {
            return [
                CamadaDescrita(id: "ceu", titulo: "Céu: sol e lua",
                               descricao: "Céu. Bem perto da parede, as sombras ficam nítidas. O sol, com hélices girando atrás do rosto, e a lua atravessam o alto da parede em sentidos contrários e se encontram num eclipse. Estrelas pulsam devagar, nuvens passam e passarinhos cruzam voando.",
                               faixa: 0.16...0.40),
                CamadaDescrita(id: "arvoresDeTras", titulo: "Floresta: árvores do fundo",
                               descricao: "Árvores do fundo. Uma fileira de árvores altas e finas, longe da chama. A sombra delas é clara e macia.",
                               faixa: 0.40...0.52),
                CamadaDescrita(id: "arvoresDaFrente", titulo: "Floresta: árvores da frente",
                               descricao: "Árvores da frente. Troncos maiores, recortados em papel, mais perto da chama. A sombra fica maior, mais escura e borrada.",
                               faixa: 0.52...0.62),
                CamadaDescrita(id: "arbustos", titulo: "Floresta: arbustos",
                               descricao: "Arbustos. Moitas arredondadas junto ao chão, coladas na chama. Viram uma massa escura e desfocada na base da parede.",
                               faixa: 0.62...0.70)
            ]
        }
        return [
            CamadaDescrita(id: "ceu", titulo: "Céu: sol e lua",
                           descricao: "Céu de papel azul-noite. O sol, com rosto e hélices que giram, e a lua, com olhos que piscam, atravessam o céu em sentidos contrários até se encontrarem num eclipse. Estrelas pulsam, nuvens brancas passam e passarinhos cruzam voando.",
                           faixa: 0.10...0.38),
            CamadaDescrita(id: "arvoresDeTras", titulo: "Floresta: árvores do fundo",
                           descricao: "Árvores do fundo. Uma fileira de árvores azul-escuras, finas e altas, quase sumindo na noite.",
                           faixa: 0.38...0.50),
            CamadaDescrita(id: "arvoresDaFrente", titulo: "Floresta: árvores da frente",
                           descricao: "Árvores da frente. Troncos cinza-claros, recortados em papel, com contorno marcado, na frente da fileira azul.",
                           faixa: 0.50...0.60),
            CamadaDescrita(id: "arbustos", titulo: "Floresta: arbustos",
                           descricao: "Arbustos. Moitas arredondadas em azul e lilás, na beira do palco, em volta da vela.",
                           faixa: 0.60...0.68)
        ]
    }

    private static func circo(sombra: Bool) -> [CamadaDescrita] {
        let parede = sombra ? "Na parede, a sombra" : "O desenho"
        return [
            CamadaDescrita(id: "ceu", titulo: "Céu: lua e passarinho",
                           descricao: "\(parede) da lua e de um passarinho, que passam devagar pelo alto, um depois do outro.",
                           faixa: 0.12...0.40),
            CamadaDescrita(id: "tenda", titulo: "Circo: tenda",
                           descricao: "\(parede) da tenda listrada do circo, que cobre todo o fundo.",
                           faixa: 0.40...0.58),
            CamadaDescrita(id: "picadeiro", titulo: "Circo: picadeiro",
                           descricao: "\(parede) do picadeiro, o chão redondo do circo, embaixo da vela.",
                           faixa: 0.58...0.68)
        ]
    }
}

// Elementos invisíveis, um por camada, com o rotor "Camadas de papel".
// Eles ficam por último na ordem do VoiceOver: quem desliza pela tela ouve primeiro os botões.
//
// A última entrada do rotor é "Verificar estado da vela":
// - Dentro da caixa a vela já é um elemento na tela: passe estadoDaVela = nil e marque a vela
//   com .accessibilityRotorEntry(id: CamadasDaCenaAcessiveis.idDaVela, in: rotor).
//   (Antes havia um quadrado só para isso, e o estado da vela era lido duas vezes.)
// - No teatro de sombras a vela fica dentro da caixa: passe o texto e um ponto pequeno faz esse papel.
// O rotor em si é declarado no container de fora (.rotorCamadasDePapel), que contém a vela e as camadas.
struct CamadasDaCenaAcessiveis: View {
    static let idDaVela = "estadoDaVela"

    var camadas: [CamadaDescrita]
    var estadoDaVela: String? = nil
    var rotor: Namespace.ID

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(camadas) { camada in
                    let alto = geo.size.height * camada.faixa.lowerBound
                    let baixo = geo.size.height * camada.faixa.upperBound
                    AlvoAcessivel()
                        .frame(width: geo.size.width * 0.7, height: max(1, baixo - alto))
                        .position(x: geo.size.width / 2, y: (alto + baixo) / 2)
                        .accessibilityElement()
                        .accessibilityLabel(camada.descricao)
                        .accessibilityRotorEntry(id: camada.id, in: rotor)
                }
                if let estadoDaVela {
                    // Um ponto pequeno, para não cobrir os botões no toque do VoiceOver
                    AlvoAcessivel()
                        .frame(width: 44, height: 44)
                        .position(x: geo.size.width * 0.82, y: geo.size.height * 0.74)
                        .accessibilityElement()
                        .accessibilityLabel("Estado da vela")
                        .accessibilityValue(estadoDaVela)
                        .accessibilityRotorEntry(id: Self.idDaVela, in: rotor)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityElement(children: .contain)
        .accessibilitySortPriority(-1)
    }
}

extension View {
    // O rotor "Camadas de papel": as camadas, de cima para baixo, e por último o estado da vela
    func rotorCamadasDePapel(_ camadas: [CamadaDescrita], in rotor: Namespace.ID) -> some View {
        accessibilityRotor("Camadas de papel") {
            ForEach(camadas) { camada in
                AccessibilityRotorEntry(Text(camada.titulo), id: camada.id, in: rotor)
            }
            AccessibilityRotorEntry(Text("Verificar estado da vela"), id: CamadasDaCenaAcessiveis.idDaVela, in: rotor)
        }
    }
}

// Quase transparente (e não .clear): uma vista totalmente transparente pode sumir para o VoiceOver
struct AlvoAcessivel: View {
    var body: some View {
        Color.black.opacity(0.001)
    }
}
