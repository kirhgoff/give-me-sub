# GiveMeSub

Live on-device captions for whatever your Mac plays. A menu bar app taps all system audio with a Core Audio process tap, transcribes it locally with the Whistle speech model, and shows the words in a floating overlay above every window, fullscreen apps included.

## Install

```
brew tap kirhgoff/tap && brew trust --tap kirhgoff/tap
brew install --cask kirhgoff/tap/give-me-sub
```

Apple silicon, macOS 26+. Releases are Developer ID signed and notarized. Upgrade with `brew upgrade --cask give-me-sub`.

## Build from source

1. `Scripts/fetch-vendor.sh` (downloads `libneedle.a` and `whistle.cact`)
2. `brew install xcodegen`
3. `xcodegen generate && open GiveMeSub.xcodeproj`
4. Build and run the `GiveMeSub` scheme in Xcode; grant "System Audio Recording" when prompted.

## Use

Play anything with audio, click the menu bar icon > Start captions. Pick a language if autodetect misfires.

## Hotkey

The app answers `givemesub://toggle`, `givemesub://start` and `givemesub://stop`; a link launches the app if needed and the overlay flashes "Captions on/off".

Raycast: Create Quicklink > Name "Toggle captions", Link `givemesub://toggle`, Open With "GiveMeSub" > ⌘↵. Then select it in Raycast search > ⌘K > Configure Command > Set Hotkey. (Or Import Quicklinks with `[{"name":"Toggle captions","link":"givemesub://toggle","openWith":"GiveMeSub"}]`.)
Shortcuts: a shortcut with "Open URLs" -> `givemesub://toggle` and a keyboard shortcut in its details.
Terminal: `open givemesub://toggle`.

Menu bar > "Launch at login" registers the app via SMAppService (System Settings > General > Login Items).

## Release

One-time: `Scripts/setup-release.sh` (Developer ID .p12, notary API key, TAP_TOKEN -> GitHub secrets; `APPLE_TEAM_ID` repo variable and `.env`).
Then: `git tag v0.1.0 && git push origin v0.1.0`. `.github/workflows/release.yml` archives with Developer ID + hardened runtime, notarizes, staples, publishes `GiveMeSub.zip` to the GitHub Release and bumps `Casks/give-me-sub.rb` in kirhgoff/homebrew-tap. Version = tag. Runner is `xcode-27` (preview); switch `runs-on` to `macos-26` if it queues or breaks.

Local signed build:

```
xcodebuild archive -project GiveMeSub.xcodeproj -scheme GiveMeSub -archivePath build/GiveMeSub.xcarchive CODE_SIGN_IDENTITY="Developer ID Application" DEVELOPMENT_TEAM=$(grep APPLE_TEAM_ID .env | cut -d= -f2) OTHER_CODE_SIGN_FLAGS=--timestamp
```

## Check

Product > Test (`GiveMeSubTests`); it synthesizes speech with `say` and checks the transcript.

## Known limits

- Local (ad-hoc) builds re-prompt System Audio Recording after each rebuild; brew releases are Developer ID signed and keep the grant.
- All system audio is captioned, so notifications and other apps' sound are transcribed too.

## License

MIT. The vendored needle library and whistle model are Apache-2.0 (Cactus Compute); their license text is bundled in the app as `Contents/Resources/NOTICE`.
