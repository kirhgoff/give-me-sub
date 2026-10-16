---
name: swift-testing
description: Swift Testing conventions for the app's unit tests. Use when writing, changing or reviewing tests, fakes or test helpers.
user-invocable: false
---

# Testing

## What to test

- Test at the highest seam that runs without hardware, permissions or a network: usually an `@Observable` model built with fakes for its I/O protocols.
- Assert outcomes a user would see (model state, what a fake was asked to do), not internal calls.
- A bug fix starts with a failing regression test at that seam.
- Hardware-bound services (audio taps, cameras, system permissions) and plain view code stay untested. Verify them by running the app or taking a screenshot, and say so in the PR.
- When a real dependency can run in a test (a bundled model, a file format), keep one integration test through its protocol.

## Shape

```swift
import Testing
@testable import GiveMeSub

struct SessionTests {
    private let source = FakeAudioSource(blocks: [.silence, .silence])
    private let transcriber = FakeTranscriber()

    @Test
    func `stop keeps the captions-off flash visible`() async {
        let session = Session(source: source, transcriber: transcriber)

        await session.start().value
        await session.stop().value

        #expect(session.caption.text == Session.captionsOff)
    }
}
```

- `import Testing`, `@Test` on its own line, and a backtick name that states the behaviour. Add no display-name string.
- Suites are main-actor by default isolation; never add `@MainActor`.
- Shared fakes and the system under test are `let` properties; Swift Testing creates a fresh suite instance per test.
- Use `@Test(arguments:)` for the same check over several inputs, and `#require` to unwrap instead of nesting.
- Order tests to follow the order of the code under test.

## Fakes

- Fakes are `private` types in the test file, named for their role (`FakeTranscriber`), with properties without a `mock` prefix.
- A fake called off main through an async protocol is an `actor`, or a `nonisolated final class` over a `Mutex` when its protocol is synchronous.
- A test never reaches a real singleton, network, notification centre or file outside a temp directory; if it does, the dependency is missing an `init` parameter.

## Waiting

- No sleeps (SwiftLint fails `Task.sleep` in tests) and no polling loops.
- Await the task the API returns (`await model.start().value`), or wrap a callback in `confirmation { }`.
- Every task the code under test starts has finished or been cancelled when the test returns.

## Done when

Every new behaviour and every fixed bug has a test at the highest seam, and the suite passes in the Xcode MCP test run.
