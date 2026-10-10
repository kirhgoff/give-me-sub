import SwiftUI

struct CaptionView: View {
    let state: CaptionState
    var style = CaptionStyle()

    var body: some View {
        text
            .font(.system(size: style.fontSize, weight: .semibold))
            .multilineTextAlignment(.center)
            .padding(.horizontal, style.horizontalPadding)
            .padding(.vertical, style.verticalPadding)
            .background(.black.opacity(style.backgroundOpacity), in: RoundedRectangle(cornerRadius: style.cornerRadius))
            .frame(maxWidth: maxWidth)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var text: Text {
        let committed = Text(state.committed).foregroundStyle(.white)
        let pending = Text(state.pending).foregroundStyle(.white.opacity(style.pendingOpacity))
        return Text("\(committed) \(pending)")
    }

    private var maxWidth: CGFloat {
        (NSScreen.main?.frame.width ?? style.fallbackScreenWidth) * style.maxWidthRatio
    }
}

#Preview {
    let state = CaptionState()
    state.show(TranscriptSegment(text: "turn off the kitchen", pending: "lights"))
    return CaptionView(state: state)
        .padding()
}
