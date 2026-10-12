import Testing
@testable import GiveMeSub

struct CaptionStateTests {
    private let caption = CaptionState()

    @Test
    func `a subtitle pass without words keeps the flash on screen`() {
        caption.flash(Captioner.captionsOn)

        caption.showSubtitle("")

        #expect(caption.committed == Captioner.captionsOn)
        #expect(caption.isVisible)
    }
}
