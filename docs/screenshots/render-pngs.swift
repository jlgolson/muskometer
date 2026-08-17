#!/usr/bin/env swift
import AppKit
import Foundation
import WebKit

/// Headless HTML → PNG via WKWebView + loadHTMLString (sandbox-friendly).
/// Usage: swift docs/screenshots/render-pngs.swift <html> <png> <width> <height>

final class Render: NSObject, WKNavigationDelegate {
    let webView: WKWebView
    let outputURL: URL
    let width: CGFloat
    let height: CGFloat

    init(width: CGFloat, height: CGFloat, outputURL: URL) {
        self.width = width
        self.height = height
        self.outputURL = outputURL
        let config = WKWebViewConfiguration()
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = false
        config.defaultWebpagePreferences = prefs
        let frame = NSRect(x: 0, y: 0, width: width, height: height)
        webView = WKWebView(frame: frame, configuration: config)
        super.init()
        webView.navigationDelegate = self
        if #available(macOS 12.0, *) {
            webView.underPageBackgroundColor = .clear
        }
        webView.setValue(false, forKey: "drawsBackground")
    }

    func load(html: String) {
        // baseURL nil keeps this fully in-memory (no file-sandbox trip).
        webView.loadHTMLString(html, baseURL: nil)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            self.snapshot()
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        fputs("FAIL: navigation error: \(error)\n", stderr)
        exit(1)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        fputs("FAIL: provisional navigation error: \(error)\n", stderr)
        exit(1)
    }

    private func snapshot() {
        let config = WKSnapshotConfiguration()
        config.rect = NSRect(x: 0, y: 0, width: width, height: height)
        webView.takeSnapshot(with: config) { image, error in
            if let error {
                fputs("FAIL: snapshot error: \(error)\n", stderr)
                exit(1)
            }
            guard let image else {
                fputs("FAIL: nil snapshot image\n", stderr)
                exit(1)
            }
            guard let tiff = image.tiffRepresentation,
                  let rep = NSBitmapImageRep(data: tiff),
                  let png = rep.representation(using: .png, properties: [:]) else {
                fputs("FAIL: PNG encode\n", stderr)
                exit(1)
            }
            do {
                try png.write(to: self.outputURL)
                fputs("Wrote \(self.outputURL.path) (\(Int(self.width))x\(Int(self.height)))\n", stderr)
                CFRunLoopStop(CFRunLoopGetMain())
                exit(0)
            } catch {
                fputs("FAIL: write \(error)\n", stderr)
                exit(1)
            }
        }
    }
}

guard CommandLine.arguments.count == 5,
      let width = Double(CommandLine.arguments[3]),
      let height = Double(CommandLine.arguments[4]) else {
    fputs("Usage: render-pngs.swift <html> <png> <width> <height>\n", stderr)
    exit(2)
}

let htmlPath = CommandLine.arguments[1]
let pngPath = CommandLine.arguments[2]
let htmlURL = URL(fileURLWithPath: htmlPath).standardizedFileURL
let pngURL = URL(fileURLWithPath: pngPath).standardizedFileURL

guard let htmlData = try? Data(contentsOf: htmlURL),
      let html = String(data: htmlData, encoding: .utf8) else {
    fputs("FAIL: could not read HTML \(htmlURL.path)\n", stderr)
    exit(1)
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let renderer = Render(width: CGFloat(width), height: CGFloat(height), outputURL: pngURL)
let window = NSWindow(
    contentRect: NSRect(x: 0, y: 0, width: width, height: height),
    styleMask: [.borderless],
    backing: .buffered,
    defer: false
)
window.isReleasedWhenClosed = false
window.backgroundColor = .clear
window.isOpaque = false
window.contentView = renderer.webView
window.orderFrontRegardless()

renderer.load(html: html)

DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
    fputs("FAIL: timed out waiting for snapshot\n", stderr)
    exit(1)
}

app.run()
