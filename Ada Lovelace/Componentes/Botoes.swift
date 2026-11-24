//  Botoes.swift
//  Botões, cortina, caixa de fósforos e fósforo.

import SwiftUI

// Botão redondo de papel com ícone
struct BotaoRedondo: View {
    var icone: String
    var rotulo: String
    var tamanho: CGFloat = 52
    var acao: () -> Void

    var body: some View {
        Button(action: acao) {
            Image(systemName: icone)
                .font(.system(size: tamanho * 0.4, weight: .semibold))
                .foregroundStyle(Cores.tinta)
                .frame(width: tamanho, height: tamanho)
                .background(Circle().fill(Cores.papel))
                .overlay(Circle().stroke(Cores.tinta, lineWidth: 2))
                .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(rotulo)
    }
}

// Botão de descartar. Funciona de dois jeitos (regra de negócio "Descarte contínuo"):
//
//  - Vela acesa ou apagada (passe "derreter"): ENQUANTO a pessoa segura, a vela derrete rápido.
//    Soltou, para. Segurou até o fim, a vela acaba (estado Finalizada). O anel mostra o quanto
//    da vela já foi embora ("anel", de 0 a 1).
//  - Vela que já acabou (sem "derreter"): um TOQUE (ou segurar) coloca uma vela nova.
//    Antes era só segurando 1 segundo, e ninguém descobria: parecia que o app tinha travado.
//
// Com o VoiceOver não dá para segurar, então pede confirmação.
struct BotaoDescartar: View {
    var tamanho: CGFloat = 52
    var haptics: Haptics
    var anel: Double? = nil                      // quanto da vela já derreteu (modo derreter)
    var derreter: ((Bool) -> Void)? = nil        // true = começou a segurar, false = soltou
    var descartar: () -> Void

    @State private var segurando = false
    @State private var confirmar = false
    private var duracao: TimeInterval { 1 }
    private var modoDerreter: Bool { derreter != nil }

    var body: some View {
        ZStack {
            Circle().fill(Cores.papel)
            Circle().stroke(Cores.tinta, lineWidth: 2)
            Circle()
                .trim(from: 0, to: modoDerreter ? CGFloat(anel ?? 0) : (segurando ? 1 : 0))
                .stroke(Cores.cortina, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(3)
            Arte("iconeDescartar") {
                ZStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: tamanho * 0.5, weight: .regular))
                    Image(systemName: "flame.fill")
                        .font(.system(size: tamanho * 0.2))
                }
                .foregroundStyle(Cores.tinta)
            }
            .frame(width: tamanho * 0.6, height: tamanho * 0.6)
        }
        .frame(width: tamanho, height: tamanho)
        .scaleEffect(segurando && modoDerreter ? 0.92 : 1)
        .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
        .contentShape(Circle())
        // Vela acabada: um toque já basta (não tem mais nada a perder)
        .simultaneousGesture(TapGesture().onEnded {
            guard !modoDerreter else { return }
            haptics.tique()
            descartar()
        })
        .onLongPressGesture(minimumDuration: modoDerreter ? 3600 : duracao, maximumDistance: 30) {
            // Só chega aqui no modo "vela nova" (no modo derreter o tempo é enorme de propósito)
            guard !modoDerreter else { return }
            haptics.cancelarSegurar()
            segurando = false
            descartar()
        } onPressingChanged: { pressionando in
            if let derreter {
                withAnimation(.easeOut(duration: 0.15)) { segurando = pressionando }
                derreter(pressionando)      // a Sessao derrete e cuida da vibração
            } else if pressionando {
                haptics.iniciarSegurar(duracao: duracao)
                withAnimation(.linear(duration: duracao)) { segurando = true }
            } else {
                haptics.cancelarSegurar()
                withAnimation(.easeOut(duration: 0.2)) { segurando = false }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(modoDerreter ? "Derreter a vela" : "Vela nova")
        .accessibilityHint(modoDerreter ? "Derrete a vela até o fim" : "Joga esta vela fora e coloca uma nova")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { confirmar = true }
        .confirmationDialog(modoDerreter ? "Derreter a vela até o fim?" : "Colocar uma vela nova?",
                            isPresented: $confirmar, titleVisibility: .visible) {
            Button(modoDerreter ? "Derreter" : "Vela nova", role: .destructive, action: descartar)
            Button("Cancelar", role: .cancel) {}
        }
    }
}

// Cortina vertical que desce para fechar (fim da vela ou descartar)
struct CortinaView: View {
    var fechada: Bool
    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento

    var body: some View {
        GeometryReader { geo in
            // O pano é mais comprido que a tela: a barra de baixo (as pontas recortadas, com
            // buracos entre elas) fica TODA abaixo da tela quando a cortina está fechada.
            // Assim, fechada, ela cobre a tela inteira até o fim; subindo e descendo, as pontas
            // aparecem passando. Vale para qualquer tamanho de iPhone ou iPad.
            let comprimento = TecidoDaCortina.comprimento(tela: geo.size.height)
            let tecido = TecidoDaCortina()
                .frame(width: geo.size.width, height: comprimento, alignment: .top)
                .clipped()

            Group {
                if reduzirMovimento {
                    // Sem movimento: a cortina só aparece e some
                    tecido.opacity(fechada ? 1 : 0)
                } else {
                    tecido.offset(y: fechada ? 0 : -comprimento)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// O pano da cortina. A arte da Georgia ("cortina") é deitada: ela PREENCHE a tela
// (corta um pouco dos lados) em vez de encolher para caber, senão sobrava tela vazia.
private struct TecidoDaCortina: View {
    // Na arte da Georgia (3032 × 2348) o pano é inteiro (sem nenhum buraco) até 85,5% da
    // altura; daí para baixo vêm as pontas recortadas.
    static let parteInteira: CGFloat = 2009.0 / 2348.0

    // Altura do pano para a parte inteira chegar até o fim da tela (com folga)
    static func comprimento(tela altura: CGFloat) -> CGFloat {
        arteExiste("cortina") ? altura / parteInteira + 20 : altura + 60
    }

    var body: some View {
        if arteExiste("cortina") {
            // Preenche a largura/altura pedida, sempre presa no ALTO (o bando de cima aparece inteiro)
            GeometryReader { geo in
                Image("cortina").resizable().scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
            }
        } else {
            ZStack {
                Cores.cortina
                HStack(spacing: 0) {
                    ForEach(0..<8, id: \.self) { _ in
                        LinearGradient(colors: [.black.opacity(0.25), .clear, .black.opacity(0.25)],
                                       startPoint: .leading, endPoint: .trailing)
                    }
                }
            }
        }
    }
}

// Caixa de fósforos: a LUVA (com a lixa de riscar na borda de cima) e a GAVETA,
// que desliza para fora por trás dela. As duas partes nunca se separam.
//
// aberta: 0 = fechada, 1 = gaveta toda para fora.
// Em repouso ela fica entreaberta, para dar para ver que são fósforos lá dentro.
struct CaixaFosforoView: View {
    var largura: CGFloat
    var aberta: CGFloat = CaixaFosforoView.emRepouso

    static let emRepouso: CGFloat = 0.28

    static func altura(largura: CGFloat) -> CGFloat { largura * 0.62 }

    // Quanto a gaveta anda para a esquerda quando abre
    static func corrida(largura: CGFloat) -> CGFloat { largura * 0.44 }

    // A faixa de riscar, em coordenadas de dentro da própria caixa
    static func faixaDaLixa(largura: CGFloat) -> CGRect {
        let h = altura(largura: largura)
        return CGRect(x: largura * 0.04, y: h * 0.08, width: largura * 0.92, height: h * 0.26)
    }

    var body: some View {
        let h = CaixaFosforoView.altura(largura: largura)
        let lixa = CaixaFosforoView.faixaDaLixa(largura: largura)

        ZStack(alignment: .leading) {
            // GAVETA (atrás da luva): desliza para a esquerda e mostra os fósforos deitados
            ZStack(alignment: .leading) {
                // O fundo da gaveta é mais escuro, para ela ler como "dentro da caixa"
                RoundedRectangle(cornerRadius: 4)
                    .fill(Cores.papel)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(LinearGradient(colors: [.black.opacity(0.28), .clear],
                                                 startPoint: .trailing, endPoint: .leading))
                    )
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Cores.tinta, lineWidth: 1.5))
                VStack(spacing: h * 0.13) {
                    ForEach(0..<3, id: \.self) { _ in
                        fosforoDeitado(comprimento: largura * 0.46)
                    }
                }
                .padding(.leading, largura * 0.06)
            }
            .frame(width: largura * 0.90, height: h * 0.82)
            .offset(x: -aberta * CaixaFosforoView.corrida(largura: largura))

            // LUVA (na frente): o corpo da caixa, com a lixa e o desenho
            Arte("caixaFosforo") {
                ZStack {
                    RoundedRectangle(cornerRadius: 5).fill(Cores.papel)
                    LixaView()
                        .frame(width: lixa.width, height: lixa.height)
                        .position(x: lixa.midX, y: lixa.midY)
                    Image(systemName: "flame")
                        .font(.system(size: h * 0.26))
                        .foregroundStyle(Cores.cortina)
                        .offset(y: h * 0.18)
                    RoundedRectangle(cornerRadius: 5).stroke(Cores.tinta, lineWidth: 2)
                }
            }
            .frame(width: largura, height: h)
        }
        .frame(width: largura, height: h, alignment: .leading)
    }

    // Um fósforo deitado dentro da gaveta (cabeça à esquerda)
    private func fosforoDeitado(comprimento: CGFloat) -> some View {
        HStack(spacing: 0) {
            Ellipse()
                .fill(Cores.cortina)
                .overlay(Ellipse().stroke(Cores.tinta, lineWidth: 0.8))
                .frame(width: comprimento * 0.2, height: comprimento * 0.13)
            Capsule()
                .fill(Color(red: 0.85, green: 0.7, blue: 0.48))
                .frame(width: comprimento * 0.8, height: comprimento * 0.07)
        }
        .frame(width: comprimento, alignment: .leading)
    }
}

// Lixa para riscar o fósforo
struct LixaView: View {
    var body: some View {
        Arte("lixa") {
            ZStack {
                RoundedRectangle(cornerRadius: 4).fill(Cores.madeira)
                Canvas { ctx, size in
                    // Pontinhos ásperos
                    let passo: CGFloat = 6
                    var y: CGFloat = 4
                    var linha = 0
                    while y < size.height - 2 {
                        var x: CGFloat = linha.isMultiple(of: 2) ? 4 : 7
                        while x < size.width - 2 {
                            ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1.6, height: 1.6)),
                                     with: .color(Cores.papel.opacity(0.35)))
                            x += passo
                        }
                        y += passo * 0.8
                        linha += 1
                    }
                }
                RoundedRectangle(cornerRadius: 4).stroke(Cores.tinta, lineWidth: 2)
            }
        }
        .accessibilityHidden(true)
    }
}

// Fósforo (cabeça em cima). Aceso = com chaminha.
struct FosforoView: View {
    var aceso: Bool
    var tamanho: CGFloat = 70

    static func posicaoCabeca(tamanho: CGFloat) -> CGFloat { tamanho * 0.1 }  // da cabeça até o topo da vista

    // Tamanho do fósforo no palco e quanto ele fica inclinado (como na mão de alguém)
    static let tamanhoNoPalco: CGFloat = 70
    static let inclinacao: Angle = .degrees(-30)

    // Onde fica o PÉ do fósforo em relação à cabeça, já com a inclinação.
    // (O palito vai até 95% da altura da vista; a cabeça está em 10%.)
    static func peDesdeACabeca(tamanho: CGFloat) -> CGSize {
        let comprimento = tamanho * 0.85
        let a = inclinacao.radians
        // Girar um ponto que está "embaixo" da cabeça (0, comprimento) pelo ângulo a
        return CGSize(width: -comprimento * sin(a), height: comprimento * cos(a))
    }

    var body: some View {
        Arte(aceso ? "fosforoAceso" : "fosforo") {
            ZStack(alignment: .top) {
                Capsule()
                    .fill(Color(red: 0.85, green: 0.7, blue: 0.48))
                    .overlay(Capsule().stroke(Cores.tinta, lineWidth: 1))
                    .frame(width: tamanho * 0.08, height: tamanho * 0.8)
                    .offset(y: tamanho * 0.15)
                Ellipse()
                    .fill(Cores.cortina)
                    .overlay(Ellipse().stroke(Cores.tinta, lineWidth: 1))
                    .frame(width: tamanho * 0.14, height: tamanho * 0.2)
                if aceso {
                    ChamaView(tamanho: tamanho * 0.4)
                        .offset(y: -tamanho * 0.28)
                }
            }
        }
        .frame(width: tamanho * 0.4, height: tamanho)
    }
}

// MARK: - Previews

#Preview("BotaoRedondo", traits: .sizeThatFitsLayout) {
    HStack(spacing: 20) {
        BotaoRedondo(icone: "gearshape", rotulo: "Configurações", tamanho: 44) {}
        BotaoRedondo(icone: "xmark", rotulo: "Fechar") {}
        BotaoRedondo(icone: "paintbrush.pointed", rotulo: "Personalizar vela", tamanho: 60) {}
    }
    .padding(30)
    .background(Cores.fundoEscuro)
}

// No Canvas, segure o botão por 1 segundo para ver o anel encher.
#Preview("BotaoDescartar", traits: .sizeThatFitsLayout) {
    VStack(spacing: 12) {
        BotaoDescartar(tamanho: 60, haptics: Haptics()) { print("Descartou a vela") }
        Text("Segure por 1 segundo")
            .font(.caption)
            .foregroundStyle(Cores.papel)
    }
    .padding(30)
    .background(Cores.fundoEscuro)
}

#Preview("CortinaView") {
    @Previewable @State var fechada = false
    ZStack {
        Cores.fundoClaro.ignoresSafeArea()
        CortinaView(fechada: fechada)
        Button(fechada ? "Abrir cortina" : "Fechar cortina") {
            withAnimation(.easeInOut(duration: 1.6)) { fechada.toggle() }
        }
        .buttonStyle(.borderedProminent)
        .tint(Cores.tinta)
    }
}

#Preview("CaixaFosforoView") {
    @Previewable @State var aberta: CGFloat = CaixaFosforoView.emRepouso
    let largura: CGFloat = 150
    VStack(spacing: 40) {
        CaixaFosforoView(largura: largura, aberta: aberta)
            // Espaço à esquerda para a gaveta ter para onde sair
            .padding(.leading, CaixaFosforoView.corrida(largura: largura))
        Slider(value: $aberta, in: 0...1) { Text("Gaveta") }
        Text("aberta: \(Double(aberta), specifier: "%.2f")  (em repouso: \(Double(CaixaFosforoView.emRepouso), specifier: "%.2f"))")
            .font(.caption)
            .foregroundStyle(Cores.papel)
    }
    .padding(30)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Cores.fundoEscuro)
}

#Preview("LixaView", traits: .sizeThatFitsLayout) {
    LixaView()
        .frame(width: 140, height: 30)
        .padding(30)
        .background(Cores.papel)
}

#Preview("FosforoView", traits: .sizeThatFitsLayout) {
    HStack(alignment: .bottom, spacing: 40) {
        FosforoView(aceso: false)
        FosforoView(aceso: true)
        FosforoView(aceso: true, tamanho: 120)
    }
    .padding(40)
    .background(Cores.fundoEscuro)
}
