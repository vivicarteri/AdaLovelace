//  Formas.swift
//  Formas desenhadas no código (chama, estrela, lua e bonequinhos provisórios).

import SwiftUI

// Gota de cabeça para baixo: ponta em cima, redonda embaixo (chama)
struct Gota: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let raio = r.width / 2
        let centro = CGPoint(x: r.midX, y: r.maxY - raio)
        p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: centro.y),
                       control: CGPoint(x: r.maxX, y: r.minY + r.height * 0.45))
        p.addArc(center: centro, radius: raio, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
        p.addQuadCurve(to: CGPoint(x: r.midX, y: r.minY),
                       control: CGPoint(x: r.minX, y: r.minY + r.height * 0.45))
        p.closeSubpath()
        return p
    }
}

struct Estrela: Shape {
    var pontas = 5
    var miolo: CGFloat = 0.45   // quanto a estrela é "fina"

    func path(in r: CGRect) -> Path {
        var p = Path()
        let centro = CGPoint(x: r.midX, y: r.midY)
        let fora = min(r.width, r.height) / 2
        let dentro = fora * miolo
        for i in 0..<(pontas * 2) {
            let raio = i.isMultiple(of: 2) ? fora : dentro
            let angulo = Double(i) * .pi / Double(pontas) - .pi / 2
            let ponto = CGPoint(x: centro.x + raio * CGFloat(cos(angulo)),
                                y: centro.y + raio * CGFloat(sin(angulo)))
            if i == 0 { p.move(to: ponto) } else { p.addLine(to: ponto) }
        }
        p.closeSubpath()
        return p
    }
}

struct LuaCrescente: Shape {
    func path(in r: CGRect) -> Path {
        let cheia = Path(ellipseIn: r)
        let corte = Path(ellipseIn: r.offsetBy(dx: r.width * 0.32, dy: -r.height * 0.08))
        return cheia.subtracting(corte)
    }
}

// Bonequinho provisório (até a Georgia mandar os personagens)
struct Bonequinho: Shape {
    var bracos: Double = 0.6     // ângulo dos braços (0 = para baixo, 1,5 = para cima)
    var pernas: Double = 0.35

    func path(in r: CGRect) -> Path {
        var p = Path()
        let w = r.width, h = r.height
        let cabeca = h * 0.16
        let ombro = CGPoint(x: r.midX, y: r.minY + cabeca * 2 + h * 0.04)
        let quadril = CGPoint(x: r.midX, y: r.minY + h * 0.62)

        p.addEllipse(in: CGRect(x: r.midX - cabeca, y: r.minY, width: cabeca * 2, height: cabeca * 2))
        p.move(to: CGPoint(x: r.midX, y: r.minY + cabeca * 2))
        p.addLine(to: quadril)

        let braco = h * 0.32
        for lado in [-1.0, 1.0] {
            p.move(to: ombro)
            p.addLine(to: CGPoint(x: ombro.x + CGFloat(sin(bracos) * lado) * min(braco, w / 2),
                                  y: ombro.y + CGFloat(cos(bracos)) * braco))
        }
        let perna = h * 0.38
        for lado in [-1.0, 1.0] {
            p.move(to: quadril)
            p.addLine(to: CGPoint(x: quadril.x + CGFloat(sin(pernas) * lado) * perna,
                                  y: quadril.y + CGFloat(cos(pernas)) * perna))
        }
        return p
    }
}

// MARK: - Previews

#Preview("Gota", traits: .sizeThatFitsLayout) {
    HStack(alignment: .bottom, spacing: 30) {
        Gota()
            .fill(Cores.dourado)
            .overlay(Gota().stroke(Cores.tinta, lineWidth: 2))
            .frame(width: 40, height: 90)
        Gota()
            .stroke(Cores.tinta, lineWidth: 2)
            .frame(width: 60, height: 90)
    }
    .padding(30)
    .background(Cores.papel)
}

#Preview("Estrela", traits: .sizeThatFitsLayout) {
    HStack(spacing: 24) {
        Estrela()
            .fill(Cores.dourado)
            .overlay(Estrela().stroke(Cores.tinta, lineWidth: 1.5))
        Estrela()
            .stroke(Cores.tinta, lineWidth: 1.5)
        Estrela(pontas: 8, miolo: 0.6)
            .fill(Cores.dourado)
            .overlay(Estrela(pontas: 8, miolo: 0.6).stroke(Cores.tinta, lineWidth: 1.5))
        Estrela(miolo: 0.25)
            .fill(Cores.cortina)
    }
    .frame(height: 60)
    .padding(30)
    .background(Cores.papel)
}

#Preview("LuaCrescente", traits: .sizeThatFitsLayout) {
    LuaCrescente()
        .fill(Cores.cera)
        .overlay(LuaCrescente().stroke(Cores.tinta, lineWidth: 2))
        .frame(width: 120, height: 120)
        .padding(30)
        .background(Cores.fundoEscuro)
}

// Os braços vão de 0 (para baixo) até ~3 (bem para cima, como a trapezista)
#Preview("Bonequinho", traits: .sizeThatFitsLayout) {
    HStack(alignment: .bottom, spacing: 24) {
        ForEach([0.0, 0.6, 1.5, 2.8], id: \.self) { bracos in
            VStack(spacing: 8) {
                Bonequinho(bracos: bracos)
                    .stroke(Cores.tinta, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 54, height: 90)
                Text("braços \(bracos, specifier: "%.1f")")
                    .font(.caption2)
            }
        }
    }
    .padding(30)
    .background(Cores.papel)
}
