# Homebrew + an ad-hoc-signed cask app on macOS 26

Research for KIR-250, 2026-10-10. Context: GiveMeSub is a menu bar app, ad-hoc signed
(`CODE_SIGN_IDENTITY: "-"`), hardened runtime off, not sandboxed. It uses a Core Audio
process tap (the "System Audio Recording" TCC permission) and bundles a Safari web extension
appex. It ships through the personal tap `kirhgoff/homebrew-tap` to a single user. Checked
against Homebrew 7.0.9 (brew `cdc1ca5032`, 2026-10-08).

## Answer

- **`--no-quarantine` is gone.** It was hidden in 4.6.19 (Oct 2025), deprecated in 5.0.0
  (Nov 2025) and deleted in 6.0.0 (Jun 2026). Homebrew quarantines every cask download.
- **A third-party cask can still remove quarantine at install time**, but only from a flight hook,
  and Homebrew is actively closing that door. Legacy Ruby `postflight do … end` blocks still
  run in third-party taps but print deprecation warnings until 2027-12-11. The declarative
  `postflight_steps` replacement has a `run` step that can call `/usr/bin/xattr`.
- **Gatekeeper on macOS 15 and 26:** a quarantined ad-hoc app is blocked on first launch.
  Control-click > Open no longer bypasses this. The user has to approve it once under System
  Settings > Privacy & Security > Open Anyway.
- **TCC does not carry over:** each ad-hoc build gets a `cdhash`-only designated requirement
  (DR), so a "System Audio Recording" grant does not survive an update.
- **A stable signing identity keeps both TCC and Homebrew's Gatekeeper approval across
  upgrades.** Homebrew 7 copies the user's Gatekeeper approval to the new version only when the
  new bundle satisfies the old one's DR.
- **Safari ignores the ad-hoc extension** unless "Allow unsigned extensions" is ticked, and
  that box resets every time Safari quits. An Apple Development signature fixes this; a
  self-signed one does not.

**Recommendation:** sign with a free Apple Development certificate (Xcode Personal Team). It
gives a stable, Apple-anchored DR, so TCC remembers the grant, Homebrew carries the Gatekeeper
approval across upgrades, and Safari loads the extension. You still approve the first install
with Open Anyway once. If you don't want an Apple account in the build, use a long-lived
self-signed code-signing certificate instead: TCC and Homebrew behave the same, but the Safari
extension stays dev-only. Leave quarantine alone rather than stripping it in `postflight`. That
hook is deprecated, and with a stable signer it isn't needed.

## Homebrew

### `--no-quarantine` / `--quarantine`

- 5.0.0 release notes: "`--no-quarantine` and `--quarantine` flags have been deprecated as
  Homebrew does not wish to easily provide circumvention to macOS security features." The same
  release says "Casks without codesigning are deprecated" and that `homebrew/cask` casks failing
  Gatekeeper are disabled in September 2026. —
  [Homebrew 5.0.0](https://brew.sh/2025/11/12/homebrew-5.0.0/)
- brew commit `ffe954753b` "Prepare for deprecation of `--no-quarantine`" (2025-10-23, first in
  tag 4.6.19) hid the flag from the docs and completions.
- brew commit `bc44e3d019` "Homebrew 6 deprecations" (2026-06-08, first in tag 6.0.0) deletes the
  `--[no-]quarantine` switch, which had been `odisabled: true`, from `cmd/install.rb`. The
  remaining code was removed in `ba25213c81` "Remove leftover code for `--no-quarantine`"
  (2026-07-30). `brew install --help` on 7.0.9 has no quarantine option.
- Supply-chain doc: "Homebrew applies macOS quarantine attributes to Cask downloads so
  Gatekeeper performs these checks instead of Homebrew bypassing them." —
  [Homebrew Security and Supply Chain](https://docs.brew.sh/Homebrew-Security-and-Supply-Chain)
  (`docs/Homebrew-Security-and-Supply-Chain.md` L221)

### Gatekeeper policy only binds the official tap

Acceptable-Casks requires Gatekeeper to pass for `homebrew/cask` only: "apps … must pass
Homebrew's Gatekeeper checks and must not require System Integrity Protection or Gatekeeper to
be disabled or bypassed." — [Acceptable Casks](https://docs.brew.sh/Acceptable-Casks). A personal
tap is not audited against this, so an unnotarized cask still installs from it.

### Stripping quarantine in `postflight`

- Cookbook: "Casks in official Homebrew taps must use these structured stanzas; legacy Ruby flight
  blocks are rejected. The legacy forms remain available temporarily for third-party tap
  compatibility." — [Cask Cookbook, `*flight_steps`](https://docs.brew.sh/Cask-Cookbook#stanza-flight_steps)
- 7.0.0 release notes: "Formula `post_install` and cask `*flight` Ruby blocks are deprecated in
  favour of declared `*_steps`"; "official taps reject legacy hooks" while "third-party taps
  receive warnings until 11 December 2027." — [Homebrew 7.0.0](https://brew.sh/2026/09/13/homebrew-7.0.0/)
- The `postflight_steps` DSL has a `run` step that executes a literal command, for example
  `run "/usr/bin/xattr", args: ["-dr", "com.apple.quarantine", "GiveMeSub.app"], base: :appdir`.
  The step sandbox "permits writes to … the caskroom, app directory, …" (Cookbook). I have not
  tested whether that sandbox allows `xattr -d`, and no Homebrew doc covers using it to remove
  quarantine.
- Since 6.0.0, every non-official tap needs explicit trust before Homebrew evaluates it:
  `brew trust kirhgoff/tap`, or `brew trust --cask kirhgoff/tap/<cask>`. —
  [Tap Trust](https://docs.brew.sh/Tap-Trust), [Homebrew 6.0.0](https://brew.sh/2026/06/11/homebrew-6.0.0/)

### How Homebrew 7 handles Gatekeeper approval on upgrade (source)

`Library/Homebrew/cask/upgrade.rb` `quarantine_release_decision` runs on every `brew upgrade`:

1. It records whether the old app was user-approved (Open Anyway) or carried no quarantine at
   all, along with its signing identity. That identity is the app's **designated requirement**
   (`extend/os/mac/cask/quarantine.rb#signing_identity` → `Security.designated_requirement`).
2. If the new bundle satisfies the old DR, it returns `:release`, and `inherit_user_approval!`
   sets the user-approved flag on the new quarantine attribute, so there is no Gatekeeper prompt.
3. If the signer differs, it prints "`<token>`'s signer changed so macOS may prompt at next launch."

An ad-hoc DR is `cdhash H"…"`, which never matches the next build, so every upgrade of the
current app ends in `:signer_changed` and a new Open Anyway trip. With a stable signer the
approval carries forward automatically.

## Gatekeeper on macOS 15 and 26

- Apple Developer News (Aug 2024), quoted by several outlets: "In macOS Sequoia, users will no
  longer be able to Control-click to override Gatekeeper when opening software that isn't signed
  correctly or notarized. They'll need to visit System Settings > Privacy & Security to review
  security information for software before allowing it to run." (The developer.apple.com page did
  not render here; see for example [Eclectic Light](https://eclecticlight.co/2024/08/10/gatekeeper-and-notarization-in-sequoia/).)
- Apple Support: when "macOS can't verify that the app is free of malware", open System Settings
  > Privacy & Security > Open Anyway, confirm with Open, and "the app is saved as an exception to
  your security settings". — [Safely open apps on your Mac](https://support.apple.com/en-us/102445)
- I found no first-party note of a further Gatekeeper change in macOS 26. Apple's
  current guidance is the Sequoia flow above.
- Neither a self-signed nor an Apple Development signature passes Gatekeeper. Only Developer ID
  plus notarization does, and that needs the paid program. So the first install always needs one
  Open Anyway. After that, a stable signer lets Homebrew carry the approval forward.

## TCC ("System Audio Recording") across updates

- TN3127: "macOS solves this problem by recording your app's DR in its database of apps
  authorized to access the microphone. Each time your app tries to access the microphone, macOS
  checks that this version of the app satisfies the original DR." And: "Ad hoc signed code …
  has a DR but it's tied to that specific version of the code. … Without a DR, macOS can't track
  this authorization across versions of your app." —
  [TN3127: Inside Code Signing: Requirements](https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements)
- Quinn (Apple DTS), on a Screen Recording grant lost after an ad-hoc update: "Ad hoc signed code
  does not include a stable DR … Sign your code with a stable code-signing identity, ideally one
  issued by Apple. That means: Apple Development, during development … Developer ID, for direct
  distribution." — [forums/thread/795739](https://developer.apple.com/forums/thread/795739)
- Verified locally: two ad-hoc builds of the same source with the same identifier get DRs of the
  form `cdhash H"…"`, and build 2 fails build 1's DR (`codesign -v -R` exit 3).
- **Self-signed certificate:** codesign's default DR for a non-Apple certificate is
  `identifier "<id>" and certificate leaf = H"<SHA-1 of cert>"` (developer posts in
  [forums/thread/50955](https://developer.apple.com/forums/thread/50955) and
  [98484](https://developer.apple.com/forums/thread/98484)). That stays stable for as long as the
  same certificate signs, so pick a long validity period. Quinn's view on non-Apple CAs: "I've no
  idea how well it works when you use a non-Apple CA … I _strongly_ recommend … Developer ID"
  (98484). I could not test this end to end: an untrusted self-signed identity in a temporary
  keychain was rejected by codesign ("no identity found"). It has to be created in the login
  keychain and trusted for code signing.
- **Apple Development (free Personal Team):** Apple-issued, so the DR is
  `anchor apple generic and identifier "…" and …` plus terms identifying the signer (TN3127 omits
  the details). Quinn names it as a stable identity for TCC. Unverified: whether those signer
  terms survive renewal of a free certificate. Re-check `codesign -d -r-` after a renewal.

## Safari web extension

- "If you're not part of the Apple Developer Program, or if you haven't yet configured a developer
  identity … your Safari web extension won't be signed with a development certificate. For
  security purposes, Safari ignores unsigned extensions by default." "The 'Allow unsigned
  extensions' setting for Safari resets when you quit Safari." —
  [Running your Safari web extension](https://developer.apple.com/documentation/safariservices/running-your-safari-web-extension)
- "Safari only supports signed extensions …" —
  [Distributing your Safari web extension](https://developer.apple.com/documentation/safariservices/distributing-your-safari-web-extension)
- So the ad-hoc appex, and a self-signed one, only loads with the per-launch dev toggle. An
  Apple Development signature is what that page calls "signed with a development certificate".
  The Zen/Gecko native-messaging path doesn't depend on Safari's signing check.

## Open questions

- Whether `postflight_steps` → `run "/usr/bin/xattr" …` works inside Homebrew's step sandbox.
  Moot if we adopt a stable signer.
- Whether a renewed free Apple Development certificate keeps the same DR.
