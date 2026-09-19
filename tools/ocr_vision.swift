// ocr_vision.swift
// 用途：调用 macOS 自带 Vision 框架，对指定目录下的图片批量做中文 OCR，直接落盘为 Markdown。
// 特点：零第三方依赖、纯本地、离线；识别正文不回显到控制台（仅打印一行统计），以最小化 token 消耗。
// 构建与用法：
//   本机编译器(Swift 6.3.3)与默认 SDK(MacOSX27.0，由 Swift 6.4 构建)不匹配，
//   需显式指定 26.5 SDK 编译：
//     swiftc -sdk /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk ocr_vision.swift -o /tmp/ocrbin
//     /tmp/ocrbin <图片目录> <输出md路径> [最大边长=2000]
// 兼容：macOS 12+（VNRecognizeTextRequest zh-Hans）

import Foundation
import Vision
import ImageIO
import CoreGraphics

let args = CommandLine.arguments
guard args.count >= 3 else {
    FileHandle.standardError.write("用法: swift ocr_vision.swift <图片目录> <输出md路径> [最大边长]\n".data(using: .utf8)!)
    exit(2)
}
let dirPath = args[1]
let outPath = args[2]
let maxSide = CGFloat(args.count >= 4 ? (Double(args[3]) ?? 2000) : 2000)

let fm = FileManager.default
let dirURL = URL(fileURLWithPath: dirPath)

guard let all = try? fm.contentsOfDirectory(at: dirURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
    FileHandle.standardError.write("无法读取目录: \(dirPath)\n".data(using: .utf8)!)
    exit(1)
}

// 从形如 微信图片_20260919120419_35_245.jpg 的文件名中取出页序号 35（倒数第二段数字）
func pageNumber(_ name: String) -> Int {
    let base = (name as NSString).deletingPathExtension
    let parts = base.components(separatedBy: "_")
    if parts.count >= 2, let n = Int(parts[parts.count - 2]) { return n }
    if let n = Int(parts.last ?? "") { return n }
    return Int.max
}

let images = all
    .filter { ["jpg", "jpeg", "png"].contains($0.pathExtension.lowercased()) }
    .sorted { a, b in
        let na = pageNumber(a.lastPathComponent)
        let nb = pageNumber(b.lastPathComponent)
        if na != nb { return na < nb }
        return a.lastPathComponent < b.lastPathComponent
    }

// 载入并按最长边降采样（顺带处理 8~9MB 超大图，控制耗时）
func loadCGImage(_ url: URL) -> CGImage? {
    guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
    let opts: [CFString: Any] = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceThumbnailMaxPixelSize: maxSide
    ]
    if let thumb = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) {
        return thumb
    }
    return CGImageSourceCreateImageAtIndex(src, 0, nil)
}

// 识别单张图片，返回按“先上后下、再左后右”排序的文本行
func recognize(_ cg: CGImage) -> [String] {
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.recognitionLanguages = ["zh-Hans", "en-US"]
    request.usesLanguageCorrection = true

    let handler = VNImageRequestHandler(cgImage: cg, options: [:])
    do { try handler.perform([request]) } catch { return [] }

    guard let results = request.results else { return [] }
    let sorted = results.sorted { a, b in
        // Vision 归一化坐标原点在左下，y 越大越靠上
        let ay = a.boundingBox.origin.y + a.boundingBox.height
        let by = b.boundingBox.origin.y + b.boundingBox.height
        if abs(ay - by) > 0.010 { return ay > by }
        return a.boundingBox.origin.x < b.boundingBox.origin.x
    }
    return sorted.compactMap { $0.topCandidates(1).first?.string }
}

let df = DateFormatter()
df.dateFormat = "yyyy-MM-dd"
let today = df.string(from: Date())

let firstNum = images.first.map { pageNumber($0.lastPathComponent) } ?? 0
let lastNum = images.last.map { pageNumber($0.lastPathComponent) } ?? 0

var out = ""
out += "# 周度复盘与月度复盘 · 书摘原文（本地 OCR 转录）\n\n"
out += "- **来源**：《复盘自己：从记录到蜕变的行动指南》[日]山田智惠（第 4 章）\n"
out += "- **图片**：`input/` 下 \(images.count) 张书页照片，序号 \(firstNum)~\(lastNum)\n"
out += "- **转录方式**：macOS Vision 框架本地 OCR（zh-Hans + en-US，accurate），零第三方依赖\n"
out += "- **转录日期**：\(today)\n"
out += "- **说明**：本文件为 OCR 原始文本，可能存在个别错字/断行；整理版见《复盘方法论-知识库》。\n\n---\n\n"

var ok = 0
var fail = 0
for url in images {
    let num = pageNumber(url.lastPathComponent)
    out += "<!-- 图片 \(num) -->\n\n"
    guard let cg = loadCGImage(url) else {
        fail += 1
        out += "> [OCR 失败：无法读取图片]\n\n"
        continue
    }
    let lines = recognize(cg)
    if lines.isEmpty { fail += 1 } else { ok += 1 }
    out += lines.joined(separator: "\n")
    out += "\n\n"
}

let outURL = URL(fileURLWithPath: outPath)
try? fm.createDirectory(at: outURL.deletingLastPathComponent(), withIntermediateDirectories: true)
do {
    try out.write(to: outURL, atomically: true, encoding: .utf8)
} catch {
    FileHandle.standardError.write("写入失败: \(error)\n".data(using: .utf8)!)
    exit(1)
}

print("[OCR] 完成：成功 \(ok) 张 / 失败 \(fail) 张 → \(outPath)")
