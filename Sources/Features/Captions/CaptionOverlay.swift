import AppKit
import Observation
import SwiftUI

final class CaptionOverlay {
    private static let bottomOffsetRatio = 0.1

    private let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    private let host: NSHostingView<CaptionView>
    private let style: CaptionStyle
    @ObservationIgnored private var observationTask: Task<Void, Never>?

    init(state: CaptionState, style: CaptionStyle = CaptionStyle()) {
        self.style = style
        host = NSHostingView(rootView: CaptionView(state: state, style: style))
        // Otherwise the hosting view resizes the panel to the text's narrowest layout, thousands of points tall.
        host.sizingOptions = []
        panel.contentView = host
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        observationTask = Task { [weak self] in
            let changes = Observations { (state.isVisible, state.committed, state.pending) }
            for await (isVisible, _, _) in changes {
                guard let self else { return }
                update(isVisible: isVisible)
            }
        }
    }

    private func update(isVisible: Bool) {
        guard isVisible else {
            panel.orderOut(nil)
            return
        }
        reposition()
        panel.orderFrontRegardless()
    }

    private func reposition() {
        guard let screen = NSScreen.main else { return }
        let size = NSSize(width: screen.frame.width * style.maxWidthRatio, height: screen.visibleFrame.height * style.areaHeightRatio)
        let origin = NSPoint(x: screen.frame.midX - size.width / 2, y: screen.visibleFrame.minY + screen.frame.height * Self.bottomOffsetRatio)
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
    }
}
