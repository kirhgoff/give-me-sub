# GiveMeSub

Live on-device captions for Safari videos. A menu bar app taps Safari's audio (the WebKit GPU process) with a Core Audio process tap, transcribes it locally with the Whistle speech model, and sends the words to a Safari web extension that overlays them on the playing video.

## Setup

1. `Scripts/fetch-vendor.sh` (downloads `libneedle.a` and `whistle.cact`)
2. `brew install xcodegen`
3. `xcodegen generate && open GiveMeSub.xcodeproj`
4. Build and run the `GiveMeSub` scheme in Xcode; grant "System Audio Recording" when prompted.

## Enable in Safari

1. Safari > Settings > Advanced > "Show features for web developers".
2. Safari > Settings > Developer > "Allow unsigned extensions" (resets whenever Safari quits).
3. Safari > Settings > Extensions > enable "GiveMeSub" and allow it on every website.

## Use

Play a video, click the menu bar icon > Start captions. Pick a language if autodetect misfires.

## Check

Product > Test (`GiveMeSubTests`); it synthesizes speech with `say` and checks the transcript.

## Known limits

- Native `<video>` fullscreen has no overlay.
- Ad-hoc signing may re-prompt the audio permission after rebuilds; set `DEVELOPMENT_TEAM` and `CODE_SIGN_STYLE: Automatic` in `project.yml` to avoid it.
- Every WebKit GPU process is captured, so other WebKit apps' audio leaks in.
