// converte-video.swift
// Transforma um vídeo .mov (fundo transparente, 12 fps) em imagens para o app:
// a peça parada + só o pedacinho que muda em cada quadro + o ritmo.
//
// COMO USAR (no Terminal, dentro da pasta do projeto):
//   DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift Ferramentas/converte-video.swift caminho/do/video.mov cenarioNome "Ada Lovelace/Assets.xcassets"
//
// No final ele imprime o trecho para colar em Componentes/CenarioAnimado.swift (peça, pedaço e ritmo).
// Funciona bem quando só uma parte pequena muda (olho piscando, boca, bandeirinha).
// Se a peça inteira se mexe no vídeo, o "pedaço" vira a peça toda e fica pesado: aí é melhor
// fazer o movimento no código e mandar só o que é desenhado quadro a quadro.

import AVFoundation
import AppKit

func falhar(_ mensagem: String) -> Never {
    FileHandle.standardError.write(Data("Erro: \(mensagem)\n".utf8))
    exit(1)
}

let a = CommandLine.arguments
guard a.count >= 4 else {
    falhar("uso: converte-video.swift <video.mov> <nome> <Assets.xcassets>")
}
let url = URL(fileURLWithPath: a[1])
let nome = a[2]
// Ao reconverter uma peça, mantenha os quadros no grupo onde ela já está.
let destino = URL(fileURLWithPath: a[3], isDirectory: true)
let assets: String
if destino.pathExtension == "xcassets",
   let itens = FileManager.default.enumerator(at: destino, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]),
   let pecaExistente = itens.lazy.compactMap({ $0 as? URL }).first(where: { $0.lastPathComponent == "\(nome).imageset" }) {
    assets = pecaExistente.deletingLastPathComponent().path
} else {
    assets = destino.path
}

guard FileManager.default.fileExists(atPath: url.path) else {
    falhar("arquivo de vídeo não encontrado em '\(url.path)'.")
}

let asset = AVURLAsset(url: url)
guard let track = asset.tracks(withMediaType: .video).first else {
    falhar("nenhuma faixa de vídeo encontrada em '\(url.lastPathComponent)'.")
}

struct AnaliseVideo {
    let largura: Int
    let altura: Int
    let limites: [Int]
}

// PASSO 1: descobrir onde está a peça e onde fica o que muda (ignorando o "chuvisco" do vídeo)
func analisar() -> AnaliseVideo {
    let reader: AVAssetReader
    do {
        reader = try AVAssetReader(asset: asset)
    } catch {
        falhar("não foi possível abrir o vídeo para leitura: \(error.localizedDescription)")
    }
    let out = AVAssetReaderTrackOutput(
        track: track,
        outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
    )
    guard reader.canAdd(out) else {
        falhar("não foi possível adicionar a saída de leitura da faixa de vídeo.")
    }
    reader.add(out)
    guard reader.startReading() else {
        falhar("falha ao iniciar a leitura do vídeo: \(reader.error?.localizedDescription ?? "erro desconhecido")")
    }

    var base: [UInt8] = []
    var W = 0, H = 0, i = 0
    var colA = [Int](), rowA = [Int](), colD = [Int](), rowD = [Int]()

    while let sb = out.copyNextSampleBuffer(), let pb = CMSampleBufferGetImageBuffer(sb) {
        CVPixelBufferLockBaseAddress(pb, .readOnly)
        W = CVPixelBufferGetWidth(pb)
        H = CVPixelBufferGetHeight(pb)
        let bpr = CVPixelBufferGetBytesPerRow(pb)
        guard let baseAddr = CVPixelBufferGetBaseAddress(pb) else {
            CVPixelBufferUnlockBaseAddress(pb, .readOnly)
            falhar("buffer de pixels inválido no quadro \(i).")
        }
        let p = baseAddr.assumingMemoryBound(to: UInt8.self)

        if i == 0 {
            colA = [Int](repeating: 0, count: W)
            rowA = [Int](repeating: 0, count: H)
            colD = colA
            rowD = rowA
            base = [UInt8](repeating: 0, count: W * H * 4)
            for y in 0..<H {
                for x in 0..<(W * 4) {
                    base[y * W * 4 + x] = p[y * bpr + x]
                }
            }
        }

        for y in 0..<H {
            let linhaO = y * bpr
            let linhaB = y * W * 4
            for x in 0..<W {
                let o = linhaO + x * 4
                let b = linhaB + x * 4
                if i == 0 && p[o + 3] > 60 {
                    colA[x] += 1
                    rowA[y] += 1
                }
                if i > 0 {
                    var d = 0
                    for c in 0..<4 {
                        d = max(d, abs(Int(p[o + c]) - Int(base[b + c])))
                    }
                    if d > 60 {
                        colD[x] += 1
                        rowD[y] += 1
                    }
                }
            }
        }
        CVPixelBufferUnlockBaseAddress(pb, .readOnly)
        i += 1
    }

    if reader.status == .failed {
        falhar("leitura do vídeo interrompida: \(reader.error?.localizedDescription ?? "erro desconhecido")")
    }
    guard i > 0, W > 0, H > 0 else {
        falhar("o vídeo não contém quadros decodificáveis.")
    }

    func faixa(_ v: [Int], _ n: Int) -> (Int, Int)? {
        let idx = v.indices.filter { v[$0] >= n }
        guard let primeiro = idx.first, let ultimo = idx.last else { return nil }
        return (primeiro, ultimo)
    }

    let faixaAX = faixa(colA, 4) ?? faixa(colA, 1) ?? (0, W - 1)
    let faixaAY = faixa(rowA, 4) ?? faixa(rowA, 1) ?? (0, H - 1)
    let (ax0, ax1) = faixaAX
    let (ay0, ay1) = faixaAY

    let faixaDX = faixa(colD, 6) ?? faixa(colD, 1)
    let faixaDY = faixa(rowD, 6) ?? faixa(rowD, 1)
    let (dx0, dx1, dy0, dy1): (Int, Int, Int, Int)
    if let (x0, x1) = faixaDX, let (y0, y1) = faixaDY {
        (dx0, dx1, dy0, dy1) = (x0, x1, y0, y1)
    } else {
        // Nada muda entre os quadros
        (dx0, dx1, dy0, dy1) = (ax0, ax0, ay0, ay0)
    }

    return AnaliseVideo(largura: W, altura: H, limites: [ax0, ay0, ax1, ay1, dx0, dy0, dx1, dy1])
}

let analise = analisar()
let n = analise.limites

// PASSO 2: salvar a peça, os pedacinhos diferentes e o ritmo
let margem = 10, margemMuda = 14
let W = analise.largura > 0 ? analise.largura : Int(track.naturalSize.width)
let H = analise.altura > 0 ? analise.altura : Int(track.naturalSize.height)
let fpsBruto = Double(track.nominalFrameRate)
let fps = fpsBruto > 0 ? fpsBruto : 12.0
let total = max(1, Int((CMTimeGetSeconds(asset.duration) * fps).rounded()))

func caixa(_ x0: Int, _ y0: Int, _ x1: Int, _ y1: Int, _ m: Int) -> CGRect {
    let a = max(0, x0 - m), b = max(0, y0 - m), c = min(W, x1 + 1 + m), d = min(H, y1 + 1 + m)
    return CGRect(x: a, y: b, width: max(1, c - a), height: max(1, d - b))
}
let peca = caixa(n[0], n[1], n[2], n[3], margem)
let muda = caixa(n[4], n[5], n[6], n[7], margemMuda)

let gen = AVAssetImageGenerator(asset: asset)
gen.appliesPreferredTrackTransform = true
gen.requestedTimeToleranceBefore = .zero
gen.requestedTimeToleranceAfter = .zero

guard let espacoCor = CGColorSpace(name: CGColorSpace.sRGB) else {
    falhar("não foi possível criar o espaço de cor sRGB.")
}

// Pixels RGBA (pré-multiplicados) de um recorte
func pixels(_ img: CGImage, _ r: CGRect) -> [UInt8] {
    let w = Int(r.width), h = Int(r.height)
    var buf = [UInt8](repeating: 0, count: w * h * 4)
    guard let ctx = CGContext(
        data: &buf,
        width: w,
        height: h,
        bitsPerComponent: 8,
        bytesPerRow: w * 4,
        space: espacoCor,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        falhar("não foi possível criar o contexto gráfico \(w)x\(h).")
    }
    guard let recorte = img.cropping(to: r) else {
        falhar("falha ao recortar retângulo \(r) da imagem.")
    }
    ctx.draw(recorte, in: CGRect(x: 0, y: 0, width: w, height: h))
    return buf
}

func diferenca(_ p: [UInt8], _ q: [UInt8]) -> Double {
    var s = 0
    for i in 0..<p.count { s += abs(Int(p[i]) - Int(q[i])) }
    return Double(s) / Double(p.count)
}

func limparPedacosAntigos() {
    let fm = FileManager.default
    guard let itens = try? fm.contentsOfDirectory(atPath: assets) else { return }
    let prefixo = "\(nome)_"
    let sufixo = ".imageset"
    for item in itens where item.hasPrefix(prefixo) && item.hasSuffix(sufixo) {
        let miolo = item.dropFirst(prefixo.count).dropLast(sufixo.count)
        if !miolo.isEmpty && miolo.allSatisfy(\.isNumber) {
            try? fm.removeItem(atPath: "\(assets)/\(item)")
        }
    }
}

func salvar(_ img: CGImage, _ nomeImagem: String) {
    let pasta = "\(assets)/\(nomeImagem).imageset"
    do {
        try FileManager.default.createDirectory(atPath: pasta, withIntermediateDirectories: true)
        let rep = NSBitmapImageRep(cgImage: img)
        guard let png = rep.representation(using: .png, properties: [:]) else {
            falhar("não foi possível codificar '\(nomeImagem).png'.")
        }
        try png.write(to: URL(fileURLWithPath: "\(pasta)/\(nomeImagem).png"), options: .atomic)
        let json = "{\n  \"images\" : [\n    {\n      \"filename\" : \"\(nomeImagem).png\",\n      \"idiom\" : \"universal\"\n    }\n  ],\n  \"info\" : {\n    \"author\" : \"xcode\",\n    \"version\" : 1\n  }\n}\n"
        try json.write(toFile: "\(pasta)/Contents.json", atomically: true, encoding: .utf8)
    } catch {
        falhar("falha ao salvar '\(nomeImagem)': \(error.localizedDescription)")
    }
}

limparPedacosAntigos()

var unicos: [[UInt8]] = []      // pedacinhos já salvos (0 = o da peça parada)
var ritmo: [Int] = []
var piorPerdaDeAlfa = 0
for i in 0..<total {
    let t = CMTime(seconds: Double(i) / fps, preferredTimescale: 60000)
    let img: CGImage
    do {
        img = try gen.copyCGImage(at: t, actualTime: nil)
    } catch {
        falhar("falha ao extrair o quadro \(i) em \(Double(i) / fps)s: \(error.localizedDescription)")
    }
    if i == 0 {
        guard let recortePeca = img.cropping(to: peca) else {
            falhar("falha ao recortar a peça principal \(peca).")
        }
        salvar(recortePeca, nome)
    }
    let p = pixels(img, muda)
    if i == 0 { unicos.append(p); ritmo.append(0); continue }
    // Algum pixel ficou transparente onde a peça parada tem desenho? (o pedacinho não conseguiria apagar)
    for k in stride(from: 3, to: p.count, by: 4) { piorPerdaDeAlfa = max(piorPerdaDeAlfa, Int(unicos[0][k]) - Int(p[k])) }
    if let j = unicos.firstIndex(where: { diferenca($0, p) < 2.0 }) { ritmo.append(j); continue }
    unicos.append(p); ritmo.append(unicos.count - 1)
    guard let recorteMuda = img.cropping(to: muda) else {
        falhar("falha ao recortar o pedaço \(muda) no quadro \(i).")
    }
    salvar(recorteMuda, "\(nome)_\(unicos.count - 1)")
}
let fpsTexto = fps.rounded() == fps ? String(Int(fps)) : String(format: "%.3f", fps)
print("// \(nome): \(total) quadros a \(fpsTexto) fps, \(unicos.count - 1) pedacinhos diferentes. Maior perda de alfa: \(piorPerdaDeAlfa)")
print("// peca: \(peca)  muda: \(muda)")
print("""

    static let \(nome) = PecaAnimada(
        nome: "\(nome)",
        peca: CGRect(x: \(Int(peca.minX)), y: \(Int(peca.minY)), width: \(Int(peca.width)), height: \(Int(peca.height))),
        pedaco: CGRect(x: \(Int(muda.minX)), y: \(Int(muda.minY)), width: \(Int(muda.width)), height: \(Int(muda.height))),
        ritmo: [\(ritmo.map(String.init).joined(separator: ", "))]
    )
""")
