//  Floresta.swift
//  O cenário novo da Georgia: a floresta, montada igual ao mockup dela (IMG_3976).
//
//  COMO FOI MONTADO
//  A Georgia desenhou a floresta numa tela DEITADA de 2732 × 2048 (a tela do iPad deitado).
//  Todas as medidas aqui estão nessa tela ("pixels da Georgia"). Ela é encaixada pela ALTURA:
//    - iPad: aparece a floresta inteira (deitado) e ela fica PARADA; só o céu se mexe.
//    - iPhone: a mata forma um rolo contínuo (como uma câmera passando). O céu (sol, lua,
//      nuvens, pássaros, estrelas, coração) faz o mesmo roteiro do iPad, na tela do iPhone.
//  Com a vela APAGADA a floresta não aparece (o palco fica escuro); ela surge ao acender.
//
//  Camadas, de trás para a frente (igual ao mockup):
//    fundo (céu + silhuetas bem apagadas) → árvores azul-escuras → árvores cinza (com contorno)
//    → estrelas → SOL e LUA (eclipse) → nuvens → coração → arbustos → coelho → passarinhos
//
//  O ROTEIRO segue o animatic da Georgia (5 min no vídeo = 10 min no app, em loop).
//  Ele só anda com a vela acesa. A lua vem da esquerda e o sol da direita, devagar, e eles
//  se encontram no ECLIPSE (4:52 do app); depois se cruzam e saem pelos lados. O coração desce,
//  abre as fitas e sobe (duas vezes), as nuvens e os passarinhos atravessam, o coelho pula
//  pelo chão e as estrelas vão aparecendo e depois somem. No fim só sobra a floresta.
//  Os pontos de cada peça estão na seção "Roteiro" logo abaixo.
//
//  Se "florestaFundo" não estiver no Assets, o app volta para a tenda do circo.

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum Floresta {
    // Tela em que a Georgia desenhou a floresta
    static let largura: CGFloat = 2732
    static let altura: CGFloat = 2048

    // ⚙️ Qual x da floresta fica no MEIO da tela (1366 = o meio da floresta)
    static let centroX: CGFloat = 1366

    // Quanto a floresta cresce para ocupar a altura do Quadro
    static let escala: CGFloat = Quadro.altura / altura

    // A floresta está no Assets? (a conta é feita uma vez e guardada)
    static let ligada: Bool = arteExiste("florestaFundo")

    // A COMPOSIÇÃO É UMA SÓ (o mockup da Georgia com o iPhone no meio do iPad): o iPad mostra a
    // floresta inteira e o iPhone é uma JANELA no meio dela, na MESMA escala. Por isso as árvores,
    // as cores e o tamanho dos elementos são iguais nos dois; só muda quanto da floresta aparece.

    // ⚙️ Estrelas (na referência elas são um pouco maiores que o desenho)
    static let aumentoDosElementos: CGFloat = 1.1

    // Só o iPhone desliza a floresta. No iPad ela fica parada (só o céu se mexe).
    static var desliza: Bool {
        #if canImport(UIKit)
        UIDevice.current.userInterfaceIdiom == .phone
        #else
        false
        #endif
    }


    // Pixels da Georgia → pixels do Quadro (o mesmo sistema da vela e do resto do palco)
    static func noQuadro(x: CGFloat) -> CGFloat { Quadro.largura / 2 + (x - centroX) * escala }
    static func noQuadro(y: CGFloat) -> CGFloat { y * escala }

    // Onde começa o céu (o alto do eclipse), em fração da altura da tela.
    // O teatro de sombras usa isso para o eclipse nunca sumir atrás da cortina de cima.
    static let topoDasSombras: CGFloat = 0.12

    // MARK: Camadas paradas

    struct Peca {
        let nome: String
        let x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat   // canto de cima, pixels da Georgia
        var tinta: Color = .white       // colorMultiply: escurece/azula a peça (branco = cor original)
        var espelho = false
        var sombra: CamadaDaSombra? = nil   // em qual camada ela faz sombra no teatro (nil = não faz)
    }

    // Cores (colorMultiply = cor desejada ÷ cor original da peça).
    // ⚙️ Árvores do fundo: ROXO-escuro (pedido da Georgia). Na referência o tronco é ~(24, 22, 32);
    // aqui ele fica um pouco mais roxo, ~(27, 22, 44).
    static let roxoDasArvoresDoFundo = Color(red: 0.24, green: 0.19, blue: 0.38)
    static let arbustoEscuroRef = Color(red: 0.57, green: 0.57, blue: 0.58)    // arbustos de trás


    static let fundo = Peca(nome: "florestaFundo", x: 0, y: 0, w: 2732, h: 2048)   // o céu de fundo não faz sombra

    // As árvores grandes nas posições em que a Georgia desenhou (iguais no iPhone e no iPad).
    // As cinza ficam na cor original; as do meio, roxo-escuras.
    static let arvores: [Peca] = [
        Peca(nome: "florestaFundoArvores2", x: 42, y: 660, w: 2522, h: 1381,
             tinta: roxoDasArvoresDoFundo, sombra: .arvoresDeTras),
        Peca(nome: "florestaFundoArvores1", x: 42, y: 408, w: 2655, h: 1598,
             sombra: .arvoresDaFrente)
    ]

    // A Georgia mandou dois arbustos; do lado direito eles se repetem espelhados (como no mockup).
    // Os de trás um pouco escurecidos, os da frente na cor original.
    // Os dois do MEIO estão virados (pedido da Georgia): o lado mais alto de cada um fica para fora
    // e a parte baixa se encontra no meio, embaixo da vela.
    static let arbustos: [Peca] = [
        Peca(nome: "florestaArbusto1", x: 0, y: 1426, w: 1158, h: 622, tinta: arbustoEscuroRef, sombra: .arbustos),
        Peca(nome: "florestaArbusto1", x: 1574, y: 1426, w: 1158, h: 622, tinta: arbustoEscuroRef, espelho: true,
             sombra: .arbustos),
        Peca(nome: "florestaArbusto2", x: 474, y: 1691, w: 1144, h: 357, espelho: true, sombra: .arbustos),
        Peca(nome: "florestaArbusto2", x: 1114, y: 1691, w: 1144, h: 357, sombra: .arbustos)
    ]

    // MARK: Roteiro (animatic da Georgia)
    //
    // Tudo o que anda segue o ANIMATIC dela ("animaticqualidade baixa.mp4", 5 min).
    // No animatic aparecem 3 telas de iPhone lado a lado = a floresta inteira (o iPad deitado).
    // Cada peça tem PONTOS de passagem medidos nos quadros do vídeo:
    //   t: segundos do roteiro do app (o animatic tem 5 min e o app 10 min, então t = tempo do vídeo × 2)
    //   f: onde ela está na largura da FLORESTA INTEIRA (as 3 telas do animatic):
    //      0 = borda esquerda, 0.5 = meio, 1 = borda direita
    //      (Floresta.foraEsquerda / foraDireita = inteira fora da floresta)
    //   y: altura do centro, em pixels da Georgia
    // O iPad mostra a floresta inteira (o animatic todo). O iPhone é a TELA DO MEIO do animatic:
    // ele vê só o terço do meio, então só aparece o que passa por ali, na ordem e no ritmo do
    // vídeo (as peças não correm mais para caber na tela pequena).

    struct Ponto {
        let t: Double
        let f: CGFloat
        let y: CGFloat
        init(_ t: Double, _ f: CGFloat, _ y: CGFloat) { self.t = t; self.f = f; self.y = y }
    }

    static let foraEsquerda: CGFloat = -1000
    static let foraDireita: CGFloat = 1000

    // f → distância até o meio da tela, em pixels da Georgia (tamanho: largura da peça).
    // A conta é sempre na floresta inteira (2732), igual no iPhone e no iPad. Num iPad mais largo
    // que a floresta, usa a tela toda.
    static func distanciaDoMeio(_ f: CGFloat, larguraVisivel: CGFloat, tamanho: CGFloat) -> CGFloat {
        let w = max(larguraVisivel, largura)
        if f <= foraEsquerda { return -(w + tamanho) / 2 - 20 }
        if f >= foraDireita { return (w + tamanho) / 2 + 20 }
        return (f - 0.5) * w
    }

    // Onde a peça está no instante t: uma curva suave (Catmull-Rom) passando pelos pontos.
    // Devolve a distância até o meio e o y. nil = fora do roteiro dela.
    static func posicao(_ pontos: [Ponto], _ t: Double, larguraVisivel: CGFloat,
                        tamanho: CGFloat) -> (dx: CGFloat, y: CGFloat)? {
        guard let primeiro = pontos.first, let ultimo = pontos.last,
              t >= primeiro.t, t <= ultimo.t else { return nil }
        let i = max(0, (pontos.lastIndex(where: { $0.t <= t }) ?? 0))
        let j = min(i + 1, pontos.count - 1)
        func dx(_ k: Int) -> CGFloat {
            distanciaDoMeio(pontos[max(0, min(k, pontos.count - 1))].f, larguraVisivel: larguraVisivel, tamanho: tamanho)
        }
        func y(_ k: Int) -> CGFloat { pontos[max(0, min(k, pontos.count - 1))].y }
        let duracao = pontos[j].t - pontos[i].t
        let s = CGFloat(duracao > 0 ? (t - pontos[i].t) / duracao : 0)
        return (catmullRom(dx(i - 1), dx(i), dx(j), dx(j + 1), s),
                catmullRom(y(i - 1), y(i), y(j), y(j + 1), s))
    }

    static func catmullRom(_ p0: CGFloat, _ p1: CGFloat, _ p2: CGFloat, _ p3: CGFloat, _ s: CGFloat) -> CGFloat {
        let s2 = s * s, s3 = s2 * s
        return 0.5 * (2 * p1 + (p2 - p0) * s + (2 * p0 - 5 * p1 + 4 * p2 - p3) * s2 + (3 * p1 - p0 - 3 * p2 + p3) * s3)
    }

    // NAS SOMBRAS a camada encolhe na parede (só o que está perto da tela visível importa). Perto do meio a sombra fica IGUAL ao cenário
    // (o eclipse acontece na mesma hora nos dois); para as bordas o caminho vai abrindo até a
    // peça nascer e sumir FORA da parede (e não no meio dela).
    static func esticar(_ dx: CGFloat, larguraVisivel: CGFloat, percurso: CGFloat?, tamanho: CGFloat) -> CGFloat {
        guard let percurso, percurso > larguraVisivel else { return dx }
        let meia = (larguraVisivel + tamanho) / 2
        let u = min(1.3, abs(dx) / max(meia, 1))
        let k = (percurso + tamanho) / (larguraVisivel + tamanho)
        return dx * (1 + (k - 1) * u * u)
    }

    // MARK: Estrelas
    // No animatic as estrelas vão chegando (a partir de 0:15), chegam a umas 7 no meio da história
    // e depois vão embora; no fim só sobra a floresta.
    // REGRA: estrela NÃO aparece nem some no lugar (sem transparência). Ela só SOBE e DESCE:
    // chega descendo do alto da tela e vai embora subindo até sair pelo alto. Enquanto está em
    // cena, fica inteira abaixo da barra de cima (em qualquer aparelho) e balança de leve.
    struct Estrela {
        let nome: String
        let altura: CGFloat
        let fase: Double
        let pontos: [Ponto]
    }

    static let estrelas: [Estrela] = [
        // A estrela grande: perto do coração no começo…
        Estrela(nome: "florestaEstrela1", altura: 150, fase: 0, pontos: [
            Ponto(30, 0.42, 140), Ponto(40, 0.42, 250), Ponto(60, 0.42, 456), Ponto(90, 0.42, 328),
            Ponto(140, 0.45, 160)]),
        // …e de novo no eclipse: desce até o meio dele e volta a subir
        Estrela(nome: "florestaEstrela1", altura: 150, fase: 1.1, pontos: [
            Ponto(240, 0.57, 243), Ponto(260, 0.57, 595), Ponto(290, 0.57, 850), Ponto(310, 0.57, 580),
            Ponto(350, 0.57, 110)]),
        // Direita: desce do alto até perto das árvores, fica, e no fim sobe e sai pelo alto
        Estrela(nome: "florestaEstrela2", altura: 104, fase: 2.3, pontos: [
            Ponto(30, 0.84, 80), Ponto(60, 0.84, 273), Ponto(90, 0.85, 480), Ponto(180, 0.88, 1120),
            Ponto(210, 0.9, 1330), Ponto(390, 0.9, 1200), Ponto(420, 0.89, 850), Ponto(480, 0.87, 638),
            Ponto(510, 0.86, 443), Ponto(560, 0.85, 400), Ponto(575, 0.84, 40)]),
        // Esquerda: o mesmo, do outro lado
        Estrela(nome: "florestaEstrela2", altura: 100, fase: 3.7, pontos: [
            Ponto(60, 0.21, 152), Ponto(90, 0.21, 420), Ponto(120, 0.23, 577), Ponto(180, 0.26, 1000),
            Ponto(210, 0.26, 1240), Ponto(360, 0.26, 1300), Ponto(450, 0.23, 720), Ponto(480, 0.23, 547),
            Ponto(510, 0.21, 290), Ponto(560, 0.21, 290), Ponto(575, 0.21, 40)]),
        // Pequenas que aparecem no meio da história
        Estrela(nome: "florestaEstrela1", altura: 96, fase: 4.4, pontos: [
            Ponto(150, 0.5, 430), Ponto(240, 0.52, 1063), Ponto(330, 0.52, 900), Ponto(345, 0.5, 700)]),
        Estrela(nome: "florestaEstrela2", altura: 92, fase: 5.2, pontos: [
            Ponto(150, 0.81, 152), Ponto(360, 0.8, 150), Ponto(400, 0.8, 60)]),
        Estrela(nome: "florestaEstrela1", altura: 90, fase: 0.6, pontos: [
            Ponto(180, 0.14, 182), Ponto(360, 0.15, 456), Ponto(420, 0.14, 91), Ponto(430, 0.14, 40)])
    ]

    // ⚙️ Segundos que a estrela leva para descer do alto até o lugar dela (e para subir e sair)
    static let descidaDaEstrela: Double = 20

    // O caminho inteiro da estrela: desce de fora (acima da tela) → os pontos do roteiro
    // (nunca acima de minimoY) → sobe e sai pelo alto.
    static func caminho(da e: Estrela, minimoY: CGFloat, foraY: CGFloat) -> [Ponto] {
        guard let primeiro = e.pontos.first, let ultimo = e.pontos.last else { return [] }
        let meio = e.pontos.map { Ponto($0.t, $0.f, max($0.y, minimoY)) }
        return [Ponto(primeiro.t - descidaDaEstrela, primeiro.f, foraY)] + meio
            + [Ponto(ultimo.t + descidaDaEstrela, ultimo.f, foraY)]
    }

    // MARK: Sol, lua, nuvens e passarinhos

    // Peça que anda no céu (sol, lua, nuvem, passarinho)
    struct Andante {
        let peca: PecaAnimada
        let altura: CGFloat     // altura da peça, pixels da Georgia
        let pontos: [Ponto]
        var balanco: CGFloat = 0
        var fase: Double = 0

        var astro = false             // sol e lua têm o tamanho calculado à parte
        var aumento: CGFloat = 1.1   // ⚙️ quanto a peça cresce em relação ao desenho (medido na referência)
        // Tamanho desenhado
        var alturaNaTela: CGFloat { astro ? altura : altura * aumento }
        var largura: CGFloat { alturaNaTela * peca.peca.width / peca.peca.height }
    }

    // SOL E LUA (animatic): ficam em cena quase a história inteira. A lua entra pela esquerda e o
    // sol pela direita; andam devagar até o meio e se encontram no ECLIPSE (2:26 do animatic =
    // 4:52 do app); depois se cruzam, continuam (o sol para a esquerda e a lua para a direita)
    // e saem pelos lados (4:40 do animatic = 9:20 do app).
    static let instanteDoEclipse: Double = 292

    // A primeira linha livre do céu, logo abaixo da barra de cima (botões), em pixels da Georgia.
    // Vale para qualquer iPhone ou iPad: usa a área segura do aparelho (quadro.origem) e o
    // tamanho real da barra.
    static func topoLivre(no quadro: Quadro) -> CGFloat {
        let escalaNaTela = escala * quadro.escala
        let fimDaBarra = MedidasBarraDoPalco.margemSuperior + MedidasBarraDoPalco.diametro
        return max(altura * topoDasSombras, (fimDaBarra + 8 - quadro.origem.y) / max(escalaNaTela, 0.001))
    }

    static func astros(no quadro: Quadro) -> (sol: Andante, lua: Andante) {
        let topo = topoLivre(no: quadro)
        // Os astros terminam acima das copas. Reservamos espaço para o balanço nas duas extremidades.
        let balanco: CGFloat = 8
        // O tamanho e a altura da referência (lua ~770 de altura, centro em ~742). Numa tela onde
        // não cabe entre a barra de cima e a chama da vela (no tamanho padrão), ela diminui o
        // necessário para caber inteira: nunca é cortada pela barra nem cobre a chama.
        let alturaRef: CGFloat = 770, centroRef: CGFloat = 742
        let limite = topoDaChamaPadrao - 20
        let cabe = max(200, limite - topo - 2 * balanco)
        let alturaDaLua = min(alturaRef, cabe), alturaDoSol = alturaDaLua
        let y = max(topo + balanco + alturaDaLua / 2, min(centroRef, limite - balanco - alturaDaLua / 2))
        let e = instanteDoEclipse
        let lua = [Ponto(0, foraEsquerda, y), Ponto(60, 0.0, y), Ponto(120, 0.12, y), Ponto(180, 0.24, y),
                   Ponto(240, 0.37, y), Ponto(e, 0.465, y), Ponto(360, 0.67, y), Ponto(420, 0.83, y),
                   Ponto(480, 0.99, y), Ponto(560, foraDireita, y)]
        let sol = [Ponto(0, foraDireita, y), Ponto(60, 1.01, y), Ponto(120, 0.89, y), Ponto(180, 0.77, y),
                   Ponto(240, 0.64, y), Ponto(e, 0.545, y), Ponto(360, 0.34, y), Ponto(420, 0.17, y),
                   Ponto(480, -0.02, y), Ponto(560, foraEsquerda, y)]
        var s = Andante(peca: CenarioNovo.sol, altura: alturaDoSol, pontos: sol, balanco: balanco, fase: 1.3)
        var l = Andante(peca: CenarioNovo.lua, altura: alturaDaLua, pontos: lua, balanco: balanco)
        s.astro = true
        l.astro = true
        return (s, l)
    }

    // NUVENS (animatic): só duas, bem lentas.
    // A de baixo vai da esquerda para a direita junto com a lua (0:55–2:10 do animatic);
    // a de cima vem da direita, passa por cima do sol e sai pela esquerda (1:15–2:40).
    static let nuvens: [Andante] = [
        Andante(peca: CenarioNovo.nuvem1, altura: 144, pontos: [
            Ponto(100, foraEsquerda, 1110), Ponto(120, 0.04, 1110), Ponto(160, 0.28, 1100),
            Ponto(180, 0.5, 1110), Ponto(200, 0.77, 1110), Ponto(230, 0.91, 1080), Ponto(250, 0.97, 1110),
            Ponto(262, foraDireita, 1110)],
                balanco: 4, fase: 2.5, aumento: 2.0),
        Andante(peca: CenarioNovo.nuvem2, altura: 136, pontos: [
            Ponto(150, foraDireita, 360), Ponto(170, 0.94, 352), Ponto(190, 0.87, 395), Ponto(200, 0.76, 365),
            Ponto(220, 0.64, 480), Ponto(240, 0.42, 456), Ponto(260, 0.26, 577), Ponto(280, 0.16, 626),
            Ponto(300, 0.02, 638), Ponto(320, foraEsquerda, 600)],
                balanco: 5, fase: 1.1)
    ]

    // PASSARINHOS (animatic): o primeiro vem do alto à esquerda, desce, cruza a floresta e sai
    // pela direita subindo (0:00–1:37). O segundo vem da direita, desce pelo eclipse, passa
    // perto do sol e sai pela esquerda (2:05–3:40).
    static let passarinhos: [Andante] = [
        Andante(peca: CenarioNovo.passarinho, altura: 214, pontos: [
            Ponto(0, foraEsquerda, 273), Ponto(10, 0.01, 365), Ponto(20, 0.06, 425), Ponto(30, 0.14, 717),
            Ponto(40, 0.22, 850), Ponto(50, 0.27, 990), Ponto(60, 0.33, 1063), Ponto(80, 0.38, 1000),
            Ponto(100, 0.46, 1063), Ponto(120, 0.57, 970), Ponto(140, 0.67, 760), Ponto(160, 0.84, 500),
            Ponto(180, 0.99, 425), Ponto(195, foraDireita, 365)],
                balanco: 4, fase: 0.7, aumento: 1.85),
        Andante(peca: CenarioNovo.passarinho2, altura: 202, pontos: [
            Ponto(250, foraDireita, 425), Ponto(270, 0.94, 413), Ponto(280, 0.89, 535), Ponto(290, 0.79, 626),
            Ponto(300, 0.71, 760), Ponto(310, 0.63, 970), Ponto(320, 0.52, 1124), Ponto(330, 0.49, 1209),
            Ponto(340, 0.47, 1100), Ponto(350, 0.44, 1027), Ponto(360, 0.41, 1124), Ponto(380, 0.31, 1020),
            Ponto(400, 0.17, 1233), Ponto(410, 0.06, 1264), Ponto(420, 0.06, 1124), Ponto(430, -0.03, 1030),
            Ponto(440, foraEsquerda, 547)],
                balanco: 4, fase: 2.1, aumento: 1.85)
    ]

    // O roteiro não tem mais câmera lenta no eclipse (o animatic anda num ritmo só):
    // o sol e a lua já passam bem devagar e ficam um bom tempo um na frente do outro.
    static func tempoDoCenario(_ tempo: Double) -> Double {
        tempo.truncatingRemainder(dividingBy: RelogioDaHistoria.ciclo)
    }

    // Onde fica o alto da chama com a vela no tamanho padrão (pixels da Georgia).
    // Vem das medidas da arte da vela (ArteVela): pavio da vela padrão menos a altura da chama.
    static var topoDaChamaPadrao: CGFloat {
        let cheia = GeometriaVela.alturaCheia(posicao: VelaConfig().posicaoSlider, alturaMaxima: ArteVela.alturaMaxima)
        let pavio = ArteVela.baseY - cheia
        return (pavio - (ArteVela.chamaAltura - ArteVela.chamaDentro)) / escala
    }

    // MARK: Coração
    // O CORAÇÃO "The lovers": aparece duas vezes, nos momentos do animatic (0:03–1:25 e 3:22–4:58
    // do vídeo). A ORDEM (pedido da Georgia): ele DESCE até parar → SÓ ENTÃO abre as fitas →
    // fica parado → FECHA as fitas → SÓ ENTÃO sobe e sai pelo alto. Nunca anda com as fitas abertas.
    struct PassagemDoCoracao {
        let pontos: [(t: Double, y: CGFloat)]   // y = centro, pixels da Georgia (fora = acima da tela)
        let chega: Double     // quando as fitas abrem
        let sai: Double       // quando as fitas terminam de fechar
        var inicio: Double { pontos.first?.t ?? 0 }
        var fim: Double { pontos.last?.t ?? 0 }
    }

    struct Coracao {
        let nome = "florestaCoracao"
        let w: CGFloat = 720, h: CGFloat = 566     // tamanho desenhado, pixels da Georgia
        var fora: CGFloat { -h / 2 - 40 }          // inteiro acima da tela
        var passagens: [PassagemDoCoracao] {
            // Centro parado: 0,40 da altura (medido na tela do meio do animatic em alta).
            // Entre dois pontos ele anda suave (começa e termina devagar) e fica parado quando dois
            // pontos seguidos têm o mesmo y. chega/sai: as fitas abrem logo depois de ele parar e
            // terminam de fechar antes de ele começar a subir.
            [PassagemDoCoracao(pontos: [(6, fora), (30, 820), (113, 820), (150, fora)], chega: 30.3, sai: 112.5),
             PassagemDoCoracao(pontos: [(404, fora), (432, 840), (563, 840), (596, fora)], chega: 432.3, sai: 562.5)]
        }
    }
    static let coracao = Coracao()
    // Onde fica o meio do corpo do coração dentro do desenho (fração da largura; medido na arte)
    static let meioDoCorpoDoCoracao: CGFloat = 0.552

    // O centro do coração nunca desce até a chama da vela (fica uma folga entre a ponta e a chama)
    static func limiteDoCoracao() -> CGFloat {
        topoDaChamaPadrao - 20 - coracao.h / 2
    }

    // Em qual das passagens o coração está agora (nil = fora de cena)
    static func passagemDoCoracao(_ relogio: Double) -> PassagemDoCoracao? {
        coracao.passagens.first(where: { relogio >= $0.inicio && relogio <= $0.fim })
    }

    // y do centro do coração agora: de um ponto ao outro, começando e terminando devagar
    // (sem passar do ponto: ele para exatamente no lugar, e só então as fitas abrem)
    static func yDoCoracao(_ p: PassagemDoCoracao, _ relogio: Double) -> CGFloat {
        let pts = p.pontos.map { (t: $0.t, y: min($0.y, limiteDoCoracao())) }
        guard let primeiro = pts.first, let ultimo = pts.last else { return coracao.fora }
        if relogio <= primeiro.t { return primeiro.y }
        if relogio >= ultimo.t { return ultimo.y }
        let j = pts.firstIndex(where: { $0.t > relogio }) ?? pts.count - 1
        let a = pts[j - 1], b = pts[j]
        let k = CGFloat((relogio - a.t) / max(b.t - a.t, 0.001))
        return a.y + (b.y - a.y) * k * k * (3 - 2 * k)
    }

    // MARK: Coelho
    // COELHO (animatic + vídeo "Coelhinho pronto"): fica sentado mexendo a orelha e a cabeça
    // e, de tempos em tempos, dá um pulo para o lado. No animatic ele atravessa a floresta pulando
    // da esquerda para a direita (0:00–1:35), some, e volta da direita para a esquerda (2:35–4:10).
    // Cada parada é (t, f): o instante em que ele CHEGA lá depois do pulo.
    // No iPhone o chão anda: sentado, o coelho anda junto com o chão (não escorrega). Ele passa
    // pelo lugar do animatic no MEIO do tempo sentado, para não se afastar muito do roteiro.
    struct Parada {
        let t: Double
        let f: CGFloat
        init(_ t: Double, _ f: CGFloat) { self.t = t; self.f = f }
    }

    static let caminhosDoCoelho: [[Parada]] = [
        [Parada(0, 0.01), Parada(10, 0.12), Parada(20, 0.26), Parada(70, 0.46), Parada(80, 0.61),
         Parada(130, 0.72), Parada(140, 0.94), Parada(190, foraDireita)],
        [Parada(300, foraDireita), Parada(310, 0.98), Parada(360, 0.92), Parada(370, 0.78), Parada(380, 0.62),
         Parada(420, 0.57), Parada(430, 0.42), Parada(440, 0.29), Parada(490, 0.14), Parada(500, foraEsquerda)]
    ]

    // Quadros extraídos do vídeo "Coelhinho pronto" (12 por segundo), todos do mesmo tamanho,
    // com o coelho no meio do quadro e os pés no mesmo lugar:
    //  - SENTADO (florestaCoelho_1…43): 0–6,9 s do vídeo. Até 5 s ele mexe a orelha e a cabeça;
    //    depois respira (41/42) e, no fim, se prepara para pular (43).
    //  - PULO e POUSO (florestaCoelhoPulo_1…25): 6,9–10 s do vídeo, na ordem de ritmoDoPulo.
    static let ritmoDoCoelhoSentado: [Int] = [
        1, 1, 2, 3, 3, 4, 5, 5, 6, 7, 7, 8, 9, 9, 10, 11, 11, 12, 13, 13, 14, 15, 15, 16, 17, 17, 18, 19, 19,
        20, 21, 21, 22, 23, 23, 24, 25, 25, 26, 27, 27, 28, 29, 29, 30, 31, 31, 32, 33, 33, 34, 35, 35, 36, 37,
        37, 38, 39, 39, 40, 41, 41, 41, 42, 42, 42, 41, 41, 41, 42, 42, 42, 41, 41, 41, 42, 42, 42, 41, 41, 41,
        43, 43]
    static let inicioDaRespiracao = 60      // a partir daqui (no ritmo acima) ele só respira: 41, 42…
    static let fimDaRespiracao = 81         // os 2 últimos (43) são a preparação do pulo
    static let ritmoDoPulo: [Int] = [
        1, 2, 2, 3, 4, 4, 5, 6, 6, 7, 8, 8, 9, 10, 10, 11, 12, 12, 13, 14, 14, 15, 16, 16, 17, 18, 18, 19,
        20, 20, 21, 22, 22, 23, 24, 24, 25]
    // Quanto do caminho ele já andou em cada quadro do pulo (medido no vídeo: o centro do coelho).
    // Começa devagar (ele agacha e toma impulso), voa rápido e chega devagar no pouso.
    static let progressoDoPulo: [CGFloat] = [
        0.048, 0.076, 0.076, 0.145, 0.168, 0.168, 0.216, 0.261, 0.261, 0.333, 0.397, 0.397, 0.545, 0.595,
        0.595, 0.688, 0.73, 0.73, 0.798, 0.858, 0.858, 0.913, 0.948, 0.948, 0.974, 1, 1, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1]
    // ⚙️ Velocidade do pulo (1 = igual ao vídeo; maior = mais rápido). Um pouco mais rápido que o
    // vídeo: as poses trocam mais seguido e o pulo fica mais vivo.
    static let velocidadeDoPulo: Double = 1.2
    // ⚙️ Quanto do tempo de cada pose é usado para misturar com a próxima (0 = troca seca,
    // 1 = mistura o tempo todo). Pouca mistura = sem "coelho duplo"; um pouco = sem tranco.
    static let misturaDoPulo: Double = 0.5
    static var duracaoDoPulo: Double { Double(ritmoDoPulo.count) / (12 * velocidadeDoPulo) }
    // Tamanho do quadro (1040 × 910 na tela de 3840 da Georgia → pixels da floresta)
    static let coelhoW: CGFloat = 740, coelhoH: CGFloat = 647
    static let pesDoCoelho: CGFloat = 1950       // onde os pés ficam (pixels da Georgia)
    // ⚙️ Quanto a sombra do coelho sobe na parede (pixels da Georgia)
    static let subidaDaSombraDoCoelho: CGFloat = 260
    static let pesNoQuadro: CGFloat = 863 / 910   // onde os pés ficam dentro do quadro (fração)

    // Qual quadro mostrar sentado (s = segundos desde que pousou, r = segundos até o próximo pulo).
    // Igual ao vídeo, que se repete: ele mexe a orelha e a cabeça (0–5 s), respira e se prepara
    // (5–6,9 s) e pula. Quando ele fica sentado mais tempo, a animação INTEIRA se repete (as orelhas
    // continuam mexendo), e a última repetição termina exatamente na hora do pulo, no mesmo quadro
    // em que o pulo começa no vídeo. O que sobra de tempo vai logo depois do pouso, respirando.
    static func quadroSentado(desde s: Double, faltam r: Double) -> Int {
        let n = ritmoDoCoelhoSentado.count                    // 83 quadros = 6,9 s
        let total = max(0, Int(((s + r) * 12).rounded()))     // quadros sentado nesta parada
        let i = min(max(0, Int(s * 12)), max(total - 1, 0))
        let sobra = total % n
        if i < sobra {
            // respirando (41, 42…), a mesma pose parada do vídeo
            let ciclo = fimDaRespiracao - inicioDaRespiracao
            return ritmoDoCoelhoSentado[inicioDaRespiracao + i % ciclo]
        }
        return ritmoDoCoelhoSentado[(i - sobra) % n]
    }

    // Velocidade do chão no iPhone (pixels da Georgia por segundo; no iPad o chão é parado)
    static var velocidadeDoChao: CGFloat { desliza ? 2 * largura / CGFloat(RelogioDaHistoria.ciclo) : 0 }

    // Onde o coelho está, qual quadro e para que lado olha. nil = fora de cena.
    // As POSES diferentes do pulo, na ordem: em que instante do vídeo cada uma aparece e quanto do
    // caminho o coelho já andou nela. (No vídeo cada pose fica parada 1 ou 2 quadros, a 12 por
    // segundo: só umas 8 trocas por segundo, por isso o pulo parecia "travado".)
    static let posesDoPulo: [(quadro: Int, instante: Double, andou: CGFloat)] = {
        var poses: [(quadro: Int, instante: Double, andou: CGFloat)] = []
        for (i, q) in ritmoDoPulo.enumerated() where poses.last?.quadro != q {
            poses.append((q, Double(i) / 12, progressoDoPulo[i]))
        }
        return poses
    }()

    // Onde o coelho está, o que desenhar e para que lado olha. nil = fora de cena.
    // quadro/proximo/mistura: no pulo, a pose de agora vai se MISTURANDO com a próxima
    // (mistura 0 → 1), para o movimento ficar contínuo entre um desenho e outro.
    static func coelho(_ t: Double, larguraVisivel: CGFloat)
        -> (dx: CGFloat, quadro: String, proximo: String?, mistura: CGFloat, paraDireita: Bool)? {
        let tamanho = coelhoW * 0.5
        for paradas in caminhosDoCoelho {
            guard let primeira = paradas.first, let ultima = paradas.last,
                  t >= primeira.t, t < ultima.t else { continue }
            let v = velocidadeDoChao
            func lugar(_ p: Parada) -> CGFloat { distanciaDoMeio(p.f, larguraVisivel: larguraVisivel, tamanho: tamanho) }
            // Quando o coelho pula para sair da parada k (fim do tempo sentado)
            func comecaPulo(_ k: Int) -> Double {
                k + 1 < paradas.count ? max(paradas[k].t, paradas[k + 1].t - duracaoDoPulo) : paradas[k].t
            }
            // Onde ele está sentado na parada k, no instante t (anda com o chão)
            func sentado(_ k: Int, _ t: Double) -> CGFloat {
                let meio = (paradas[k].t + comecaPulo(k)) / 2
                return lugar(paradas[k]) - v * CGFloat(t - meio)
            }
            for k in 0..<(paradas.count - 1) {
                let a = paradas[k], b = paradas[k + 1]
                guard t >= a.t, t < b.t else { continue }
                let paraDireita = b.f > a.f
                let pulo = comecaPulo(k)
                if t < pulo {
                    let q = quadroSentado(desde: t - a.t, faltam: pulo - t)
                    return (sentado(k, t), "florestaCoelho_\(q)", nil, 0, paraDireita)
                }
                // O PULO: cada pose aparece no instante do vídeo e vai se misturando com a próxima;
                // o caminho segue a velocidade do vídeo (devagar no impulso, rápido no ar, devagar no
                // pouso). Assim não tem tranco nem entre os desenhos nem no deslocamento.
                let poses = posesDoPulo
                let agora = (t - pulo) * velocidadeDoPulo
                let i = max(0, (poses.lastIndex(where: { $0.instante <= agora }) ?? 0))
                let j = min(i + 1, poses.count - 1)
                let intervalo = poses[j].instante - poses[i].instante
                let fracao: Double = intervalo > 0 ? min(1, max(0, (agora - poses[i].instante) / intervalo)) : 0
                // o caminho anda o tempo todo; o desenho só se mistura no fim de cada pose (suave)
                let andou = poses[i].andou + (poses[j].andou - poses[i].andou) * CGFloat(fracao)
                let inicioDaMistura = 1 - misturaDoPulo
                let u = min(1, max(0, (fracao - inicioDaMistura) / max(misturaDoPulo, 0.001)))
                let m = CGFloat(u * u * (3 - 2 * u))
                let de = sentado(k, pulo), ate = sentado(k + 1, b.t)
                return (de + (ate - de) * andou, "florestaCoelhoPulo_\(poses[i].quadro)",
                        j != i ? "florestaCoelhoPulo_\(poses[j].quadro)" : nil, m, paraDireita)
            }
        }
        return nil
    }

    // Frequência que fecha o ciclo: "n" voltas completas em 10 minutos (balanços, estrelas…)
    static func onda(_ n: Double, _ relogio: Double, fase: Double = 0) -> Double {
        sin(2 * .pi * n * relogio / RelogioDaHistoria.ciclo + fase)
    }
}

// O RELÓGIO DA HISTÓRIA
// O roteiro tem 600 segundos de animação.
// Ela só anda com a vela ACESA: pausa quando a vela apaga e volta do zero com uma vela nova.
// A vista converte o tempo acumulado em tempo de cena conforme a largura visível.
@MainActor
enum RelogioDaHistoria {
    // ⚙️ Duração da história, em segundos
    static let ciclo: Double = 600

    private static var acumulado: TimeInterval = 0
    private static var acesaDesde: Date?
    #if DEBUG
    private static var velocidade: Double = 1
    #else
    private static let velocidade: Double = 1
    #endif

    static func acender(agora: Date = Date()) {
        guard acesaDesde == nil else { return }
        #if DEBUG
        atualizarVelocidadeDeTeste(agora: agora)
        #endif
        acesaDesde = agora
    }

    static func pausar(agora: Date = Date()) {
        guard acesaDesde != nil else { return }
        acumulado = tempo(em: agora)
        acesaDesde = nil
    }

    static func zerar() {
        acumulado = 0
        acesaDesde = nil
    }

    // Tempo acumulado de reprodução desde o início da história.
    static func tempo(em data: Date) -> Double {
        let decorrido = acesaDesde.map { max(0, data.timeIntervalSince($0)) } ?? 0
        return acumulado + decorrido * velocidade
    }

    #if DEBUG
    static func atualizarVelocidadeDeTeste(agora: Date = Date()) {
        let padrao = UserDefaults.standard
        let novaVelocidade = padrao.bool(forKey: Chaves.acelerarCenario)
            ? min(20, max(2, padrao.double(forKey: Chaves.velocidadeDoCenario)))
            : 1
        guard novaVelocidade != velocidade else { return }

        // Guarda a posição no ritmo anterior antes de começar a contar no novo.
        if acesaDesde != nil {
            acumulado = tempo(em: agora)
            acesaDesde = agora
        }
        velocidade = novaVelocidade
    }
    #endif
}

// A floresta inteira, desenhada dentro da cena (que já tem relógio e Quadro).
// sombra: só as silhuetas pretas (sem o fundo).
// acesa: com a vela apagada a floresta some.
struct FlorestaView: View {
    let quadro: Quadro
    let t: Double
    var sombra = false
    var acesa = true
    var camada: CamadaDaSombra? = nil   // no teatro: desenha só as sombras desta camada (nil = todas)

    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento

    // No cenário tudo aparece. Na sombra, só o que é da camada pedida.
    private func mostra(_ c: CamadaDaSombra?) -> Bool {
        guard sombra else { return true }
        guard let c else { return false }
        return camada == nil || camada == c
    }

    var body: some View {
        // O relógio da história só anda com a vela acesa. O cenário e as
        // sombras usam o mesmo, então andam juntos. Com "Reduzir movimento", tudo fica parado
        // no eclipse (a cena do mockup).
        let tempo = RelogioDaHistoria.tempo(em: Date(timeIntervalSinceReferenceDate: t))
        GeometryReader { geo in
            let larguraVisivel = geo.size.width / max(Floresta.escala * quadro.escala, 0.001)
            let astros = Floresta.astros(no: quadro)
            let relogio = reduzirMovimento ? Floresta.instanteDoEclipse : Floresta.tempoDoCenario(tempo)
            // Na parede a camada de sombra ENCOLHE (céu pela metade, por exemplo). Se as peças
            // entrassem e saíssem na borda da tela normal, a sombra delas nasceria e morreria no
            // meio da parede. Então, nas sombras, o caminho vai até onde a borda da tela cai
            // depois de encolher (com uma folga para o balanço da chama).
            // O relógio continua o mesmo: cenário e sombra passam pelo meio juntos.
            let percurso = sombra ? larguraVisivel / max(camada?.escala ?? 1, 0.1) * 1.2 : larguraVisivel
            ZStack {
                faixa(relogio, larguraVisivel: percurso) {
                    if !sombra { peca(Floresta.fundo) }
                    ForEach(Floresta.arvores.indices, id: \.self) { i in
                        let p = Floresta.arvores[i]
                        if mostra(p.sombra) { peca(p) }
                    }
                }
                if mostra(.ceu) {
                    estrelas(relogio, larguraVisivel, percurso)
                    andante(astros.sol, relogio, larguraVisivel, percurso)
                    andante(astros.lua, relogio, larguraVisivel, percurso)
                    ForEach(Floresta.nuvens.indices, id: \.self) { i in
                        andante(Floresta.nuvens[i], relogio, larguraVisivel, percurso)
                    }
                    coracao(relogio)
                }
                if mostra(.arbustos) {
                    faixa(relogio, larguraVisivel: percurso) {
                        ForEach(Floresta.arbustos.indices, id: \.self) { i in peca(Floresta.arbustos[i]) }
                    }
                }
                // O coelho continua na frente dos arbustos no cenário; na parede ele fica junto com o
                // céu (sombra nítida e com detalhes, como os elementos de cima, e não borrada como a mata)
                if mostra(.ceu) {
                    coelho(relogio, larguraVisivel, percurso)
                    ForEach(Floresta.passarinhos.indices, id: \.self) { i in
                        andante(Floresta.passarinhos[i], relogio, larguraVisivel, percurso)
                    }
                }
            }
        }
        .opacity(acesa || sombra ? 1 : 0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var escala: CGFloat { Floresta.escala * quadro.escala }

    // Recorta as peças só nas LATERAIS da tela. Em cima e embaixo não: o recorte de cima cortava
    // estrelas e passarinhos na altura da barra de status (a área segura do aparelho).
    static var recorteDosLados: some View { Rectangle().padding(.vertical, -4000) }

    // SOBREPOSIÇÃO (teatro de sombras): cada silhueta tem a sua própria transparência.
    // Onde uma passa na frente da outra (a lua na frente do sol, a nuvem na frente da lua),
    // a luz atravessa as duas e a sombra fica MAIS ESCURA, como na referência da Georgia.
    private var opacidadeDaSombra: Double { camada?.opacidade ?? 0.7 }

    // ⚙️ Sombra de papel recortado no cenário aceso (como no protótipo do circo da Georgia):
    // cada peça projeta uma sombra macia no que está atrás dela.
    // O tamanho da sombra é PROPORCIONAL ao tamanho da peça (fração da altura dela):
    // a lua grande faz uma sombra maior que uma estrelinha. raioMinimo em pixels da Georgia.
    // (Mais marcada, pedido da Georgia: dá para ver um elemento fazendo sombra no outro.)
    static let sombraDoPapel = (opacidade: 0.62, raio: CGFloat(0.024), x: CGFloat(0.008), y: CGFloat(0.024),
                                raioMinimo: CGFloat(6))

    // altura: altura da peça desenhada, em pixels da Georgia
    private func comSombraDePapel<V: View>(_ vista: V, altura: CGFloat, ativa: Bool = true) -> some View {
        let s = FlorestaView.sombraDoPapel
        let raio = max(s.raioMinimo, altura * s.raio)
        let passo = raio / s.raio   // (a mesma conta, para o deslocamento acompanhar o raio)
        // compositingGroup: a peça vira UMA folha só antes da sombra. Sem isso, cada pedaço
        // dela (o rosto animado do sol e da lua) fazia a própria sombra: era o quadrado na cara.
        return vista
            .compositingGroup()
            .shadow(color: .black.opacity(sombra || !ativa ? 0 : s.opacidade),
                    radius: raio * escala, x: passo * s.x * escala, y: passo * s.y * escala)
    }

    // Cada par de painéis fecha uma volta. O espelho une bordas idênticas.
    private func faixa<Conteudo: View>(_ relogio: Double, larguraVisivel: CGFloat,
                                       alternaEspelho: Bool = true,
                                       @ViewBuilder conteudo: () -> Conteudo) -> some View {
        let largura = Floresta.largura * escala
        let voltas = Floresta.desliza && !reduzirMovimento ? 2 * relogio / RelogioDaHistoria.ciclo : 0
        let painel = Int(floor(voltas))
        let fracao = voltas - Double(painel)
        let vizinhos = max(1, Int(ceil(larguraVisivel / Floresta.largura)))
        let centro = quadro.x(Floresta.noQuadro(x: Floresta.centroX))
        let painelDeArte = ZStack { conteudo() }
        return ZStack {
            ForEach(-vizinhos...vizinhos, id: \.self) { i in
                painelDeArte
                    .frame(width: largura, height: Floresta.altura * escala)
                    .clipped()
                    .scaleEffect(x: alternaEspelho && !(painel + i).isMultiple(of: 2) ? -1 : 1, y: 1)
                    .position(x: centro + (CGFloat(i) - fracao) * largura,
                              y: quadro.y(Quadro.altura / 2))
            }
        }
    }

    private func peca(_ p: Floresta.Peca) -> some View {
        let fundo = p.nome == Floresta.fundo.nome   // o céu de fundo não projeta sombra
        let vista = Image(p.nome)
            .resizable()
            .frame(width: p.w * Floresta.escala * quadro.escala, height: p.h * Floresta.escala * quadro.escala)
            .scaleEffect(x: p.espelho ? -1 : 1, y: 1)
            .colorMultiply(sombra ? .black : p.tinta)
        return comSombraDePapel(vista, altura: p.h, ativa: !fundo)
            .opacity(sombra ? opacidadeDaSombra : 1)
            .position(x: (p.x + p.w / 2) * escala, y: (p.y + p.h / 2) * escala)
    }

    // Uma peça do céu andando (sol, lua, nuvem, passarinho)
    @ViewBuilder
    private func andante(_ a: Floresta.Andante, _ relogio: Double, _ larguraVisivel: CGFloat,
                         _ percurso: CGFloat) -> some View {
        if let p = Floresta.posicao(a.pontos, relogio, larguraVisivel: larguraVisivel, tamanho: a.largura) {
            let dx = Floresta.esticar(p.dx, larguraVisivel: larguraVisivel,
                                      percurso: sombra ? percurso : nil, tamanho: a.largura)
            let balanco = reduzirMovimento ? 0 : a.balanco * CGFloat(Floresta.onda(57, relogio, fase: a.fase * 4))
            let vista = comSombraDePapel(
                // O rosto (olhos e bochechas) e os raios do sol andam no TEMPO REAL, no ritmo dos
                // vídeos da Georgia (12 quadros/s). Antes andavam no relógio da história, que no
                // eclipse ficava mais lento e, no teste acelerado, corria junto.
                // Na parede o desenho vira sombra COM os detalhes (rosto, raios, penas), como na
                // referência da Georgia: o rosto do sol e da lua aparece dentro da sombra.
                PecaAnimadaView(peca: a.peca, t: t, fase: a.fase)
                    .frame(width: a.largura * escala, height: a.alturaNaTela * escala)
                    .modifier(TomDaSombraDoCeu(ativo: sombra)),
                altura: a.alturaNaTela)
                .opacity(sombra ? opacidadeDaSombra : 1)
                .position(x: quadro.x(Floresta.noQuadro(x: Floresta.centroX + dx)),
                          y: quadro.y(Floresta.noQuadro(y: p.y + balanco)))
            // Na parede NÃO recorta: a camada encolhe depois, e o recorte cortaria a sombra
            // no meio da tela (era o sol "cortado" numa linha reta).
            if sombra { vista } else { vista.mask(FlorestaView.recorteDosLados) }
        }
    }

    // O coração: desce do alto no meio da tela, abre as fitas, vai subindo e sai pelo alto
    @ViewBuilder
    private func coracao(_ relogio: Double) -> some View {
        if let p = Floresta.passagemDoCoracao(relogio) {
            let c = Floresta.coracao
            let balanco = reduzirMovimento ? 0 : 6 * CGFloat(Floresta.onda(57, relogio, fase: 0.9))
            let y = Floresta.yDoCoracao(p, relogio) + balanco
            comSombraDePapel(Image(nomeDoCoracao(relogio, passagem: p))
                .resizable()
                .frame(width: c.w * escala, height: c.h * escala)
                .modifier(TomDaSombraDoCeu(ativo: sombra)),
                altura: c.h)
                .opacity(sombra ? opacidadeDaSombra : 1)
                // Alinhado com a VELA: o corpo vermelho do coração fica bem em cima dela.
                // (No desenho o corpo não está no meio da imagem: fica 5% para a direita, e a vela
                // também não está exatamente no meio da tela.)
                .position(x: quadro.x(ArteVela.centroX) - (Floresta.meioDoCorpoDoCoracao - 0.5) * c.w * escala,
                          y: quadro.y(Floresta.noQuadro(y: y)))
        }
    }

    // Qual desenho do coração mostrar (vídeos "Coração entrada" e "Coração saída" da Georgia):
    // desce sem as fitas → as fitas abrem quando ele chega → fica aberto → as fitas fecham → sobe.
    // Todos os quadros têm o mesmo tamanho e o coração no mesmo lugar.
    private func nomeDoCoracao(_ relogio: Double, passagem p: Floresta.PassagemDoCoracao) -> String {
        let c = Floresta.coracao
        let fps = ArteAnimada.fpsPadrao
        let entrada = ArteAnimada.quadros("florestaCoracaoEntrada")
        let saida = ArteAnimada.quadros("florestaCoracaoSaida")
        guard entrada > 0, saida > 0, arteExiste("florestaCoracaoSemFitas") else { return c.nome }
        let inicioDaSaida = p.sai - Double(saida) / fps
        if relogio < p.chega || relogio >= p.sai { return "florestaCoracaoSemFitas" }
        if relogio < p.chega + Double(entrada) / fps {
            return "florestaCoracaoEntrada_\(min(entrada, Int((relogio - p.chega) * fps) + 1))"
        }
        if relogio >= inicioDaSaida {
            return "florestaCoracaoSaida_\(min(saida, Int((relogio - inicioDaSaida) * fps) + 1))"
        }
        return c.nome
    }

    // O coelho: sentado mexendo as orelhas e, de tempos em tempos, um pulo
    @ViewBuilder
    private func coelho(_ relogio: Double, _ larguraVisivel: CGFloat, _ percurso: CGFloat) -> some View {
        if arteExiste("florestaCoelho_1"),
           let c = Floresta.coelho(relogio, larguraVisivel: larguraVisivel) {
            let w = Floresta.coelhoW, h = Floresta.coelhoH
            let dx = Floresta.esticar(c.dx, larguraVisivel: larguraVisivel,
                                      percurso: sombra ? percurso : nil, tamanho: w * 0.5)
            // Na parede a sombra do coelho fica um pouco mais alta (senão ela some atrás da caixinha
            // e da sombra dos arbustos)
            let centroY = Floresta.pesDoCoelho - (Floresta.pesNoQuadro - 0.5) * h
                - (sombra ? Floresta.subidaDaSombraDoCoelho : 0)
            // Duas poses misturadas (no pulo): as duas ficam inteiras no meio da troca, então o
            // coelho nunca fica transparente; a de agora some e a próxima aparece aos poucos.
            let proxima = reduzirMovimento ? nil : c.proximo
            let desenho = ZStack {
                Image(reduzirMovimento ? "florestaCoelho_1" : c.quadro)
                    .resizable()
                    .opacity(proxima == nil ? 1 : Double(min(1, 2 * (1 - c.mistura))))
                if let proxima {
                    Image(proxima)
                        .resizable()
                        .opacity(Double(min(1, 2 * c.mistura)))
                }
            }
            let vista = comSombraDePapel(desenho
                .frame(width: w * escala, height: h * escala)
                .scaleEffect(x: c.paraDireita ? 1 : -1, y: 1)   // o desenho olha para a direita
                .modifier(TomDaSombraDoCeu(ativo: sombra)),
                altura: h * 0.6)
                .opacity(sombra ? opacidadeDaSombra : 1)
                .position(x: quadro.x(Floresta.noQuadro(x: Floresta.centroX + dx)),
                          y: quadro.y(Floresta.noQuadro(y: centroY)))
            if sombra { vista } else { vista.mask(FlorestaView.recorteDosLados) }
        }
    }

    // Estrelas: descem do alto, ficam balançando (sobem e descem) e vão embora subindo
    private func estrelas(_ relogio: Double, _ larguraVisivel: CGFloat, _ percurso: CGFloat) -> some View {
        ForEach(Floresta.estrelas.indices, id: \.self) { i in
            let e = Floresta.estrelas[i]
            let tamanho = e.altura * Floresta.aumentoDosElementos
            // Parada: inteira abaixo da barra de cima (mesmo pulsando e flutuando).
            // Fora: inteira acima do alto da tela, em qualquer aparelho.
            let minimoY = Floresta.topoLivre(no: quadro) + tamanho * 1.06 / 2 + 10
            let altoDaTela = (-quadro.origem.y - 80) / max(escala, 0.001)
            let foraY = min(altoDaTela, 0) - tamanho
            if let p = Floresta.posicao(Floresta.caminho(da: e, minimoY: minimoY, foraY: foraY), relogio,
                                        larguraVisivel: larguraVisivel, tamanho: tamanho) {
                let dx = Floresta.esticar(p.dx, larguraVisivel: larguraVisivel,
                                          percurso: sombra ? percurso : nil, tamanho: tamanho)
                let vista = estrela(e, relogio)
                    .position(x: quadro.x(Floresta.noQuadro(x: Floresta.centroX + dx)),
                              y: quadro.y(Floresta.noQuadro(y: p.y)))
                if sombra { vista } else { vista.mask(FlorestaView.recorteDosLados) }
            }
        }
    }

    private func estrela(_ e: Floresta.Estrela, _ relogio: Double) -> some View {
        let pulso = reduzirMovimento ? 0 : (1 + Floresta.onda(86, relogio, fase: e.fase)) / 2
        let tamanho = e.altura * Floresta.aumentoDosElementos * escala * (1 + 0.06 * pulso)
        let flutua = reduzirMovimento ? 0 : 8 * Floresta.onda(48, relogio, fase: e.fase)
        return comSombraDePapel(Image(e.nome)
            .resizable()
            .scaledToFit()
            .frame(width: tamanho, height: tamanho)
            .modifier(TomDaSombraDoCeu(ativo: sombra)),
            altura: e.altura * Floresta.aumentoDosElementos)
            .opacity(sombra ? opacidadeDaSombra : 1)
            .offset(y: flutua * escala)
    }
}

// MARK: - Previews

#Preview("Floresta: vela acesa") {
    GeometryReader { geo in
        TimelineView(.animation(minimumInterval: 1 / 30)) { contexto in
            FlorestaView(quadro: Quadro(tela: geo.size), t: contexto.date.timeIntervalSinceReferenceDate)
        }
    }
    .ignoresSafeArea()
    .background(Cores.fundoEscuro)
}

// Como as sombras ficam no teatro de sombras
#Preview("Floresta: sombras") {
    GeometryReader { geo in
        TimelineView(.animation(minimumInterval: 1 / 30)) { contexto in
            FlorestaView(quadro: Quadro(tela: geo.size), t: contexto.date.timeIntervalSinceReferenceDate,
                         sombra: true)
                .opacity(0.7)
                .blur(radius: 2.5)
                .scaleEffect(1.15, anchor: .bottom)
        }
    }
    .ignoresSafeArea()
    .background(Cores.papel)
}

// AS SOMBRAS EM CAMADAS (regra física do teatro de sombras)
// Quanto mais PERTO DA PAREDE um boneco está, mais nítida e menor é a sombra dele.
// Quanto mais PERTO DA CHAMA, mais borrada, maior e mais pesada (vira uma massa escura).
// Pela referência da Georgia: o céu fica perto da parede (nítido) e a mata perto da chama.
// Elas vêm em ordem: primeiro a que fica mais perto da parede.
enum CamadaDaSombra: CaseIterable {
    case ceu, arvoresDeTras, arvoresDaFrente, arbustos

    // Medido na referência da Georgia (Refsombras): parede branca; o céu (sol, lua, nuvens,
    // coração, pássaros, estrelas) bem escuro e nítido, com os detalhes aparecendo por dentro;
    // as árvores cinza-claras e um pouco borradas; os arbustos médios, escurecendo onde se
    // cruzam. A cena aparece no MESMO tamanho de dentro da caixa (dá para reconhecer tudo).

    // ⚙️ Borrão (em pontos, numa tela de iPhone; no iPad cresce junto com a tela)
    var borrao: CGFloat {
        switch self {
        case .ceu: 3        // (estava nítido demais; na referência a borda é macia)
        case .arvoresDeTras: 5
        case .arvoresDaFrente: 4.5
        case .arbustos: 5.5
        }
    }

    // ⚙️ Quão escura é a sombra (onde duas se cruzam, fica mais escuro ainda)
    var opacidade: Double {
        switch self {
        case .ceu: 0.82
        case .arvoresDeTras: 0.3
        case .arvoresDaFrente: 0.42
        case .arbustos: 0.55
        }
    }

    // ⚙️ Tamanho da sombra na parede, comparado com o cenário. A cena inteira encolhe por igual,
    // presa no chão (como na referência, tudo na mesma proporção de dentro da caixa), só o
    // necessário para o céu caber inteiro abaixo da cortina de cima.
    var escala: CGFloat { 0.82 }

    // De onde a camada encolhe (fração da altura da tela): todas do chão, juntas.
    var ancoraY: CGFloat { 1.0 }

    // Onde o alto do céu (eclipse) vai parar depois de encolher (fração da altura da tela)
    static var topoDoCeu: CGFloat {
        CamadaDaSombra.ceu.ancoraY + (Floresta.topoDasSombras - CamadaDaSombra.ceu.ancoraY) * CamadaDaSombra.ceu.escala
    }
}



// A sombra das peças do céu na parede: escura, mas mostrando os detalhes do desenho (o rosto
// do sol e da lua, as penas, as fitas do coração), como na referência da Georgia.
// (As árvores, os arbustos e o coelho continuam como silhueta lisa.)
struct TomDaSombraDoCeu: ViewModifier {
    var ativo: Bool
    // ⚙️ Cor da parte clara do desenho na sombra (0 = preto; mais alto = detalhes mais visíveis)
    // Preto: a sombra é só a SILHUETA, como uma sombra de verdade. Com 0,2 ainda dava para ver
    // os detalhes de dentro do desenho (as fitas do coração, os riscos), e não devia.
    static let tom = Color.black

    func body(content: Content) -> some View {
        if ativo {
            content
                .grayscale(1)
                .colorMultiply(TomDaSombraDoCeu.tom)
        } else {
            content
        }
    }
}
