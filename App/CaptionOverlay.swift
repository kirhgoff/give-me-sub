import AppKit
import SwiftUI

private struct CaptionView: View {
    let committed: String
    let pending: String

    var body: some View {
        Text("\(Text(committed).foregroundColor(.white)) \(Text(pending).foregroundColor(.white.opacity(0.6)))")
            .font(.system(size: 28, weight: .semibold))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 12))
            .frame(maxWidth: (NSScreen.main?.frame.width ?? 1200) * 0.7)
            .fixedSize(horizontal: false, vertical: true)
    }
}

final class CaptionOverlay {
    private let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    private var committed = ""
    private var hideTimer: Timer?

    init() {
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.hidesOnDeactivate = false
    }

    func show(text: String, pending: String) {
        if !text.isEmpty { committed = (committed + " " + text).split(separator: " ").suffix(18).joined(separator: " ") }
        present(CaptionView(committed: committed, pending: pending), hideAfter: 4)
    }

    func flash(_ text: String) {
        committed = ""
        present(CaptionView(committed: text, pending: ""), hideAfter: 1)
    }

    private func present(_ view: CaptionView, hideAfter seconds: TimeInterval) {
        let host = NSHostingView(rootView: view)
        panel.contentView = host
        let size = host.fittingSize
        if let screen = NSScreen.main {
            let origin = NSPoint(x: screen.frame.midX - size.width / 2, y: screen.visibleFrame.minY + screen.frame.height * 0.1)
            panel.setFrame(NSRect(origin: origin, size: size), display: true)
        }
        panel.orderFrontRegardless()
        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { [weak self] _ in
            self?.panel.orderOut(nil)
            self?.committed = ""
        }
    }
}
