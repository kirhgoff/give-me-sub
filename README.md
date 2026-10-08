# GiveMeSub

Live on-device captions for browser videos. A menu bar app taps the browser's audio (Safari's WebKit GPU process, or Zen/Firefox's main process) with a Core Audio process tap, transcribes it locally with the Whistle speech model, and sends the words to a web extension that overlays them on the playing video. One extension folder serves both Safari (bundled .appex) and Zen/Firefox (native messaging to the same app binary).

## Setup

1. `Scripts/fetch-vendor.sh` (downloads `libneedle.a` and `whistle.cact`)
2. `brew install xcodegen`
3. `xcodegen generate && open GiveMeSub.xcodeproj`
4. Build and run the `GiveMeSub` scheme in Xcode; grant "System Audio Recording" when prompted.

## Enable in Safari

1. Safari > Settings > Advanced > "Show features for web developers".
2. Safari > Settings > Developer > "Allow unsigned extensions" (resets whenever Safari quits).
3. Safari > Settings > Extensions > enable "GiveMeSub" and allow it on every website.

## Enable in Zen (or Firefox)

Every launch the app rewrites `~/Library/Application Support/Mozilla/NativeMessagingHosts/givemesub.json`, pointing the browser at its own binary as the native messaging host, so run the app once first.

1. Zen: `about:debugging#/runtime/this-firefox` > Load Temporary Add-on > pick `Extension/Resources/manifest.json`.
2. Play a video, click the menu bar icon > Start captions. Host errors show up in the Browser Console (Tools > Browser Tools).

Temporary add-ons vanish when the browser quits. Permanent: set `xpinstall.signatures.required` to `false` in `about:config` (Zen is built without `MOZ_REQUIRE_SIGNING`, so this is honored), then `cd Extension/Resources && zip -r ../../givemesub.xpi .` and open the xpi in Zen.

## Use

Play a video, click the menu bar icon > Start captions. Pick a language if autodetect misfires.

## Check

Product > Test (`GiveMeSubTests`); it synthesizes speech with `say` and checks the transcript, and checks the native messaging frame layout.

## Known limits

- Native `<video>` fullscreen has no overlay.
- Ad-hoc signing may re-prompt the audio permission after rebuilds; set `DEVELOPMENT_TEAM` and `CODE_SIGN_STYLE: Automatic` in `project.yml` to avoid it.
- Every WebKit GPU process and every Zen/Firefox window is captured, so other WebKit apps' and other browser tabs' audio leaks in.
