// converte-video.swift
// Transforma um vídeo .mov da Georgia (fundo transparente, 12 fps) em imagens para o app:
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

let a = CommandLine.arguments
guard a.count >= 4 else { print("uso: converte-video.swift <video.mov> <nome> <Assets.xcassets>"); exit(1) }
let url = URL(fileURLWithPath: a[1]); let nome = a[2]; let assets = a[3]
let asset = AVURLAsset(url: url)
let track = asset.tracks(withMediaType: .video)[0]

// PASSO 1: descobrir onde está a peça e onde fica o que muda (ignorando o "chuvisco" do vídeo)
func analisar() -> [Int] {
    let reader = try! AVAssetReader(asset: asset)
    let out = AVAssetReaderTrackOutput(track: track, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
    reader.add(out); reader.startReading()
    var base: [UInt8] = []; var W = 0, H = 0, i = 0
    var colA = [Int](), rowA = [Int](), colD = [Int](), rowD = [Int]()
    while let sb = out.copyNextSampleBuffer(), let pb = CMSampleBufferGetImageBuffer(sb) {
        CVPixelBufferLockBaseAddress(pb, .readOnly)
        W = CVPixelBufferGetWidth(pb); H = CVPixelBufferGetHeight(pb); let bpr = CVPixelBufferGetBytesPerRow(pb)
        let p = CVPixelBufferGetBaseAddress(pb)!.assumingMemoryBound(to: UInt8.self)
        if i == 0 {
            colA = [Int](repeating: 0, count: W); rowA = [Int](repeating: 0, count: H); colD = colA; rowD = rowA
            base = [UInt8](repeating: 0, count: W * H * 4)
            for y in 0..<H { for x in 0..<W * 4 { base[y * W * 4 + x] = p[y * bpr + x] } }
        }
        for y in stride(from: 0, to: H, by: 2) { for x in stride(from: 0, to: W, by: 2) {
            let o = y * bpr + x * 4, b = y * W * 4 + x * 4
            if i == 0 && p[o + 3] > 60 { colA[x] += 1; rowA[y] += 1 }
            if i > 0 {
                var d = 0; for c in 0..<4 { d = max(d, abs(Int(p[o + c]) - Int(base[b + c]))) }
                if d > 60 { colD[x] += 1; rowD[y] += 1 }
            }
        } }
        CVPixelBufferUnlockBaseAddress(pb, .readOnly)
        i += 1
    }
    func faixa(_ v: [Int], _ n: Int) -> (Int, Int) {
        let idx = v.indices.filter { v[$0] >= n }
        return idx.isEmpty ? (0, 0) : (idx.first!, idx.last!)
    }
    let (ax0, ax1) = faixa(colA, 4), (ay0, ay1) = faixa(rowA, 4)
    var (dx0, dx1) = faixa(colD, 6), (dy0, dy1) = faixa(rowD, 6)
    if dx1 == 0 && dy1 == 0 { (dx0, dx1, dy0, dy1) = (ax0, ax0, ay0, ay0) }   // nada muda
    return [ax0, ay0, ax1, ay1, dx0, dy0, dx1, dy1]
}
let n = analisar()

// PASSO 2: salvar a peça, os pedacinhos diferentes e o ritmo
let margem = 10, margemMuda = 14
let W = Int(track.naturalSize.width), H = Int(track.naturalSize.height)
let fps = Double(track.nominalFrameRate)
let total = Int((CMTimeGetSeconds(asset.duration) * fps).rounded())

func caixa(_ x0: Int, _ y0: Int, _ x1: Int, _ y1: Int, _ m: Int) -> CGRect {
    let a = max(0, x0 - m), b = max(0, y0 - m), c = min(W, x1 + 1 + m), d = min(H, y1 + 1 + m)
    return CGRect(x: a, y: b, width: c - a, height: d - b)
}
let peca = caixa(n[0], n[1], n[2], n[3], margem)
let muda = caixa(n[4], n[5], n[6], n[7], margemMuda)

let gen = AVAssetImageGenerator(asset: asset)
gen.requestedTimeToleranceBefore = .zero; gen.requestedTimeToleranceAfter = .zero

// Pixels RGBA (pré-multiplicados) de um recorte
func pixels(_ img: CGImage, _ r: CGRect) -> [UInt8] {
    let w = Int(r.width), h = Int(r.height)
    var buf = [UInt8](repeating: 0, count: w * h * 4)
    let ctx = CGContext(data: &buf, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.draw(img.cropping(to: r)!, in: CGRect(x: 0, y: 0, width: w, height: h))
    return buf
}
func diferenca(_ p: [UInt8], _ q: [UInt8]) -> Double {
    var s = 0; for i in 0..<p.count { s += abs(Int(p[i]) - Int(q[i])) }
    return Double(s) / Double(p.count)
}
func salvar(_ img: CGImage, _ nomeImagem: String) {
    let pasta = "\(assets)/\(nomeImagem).imageset"
    try? FileManager.default.createDirectory(atPath: pasta, withIntermediateDirectories: true)
    let rep = NSBitmapImageRep(cgImage: img)
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(pasta)/\(nomeImagem).png"))
    let json = "{\n  \"images\" : [\n    {\n      \"filename\" : \"\(nomeImagem).png\",\n      \"idiom\" : \"universal\"\n    }\n  ],\n  \"info\" : {\n    \"author\" : \"xcode\",\n    \"version\" : 1\n  }\n}\n"
    try! json.write(toFile: "\(pasta)/Contents.json", atomically: true, encoding: .utf8)
}

var unicos: [[UInt8]] = []      // pedacinhos já salvos (0 = o da peça parada)
var ritmo: [Int] = []
var piorPerdaDeAlfa = 0
for i in 0..<total {
    let t = CMTime(value: CMTimeValue(i), timescale: CMTimeScale(fps))
    let img = try! gen.copyCGImage(at: t, actualTime: nil)
    if i == 0 { salvar(img.cropping(to: peca)!, nome) }
    let p = pixels(img, muda)
    if i == 0 { unicos.append(p); ritmo.append(0); continue }
    // Algum pixel ficou transparente onde a peça parada tem desenho? (o pedacinho não conseguiria apagar)
    for k in stride(from: 3, to: p.count, by: 4) { piorPerdaDeAlfa = max(piorPerdaDeAlfa, Int(unicos[0][k]) - Int(p[k])) }
    if let j = unicos.firstIndex(where: { diferenca($0, p) < 2.0 }) { ritmo.append(j); continue }
    unicos.append(p); ritmo.append(unicos.count - 1)
    salvar(img.cropping(to: muda)!, "\(nome)_\(unicos.count - 1)")
}
print("// \(nome): \(total) quadros a \(fps) fps, \(unicos.count - 1) pedacinhos diferentes. Maior perda de alfa: \(piorPerdaDeAlfa)")
print("// peca: \(peca)  muda: \(muda)")
print("""

    static let \(nome) = PecaAnimada(
        nome: "\(nome)",
        peca: CGRect(x: \(Int(peca.minX)), y: \(Int(peca.minY)), width: \(Int(peca.width)), height: \(Int(peca.height))),
        pedaco: CGRect(x: \(Int(muda.minX)), y: \(Int(muda.minY)), width: \(Int(muda.width)), height: \(Int(muda.height))),
        ritmo: [\(ritmo.map(String.init).joined(separator: ", "))]
    )
""")
