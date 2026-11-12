//  VelaConfig.swift
//  Como a vela foi personalizada: tamanho (= tempo) e enfeites.

import Foundation
import CoreGraphics

enum TipoEnfeite: String, Codable, CaseIterable {
    case alfinete, penduricalho

    var nome: String { self == .alfinete ? "alfinete" : "penduricalho" }
}

// Um alfinete ou penduricalho espetado na vela
struct Enfeite: Identifiable, Codable, Equatable {
    var id = UUID()
    var tipo: TipoEnfeite
    var altura: Double   // 0 = base da vela, 1 = topo
    var lado: Double     // -1 = esquerda, 1 = direita
}

// Furinho que fica na cera quando a pessoa tira um enfeite do lugar
struct Marca: Identifiable, Codable, Equatable {
    var id = UUID()
    var altura: Double
    var lado: Double
}

struct VelaConfig: Codable, Equatable {
    var posicaoSlider: Double = 0.4   // 0 = vela mais curta, 1 = mais longa
    var enfeites: [Enfeite] = []
    var marcas: [Marca] = []

    // Regras de negócio
    static let minimoMinutos = 10.0
    static let maximoMinutos = 180.0
    static let limitePorTipo = 6
    static let faixaPermitida = 0.06...0.94      // não deixa espetar bem na base nem bem no topo

    // Slider exponencial: começa com passos pequenos e vai aumentando.
    // minutos = 10 × 18^posição  →  0 = 10 min, 0,5 ≈ 42 min, 1 = 180 min
    // Arredondado para múltiplos de 5 minutos.
    static func minutos(para posicao: Double) -> Int {
        let p = max(0, min(1, posicao))
        let bruto = minimoMinutos * pow(maximoMinutos / minimoMinutos, p)
        return Int((bruto / 5).rounded()) * 5
    }

    var minutos: Int { VelaConfig.minutos(para: posicaoSlider) }
    var duracao: TimeInterval { Double(minutos) * 60 }

    func quantos(_ tipo: TipoEnfeite) -> Int {
        enfeites.filter { $0.tipo == tipo }.count
    }

    func sobram(_ tipo: TipoEnfeite) -> Int {
        VelaConfig.limitePorTipo - quantos(tipo)
    }

    // ONDE O ENFEITE VAI PARAR
    //
    // A regra: pode colocar um pertinho do outro, só não pode ficar um EM CIMA do outro.
    // Se a pessoa solta em cima de um enfeite que já está lá, o app empurra o novo
    // um pouquinho para cima ou para baixo — o que estiver mais perto de onde ela soltou.
    //
    // Cada lado da vela (esquerda e direita) é contado separado: um alfinete na esquerda
    // não atrapalha um penduricalho na direita.
    //
    // Devolve a altura onde o enfeite coube, ou nil se não tem mais espaço
    // (aí ele cai no pote, como quando não encosta na vela).
    func acomodar(_ tipo: TipoEnfeite, altura: Double, lado: Double, tamanho: TamanhoEnfeite) -> Double? {
        guard sobram(tipo) > 0 else { return nil }
        let faixa = VelaConfig.faixaPermitida
        let vizinhos = enfeites.filter { ($0.lado < 0) == (lado < 0) }

        // Lugares que valem a pena tentar: onde a pessoa soltou e, para cada vizinho,
        // o encostadinho em cima e o encostadinho embaixo dele.
        var candidatos = [altura]
        for v in vizinhos {
            candidatos.append(v.altura + tamanho.acima(v.tipo) + tamanho.abaixo(tipo))
            candidatos.append(v.altura - tamanho.abaixo(v.tipo) - tamanho.acima(tipo))
        }

        let folga = 0.0001   // para o "encostadinho" não ser recusado por arredondamento
        return candidatos
            .map { min(max($0, faixa.lowerBound), faixa.upperBound) }
            .filter { lugar in
                vizinhos.allSatisfy { v in
                    if lugar >= v.altura {
                        return lugar - v.altura >= tamanho.abaixo(tipo) + tamanho.acima(v.tipo) - folga
                    } else {
                        return v.altura - lugar >= tamanho.abaixo(v.tipo) + tamanho.acima(tipo) - folga
                    }
                }
            }
            .min { abs($0 - altura) < abs($1 - altura) }   // o mais perto de onde ela soltou
    }

    // O lugar livre mais alto daquele lado (usado pelo VoiceOver)
    func primeiroLugarLivre(_ tipo: TipoEnfeite, lado: Double, tamanho: TamanhoEnfeite) -> Double? {
        acomodar(tipo, altura: VelaConfig.faixaPermitida.upperBound, lado: lado, tamanho: tamanho)
    }
}

// Quanto cada enfeite ocupa na vela, para cima e para baixo da linha onde ele espeta.
// Os números saem do tamanho do desenho (em pontos) e chegam aqui já em fração da
// altura da vela — assim a regra funciona igual para vela pequena e vela grande.
// Quem monta isso é a tela: veja TamanhoEnfeite.daVela(...) na VelaView.
struct TamanhoEnfeite {
    var alfineteAcima: Double
    var alfineteAbaixo: Double
    var penduricalhoAcima: Double
    var penduricalhoAbaixo: Double

    func acima(_ tipo: TipoEnfeite) -> Double {
        tipo == .alfinete ? alfineteAcima : penduricalhoAcima
    }

    func abaixo(_ tipo: TipoEnfeite) -> Double {
        tipo == .alfinete ? alfineteAbaixo : penduricalhoAbaixo
    }
}

// Tamanho da vela na tela. Vela mais longa = mais alta.
enum GeometriaVela {
    static func alturaCheia(posicao: Double, alturaMaxima: CGFloat) -> CGFloat {
        alturaMaxima * (0.35 + 0.65 * CGFloat(max(0, min(1, posicao))))
    }
}
