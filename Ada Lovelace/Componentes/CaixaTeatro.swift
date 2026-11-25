//  CaixaTeatro.swift
//  A caixa do teatro vista de fora e a "câmera" que entra e sai dela.
//
//  A abertura da caixa tem o mesmo formato da tela. Dentro dela aparece o palco de verdade, em miniatura.
//  ZOOM OUT: a câmera sai do teatro → o palco vai ficando pequeno dentro da caixa → a cortina da caixa fecha.
//  ZOOM IN:  a cortina da caixa abre → a câmera entra até o palco ocupar a tela toda.

import SwiftUI
import Foundation

struct MedidasCaixa {
    let tela: CGSize                 // tamanho da área da tela onde tudo é desenhado
    // As margens da área segura (Dynamic Island, barrinha de baixo). O palco de verdade desenha
    // também nelas (o fundo e a cortina vão até a borda do aparelho), então o palco em miniatura
    // e o zoom contam com a TELA INTEIRA. Antes contavam só a área segura e, no fim do zoom in,
    // aparecia um pedaço da placa em cima e a imagem pulava.
    var margens = EdgeInsets()

    var telaCheia: CGSize {
        CGSize(width: tela.width + margens.leading + margens.trailing,
               height: tela.height + margens.top + margens.bottom)
    }

    // TEATRO DA GEORGIA ("caixaTeatro", recorte de Teatro_Com_Placa_2, 724 × 728 pixels).
    // A abertura dela é mais larga que alta (a tela do iPhone é comprida em pé). O desenho fica
    // igual ao dela: o palco em miniatura aparece no meio da abertura, no tamanho que ele vai ter
    // quando a câmera chegar, e a cortininha da caixa cobre o resto dos lados.
    private static let arteTamanho = CGSize(width: 724, height: 728)
    // Para onde a câmera vai: a abertura abaixo da placa "candle tales" (que desce até y 253)
    // e dos arabescos dos cantos. Assim, no fim do zoom, nada do desenho fica na frente do palco.
    private static let arteAbertura = CGRect(x: 76, y: 256, width: 565, height: 381)
    // Onde o palco e a cortininha são desenhados, ATRÁS da moldura (um pouco maior que a abertura)
    private static let arteFundo = CGRect(x: 70, y: 140, width: 578, height: 500)

    var usaArte: Bool { arteExiste("caixaTeatro") }
    private var escalaDaArte: CGFloat { min(tela.width * 0.36, 160) / MedidasCaixa.arteTamanho.width }

    // Sem a arte: a ABERTURA tem o mesmo formato da tela, para o zoom encaixar certinho.
    // Com a arte: é a abertura do desenho da Georgia.
    var abertura: CGSize {
        if usaArte {
            let f = escalaDaArte
            return CGSize(width: MedidasCaixa.arteAbertura.width * f, height: MedidasCaixa.arteAbertura.height * f)
        }
        let largura = min(tela.width * 0.16, 70)
        return CGSize(width: largura, height: largura * tela.height / max(tela.width, 1))
    }

    // Onde o palco e a cortininha ficam (atrás da moldura), a partir do canto de cima da caixa
    var fundo: CGRect {
        let f = escalaDaArte, r = MedidasCaixa.arteFundo
        return CGRect(x: r.minX * f, y: r.minY * f, width: r.width * f, height: r.height * f)
    }

    // O palco em miniatura: do tamanho que a tela INTEIRA vai ter quando a câmera chegar na abertura
    var miniatura: CGSize {
        let t = usaArte ? telaCheia : tela
        return CGSize(width: t.width / zoomFinal, height: t.height / zoomFinal)
    }

    // Para onde a câmera aponta. Com a arte: o meio da abertura é o meio da TELA INTEIRA; a
    // câmera trabalha na área segura, então o alvo é deslocado pelas margens (em miniatura).
    var alvoDaCamera: CGPoint {
        guard usaArte else { return centroDaAbertura }
        let c = centroDaAbertura
        return CGPoint(x: c.x + (margens.leading - margens.trailing) / 2 / zoomFinal,
                       y: c.y + (margens.top - margens.bottom) / 2 / zoomFinal)
    }

    // A MOLDURA em volta da abertura: colunas dos lados, telhado em cima e palco embaixo.
    // É ela que dá cara de caixa de teatro. Sem moldura, a caixa ficava com o formato
    // comprido e estreito da tela do iPhone e parecia uma cartinha em pé.
    var coluna: CGFloat { abertura.width * 0.55 }
    var telhado: CGFloat { abertura.width * 0.42 }
    var palco: CGFloat { abertura.width * 0.30 }

    var caixa: CGSize {
        if usaArte {
            let f = escalaDaArte
            return CGSize(width: MedidasCaixa.arteTamanho.width * f, height: MedidasCaixa.arteTamanho.height * f)
        }
        return CGSize(width: abertura.width + coluna * 2,
                      height: abertura.height + telhado + palco)
    }

    // Onde a caixa inteira fica na tela (é por aqui que a vista é posicionada)
    var centro: CGPoint {
        CGPoint(x: tela.width / 2, y: tela.height - 18 - caixa.height / 2)
    }

    // O meio da ABERTURA — é para cá que a câmera vai, e é daqui que sai a luz
    var centroDaAbertura: CGPoint {
        if usaArte {
            let f = escalaDaArte, r = MedidasCaixa.arteAbertura, t = MedidasCaixa.arteTamanho
            return CGPoint(x: centro.x + (r.midX - t.width / 2) * f,
                           y: centro.y + (r.midY - t.height / 2) * f)
        }
        return CGPoint(x: centro.x, y: centro.y - caixa.height / 2 + telhado + abertura.height / 2)
    }

    // Quanto a câmera aproxima para a abertura cobrir a tela inteira
    var zoomFinal: CGFloat {
        guard usaArte else { return tela.width / max(abertura.width, 1) }
        // A abertura cobre a tela INTEIRA quando a câmera chega
        return max(telaCheia.width / max(abertura.width, 1), telaCheia.height / max(abertura.height, 1))
    }
}

// A câmera. z = 0: vista de fora normal. z = 1: colada na caixa (a abertura ocupa a tela).
// O zoom é exponencial, para a aproximação parecer uma câmera de verdade (e não acelerar no fim).
nonisolated struct EfeitoCamera: GeometryEffect {
    var z: CGFloat
    var zoomFinal: CGFloat
    var alvo: CGPoint        // centro da abertura da caixa
    var tela: CGSize

    var animatableData: CGFloat {
        get { z }
        set { z = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let escala = pow(zoomFinal, z)
        let quanto = zoomFinal > 1 ? (escala - 1) / (zoomFinal - 1) : 0   // 0 → 1, junto com o zoom
        let dx = (tela.width / 2 - alvo.x) * quanto
        let dy = (tela.height / 2 - alvo.y) * quanto
        // Aumenta em volta do centro da caixa e leva a caixa para o centro da tela
        let t = CGAffineTransform(translationX: alvo.x + dx, y: alvo.y + dy)
            .scaledBy(x: escala, y: escala)
            .translatedBy(x: -alvo.x, y: -alvo.y)
        return ProjectionTransform(t)
    }
}

// Cortina de duas folhas que abre para os lados. abertura: 0 = fechada, 1 = aberta.
struct CortinaCaixa: View {
    var abertura: CGFloat
    var sobra: CGFloat = 0   // aberta, cada folha ainda cobre este tanto do lado (teatro da Georgia)
    var arte = "cortinaCaixa"   // qual desenho de pano (no teatro da Georgia: o mesmo pano do palco)

    static let descida: CGFloat = 0.05   // fração da altura da abertura

    var body: some View {
        GeometryReader { geo in
            // Aberta (1): cada folha cobre só a "sobra" do lado. Fechada (0): meia abertura cada.
            // No meio do caminho, anda proporcional (antes ela ficava parada na sobra e só
            // começava a fechar no fim).
            let w = geo.size.width, h = geo.size.height
            // Fechada, cada folha passa um pouco do meio: a borda de dentro do pano do palco é
            // inclinada (igual na cortina grande, CortinaLateralView). Sem isso ficava uma fresta
            // escura no meio da caixa fechada.
            let passaDoMeio = arte == CortinaLateralView.nome
                ? h * CortinaLateralView.proporcao * CortinaLateralView.inclinacaoDaBorda + 1 : 0
            let fechada = w / 2 + passaDoMeio
            let sobraValida = min(sobra, fechada)
            let metade = sobraValida + (fechada - sobraValida) * (1 - abertura)
            // As folhas ficam uma em cada canto e podem se cruzar no meio (por isso ZStack)
            ZStack {
                FolhaDeCortina(arte: arte)
                    .frame(width: metade)
                    .frame(maxWidth: .infinity, alignment: .leading)
                FolhaDeCortina(arte: arte)
                    .frame(width: metade)
                    .scaleEffect(x: -1, y: 1)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            // ⚙️ O pano desce um pouco além do fundo da abertura, para as franjas encostarem no chão
            // do teatro (o que passa fica escondido atrás da base de madeira do desenho).
            // Era 0: sobrava uma faixa escura entre as franjas e o chão.
            .frame(height: h * (1 + CortinaCaixa.descida), alignment: .top)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct FolhaDeCortina: View {
    var arte = "cortinaCaixa"

    var body: some View {
        if arte == CortinaLateralView.nome && arteExiste(arte) {
            // O pano do palco: preenche a folha, com a borda de dentro (a das franjas) no meio.
            // O Color.clear tem EXATAMENTE o tamanho da folha e o pano é recortado nele.
            // (Antes o pano "vazava" para fora da folha e cobria o palco: era a cortina meio
            // aberta que aparecia do nada no começo do zoom out.)
            Color.clear
                .overlay(alignment: .trailing) {
                    Image(arte)
                        .resizable()
                        .scaledToFill()
                }
                .clipped()
        } else {
            folhaProvisoria
        }
    }

    private var folhaProvisoria: some View {
        Arte("cortinaCaixa") {
            ZStack {
                Cores.cortina
                HStack(spacing: 0) {
                    ForEach(0..<3, id: \.self) { _ in
                        LinearGradient(colors: [.black.opacity(0.3), .clear, .black.opacity(0.3)],
                                       startPoint: .leading, endPoint: .trailing)
                    }
                }
            }
        }
    }
}

// A caixa vista de fora: teatrinho de papel com telhado de cortina, colunas listradas,
// palco embaixo e, no meio, a abertura com o palco de verdade em miniatura lá dentro.
struct CaixaTeatroView: View {
    var medidas: MedidasCaixa
    var acesa: Bool
    var aberturaCortina: CGFloat          // 0 = fechada, 1 = aberta
    var conteudo: AnyView? = nil          // o palco em miniatura

    var body: some View {
        if medidas.usaArte {
            caixaDaGeorgia
        } else {
            caixaProvisoria
        }
    }

    // O teatro da Georgia: o palco e a cortininha ficam ATRÁS do desenho, que tem a abertura vazada
    private var caixaDaGeorgia: some View {
        let caixa = medidas.caixa
        let fundo = medidas.fundo
        let mini = medidas.miniatura
        // O palco fica no meio da abertura (para onde a câmera vai), que não é bem o meio do fundo
        let desvioDoPalco = CGSize(width: medidas.centroDaAbertura.x - medidas.centro.x - (fundo.midX - caixa.width / 2),
                                   height: medidas.centroDaAbertura.y - medidas.centro.y - (fundo.midY - caixa.height / 2))
        return ZStack {
            ZStack {
                Cores.fundoEscuro
                if let conteudo {
                    conteudo
                        .frame(width: medidas.telaCheia.width, height: medidas.telaCheia.height)
                        .scaleEffect(1 / max(medidas.zoomFinal, 1))
                        .frame(width: mini.width, height: mini.height)
                        .clipped()
                        .offset(desvioDoPalco)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                // A cortina da caixa é o mesmo pano verde do palco. Ela FECHA enquanto a câmera se
                // afasta (zoom out) e ABRE de novo quando a câmera volta (zoom in). Aberta, o pano
                // fica recolhido nos lados da abertura (que é mais larga que a tela).
                // (Sem a fresta de luz no meio: fechada, a cortina fica fechada mesmo.)
                CortinaCaixa(abertura: aberturaCortina, sobra: max(0, (fundo.width - mini.width) / 2),
                             arte: CortinaLateralView.nome)
            }
            .frame(width: fundo.width, height: fundo.height)
            .clipped()
            .offset(x: fundo.midX - caixa.width / 2, y: fundo.midY - caixa.height / 2)

            Image("caixaTeatro")
                .resizable()
                .frame(width: caixa.width, height: caixa.height)
        }
        .frame(width: caixa.width, height: caixa.height)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Cores.dourado)
                .blur(radius: 24)
                .opacity(acesa ? 0.8 : 0)
        )
    }

    // A caixa feita no código (enquanto não tinha a arte da Georgia)
    private var caixaProvisoria: some View {
        let a = medidas.abertura
        let caixa = medidas.caixa
        let desvioAbertura = -caixa.height / 2 + medidas.telhado + a.height / 2

        return ZStack {
            // Corpo da caixa
            Arte("caixaTeatro") {
                // Os cantos de cima acompanham o telhado arredondado
                let forma = UnevenRoundedRectangle(topLeadingRadius: caixa.width * 0.09, bottomLeadingRadius: 5,
                                                   bottomTrailingRadius: 5, topTrailingRadius: caixa.width * 0.09)
                ZStack {
                    forma.fill(Cores.papel)
                    // Colunas listradas dos dois lados, como a frente de um teatrinho
                    HStack(spacing: a.width) {
                        ColunaListrada(largura: medidas.coluna)
                        ColunaListrada(largura: medidas.coluna)
                    }
                    forma.stroke(Cores.tinta, lineWidth: 2)
                }
                .clipShape(forma)
            }
            .frame(width: caixa.width, height: caixa.height)

            // A abertura, logo abaixo do telhado
            ZStack {
                Cores.fundoEscuro
                if let conteudo {
                    // O palco é desenhado no tamanho da tela e encolhido até caber na abertura
                    conteudo
                        .frame(width: medidas.tela.width, height: medidas.tela.height)
                        .scaleEffect(a.width / max(medidas.tela.width, 1))
                        .frame(width: a.width, height: a.height)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                CortinaCaixa(abertura: aberturaCortina)
                // Luz da vela passando pela fresta da cortina fechada
                Rectangle()
                    .fill(Cores.dourado)
                    .frame(width: 3)
                    .blur(radius: 2)
                    .opacity(acesa && aberturaCortina < 0.05 ? 0.9 : 0)
            }
            .frame(width: a.width, height: a.height)
            .clipped()
            .overlay(Rectangle().stroke(Cores.tinta, lineWidth: 2.5))
            .offset(y: desvioAbertura)

            // Telhado: cortininha vermelha com franjas caindo por cima da abertura
            ZStack(alignment: .bottom) {
                Cores.cortina
                HStack(spacing: 0) {
                    ForEach(0..<6, id: \.self) { _ in
                        Circle()
                            .fill(Cores.cortina)
                            .overlay(Circle().stroke(Cores.tinta, lineWidth: 1))
                            .frame(width: caixa.width / 6, height: caixa.width / 6)
                    }
                }
                .offset(y: caixa.width / 12)
                Estrela()
                    .fill(Cores.dourado)
                    .overlay(Estrela().stroke(Cores.tinta, lineWidth: 1))
                    .frame(width: medidas.telhado * 0.5, height: medidas.telhado * 0.5)
                    .offset(y: -medidas.telhado * 0.35)
            }
            .frame(width: caixa.width, height: medidas.telhado, alignment: .bottom)
            // Topo arredondado (pedido da mentora: a quina reta destoava do resto do app).
            // A máscara desce além do telhado, para não cortar as franjas de baixo.
            .mask(alignment: .top) {
                UnevenRoundedRectangle(topLeadingRadius: caixa.width * 0.09, topTrailingRadius: caixa.width * 0.09)
                    .frame(height: medidas.telhado + caixa.width / 6)
            }
            .overlay(alignment: .top) {
                UnevenRoundedRectangle(topLeadingRadius: caixa.width * 0.09, topTrailingRadius: caixa.width * 0.09)
                    .trim(from: 0, to: 1)
                    .stroke(Cores.tinta, lineWidth: 2)
                    .frame(height: medidas.telhado * 0.6)
                    .mask(alignment: .top) { Rectangle().frame(height: medidas.telhado * 0.45) }
            }
            .offset(y: -caixa.height / 2 + medidas.telhado / 2)

            // Palco embaixo, um pouquinho mais largo que a caixa
            ZStack {
                RoundedRectangle(cornerRadius: 3).fill(Cores.papel)
                RoundedRectangle(cornerRadius: 3).stroke(Cores.tinta, lineWidth: 2)
                HStack(spacing: medidas.palco * 0.7) {
                    ForEach(0..<3, id: \.self) { _ in
                        Estrela()
                            .stroke(Cores.tinta, lineWidth: 1)
                            .frame(width: medidas.palco * 0.42, height: medidas.palco * 0.42)
                    }
                }
            }
            .frame(width: caixa.width * 1.14, height: medidas.palco)
            .offset(y: caixa.height / 2 - medidas.palco / 2)
        }
        .frame(width: caixa.width * 1.14, height: caixa.height)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Cores.dourado)
                .blur(radius: 24)
                .opacity(acesa ? 0.8 : 0)
        )
    }
}

// Coluna da frente do teatrinho, com listras de circo
private struct ColunaListrada: View {
    var largura: CGFloat

    var body: some View {
        GeometryReader { geo in
            let n = 3
            HStack(spacing: 0) {
                ForEach(0..<n, id: \.self) { i in
                    (i.isMultiple(of: 2) ? Cores.papel : Cores.fundoClaro.opacity(0.55))
                        .frame(width: largura / CGFloat(n))
                }
            }
            .frame(height: geo.size.height)
        }
        .frame(width: largura)
        .opacity(0.9)
    }
}

// MARK: - Previews

// A caixa aparece 2,5x maior que no app, para dar para ver os detalhes.
// Dentro da abertura vai o palco em miniatura, como no app.
#Preview("CaixaTeatroView") {
    @Previewable @State var acesa = true
    @Previewable @State var cortina: CGFloat = 1
    GeometryReader { geo in
        let medidas = MedidasCaixa(tela: geo.size)
        ZStack {
            (acesa ? Cores.papel : Cores.fundoEscuro).ignoresSafeArea()
            CaixaTeatroView(medidas: medidas, acesa: acesa, aberturaCortina: cortina,
                            conteudo: AnyView(CenarioView(acesa: acesa, progresso: 0.3, mostrarPersonagens: true,
                                                          quadro: Quadro(tela: medidas.tela))))
                .scaleEffect(2.5)
            VStack {
                Toggle("Vela acesa", isOn: $acesa)
                Slider(value: $cortina, in: 0...1) { Text("Cortina") }
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .padding()
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }
}

// A caixa no tamanho e no lugar de verdade. O slider (ou o botão) faz a câmera entrar nela.
#Preview("EfeitoCamera") {
    @Previewable @State var z: CGFloat = 0
    GeometryReader { geo in
        let medidas = MedidasCaixa(tela: geo.size)
        ZStack {
            ZStack {
                Cores.papel
                CaixaTeatroView(medidas: medidas, acesa: true, aberturaCortina: 1,
                                conteudo: AnyView(CenarioView(acesa: true, progresso: 0.3, mostrarPersonagens: true,
                                                              quadro: Quadro(tela: medidas.tela))))
                    .position(medidas.centro)
            }
            .modifier(EfeitoCamera(z: z, zoomFinal: medidas.zoomFinal,
                                   alvo: medidas.centroDaAbertura, tela: geo.size))

            VStack {
                Slider(value: $z, in: 0...1) { Text("Zoom") }
                Button(z < 0.5 ? "Entrar na caixa" : "Sair da caixa") {
                    withAnimation(.easeInOut(duration: 1.6)) { z = z < 0.5 ? 1 : 0 }
                }
                .buttonStyle(.borderedProminent)
                .tint(Cores.tinta)
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .padding()
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }
}

#Preview("CortinaCaixa") {
    @Previewable @State var abertura: CGFloat = 0.5
    VStack(spacing: 30) {
        ZStack {
            Cores.fundoClaro
            CortinaCaixa(abertura: abertura)
        }
        .frame(width: 200, height: 320)
        .clipped()
        .overlay(Rectangle().stroke(Cores.tinta, lineWidth: 2.5))
        Slider(value: $abertura, in: 0...1) { Text("Abertura") }
    }
    .padding(30)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Cores.fundoEscuro)
}

#Preview("FolhaDeCortina", traits: .sizeThatFitsLayout) {
    FolhaDeCortina()
        .frame(width: 100, height: 240)
        .padding()
}

#Preview("ColunaListrada", traits: .sizeThatFitsLayout) {
    ColunaListrada(largura: 40)
        .frame(height: 200)
        .padding()
        .background(Cores.tinta)
}
