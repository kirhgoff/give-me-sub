---
name: swift-view-models
description: Decides whether SwiftUI logic needs an @Observable model and gives the model's shape. Use when adding state, async work or logic to a view, or creating or changing an @Observable class.
user-invocable: false
---

# View models

## Does it need one?

Ask two questions about the logic, in order.

1. **Is it domain logic?** It touches storage, network, audio or another I/O seam, or you can name it without naming the screen. Then it belongs in a service or a model type, not in a view or view model.
2. **For what's left: is there a state-transition policy worth a unit test?** Signals include flags that must stay consistent (error vs success, running vs stopped), a failure the user must see, an irreversible action, or logic that keeps growing.
   - **No:** use `private @State` and private functions on the view, and let the view drive async work with `.task` or `Task { await … }` in an action. This is a choice not to test it.
   - **Yes:** use an `@Observable` model, shaped as below.

The urge to unit-test view logic is the signal to extract it. Never make view-resident logic testable in place.

## Shape

```swift
@Observable
final class Session {
    private(set) var isRunning = false
    var language: Language?

    private let source: any AudioSource
    @ObservationIgnored private var task: Task<Void, Never>?

    init(source: any AudioSource = SystemAudioTap()) {
        self.source = source
    }
}
```

- It is main-actor by default: never `@MainActor`.
- Name it for its job (`Session`, `Player`, `Editor`), not `<Screen>ViewModel`, unless it only serves one screen.
- The view owns it as `@State private var session = Session()`. A model shared by several views is created in App and passed down.
- Dependencies come through `init` defaults. Previews and tests pass fakes through the same `init`.
- A model's `init` only stores its dependencies; services start in `start()` or from `.task`. `@State private var x = Model()` runs that `init` on every view init.
- State is `private(set)` unless a view binds to it; bind with `@Bindable` or `Bindable(model).field`.
- Group related state into small `@Observable` data classes when the model grows past a handful of properties.
- Async entry points are `async` methods the view calls from `.task`. If the model must start a task itself, see the stored-task pattern in `swift-concurrency`.
- The model returns outcomes (an enum, a thrown error). Navigation, dismissal, alerts and haptics stay in the view.
- Strings shown to the user and timing values are named constants on the model.

## Done when

- Every `@Observable` has a transition rule that a test pins.
- No `@MainActor`, and no `@ObservationIgnored` on a `let`.
- Every dependency is an `init` parameter with a default.
