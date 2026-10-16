---
name: swift-concurrency
description: Swift 6 concurrency patterns for a MainActor-default app. Use when writing or changing actors, Tasks, AsyncStreams, locks, nonisolated code, or closures handed to system or C callbacks.
user-invocable: false
---

# Swift concurrency under MainActor default isolation

Every unannotated type, function and closure is main-actor isolated. Isolation is the default; leaving main is the decision you write down.

## Choosing where code runs

| The code is… | Make it |
|---|---|
| UI or session state, read by SwiftUI | a plain (main-actor) type, usually `@Observable` |
| mutable state shared across threads | an `actor` |
| a wrapper over a non-thread-safe library or blocking C calls | an `actor` on its own serial executor (below) |
| state that must be read synchronously from several threads | a `nonisolated final class …: Sendable` holding a `Mutex` |
| pure computation or a value type used off main | `nonisolated struct` / `nonisolated enum` / `nonisolated func` |

`Sendable` does not change isolation; adding it to a struct does nothing. Reach for `nonisolated`. `@unchecked Sendable` goes only on your own final class that wraps a non-Sendable framework object confined to one queue or executor, with one line naming that confinement. Prefer a `Mutex` or a `sending` parameter first.

## Closures handed to callbacks

A closure written inside main-actor code is main-actor isolated. When Core Audio, Dispatch, a notification centre or a C callback invokes it on another thread, Swift 6 traps at runtime; the compiler does not catch it. Build such closures in a `nonisolated` method, or make the owning type `nonisolated`, and copy out anything the callback hands you before crossing back.

```swift
nonisolated func makeIOBlock(yielding continuation: AsyncStream<[Float]>.Continuation) -> AudioDeviceIOBlock {
    { _, input, _, _, _ in
        let buffers = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: input))
        guard let buffer = buffers.first, let data = buffer.mData else { return }
        let count = Int(buffer.mDataByteSize) / MemoryLayout<Float>.size
        continuation.yield(Array(UnsafeBufferPointer(start: data.assumingMemoryBound(to: Float.self), count: count)))
    }
}
```

## Actor on a serial executor

```swift
actor Transcriber {
    private let queue = DispatchSerialQueue(label: "transcriber")

    nonisolated var unownedExecutor: UnownedSerialExecutor {
        queue.asUnownedSerialExecutor()
    }
}
```

Blocking calls stay off the cooperative pool, and jobs run in FIFO order. Expose compound operations as one method; a check-then-act pair across two `await`s has a reentrancy gap.

## Stored, cancellable tasks

```swift
@ObservationIgnored private var hideTask: Task<Void, Error>?

func scheduleHide(after delay: Duration) {
    hideTask?.cancel()
    hideTask = Task {
        try await Task.sleep(for: delay)
        isVisible = false
    }
}
```

- Prefer letting the view own the task: expose `func load() async` and call it from `.task { await model.load() }`.
- A task the type must start is stored and cancelled when superseded. A fire-and-forget `Task {}` that touches `self` keeps `self` alive past its owner and makes tests flaky.
- `start()`/`stop()` can return their task as `@discardableResult`, so tests `await task.value` instead of sleeping.
- In a long-lived loop, take `self` weakly per iteration (`guard let self` inside the loop body). A guard before the loop holds `self` for the loop's lifetime, so `deinit` never runs to cancel it.

## Streams

- One consumer: a plain `AsyncStream`, created with `AsyncStream.makeStream()`. Finish the continuation on stop.
- Never iterate one stream from two tasks.

## Done when

- No `@MainActor` outside closure types and members pulled back onto main from a `nonisolated` type.
- Every closure handed to a C, Core Audio or Dispatch callback is formed in a `nonisolated` method or type.
- Every stored `Task` is cancelled when superseded or stopped, and no unstored `Task {}` touches `self`.
