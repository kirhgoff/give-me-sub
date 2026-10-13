# CI release build and cross-repo cask bump

Question (KIR-251): can a hosted GitHub Actions runner build GiveMeSub (`deploymentTarget` macOS 26.0, `xcodeVersion: "27.0"` in `project.yml`, with `xcodegen` + `xcodebuild` + `Scripts/fetch-vendor.sh`)? And what is the least-privilege way for a `vX.Y.Z` tag workflow in `kirhgoff/give-me-sub` to update the cask in `kirhgoff/homebrew-tap`?

Researched 2026-10-10.

## Answer

- **Yes, it builds on hosted runners.** Use `runs-on: xcode-27` (preview, arm64, Xcode 27.0 default). `macos-26` (GA, arm64, Xcode 26.6 default) also has the SDKs a 26.0 deployment target needs, as a fallback.
- **xcodegen is not preinstalled** on any macOS image. Add `brew install xcodegen`; it has an arm64 bottle for every current macOS, so it installs in seconds.
- **`fetch-vendor.sh` works as is.** It uses `curl` and anonymous Hugging Face URLs, both of which return 200. `libneedle.a` is `macos-arm64` only, so the job needs an arm64 label. Every label above is arm64; `macos-26-intel` and the `-large` labels are not.
- **Cross-repo write: use a fine-grained PAT scoped to `kirhgoff/homebrew-tap` only, with Contents: read and write.** Store it as a secret in `give-me-sub`. A GitHub App is the stricter choice, with 1-hour tokens and no tie to a user, but it costs extra setup that a one-person personal tap does not need. `repository_dispatch` does not reduce privilege, because sending it needs Contents: write on the tap anyway.
- **`kirhgoff/homebrew-tap` does not exist yet.** The contents API returns 404, so it has to be created first, with the cask at `Casks/give-me-sub.rb`.

## 1. Runner image

From the [actions/runner-images README](https://github.com/actions/runner-images/blob/main/README.md) "Available Images" table:

| Image | Arch | Label | Status |
|---|---|---|---|
| Xcode 27 | arm64 | `xcode-27`, `xcode-27-xlarge` | preview ([#14404](https://github.com/actions/runner-images/issues/14404)) |
| macOS 26 Arm64 | arm64 | `macos-latest`, `macos-26`, `macos-26-xlarge` | GA |
| macOS 26 (x64) | x64 | `macos-26-intel`, `macos-26-large`, `macos-latest-large` | GA. Wrong arch for `libneedle.a` |

**`xcode-27`** ([xcode-27-arm64-Readme.md](https://github.com/actions/runner-images/blob/main/images/macos/xcode-27-arm64-Readme.md), image 20261006.0244.1):
- Base OS is macOS 27.0.1. Issue #14404, edited 2026-09-16: "`xcode-27` image now uses MacOS 27 OS as its base OS."
- Xcode 27.0 (27A266a) is the default at `/Applications/Xcode.app`. Xcode 27.1 and 27.2 beta are also installed.
- It ships the macOS 27.0 and 27.2 SDKs. Xcode 27.0 build 27A266a is the same build as the local Xcode, so CI matches local builds.
- Caveat from #14404: "marked as 'preview' ... some software can be unstable ... there could be queueing issues". Workflows on preview or beta images are outside the Actions SLA ([README, Image Definitions](https://github.com/actions/runner-images/blob/main/README.md#image-definitions)).

**`macos-26`** ([macos-26-arm64-Readme.md](https://github.com/actions/runner-images/blob/main/images/macos/macos-26-arm64-Readme.md), image 20260907.0351.1):
- macOS 26.6.2, with Xcode 26.6 as the default and 26.0.1 through 26.5 installed. SDKs run from macOS 26.0 to 26.5.
- A deployment target of 26.0 only needs an SDK of 26.0 or later. The code has no `@available(macOS 27…)` checks (`git grep` found none), so this image should work too.
- `xcodeVersion: "27.0"` in `project.yml` is XcodeGen's project-format and upgrade-check stamp, not a build requirement. Not verified by a run; an Xcode 26 build might warn about the project format.

**Recommendation:** `runs-on: xcode-27` to match the local toolchain. Fall back to `macos-26` if the preview queues or breaks.

**xcodegen:** neither image README lists it, and `grep -i xcodegen` matched nothing in either. The Homebrew formula `xcodegen` 2.46.0 has bottles for `arm64_tahoe` and `arm64_golden_gate`, among others ([formulae.brew.sh API](https://formulae.brew.sh/api/formula/xcodegen.json)). Homebrew 7.0.8 is preinstalled on `xcode-27`, so `brew install xcodegen` works. Pinning a version with `mint` or a release zip is optional.

**Other tools needed by the release step are preinstalled on `xcode-27`:** GitHub CLI 2.102.0 (`gh release create … GiveMeSub.zip`), curl 8.7.1, and `ditto`/`zip` from the base OS.

**Signing:** `project.yml` uses `CODE_SIGN_IDENTITY: "-"` (ad-hoc), so CI needs no certificates. Gatekeeper quarantine on an unsigned, un-notarized app is a separate distribution question and out of scope here.

## 2. Cross-repo cask update

**Fact:** the default `GITHUB_TOKEN` cannot write to the tap. "The token's permissions are limited to the repository that contains your workflow." ([GITHUB_TOKEN concepts](https://docs.github.com/en/actions/concepts/security/github_token)) The docs point to a GitHub App or a PAT for anything beyond that ([automatic token authentication](https://docs.github.com/en/actions/security-for-github-actions/security-guides/automatic-token-authentication)).

| Option | Scope | Lifetime | Setup | Notes |
|---|---|---|---|---|
| **Fine-grained PAT** | One owner; can be limited to the single repo `homebrew-tap`, with only Contents: write ([managing PATs](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens)) | Defaults to 30 days and can be set longer or infinite; GitHub recommends an expiry | One secret | Tied to the user ("tied to the user who generated them"). It must be rotated when it expires. |
| **Deploy key (write)** | Single repo, over SSH ([deploy keys](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/managing-deploy-keys)) | "credentials that don't have an expiry date" | Key pair; public key on the tap, private key as a secret | Write access equals "a collaborator on a personal repository", so it covers more than contents. Git push only; no API calls, so no PRs. |
| **GitHub App** | Installed on the tap only; tokens narrowed with `repositories:` and `permission-contents: write` ([create-github-app-token](https://github.com/actions/create-github-app-token)) | Installation tokens expire after 1 hour or less (same deploy-keys page) | Create the app, install it, store the client ID and private key | Not tied to a user and never has a password. This is the most least-privilege option, but it is the most setup. |
| **`repository_dispatch` to a tap workflow** | Sender still needs **Contents: write** on the tap: `POST /repos/{owner}/{repo}/dispatches` is listed under Contents write ([fine-grained PAT permissions](https://docs.github.com/en/rest/authentication/permissions-required-for-fine-grained-personal-access-tokens)) | Same as whichever token sends it | PAT or App, plus a second workflow in the tap | Gains nothing in privilege. It only moves the cask-editing logic into the tap. `client_payload` is limited to 10 top-level keys and under 64 KB ([REST docs](https://docs.github.com/en/rest/repos/repos#create-a-repository-dispatch-event)). |

**Recommendation:** a fine-grained PAT limited to `kirhgoff/homebrew-tap`, with Contents: read and write and a 1-year expiry, stored as the secret `TAP_TOKEN` in `give-me-sub`. Its effective scope matches the dispatch option without a second workflow. Move to a GitHub App if the tap ever has more than one writer or the rotation becomes annoying.

## 3. Updating the cask

- **Tap layout ([Homebrew: How to Create and Maintain a Tap](https://docs.brew.sh/How-to-Create-and-Maintain-a-Tap)):** the repo name starts with `homebrew-`, and casks go in a top-level `Casks/` directory. Users run `brew install kirhgoff/tap/give-me-sub` (the tap is added automatically). Non-official taps may need `brew trust --tap`, per the same page.
- **`brew bump-cask-pr` (local `--help`):** "Create a pull request to update cask with a new version." It needs `--version`, and can take `--url` and `--sha256`. With `--write-only --commit` it edits and commits without opening a PR. It also needs a full Homebrew checkout of the tap and a token in `HOMEBREW_GITHUB_API_TOKEN`. That is heavy for a personal tap you push to directly.
- **Simpler path (the "lazy" route):**
  1. Check out `kirhgoff/homebrew-tap` with `token: ${{ secrets.TAP_TOKEN }}`.
  2. `sed` the `version` and `sha256` lines in `Casks/give-me-sub.rb`, using `shasum -a 256 GiveMeSub.zip`.
  3. Commit and push.

  The cask `url` can use `#{version}` against `https://github.com/kirhgoff/give-me-sub/releases/download/v#{version}/GiveMeSub.zip`, so only two lines change per release.

## Sketch

```yaml
on: { push: { tags: ['v*.*.*'] } }
jobs:
  release:
    runs-on: xcode-27
    permissions: { contents: write }
    steps:
      - uses: actions/checkout@v5
      - run: brew install xcodegen && Scripts/fetch-vendor.sh && xcodegen
      - run: xcodebuild -project GiveMeSub.xcodeproj -scheme GiveMeSub -configuration Release -derivedDataPath build build
      - run: ditto -c -k --keepParent build/Build/Products/Release/GiveMeSub.app GiveMeSub.zip
      - run: gh release create "$GITHUB_REF_NAME" GiveMeSub.zip --generate-notes
        env: { GH_TOKEN: ${{ github.token }} }
      - uses: actions/checkout@v5
        with: { repository: kirhgoff/homebrew-tap, token: ${{ secrets.TAP_TOKEN }}, path: tap }
      - run: |
          v=${GITHUB_REF_NAME#v}; s=$(shasum -a 256 GiveMeSub.zip | cut -d' ' -f1)
          sed -i '' -e "s/version \".*\"/version \"$v\"/" -e "s/sha256 \".*\"/sha256 \"$s\"/" tap/Casks/give-me-sub.rb
          git -C tap -c user.name=github-actions -c user.email=github-actions@users.noreply.github.com commit -am "give-me-sub $v" && git -C tap push
```

Not verified by an actual run. The open points are the preview image's queue times and whether the Release build links `libneedle.a` cleanly in CI.
