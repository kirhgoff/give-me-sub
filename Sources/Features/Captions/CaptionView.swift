import SwiftUI

struct CaptionView: View {
    let state: CaptionState
    let preferences: Preferences
    var style = CaptionStyle()

    private var appearance: CaptionAppearance { preferences.appearance }

    var body: some View {
        text
            .font(font)
            .fontWeight(appearance.isBold ? .bold : .regular)
            .multilineTextAlignment(.center)
            .padding(.horizontal, style.horizontalPadding)
            .padding(.vertical, style.verticalPadding)
            .background(.black.opacity(appearance.backgroundOpacity), in: RoundedRectangle(cornerRadius: style.cornerRadius))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }

    private var font: Font {
        appearance.fontFamily.map { .custom($0, size: appearance.fontSize) } ?? .system(size: appearance.fontSize)
    }

    private var textColor: Color {
        switch appearance.textColor {
        case .white: .white
        case .yellow: .yellow
        case .cyan: .cyan
        case .green: .green
        }
    }

    private var text: Text {
        let committed = Text(state.committed).foregroundStyle(textColor)
        let pending = Text(state.pending).foregroundStyle(textColor.opacity(style.pendingOpacity))
        return Text("\(committed) \(pending)")
    }
}

#Preview {
    let state = CaptionState()
    state.show(TranscriptSegment(text: "turn off the kitchen", pending: "lights"))
    return CaptionView(state: state, preferences: Preferences())
        .padding()
}
