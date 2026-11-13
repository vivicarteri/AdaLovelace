//  VelaView.swift
//  A vela: corpo de cera, enfeites, pavio, chama e fumaça.
//  A vista fica "em pé" no chão: a base da vela é a parte de baixo da vista.

import SwiftUI

struct VelaView: View {
    var alturaCheia: CGFloat          // altura da vela inteira (já depende do tamanho escolhido)
    var largura: CGFloat
    var progresso: Double = 0         // 0 = inteira, 1 = acabou
    var acesa = false
    var apagouEm: Date? = nil         // para a fumaça
    var movimento: Movimento? = nil   // para a chama ficar sempre para cima
    var enfeites: [Enfeite] = []
    var caidos: Set<UUID> = []
    var marcas: [Marca] = []

    static func espacoChama(largura: CGFloat) -> CGFloat { largura * 1.8 }

    private var alturaCera: CGFloat { max(3, alturaCheia * CGFloat(1 - progresso)) }
    private var espacoChama: CGFloat { VelaView.espacoChama(largura: largura) }
    private var usaArte: Bool { arteExiste("velaCorpo") }
    private var escalaArte: CGFloat { largura / ArteVela.largura }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.clear

            if usaArte {
                corpoComArte
            } else {
                // Corpo de cera provisório, com escorridos no topo
                ZStack(alignment: .top) {
                    RoundedRectangle(cornerRadius: largura * 0.08)
                        .fill(Cores.cera)
                        .overlay(RoundedRectangle(cornerRadius: largura * 0.08).stroke(Cores.tinta, lineWidth: 2))
                    Escorridos(largura: largura)
                        .frame(height: min(alturaCera, largura * 0.7))
                }
                .frame(width: largura, height: alturaCera)
            }

            // Furinhos de onde a pessoa já tentou espetar
            ForEach(marcas) { marca in
                Circle()
                    .fill(Cores.tinta.opacity(0.45))
                    .frame(width: 5, height: 5)
                    .offset(x: CGFloat(marca.lado) * largura * 0.36,
                            y: -CGFloat(marca.altura) * alturaCheia + 2.5)
            }

            // Enfeites que ainda não caíram
            ForEach(enfeites.filter { !caidos.contains($0.id) }) { enfeite in
                EnfeiteView(tipo: enfeite.tipo, lado: enfeite.lado, largura: largura)
                    .offset(x: CGFloat(enfeite.lado) * largura * 0.62,
                            y: -CGFloat(enfeite.altura) * alturaCheia
                               + EnfeiteView.alturaDoAlfinete(enfeite.tipo, largura: largura))
                    .transition(.asymmetric(insertion: .opacity,
                                            removal: .offset(y: alturaCheia).combined(with: .opacity)))
            }

            // Pavio (o da arte já vem desenhado), chama e fumaça
            ZStack(alignment: .bottom) {
                if !usaArte {
                    Capsule()
                        .fill(Cores.tinta)
                        .frame(width: 3, height: largura * 0.22)
                }
                if acesa {
                    Group {
                        if usaArte {
                            ChamaView(tamanho: ArteVela.chamaAltura * escalaArte, movimento: movimento)
                                .offset(x: ArteVela.chamaDesvioX * escalaArte, y: ArteVela.chamaDentro * escalaArte)
                        } else {
                            ChamaView(tamanho: largura * 1.2, movimento: movimento)
                                .offset(y: -largura * 0.12)
                        }
                    }
                    .transition(.scale(scale: 0.2, anchor: .bottom).combined(with: .opacity))
                }
                if !acesa, let apagouEm {
                    FumacaView(desde: apagouEm, largura: largura)
                }
            }
            .offset(y: -alturaCera)
        }
        .frame(width: largura * 3, height: alturaCheia + espacoChama, alignment: .bottom)
        .animation(.easeIn(duration: Haptics.tempoQueda), value: caidos)
        .animation(.easeOut(duration: 0.4), value: acesa)
    }

    // Vela da Georgia, montada com as DUAS peças que ela desenhou:
    //   "velaTopo"  = os escorridos e o pavio (sempre no alto, sempre do mesmo tamanho)
    //   "velaCorpo" = a vela inteira; aqui usamos só a parte LISA dela, esticada ou
    //                 encolhida para a vela ficar do tamanho escolhido.
    //
    // O pulo do gato é onde as duas se encontram. O desenho do corpo também tem os
    // escorridos no começo dele, então o corpo é encolhido de um jeito que a parte lisa
    // fique com a altura certa, e os escorridos dele são cortados fora por cima.
    // Assim a emenda cai SEMPRE no mesmo ponto do desenho — exatamente onde a Georgia
    // cortou as duas peças. Antes a emenda caía num lugar qualquer do corpo e só batia
    // certo na vela do tamanho máximo; por isso o topo ficava estranho nos outros tamanhos.
    //
    // Um pedaço da cera fica escondido atrás do suporte (por isso o "escondido").
    private var corpoComArte: some View {
        let s = escalaArte
        let escondido = (ArteVela.corpoBaixo - ArteVela.baseY) * s
        let topo = (ArteVela.topoBaixo - ArteVela.corpoTopo) * s        // a peça dos escorridos
        let inteiro = (ArteVela.corpoBaixo - ArteVela.corpoTopo) * s    // o desenho do corpo todo
        let liso = (ArteVela.corpoBaixo - ArteVela.topoBaixo) * s       // só a parte lisa dele

        let visivel = alturaCera + escondido
        let corpo = max(0, visivel - topo)
        // Encolhe o desenho todo na medida em que a parte lisa fique com "corpo" de altura
        let alturaDesenho = liso > 0 ? corpo * inteiro / liso : 0

        return VStack(spacing: 0) {
            Image("velaTopo")
                .resizable()
                .frame(width: largura, height: topo)
            if corpo > 0 {
                Image("velaCorpo")
                    .resizable()
                    .frame(width: largura, height: alturaDesenho)
                    .frame(width: largura, height: corpo, alignment: .bottom)   // corta os escorridos de cima
                    .clipped()
            }
        }
        // No fim da vela a cera fica mais baixa que os escorridos: aí eles vão sumindo
        // por baixo, derretendo dentro do suporte.
        .frame(width: largura, height: visivel, alignment: .top)
        .clipped()
        .offset(y: escondido)
    }
}

// Escorridos de cera no topo da vela
private struct Escorridos: View {
    var largura: CGFloat
    var body: some View {
        HStack(alignment: .top, spacing: largura * 0.12) {
            ForEach([0.55, 0.3, 0.75, 0.4], id: \.self) { comprimento in
                Capsule()
                    .stroke(Cores.tinta.opacity(0.6), lineWidth: 1.5)
                    .frame(width: largura * 0.1, height: largura * CGFloat(comprimento))
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .clipped()
    }
}

// Alfinete (espetado de lado) ou penduricalho (estrelinha pendurada)
struct EnfeiteView: View {
    var tipo: TipoEnfeite
    var lado: Double = 1
    var largura: CGFloat

    // Altura do desenho inteiro
    static func alturaDesenho(_ tipo: TipoEnfeite, largura: CGFloat) -> CGFloat {
        tipo == .alfinete ? 10 : largura * 0.35 + 23
    }

    // Distância entre a parte de baixo do desenho e a linha do alfinete (onde ele espeta)
    static func alturaDoAlfinete(_ tipo: TipoEnfeite, largura: CGFloat) -> CGFloat {
        tipo == .alfinete ? 5 : alturaDesenho(tipo, largura: largura) - 3.5
    }

    // Quanto o desenho sobe acima da linha onde ele espeta...
    static func acima(_ tipo: TipoEnfeite, largura: CGFloat) -> CGFloat {
        alturaDesenho(tipo, largura: largura) - alturaDoAlfinete(tipo, largura: largura)
    }

    // ...e quanto ele desce abaixo dela (o penduricalho fica pendurado, então desce bastante)
    static func abaixo(_ tipo: TipoEnfeite, largura: CGFloat) -> CGFloat {
        alturaDoAlfinete(tipo, largura: largura)
    }

    var body: some View {
        let haste = largura * 0.55
        Group {
            switch tipo {
            case .alfinete:
                Arte("alfinete") {
                    HStack(spacing: 0) {
                        Circle().fill(Cores.cortina).frame(width: 10, height: 10)
                        Capsule().fill(Cores.tinta.opacity(0.8)).frame(width: haste, height: 2)
                    }
                }
                .frame(width: haste + 10, height: 10)
            case .penduricalho:
                Arte("penduricalho") {
                    VStack(spacing: 0) {
                        HStack(spacing: 0) {
                            Circle().fill(Cores.dourado).frame(width: 7, height: 7)
                            Capsule().fill(Cores.tinta.opacity(0.8)).frame(width: haste * 0.7, height: 2)
                        }
                        Rectangle().fill(Cores.tinta.opacity(0.6)).frame(width: 1, height: largura * 0.35)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 3)
                        Estrela().fill(Cores.dourado)
                            .overlay(Estrela().stroke(Cores.tinta, lineWidth: 1))
                            .frame(width: 16, height: 16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, -5)
                    }
                    .frame(width: haste * 0.7 + 7)
                }
                .frame(width: haste * 0.7 + 7, height: EnfeiteView.alturaDesenho(.penduricalho, largura: largura), alignment: .top)
            }
        }
        // O desenho é feito para o lado esquerdo; do lado direito espelhamos
        .scaleEffect(x: lado < 0 ? 1 : -1, y: 1)
        .accessibilityHidden(true)
    }
}

// Chama em forma de gota que tremula. Se receber o Movimento, fica sempre para cima.
struct ChamaView: View {
    var tamanho: CGFloat
    var movimento: Movimento? = nil
    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento

    var body: some View {
        TimelineView(.animation) { contexto in
            let t = contexto.date.timeIntervalSinceReferenceDate
            let tremor = reduzirMovimento ? 0 : 0.06 * sin(t * 11) + 0.04 * sin(t * 17.3)
            let f = 1 + tremor
            let angulo = (movimento?.angulo ?? 0) + (reduzirMovimento ? 0 : 0.04 * sin(t * 7))

            ZStack(alignment: .bottom) {
                if arteExiste("velaChama") {
                    Image("velaChama")
                        .resizable()
                        .frame(width: tamanho * ArteVela.chamaLargura / ArteVela.chamaAltura, height: tamanho)
                } else {
                Gota()
                    .fill(LinearGradient(colors: [Color(red: 1, green: 0.86, blue: 0.42),
                                                  Color(red: 0.96, green: 0.46, blue: 0.12)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: tamanho * 0.42, height: tamanho)
                Gota()
                    .fill(Color(red: 1, green: 0.98, blue: 0.85))
                    .frame(width: tamanho * 0.2, height: tamanho * 0.45)
                    .padding(.bottom, tamanho * 0.04)
                }
            }
            .scaleEffect(x: 1 / sqrt(f), y: f, anchor: .bottom)
            .rotationEffect(.radians(angulo), anchor: .bottom)
        }
        .frame(width: tamanho, height: tamanho, alignment: .bottom)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// Fumaça subindo por alguns segundos depois de apagar.
// Passados os 3 segundos a vista sai do ar: assim ela para de redesenhar 60 vezes
// por segundo enquanto a vela fica apagada (isso estava gastando bateria à toa).
struct FumacaView: View {
    var desde: Date
    var largura: CGFloat
    private var duracao: TimeInterval { 3 }

    @State private var acabou = false

    var body: some View {
        Group {
            if acabou {
                // Mesmo tamanho, sem desenhar nada: o resto da vela não se mexe do lugar
                Color.clear
                    .frame(width: largura, height: largura * 2.2)
            } else {
                TimelineView(.animation) { contexto in
                    let passou = contexto.date.timeIntervalSince(desde)
                    ZStack(alignment: .bottom) {
                        ForEach(0..<5, id: \.self) { i in
                            let t = (passou * 0.8 + Double(i) * 0.2).truncatingRemainder(dividingBy: 1)
                            Circle()
                                .fill(Color.gray.opacity(0.45 * (1 - t) * max(0, 1 - passou / duracao)))
                                .frame(width: largura * CGFloat(0.15 + 0.35 * t),
                                       height: largura * CGFloat(0.15 + 0.35 * t))
                                .offset(x: CGFloat(sin(t * 6 + Double(i))) * largura * 0.15,
                                        y: -CGFloat(t) * largura * 2)
                        }
                    }
                    .frame(width: largura, height: largura * 2.2, alignment: .bottom)
                }
            }
        }
        // Recomeça sempre que a vela apaga de novo (a data muda)
        .task(id: desde) {
            acabou = false
            let falta = duracao - Date().timeIntervalSince(desde)
            if falta > 0 {
                try? await Task.sleep(for: .seconds(falta))
                guard !Task.isCancelled else { return }
            }
            acabou = true
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// Suporte (castiçal) da arte. Fica embaixo da vela e esconde a parte de baixo dela.
struct SuporteView: View {
    var largura: CGFloat   // largura da VELA (o suporte segue a mesma escala)

    private static func escala(_ largura: CGFloat) -> CGFloat { largura / ArteVela.largura }
    static func altura(largura: CGFloat) -> CGFloat { PosicaoArte.suporte.height * escala(largura) }
    static func desvioX(largura: CGFloat) -> CGFloat { (PosicaoArte.suporte.midX - ArteVela.centroX) * escala(largura) }

    var body: some View {
        let s = SuporteView.escala(largura)
        Arte("velaSuporte") {
            VStack {
                Capsule().fill(Cores.papel).overlay(Capsule().stroke(Cores.tinta, lineWidth: 2))
                    .frame(width: largura * 1.9, height: 16)
                Spacer()
            }
        }
        .frame(width: PosicaoArte.suporte.width * s, height: PosicaoArte.suporte.height * s)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// O tamanho dos enfeites traduzido para "fração da altura da vela",
// que é como a VelaConfig raciocina na hora de empurrar um enfeite para não sobrepor.
extension TamanhoEnfeite {
    static func daVela(largura: CGFloat, alturaCheia: CGFloat) -> TamanhoEnfeite {
        let altura = max(alturaCheia, 1)
        func fracao(_ pontos: CGFloat) -> Double { Double(pontos / altura) }
        return TamanhoEnfeite(
            alfineteAcima: fracao(EnfeiteView.acima(.alfinete, largura: largura)),
            alfineteAbaixo: fracao(EnfeiteView.abaixo(.alfinete, largura: largura)),
            penduricalhoAcima: fracao(EnfeiteView.acima(.penduricalho, largura: largura)),
            penduricalhoAbaixo: fracao(EnfeiteView.abaixo(.penduricalho, largura: largura))
        )
    }
}

// MARK: - Previews
//
// A vela fica sempre em cima do suporte, como no palco: o suporte esconde o pé da vela.

// A vela mais curta, a do meio e a mais longa. Serve para conferir a emenda do topo em todos os tamanhos.
#Preview("VelaView: tamanhos") {
    let largura: CGFloat = 40
    HStack(alignment: .bottom, spacing: 0) {
        ForEach([0.0, 0.4, 1.0], id: \.self) { posicao in
            VStack(spacing: 0) {
                VelaView(alturaCheia: GeometriaVela.alturaCheia(posicao: posicao, alturaMaxima: 420),
                         largura: largura, acesa: true)
                SuporteView(largura: largura)
                    .offset(x: SuporteView.desvioX(largura: largura))
                Text("\(VelaConfig.minutos(para: posicao)) min")
                    .font(.caption)
                    .foregroundStyle(Cores.papel)
                    .padding(.top, 8)
            }
        }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Cores.fundoEscuro)
}

// Arraste o slider: a cera desce e cada enfeite cai quando a cera chega nele (mesma regra da Sessao).
// "Apagar" mostra a fumaça.
#Preview("VelaView: queimando") {
    @Previewable @State var progresso = 0.0
    @Previewable @State var acesa = true
    @Previewable @State var apagouEm: Date? = nil
    @Previewable @State var enfeites = [
        Enfeite(tipo: .alfinete, altura: 0.8, lado: -1),
        Enfeite(tipo: .penduricalho, altura: 0.6, lado: 1),
        Enfeite(tipo: .alfinete, altura: 0.35, lado: 1),
        Enfeite(tipo: .penduricalho, altura: 0.25, lado: -1),
    ]
    @Previewable @State var marcas = [Marca(altura: 0.5, lado: -1)]
    let largura: CGFloat = 60
    let caidos = Set(enfeites.filter { $0.altura >= 1 - progresso }.map(\.id))

    VStack {
        Spacer()
        VStack(spacing: 0) {
            VelaView(alturaCheia: 320, largura: largura, progresso: progresso, acesa: acesa,
                     apagouEm: apagouEm, enfeites: enfeites, caidos: caidos, marcas: marcas)
            SuporteView(largura: largura)
                .offset(x: SuporteView.desvioX(largura: largura))
        }
        Spacer()
        VStack {
            Slider(value: $progresso, in: 0...1) { Text("Progresso da vela") }
            Button(acesa ? "Apagar" : "Acender") {
                if acesa { apagouEm = .now }
                acesa.toggle()
            }
            .buttonStyle(.borderedProminent)
            .tint(Cores.tinta)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding()
    }
    .frame(maxWidth: .infinity)
    .background(Cores.fundoEscuro)
}

// Só aparece na vela provisória (quando "velaCorpo" não está no Assets)
#Preview("Provisório: Escorridos", traits: .sizeThatFitsLayout) {
    Escorridos(largura: 80)
        .frame(width: 80, height: 56)
        .background(Cores.cera)
        .padding(30)
        .background(Cores.fundoEscuro)
}

// Em cima: lado esquerdo da vela. Embaixo: lado direito (espelhado).
#Preview("EnfeiteView", traits: .sizeThatFitsLayout) {
    HStack(alignment: .top, spacing: 40) {
        ForEach(TipoEnfeite.allCases, id: \.self) { tipo in
            VStack(spacing: 20) {
                EnfeiteView(tipo: tipo, lado: -1, largura: 60)
                EnfeiteView(tipo: tipo, lado: 1, largura: 60)
                Text(tipo.nome).font(.caption)
            }
        }
    }
    .padding(30)
    .background(Cores.papel)
}

#Preview("ChamaView", traits: .sizeThatFitsLayout) {
    HStack(alignment: .bottom, spacing: 30) {
        ChamaView(tamanho: 40)
        ChamaView(tamanho: 80)
        ChamaView(tamanho: 140)
    }
    .padding(30)
    .background(Cores.fundoEscuro)
}

// A fumaça dura 3 segundos. O botão solta de novo.
#Preview("FumacaView") {
    @Previewable @State var desde = Date()
    VStack(spacing: 30) {
        FumacaView(desde: desde, largura: 60)
        Button("Soltar fumaça de novo") { desde = .now }
            .buttonStyle(.borderedProminent)
            .tint(Cores.tinta)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Cores.papel)
}

#Preview("SuporteView", traits: .sizeThatFitsLayout) {
    SuporteView(largura: 80)
        .padding(30)
        .background(Cores.fundoEscuro)
}
