# App Intents vs URL scheme for a global "toggle captions" hotkey

Question (KIR-249): do App Intents declared in give-me-sub (non-sandboxed, ad-hoc signed, `LSUIElement`, macOS 26) show up in Shortcuts and Raycast, can a global hotkey be bound to them, and what does a `givemesub://toggle` URL scheme plus a Raycast Quicklink give instead?

## Findings

### App Intents reach Shortcuts and Spotlight with no registration step
- App Intents expose an app's actions to "Siri, Spotlight, Shortcuts, and widgets". The compiler generates the metadata those system features use to discover intents. ([App Intents](https://developer.apple.com/documentation/appintents))
- App Shortcuts (`AppShortcutsProvider`) are "available as soon as someone installs your app, and you don't have to register them yourself". They show up in the Shortcuts app and other system experiences without the user building anything. ([App Shortcuts](https://developer.apple.com/documentation/appintents/app-shortcuts))
- An intent can declare `supportedModes` to run entirely in the background, without bringing the app forward. That fits a menu bar app. ([AppIntent.supportedModes](https://developer.apple.com/documentation/appintents/appintent/supportedmodes))
- Apple's docs list no sandbox, entitlement or Developer ID requirement for App Intents. What they do need is the compile-time metadata. The current build-log warning about skipped AppIntents metadata extraction is expected while the target has no App Intents code; it should go away once `import AppIntents` is linked. *(Inference: the docs neither state nor rule out an ad-hoc-signing requirement, so check it on the first build. Look for `Metadata.appintents` inside the app bundle and for the action in Shortcuts.)*
- *(Inference)* Discovery depends on LaunchServices knowing the app bundle. `/Applications` is not documented as required, but a stable install location avoids several copies of the app registering from DerivedData.

### Global hotkeys on an App Intent
- **Shortcuts app:** a user shortcut has an "Add Keyboard Shortcut" setting. Once set, you can run it "in any app in macOS" by pressing the key combination; some combinations are reserved by the system. To use it, the user wraps the app's action in a one-step shortcut and binds the key. ([Shortcuts User Guide: run with a keyboard shortcut](https://support.apple.com/guide/shortcuts-mac/apd163eb9f95))
- **Spotlight (macOS 26):** any app can provide actions to Spotlight through App Intents. Actions get "quick keys", but these are typed abbreviations inside Spotlight (e.g. `ft`), not global hotkeys. ([Take actions and shortcuts in Spotlight](https://support.apple.com/guide/mac-help/take-actions-and-shortcuts-in-spotlight-mchl4953dfeb/mac))
- **Raycast:** Raycast lists the user's macOS Shortcuts library in root search and runs them, with icons, folders and arguments. This requires Accessibility permission. ([v1.24.0](https://www.raycast.com/changelog/macos/1-24-0), [v1.44.0](https://www.raycast.com/changelog/1-44-0)) No Raycast changelog or manual page mentions direct App Intents / App Shortcuts discovery. The path is App Intent → user shortcut in Shortcuts → Raycast. Raycast hotkeys are global ("launches a Raycast command from anywhere on your system") and can be set on root-search items via Configure Command → Set Hotkey. ([Command Aliases & Hotkeys](https://manual.raycast.com/command-aliases-and-hotkeys))

### URL scheme + Raycast Quicklink
- Raycast Quicklinks accept deeplinks with custom schemes (e.g. `spotify://…`, `slack://…`), and a hotkey can be assigned to any Quicklink. ([Quicklinks](https://manual.raycast.com/quicklinks))
- *(Inference, standard LaunchServices behaviour)* Opening `givemesub://toggle` launches the app if it is not running and delivers the URL to it. The app only needs a `CFBundleURLTypes` entry and an `onOpenURL` / `application(_:open:)` handler. There is no metadata step and no Accessibility permission for Raycast, and the same URL also works from `open givemesub://toggle`, scripts and Shortcuts' "Open URLs" action.

## Recommendation
For "a hotkey toggles captions", ship the **URL scheme** first. It is a few lines of code and works from Raycast (Quicklink + hotkey), the terminal and Shortcuts. Add an **App Intent** later only if Siri, Spotlight actions or Shortcuts-native discoverability is wanted. Even then, a global hotkey still goes through a user-made shortcut (Shortcuts' own keyboard shortcut, or Raycast's hotkey on that shortcut).
