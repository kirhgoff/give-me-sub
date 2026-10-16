---
name: swiftui-composition
description: How SwiftUI views are composed — named subviews, constants, previews and modern modifiers. Use when writing or changing a SwiftUI view or AppKit/UIKit hosting code.
user-invocable: false
---

# SwiftUI composition

## Body as a table of contents

```swift
var body: some Scene {
    MenuBarExtra(Self.title, systemImage: statusIcon) {
        toggleButton
        languagePicker
        Divider()
        quitButton
    }
}

private var toggleButton: some View {
    Button(session.isRunning ? Self.stopTitle : Self.startTitle, action: session.toggle)
}
```

- `body` lists named pieces. Each piece is a `private var` (or a `@ViewBuilder private func` when it takes an argument).
- Extract a separate `View` struct when a piece has its own state, is reused, or outgrows a screenful.
- Pass a subview only the data it reads, and closures for its actions: state flows down, actions flow up.
- Use `@Environment` for view-tree services (`dismiss`, `openURL`, `colorScheme`), never to inject app services or models.

## Constants

```swift
struct CaptionStyle {
    var fontSize: CGFloat = 28
    var cornerRadius: CGFloat = 12
    var backgroundOpacity = 0.7
}

struct CaptionView: View {
    let state: CaptionState
    var style = CaptionStyle()
}
```

- A visual or timing value with a meaning gets a name on the type that owns it. Groups of tuning values live on a small style or timing value type passed as an init default, so previews and tests can vary them.
- User-facing strings are named constants on the type that shows them.

## Previews

Every view has a `#Preview` built from constant sample state: a model created with fakes, or plain values. A preview never starts real services.

## Modern APIs

- `foregroundStyle`, not `foregroundColor`.
- `onChange(of:)` with the zero- or two-parameter closure.
- `.task` for async work tied to a view's lifetime, not `onAppear` plus `Task {}`.
- `@State` owns `@Observable` models; `@Bindable` or `Bindable(model)` for bindings into one.
- AppKit/UIKit hosting: create the hosting view once and let it observe state, rather than rebuilding it on each change.

## Done when

`body` fits on one screen and names every piece, the file has no unnamed numeric literal other than 0 or 1, and every view has a `#Preview`.
