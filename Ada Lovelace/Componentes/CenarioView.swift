//  CenarioView.swift
//  O circo de papel em camadas: tenda, roda do sol e da lua, personagens e palco.
//  A história: conforme a vela queima, o sol desce e a lua sobe (do dia para a noite).

import SwiftUI

struct CenarioView: View {
    var acesa: Bool
    var progresso: Double
    var mostrarPersonagens: Bool
    var comFundo = true      // false = só as figuras (usado para fazer as sombras)
    var quadro: Quadro? = nil // posição da arte. Quem desenha a vela passa o mesmo quadro, para tudo bater.

    var body: some View {
        if arteExiste("tenda") {
            if let quadro {
                cenarioComArte(quadro)
            } else {
                GeometryReader { geo in cenarioComArte(Quadro(tela: geo.size)) }
                    .ignoresSafeArea()
            }
        } else {
            cenarioProvisorio
        }
    }

    // Com a arte da Georgia: camadas de papel, escurecendo aos poucos (do dia para a noite)
    private func cenarioComArte(_ quadro: Quadro) -> some View {
        ZStack {
            if comFundo {
                (acesa ? Cores.fundoClaro : Cores.fundoEscuro)
                    .ignoresSafeArea()
            }
            CenaArte(quadro: quadro, mostrarPersonagens: mostrarPersonagens)
            if comFundo {
                // Anoitecendo conforme a vela queima
                Color(red: 0.08, green: 0.1, blue: 0.3)
                    .opacity(0.3 * progresso)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        .animation(.easeInOut(duration: 1.2), value: acesa)
        .animation(.easeInOut(duration: 1.2), value: mostrarPersonagens)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(descricao)
    }

    // Sem arte: formas provisórias
    private var cenarioProvisorio: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                if comFundo {
                    (acesa ? Cores.fundoClaro : Cores.fundoEscuro)

                    // Camada 1: tenda listrada
                    Arte("tenda") { Tenda() }
                        .frame(width: w, height: h)
                }

                // Camada 2: roda com o sol de um lado e a lua do outro.
                // Meia volta durante a vela inteira: começa de dia, termina de noite.
                RodaSolLua(raio: h * 0.3)
                    .rotationEffect(.degrees(180 * progresso))
                    .position(x: w / 2, y: h * 0.62)
                    .mask(Rectangle().frame(height: h * 0.62).frame(maxHeight: .infinity, alignment: .top))
                    .animation(.linear(duration: 0.3), value: progresso)

                // Camada 3: personagens (só aparecem quando a vela acende)
                if mostrarPersonagens {
                    Personagens(tamanho: CGSize(width: w, height: h))
                        .transition(.opacity)
                }

                // Camada 4: palco
                Arte("palco") {
                    ZStack {
                        Ellipse().fill(Cores.papel.opacity(0.35))
                        Ellipse().stroke(Cores.tinta, lineWidth: 2)
                        HStack(spacing: w * 0.08) {
                            ForEach(0..<6, id: \.self) { _ in
                                Estrela().stroke(Cores.tinta, lineWidth: 1.5).frame(width: 14, height: 14)
                            }
                        }
                        .offset(y: h * 0.035)
                    }
                }
                .frame(width: w * 0.95, height: h * 0.13)
                .position(x: w / 2, y: h * 0.83)
            }
            .animation(.easeInOut(duration: 1.2), value: acesa)
            .animation(.easeInOut(duration: 1.2), value: mostrarPersonagens)
        }
        .ignoresSafeArea()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(descricao)
    }

    // O que o VoiceOver fala sobre o cenário (sem números)
    private var descricao: String {
        guard mostrarPersonagens else { return "Circo de papel, no escuro" }
        switch progresso {
        case ..<0.25: return "Circo de papel. Amanhecendo, o sol está alto"
        case ..<0.5: return "Circo de papel. O sol está descendo"
        case ..<0.75: return "Circo de papel. Anoitecendo, a lua está subindo"
        default: return "Circo de papel. Noite, a lua está alta"
        }
    }
}

private struct Tenda: View {
    var body: some View {
        Canvas { ctx, size in
            let topo = CGPoint(x: size.width / 2, y: -size.height * 0.15)
            for i in 0...8 {
                let x = size.width * CGFloat(i) / 8
                var p = Path()
                p.move(to: topo)
                p.addQuadCurve(to: CGPoint(x: x, y: size.height),
                               control: CGPoint(x: (topo.x + x) / 2 + (x - topo.x) * 0.3, y: size.height * 0.45))
                ctx.stroke(p, with: .color(Cores.tinta.opacity(0.45)), lineWidth: 2)
            }
        }
    }
}

private struct RodaSolLua: View {
    var raio: CGFloat

    var body: some View {
        ZStack {
            Arte("sol") {
                ZStack {
                    ForEach(0..<12, id: \.self) { i in
                        Capsule().fill(Cores.dourado)
                            .frame(width: 4, height: raio * 0.16)
                            .offset(y: -raio * 0.3)
                            .rotationEffect(.degrees(Double(i) * 30))
                    }
                    Circle().fill(Cores.dourado)
                        .overlay(Circle().stroke(Cores.tinta, lineWidth: 2))
                        .frame(width: raio * 0.4, height: raio * 0.4)
                }
            }
            .frame(width: raio * 0.8, height: raio * 0.8)
            .offset(y: -raio)

            // A lua fica do lado oposto, de cabeça para baixo, para ficar em pé quando chegar no alto
            Arte("lua") {
                LuaCrescente()
                    .fill(Cores.cera)
                    .overlay(LuaCrescente().stroke(Cores.tinta, lineWidth: 2))
            }
            .frame(width: raio * 0.75, height: raio * 0.75)
            .rotationEffect(.degrees(180))
            .offset(y: raio)
        }
        .frame(width: raio * 2.8, height: raio * 2.8)
    }
}

// Personagens provisórios, mexendo de leve (como bonecos articulados)
private struct Personagens: View {
    var tamanho: CGSize
    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento

    private struct Boneco {
        let arte: String
        let x: CGFloat, y: CGFloat, altura: CGFloat
        let bracos: Double
        let pendurado: Bool
    }

    private static let lista = [
        Boneco(arte: "personagem1", x: 0.70, y: 0.20, altura: 0.12, bracos: 2.8, pendurado: true),  // trapezista
        Boneco(arte: "personagem2", x: 0.17, y: 0.42, altura: 0.15, bracos: 1.4, pendurado: false), // acrobata
        Boneco(arte: "personagem3", x: 0.18, y: 0.70, altura: 0.16, bracos: 0.9, pendurado: false), // bambolês
        Boneco(arte: "personagem4", x: 0.82, y: 0.66, altura: 0.16, bracos: 1.6, pendurado: false), // palhaço
    ]

    private var bonecos: [Boneco] { Personagens.lista }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduzirMovimento)) { contexto in
            let t = contexto.date.timeIntervalSinceReferenceDate
            ZStack {
                ForEach(bonecos.indices, id: \.self) { i in
                    let b = bonecos[i]
                    let h = tamanho.height * b.altura
                    let balanco = reduzirMovimento ? 0 : sin(t * (b.pendurado ? 1.3 : 0.9) + Double(i)) * (b.pendurado ? 0.2 : 0.05)
                    Arte(b.arte) {
                        Bonequinho(bracos: b.bracos + sin(t * 2 + Double(i)) * (reduzirMovimento ? 0 : 0.15))
                            .stroke(Cores.tinta, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    }
                    .frame(width: h * 0.6, height: h)
                    .rotationEffect(.radians(balanco), anchor: b.pendurado ? .top : .bottom)
                    .position(x: tamanho.width * b.x, y: tamanho.height * b.y)
                }
            }
        }
        .frame(width: tamanho.width, height: tamanho.height)
    }
}

// MARK: - Previews

#Preview("CenarioView: home (apagada)") {
    CenarioView(acesa: false, progresso: 0, mostrarPersonagens: false)
}

// Arraste o slider para ver o dia virando noite enquanto a vela queima
#Preview("CenarioView: vela acesa") {
    @Previewable @State var progresso = 0.0
    CenarioView(acesa: true, progresso: progresso, mostrarPersonagens: true)
        .overlay(alignment: .bottom) {
            Slider(value: $progresso, in: 0...1) { Text("Progresso da vela") }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                .padding()
        }
}

// Só as figuras, sem fundo (é assim que ele entra no teatro de sombras quando não há arte de sombra)
#Preview("CenarioView: só as figuras") {
    CenarioView(acesa: true, progresso: 0.5, mostrarPersonagens: true, comFundo: false)
        .colorMultiply(.black)
        .opacity(0.7)
        .background(Cores.papel)
}

// O cenário provisório só aparece quando a "tenda" NÃO está no Assets.
// Como a arte da Georgia já chegou, as peças provisórias ficam aqui separadas.

#Preview("Provisório: Tenda") {
    Tenda()
        .background(Cores.fundoClaro)
        .ignoresSafeArea()
}

#Preview("Provisório: RodaSolLua") {
    @Previewable @State var progresso = 0.0
    VStack(spacing: 30) {
        RodaSolLua(raio: 110)
            .rotationEffect(.degrees(180 * progresso))
        Slider(value: $progresso, in: 0...1) { Text("Progresso da vela") }
    }
    .padding(30)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Cores.fundoClaro)
}

#Preview("Provisório: Personagens") {
    GeometryReader { geo in
        Personagens(tamanho: geo.size)
    }
    .ignoresSafeArea()
    .background(Cores.fundoClaro)
}
