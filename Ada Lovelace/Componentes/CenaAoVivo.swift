//  CenaAoVivo.swift
//  O que cada elemento da floresta está fazendo AGORA, para o rotor "Camadas de papel" do VoiceOver:
//  quantas estrelas há, onde estão o sol e a lua (e o eclipse), as nuvens, os passarinhos,
//  o coração e o coelho.
//
//  Usa as MESMAS contas do desenho (Floresta.swift): o relógio do cenário, os caminhos de cada
//  peça e a largura visível da tela (então vale para iPhone e iPad). Com Reduzir movimento a cena
//  fica parada no eclipse, e as falas descrevem esse instante.

import SwiftUI

// As partes da cena que mudam com o tempo (cada uma é uma entrada do rotor)
enum ParteDaCena {
    case estrelas, solELua, nuvens, passarinhos, coracao, coelho
}

@MainActor
enum CenaAoVivo {
    // ⚙️ Eclipse: distância entre o meio do sol e o da lua, em larguras de astro.
    //    Abaixo de "encostando" eles já se sobrepõem; abaixo de "quaseCompleto" a lua cobre boa
    //    parte do sol; abaixo de "eclipse" (ou perto da menor distância) é o eclipse.
    static let encostando: CGFloat = 1.0
    static let quaseCompleto: CGFloat = 0.6
    static let eclipse: CGFloat = 0.3
    // ⚙️ "Prestes a formar o eclipse": eles vão começar a se sobrepor dentro destes segundos
    static let prestes: Double = 30
    // ⚙️ Por quantos segundos depois do eclipse eles "acabaram de formar o eclipse"
    static let acabouDeFormar: Double = 40
    // ⚙️ Segundos à frente usados para saber se a peça está subindo ou descendo
    static let olharAFrente: Double = 4
    // ⚙️ Quanto a peça precisa subir ou descer nesse tempo para dizer "subindo"/"descendo" (pixels da arte)
    static let subidaMinima: CGFloat = 30

    // frase: o "agora" (vem depois da descrição da camada)
    // x: onde o alvo do VoiceOver fica (fração da largura da tela)
    // largura: largura do alvo (fração da largura da tela)
    static func agora(_ parte: ParteDaCena, _ data: Date, tela: CGSize, reduzirMovimento: Bool)
        -> (frase: String, x: CGFloat, largura: CGFloat) {
        let c = Contexto(data: data, tela: tela, reduzirMovimento: reduzirMovimento)
        let parada = reduzirMovimento && parte != .coelho ? " A cena está parada." : ""
        switch parte {
        case .estrelas:
            return (estrelas(c) + parada, 0.5, 0.7)
        case .solELua:
            let r = solELua(c)
            return (r.frase + parada, r.x, 0.3)
        case .nuvens:
            let r = nuvens(c)
            return (r.frase + parada, r.x, 0.25)
        case .passarinhos:
            let r = passarinhos(c)
            return (r.frase + parada, r.x, 0.2)
        case .coracao:
            return (coracao(c) + parada, 0.5, 0.25)
        case .coelho:
            let r = coelho(c)
            return (r.frase, r.x, 0.16)
        }
    }

    // MARK: - Contas comuns

    private struct Contexto {
        let relogio: Double
        let larguraVisivel: CGFloat
        let quadro: Quadro
        let reduzirMovimento: Bool

        init(data: Date, tela: CGSize, reduzirMovimento: Bool) {
            self.reduzirMovimento = reduzirMovimento
            relogio = reduzirMovimento ? Floresta.instanteDoEclipse
                                       : Floresta.tempoDoCenario(RelogioDaHistoria.tempo(em: data))
            quadro = Quadro(tela: tela)
            larguraVisivel = tela.width / max(Floresta.escala * quadro.escala, 0.001)
        }

        // Onde fica o meio da peça na tela (fração da largura)
        func fracao(_ dx: CGFloat) -> CGFloat { 0.5 + dx / max(larguraVisivel, 1) }
        func noAlvo(_ dx: CGFloat) -> CGFloat { min(0.9, max(0.1, fracao(dx))) }
        // Alguma parte da peça (de largura w) aparece na tela
        func naTela(_ dx: CGFloat, _ w: CGFloat) -> Bool { abs(dx) - w / 2 < larguraVisivel / 2 }
        // Só uma parte dela aparece (está entrando ou saindo pela beira)
        func naBeira(_ dx: CGFloat, _ w: CGFloat) -> Bool { naTela(dx, w) && abs(dx) + w / 2 > larguraVisivel / 2 }
    }

    // Posição de uma peça do céu (sol, lua, nuvem, passarinho) no instante t, igual ao desenho
    private static func posicao(_ a: Floresta.Andante, _ t: Double, _ c: Contexto) -> (dx: CGFloat, y: CGFloat)? {
        guard let p = Floresta.posicao(a.pontos, t, larguraVisivel: c.larguraVisivel, tamanho: a.largura) else { return nil }
        return (a.astro ? Floresta.caminhoDoAstro(p.dx, larguraVisivel: c.larguraVisivel, tamanho: a.largura) : p.dx, p.y)
    }

    private static func lado(_ dx: CGFloat) -> String { dx < 0 ? "esquerda" : "direita" }

    private static let numeros = ["nenhuma", "uma", "duas", "três", "quatro", "cinco", "seis", "sete",
                                  "oito", "nove", "dez"]
    private static func numero(_ n: Int) -> String { n < numeros.count ? numeros[n] : "\(n)" }

    // MARK: - Estrelas

    private static func estrelas(_ c: Contexto) -> String {
        let escala = Floresta.escala * c.quadro.escala
        let topoDaTela = -c.quadro.origem.y / max(escala, 0.001)
        var noCeu = 0, chegando = 0, indo = 0
        for e in Floresta.estrelas {
            let tamanho = e.altura * Floresta.aumentoDosElementos
            let minimoY = Floresta.topoLivre(no: c.quadro) + tamanho * 1.06 / 2 + 10
            let foraY = min((-c.quadro.origem.y - 80) / max(escala, 0.001), 0) - tamanho
            guard let p = Floresta.posicao(Floresta.caminho(da: e, minimoY: minimoY, foraY: foraY), c.relogio,
                                           larguraVisivel: c.larguraVisivel, tamanho: tamanho),
                  c.naTela(p.dx, tamanho), p.y + tamanho / 2 > topoDaTela
            else { continue }
            noCeu += 1
            if let primeiro = e.pontos.first, c.relogio < primeiro.t { chegando += 1 }
            if let ultimo = e.pontos.last, c.relogio > ultimo.t { indo += 1 }
        }
        guard noCeu > 0 else { return "Agora não há estrelas no céu." }
        var frase = noCeu == 1 ? "Agora há uma estrela no céu" : "Agora há \(numero(noCeu)) estrelas no céu"
        if noCeu == 1 {
            if chegando == 1 { frase += ", chegando" }
            if indo == 1 { frase += ", indo embora" }
        } else {
            if chegando > 0 { frase += ", \(numero(chegando)) delas chegando" }
            if indo > 0 { frase += ", \(numero(indo)) indo embora" }
        }
        return frase + "."
    }

    // MARK: - Sol e lua

    // Distância entre o sol e a lua no instante t, em larguras de astro (nil = algum fora do roteiro)
    private static func distancia(_ astros: (sol: Floresta.Andante, lua: Floresta.Andante), _ t: Double,
                                  _ c: Contexto) -> CGFloat? {
        guard let s = posicao(astros.sol, t, c), let l = posicao(astros.lua, t, c) else { return nil }
        return abs(s.dx - l.dx) / max(astros.sol.largura, 1)
    }

    // O instante em que eles ficam mais perto um do outro (o meio do eclipse) e essa distância.
    // Muda um pouco com a largura da tela (no iPhone o caminho deles é encolhido).
    private static func meioDoEclipse(_ astros: (sol: Floresta.Andante, lua: Floresta.Andante),
                                      _ c: Contexto) -> (t: Double, d: CGFloat) {
        var melhor = (t: Floresta.instanteDoEclipse, d: CGFloat.greatestFiniteMagnitude)
        for t in stride(from: Floresta.instanteDoEclipse - 60, through: Floresta.instanteDoEclipse + 60, by: 1) {
            if let d = distancia(astros, t, c), d < melhor.d { melhor = (t, d) }
        }
        return melhor
    }

    private static func solELua(_ c: Contexto) -> (frase: String, x: CGFloat) {
        let astros = Floresta.astros(no: c.quadro)
        let w = astros.sol.largura
        let sol = posicao(astros.sol, c.relogio, c).flatMap { c.naTela($0.dx, w) ? $0 : nil }
        let lua = posicao(astros.lua, c.relogio, c).flatMap { c.naTela($0.dx, w) ? $0 : nil }
        let meio = meioDoEclipse(astros, c)
        let depois = c.relogio > meio.t
        // Com Reduzir movimento a cena fica parada no eclipse (a cena do mockup)
        if c.reduzirMovimento, let s = sol, let l = lua {
            return ("Agora é o eclipse: a lua está na frente do sol.", c.noAlvo((s.dx + l.dx) / 2))
        }

        switch (sol, lua) {
        case (nil, nil):
            return (depois ? "Agora o sol e a lua já foram embora." : "Agora o sol e a lua ainda não apareceram.", 0.5)
        case (let s?, nil):
            return (depois ? "Agora a lua já saiu; o sol está saindo pela \(lado(s.dx))."
                           : "Agora o sol está entrando pela \(lado(s.dx)); a lua ainda não apareceu.", c.noAlvo(s.dx))
        case (nil, let l?):
            return (depois ? "Agora o sol já saiu; a lua está saindo pela \(lado(l.dx))."
                           : "Agora a lua está entrando pela \(lado(l.dx)); o sol ainda não apareceu.", c.noAlvo(l.dx))
        case (let s?, let l?):
            let x = c.noAlvo((s.dx + l.dx) / 2)
            let d = abs(s.dx - l.dx) / max(w, 1)
            let naBeira = c.naBeira(s.dx, w) || c.naBeira(l.dx, w)
            let eclipseCompleto = d <= max(eclipse, meio.d + 0.05)
            if eclipseCompleto { return ("Agora é o eclipse: a lua está na frente do sol.", x) }
            if !depois {
                if d <= quaseCompleto { return ("Agora a lua já cobre boa parte do sol: o eclipse está quase completo.", x) }
                if d <= encostando { return ("Agora estão formando o eclipse: a lua começa a passar na frente do sol.", x) }
                // Ainda não se sobrepõem: "prestes" se vão encostar daqui a pouco
                let vaiEncostar = (distancia(astros, c.relogio + prestes, c) ?? .greatestFiniteMagnitude) <= encostando
                if vaiEncostar { return ("Agora estão prestes a formar o eclipse.", x) }
                if naBeira {
                    return ("Agora o sol está entrando pela \(lado(s.dx)) e a lua pela \(lado(l.dx)).", x)
                }
                return ("Agora o sol, à \(lado(s.dx)), e a lua, à \(lado(l.dx)), vêm devagar um na direção do outro.", x)
            }
            if c.relogio - meio.t <= acabouDeFormar {
                return ("Agora acabaram de formar o eclipse e estão se separando.", x)
            }
            if naBeira {
                return ("Agora o sol está saindo pela \(lado(s.dx)) e a lua pela \(lado(l.dx)).", x)
            }
            return ("Agora já se cruzaram: o sol vai para a \(lado(s.dx)) e a lua para a \(lado(l.dx)).", x)
        }
    }

    // MARK: - Nuvens e passarinhos

    // Uma peça do céu que está na tela agora: onde está e para onde vai
    private struct Passando {
        let dx: CGFloat
        let y: CGFloat
        let indoX: CGFloat     // quanto anda para o lado nos próximos segundos
        let indoY: CGFloat     // quanto desce (positivo) ou sobe (negativo)
        let naBeira: Bool
    }

    private static func passando(_ a: Floresta.Andante, _ c: Contexto) -> Passando? {
        guard let p = posicao(a, c.relogio, c), c.naTela(p.dx, a.largura) else { return nil }
        let adiante = posicao(a, c.relogio + olharAFrente, c) ?? p
        // Para o lado vale o sentido do caminho inteiro (de onde entra para onde sai): nas
        // curvinhas do caminho o passarinho volta um pouco, mas continua indo para o mesmo lado.
        let dentro = a.pontos.filter { $0.f > Floresta.foraEsquerda && $0.f < Floresta.foraDireita }
        let sentido = (dentro.last?.f ?? 1) - (dentro.first?.f ?? 0)
        let subida = adiante.y - p.y
        return Passando(dx: p.dx, y: p.y, indoX: sentido,
                        indoY: abs(subida) >= subidaMinima ? subida : 0,
                        naBeira: c.naBeira(p.dx, a.largura))
    }

    // "indo para a esquerda", "entrando pela direita", "saindo pela esquerda"
    private static func caminho(_ p: Passando) -> String {
        let vaiPara = p.indoX < 0 ? "esquerda" : "direita"
        guard p.naBeira else { return "indo para a \(vaiPara)" }
        // Na beira e indo para o meio: entrando; indo para fora: saindo
        let paraFora = (p.dx < 0) == (p.indoX < 0)
        return paraFora ? "saindo pela \(lado(p.dx))" : "entrando pela \(lado(p.dx))"
    }

    private static func nuvens(_ c: Contexto) -> (frase: String, x: CGFloat) {
        let astros = Floresta.astros(no: c.quadro)
        let sol = posicao(astros.sol, c.relogio, c)
        let lua = posicao(astros.lua, c.relogio, c)
        let vistas = Floresta.nuvens.compactMap { a in passando(a, c).map { (a, $0) } }
        guard !vistas.isEmpty else { return ("Agora não há nuvens no céu.", 0.5) }

        func descricao(_ a: Floresta.Andante, _ p: Passando) -> String {
            let altura = p.y < 800 ? "no alto" : "baixo, perto das árvores"
            // As nuvens são desenhadas na frente do sol e da lua
            func naFrente(_ astro: (dx: CGFloat, y: CGFloat)?) -> Bool {
                guard let astro else { return false }
                return abs(p.dx - astro.dx) < (a.largura + astros.sol.largura) / 2 * 0.8
                    && abs(p.y - astro.y) < (a.alturaNaTela + astros.sol.alturaNaTela) / 2 * 0.8
            }
            let frenteSol = naFrente(sol), frenteLua = naFrente(lua)
            let frente = frenteSol && frenteLua ? ", na frente do sol e da lua"
                : frenteSol ? ", na frente do sol" : frenteLua ? ", na frente da lua" : ""
            return "\(altura), \(caminho(p))\(frente)"
        }

        let x = c.noAlvo(vistas[0].1.dx)
        if vistas.count == 1 {
            return ("Agora uma nuvem passa \(descricao(vistas[0].0, vistas[0].1)).", x)
        }
        let partes = vistas.map { descricao($0.0, $0.1) }
        return ("Agora \(numero(vistas.count)) nuvens passam: uma \(partes[0]); outra \(partes.dropFirst().joined(separator: "; outra ")).", x)
    }

    private static func passarinhos(_ c: Contexto) -> (frase: String, x: CGFloat) {
        let vistos = Floresta.passarinhos.compactMap { passando($0, c) }
        guard let primeiro = vistos.first else { return ("Agora não há passarinhos no céu.", 0.5) }

        func descricao(_ p: Passando) -> String {
            let deOnde = p.indoX < 0 ? "da direita para a esquerda" : "da esquerda para a direita"
            let altura = p.indoY > 0 ? ", descendo" : p.indoY < 0 ? ", subindo" : ""
            if p.naBeira { return "\(caminho(p))\(altura)" }
            return "\(deOnde)\(altura)"
        }

        let x = c.noAlvo(primeiro.dx)
        if vistos.count == 1 {
            let p = primeiro
            let verbo = p.naBeira ? "está" : "voa"
            return ("Agora um passarinho \(verbo) \(descricao(p)).", x)
        }
        return ("Agora \(numero(vistos.count)) passarinhos voam: \(vistos.map(descricao).joined(separator: "; ")).", x)
    }

    // MARK: - Coração

    private static func coracao(_ c: Contexto) -> String {
        guard let p = Floresta.passagemDoCoracao(c.relogio) else { return "Agora ele não está na cena." }
        let fps = ArteAnimada.fpsPadrao
        let abrir = Double(ArteAnimada.quadros("florestaCoracaoEntrada")) / fps
        let fechar = Double(ArteAnimada.quadros("florestaCoracaoSaida")) / fps
        let r = c.relogio
        if r < p.chega { return "Agora ele está descendo do alto." }
        if r < p.chega + abrir { return "Agora ele está parado em cima da vela, abrindo as fitas." }
        if r < p.sai - fechar { return "Agora ele está parado em cima da vela, com as fitas abertas." }
        if r < p.sai { return "Agora ele está fechando as fitas." }
        return "Agora ele está subindo e indo embora pelo alto."
    }

    // MARK: - Coelho

    private static func coelho(_ c: Contexto) -> (frase: String, x: CGFloat) {
        let foraDaCena = c.reduzirMovimento ? "Agora ele não está na cena." : "Agora ele não está na cena, logo volta."
        guard let coelho = Floresta.coelho(c.relogio, larguraVisivel: c.larguraVisivel) else {
            // Sai pela direita no fim da ida e pela esquerda no fim da volta
            return (foraDaCena, c.relogio < Floresta.agenda.coracao ? 0.9 : 0.1)
        }
        let fracao = c.fracao(coelho.dx)
        guard fracao > 0, fracao < 1 else { return (foraDaCena, fracao < 0.5 ? 0.1 : 0.9) }
        let frase: String
        if c.reduzirMovimento {
            frase = "Agora ele está sentado, parado."
        } else if coelho.quadro.hasPrefix("florestaCoelhoPulo") {
            frase = "Agora ele está pulando."
        } else {
            frase = "Agora ele está sentado."
        }
        return (frase, min(0.9, max(0.1, fracao)))
    }
}
