## Architecture

SwiftUI app, Swift 6 language mode, every type main-actor isolated by default (`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, approachable concurrency on).

- `Sources/App`: the `@main` App, scenes and object lifetimes.
- `Sources/Features/<Feature>`: a screen's views and, when it earns one, its `@Observable` model.
- `Sources/Services`: I/O seams, each a small protocol plus its production implementation.
- `Sources/Models`: plain value types shared across layers; no I/O, no SwiftUI.
- `Tests`: Swift Testing suites, one per feature seam.

Dependencies point down: App → Features → Services → Models. App creates long-lived objects; features never import each other, shared pieces move down a layer.

`project.yml` (XcodeGen) defines the project. Edit it, then run `xcodegen generate`; the `.xcodeproj` is generated and gitignored, so changes made in Xcode's target editor are lost.

## Core rules

**Concurrency** (load `swift-concurrency` before writing actors, tasks, streams or callbacks)
- Write `@MainActor` only on closure types that must run on main, or on a member of a `nonisolated` type that needs main back.
- Code that runs off main says so: `nonisolated` on the type or function, or an `actor`.
- Closures handed to C, Core Audio or Dispatch callbacks are formed in a `nonisolated` method or type.
- Use an actor only for mutable state genuinely shared across threads.
- Deferred and repeating work is a stored `Task` with `Task.sleep`, cancelled when superseded.
- Banned, and enforced by SwiftLint: `DispatchQueue.main.async`, `asyncAfter`, `Timer`, `Task.detached`, `assumeIsolated`, `nonisolated(unsafe)`.

**State and views** (load `swift-view-models` before adding state with rules; `swiftui-composition` before writing views)
- View state that has transition rules lives in an `@Observable final class`, with `@Observable` on its own line. Everything else is `private @State` on the view.
- `@ObservationIgnored` goes on `var`s views must not track (task handles, injected `var`s), never on `let`s.
- `body` reads as a list of named computed properties and small subviews.
- Every number with a meaning is a named constant on the type that owns the concept; tuning values sit on a small value type passed as an init default.

**Dependencies**
- Dependencies arrive through `init` parameters with production defaults: `init(source: any AudioSource = SystemAudioTap())`.
- Put a protocol only at an I/O seam (disk, network, audio, system APIs), and keep it small.
- Name the production implementation for what it is, or `Default<Protocol>` when nothing fits; never an `Impl` suffix.

**Style**
- Guard-first: `guard` with early return over nested `if`.
- Every `func` belongs to a type; no top-level functions.
- Failures are thrown, or logged through `os.Logger` with their reason; `try?` only where failure needs no handling at all.
- Trailing commas in multi-line literals, closing bracket on its own line.
- Code explains itself through names; a comment is one short line for a constraint the code cannot show.

**Tests** (load `swift-testing` before writing tests)
- Swift Testing, backtick names, no sleeps.
- Test at the highest seam that runs without hardware or permissions, with fakes for the I/O protocols.

## Growth rules

Add each only when its trigger fires, in its own PR.

| Trigger | Then |
|---|---|
| A type's `init` takes more than ~5 defaulted dependencies | Introduce a small DI container that the App builds once; inits keep their parameters, defaults resolve from the container. |
| The same domain logic is needed by two features | Extract it into a use case: a UI-free type in `Sources/UseCases` that takes and returns domain values. |
| A second app, or a component restyled in 3+ features | Move colours, spacing, typography and reusable components into a design-system Swift package. |
| A second language ships | Add a String Catalog; every user-facing string goes through it. |
| A crash or analytics backend exists | Report recoverable failures as non-fatals through one reporting seam instead of only `os.Logger`. |
| A stream gets a second consumer | Replace the stored `AsyncStream` with a broadcaster that vends one stream per subscriber (replaying the latest value for state streams). |
| A network API's shape diverges from the domain type | Keep transport types private to the service in `<Service>+API.swift` with a mapper; callers see only domain types. |

## Checks

Before every commit, all must pass:
1. `xcodegen generate` when `project.yml` changed.
2. `swiftlint lint --strict` exits 0.
3. Build and run the tests through the Xcode MCP server (its build and test tools, against the open project tab), never a raw `xcodebuild`.

The Stop hook (`.claude/hooks/stop-check.sh`) runs steps 1 and 2 automatically when the tree is dirty; step 3 is on you.

## Troubleshooting

If the app quits about 1 s after launch ("Finished running"), Control Center refused its menu-bar icon: `defaults read com.kirhgoff.givemesub` shows `NSStatusItem VisibleCC Item-0 = 0`. Suggest a Mac restart before debugging the code.
