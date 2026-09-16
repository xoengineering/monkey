# Monkey — Build Plan

Local-only chat app for Apple's on-device Foundation Models. macOS / iOS / iPadOS. Swift + SwiftUI. Open source, free on the App Store, no IAP.

Sections marked **[verify]** are assumptions Claude Code should confirm against current Apple docs (Xcode 27 SDK) before implementing. Everything else is either user-specified or stable knowledge.

---

## 1. Hard constraints

- Platforms: macOS 27, iOS 27, iPadOS 27. Nothing lower. No visionOS/watchOS/tvOS.
- Swift 6 language mode, strict concurrency. SwiftUI only. No UIKit/AppKit except where SwiftUI has no equivalent (wrap, don't leak).
- No Electron, no web views, no cross-platform layers.
- Network posture (a technical design rule, not a marketing slogan; the marketing will explain exactly what is opt-in): the app itself opens no sockets. Do not add the `com.apple.security.network.client` entitlement on macOS. No `URLSession`, no analytics, no crash reporters. Model inference is on-device only. The one opt-in exception is iCloud Drive sync of the conversation folders (§3a), which is off by default and handled by the system's iCloud daemon, not by the app's process. With it off, the app is fully air-gapped once installed.
- App Sandbox on. Files stay inside the app container, or in the app's iCloud ubiquity container when the user opts in.
- Model: `FoundationModels` framework, `SystemLanguageModel` **on-device only**. iOS 27 adds Private Cloud Compute and third-party `LanguageModel` conformers — do not use any of them. Only the on-device system model. **[verified]** against the installed macOS 27 SDK: `SystemLanguageModel` and `PrivateCloudComputeLanguageModel` are separate, unrelated classes with no mode switch between them. Hard-pinning on-device means constructing sessions only via `SystemLanguageModel.default` (e.g. `LanguageModelSession(model: SystemLanguageModel.default, ...)`) and never referencing `PrivateCloudComputeLanguageModel` anywhere in the codebase.
- Single user. No accounts, no sync.
- Open source, MIT license. Same repo ships to App Store. Free, no IAP, no limits.

## 2. Repo layout

```txt
Monkey/
  Package.swift                      # SPM package with all non-UI logic
  Sources/
    MonkeyCore/                        # storage, model session — no SwiftUI import
    MonkeyUI/                          # SwiftUI views, view models
    monkey/                            # CLI executable target (ArgumentParser + MonkeyCore)
  Tests/
    MonkeyCoreTests/                   # Swift Testing (not XCTest)
    MonkeyUITests/
  App/
    project.yml                       # xcodegen spec; source of truth for Monkey.xcodeproj
    Monkey.xcodeproj         # single multiplatform app target depending on the package
    Local.xcconfig.example            # copy to Local.xcconfig (gitignored) to set your bundle ID
    Monkey/
      MonkeyApp.swift
      Info.plist
      Monkey.entitlements
      PrivacyInfo.xcprivacy
      monkey.entitlements               # CLI helper: app-sandbox + app group, no network
  script/
    bootstrap                         # copies Local.xcconfig, resolves SPM deps, runs xcodegen
  LICENSE
  README.md
```

- One multiplatform app target, not three. `#if os(macOS)` only where unavoidable.
- Dependencies: Yams (jpsim/Yams) in Core for YAML; Textual (gonzalezreal/textual, ≥0.5.0) in UI for markdown rendering; swift-argument-parser in the CLI target. Pin all to tagged releases. No hand-rolled parsers or renderers.
- Bundle ID / team / product ID: leave as placeholders; user fills in. In practice: `PRODUCT_BUNDLE_IDENTIFIER` comes from `App/Local.xcconfig` (gitignored, created from `Local.xcconfig.example` by `script/bootstrap`). `DEVELOPMENT_TEAM` is deliberately *not* in that xcconfig — XcodeGen mirrors any team set there into the shared, tracked `project.pbxproj`, which would leak a real team ID into version control on the next regeneration. Team selection instead happens per-user in Xcode's Signing & Capabilities tab (stored in gitignored `xcuserdata`), or via a one-off `xcodebuild ... DEVELOPMENT_TEAM=X build` override for command-line builds.

## 3. On-disk format

Root: `~/Library/Application Support/<bundle-id>/Conversations/` (inside the sandbox container on all platforms; use `FileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, ...)`).

```txt
Conversations/
  2026-09-15T14-32-08.123Z-k7x2q9/       # same <timestamp>-<key> scheme as messages
    conversation.yaml
    2026-09-15T14-32-08.123Z-k7x2q9.md
    2026-09-15T14-32-41.507Z-m3pd1w.md
    ...
```

### `conversation.yaml`

```yaml
id: 2026-09-15T14-32-08.123Z-k7x2q9 # equals the folder name
title: Untitled
created_at: 2026-09-15T14:32:08.123Z
updated_at: 2026-09-15T14:32:41.507Z
instructions: "" # optional instructions for the model session; blank by default
message_count: 2 # cache; source of truth is the directory listing
```

### Message file: `<timestamp>-<key>.md`

- Timestamp: UTC, ISO-8601, colons replaced with `-` for filesystem safety, millisecond precision: `2026-09-15T14-32-08.123Z`.
- Key: 6-char base32/base36 random string. Purpose: two writes in the same millisecond never collide. Lexical sort by filename == chronological order.
- Frontmatter: flat YAML between `---` fences. Body: raw markdown, exactly what the user typed or the model produced.

```markdown
---
id: k7x2q9
role: user # user | assistant
created_at: 2026-09-15T14:32:08.123Z
status: complete # complete | streaming | cancelled | failed
model: system-on-device # opaque string; whatever the framework reports
in_reply_to: "" # id of the message this answers (assistant msgs)
tokens_prompt: 0 # optional; only if the SDK exposes counts
tokens_output: 0
error: "" # populated when status == failed
---

The actual markdown body.
```

### Rules

- Write atomically: write to a temp file in the same directory, then `replaceItemAt`. Never partially-written message files on disk.
- Streaming assistant replies: create the file with `status: streaming` and an empty body on first token; rewrite body at a throttled cadence (e.g. every 250 ms) while streaming; final write sets `status: complete`. On app kill mid-stream, the file exists with `status: streaming` — on next load, mark it `cancelled` (don't delete; the partial text is still useful).
- Deleting a conversation = delete the directory. Deleting a message = delete the file and update `conversation.yaml`.
- The directory listing is the index. `conversation.yaml.message_count` is a hint for UI badges, never trusted for pagination.
- Files must be plain enough to open in any editor. This is the export format too — "export" is just "reveal in Finder / share the folder".

## 3a. Storage location and opt-in iCloud sync

`ConversationStore` is initialized with a root URL. There are exactly two roots; the user picks one in Settings.

- **On device (default).** The **app group** container, so the app and the bundled CLI (§6) share it: macOS `~/Library/Group Containers/<team-id>.<group>/Conversations/`; iOS/iPadOS the equivalent group container. Nothing leaves the device.
- **iCloud Drive (opt-in).** `FileManager.url(forUbiquityContainerIdentifier:)` + `Documents/Conversations/`. Requires the iCloud entitlement (CloudDocuments service, one container ID) and an iCloud-capable provisioning profile. Does not require the network entitlement — the iCloud daemon moves bytes, not the app. **[verified]** via throwaway spike `spike/2-icloud-documents-sync` (not merged): a sandboxed macOS app and a sandboxed iOS app, both with only `com.apple.developer.icloud-services=[CloudDocuments]` + `com.apple.developer.icloud-container-identifiers=[iCloud.<bundle-id>]` — no network entitlement, no `aps-environment` — shared one iCloud container. The Mac wrote a timestamped file; a physical iPhone (separate bundle ID, same container ID) read back the exact same content with no trust prompt and no app-level networking, confirming real cross-device iCloud Drive sync end to end.

Switching:

- On → move each conversation folder with `setUbiquitous(true, itemAt:destinationURL:)`; Off → the reverse. Per-conversation progress UI; sending disabled during migration; migration is resumable if interrupted (re-run on launch, skip folders already at the destination).

Cloud-mode behavior in `ConversationStore`:

- All reads/writes through `NSFileCoordinator`; register an `NSFilePresenter` for the root so external changes (other device, user editing in Finder/Files) refresh the index and evict cached messages.
- `NSMetadataQuery` on the root to learn about message files that exist in iCloud but aren't downloaded locally; call `startDownloadingUbiquitousItem` when a page needs them; show a placeholder row until they arrive.
- Streaming rewrites are throttled (≥250 ms) to avoid spamming sync; last write wins.
- Conflict handling: message files are write-once per device and uniquely named, so they never conflict. `conversation.yaml` can: resolve by newest `updated_at`, recompute `message_count` from the listing, then remove conflict versions via `NSFileVersion`.
- The design invariant that makes all this cheap: one immutable-ish file per message, timestamp+key names, directory listing as index. Keep it.

Files app exposure on iOS (`UIFileSharingEnabled` + `LSSupportsOpeningDocumentsInPlace`) is a separate, later question; it would require the local root to be `Documents/` instead of `Application Support/`. Not in v1.

## 4. Core package design

### `FrontmatterDocument`

- Splits a file into the `---`-fenced YAML block and the markdown body; only the split is custom, the YAML itself goes through Yams.
- `parse<T: Decodable>(Data, as: T.Type) throws -> (metadata: T, body: String)` via `YAMLDecoder`.
- `serialize<T: Encodable>(metadata: T, body: String) throws -> Data` via `YAMLEncoder`.
- `conversation.yaml` is plain Yams `Codable` with no fence.
- Tests: round-trip, bodies that contain `---`, empty body, CRLF input, unicode, unknown keys ignored.

### Types

- `ConversationID`, `MessageID` — strongly typed wrappers.
- `Conversation` — `Codable`, decoded/encoded with Yams.
- `Message` — `Codable` frontmatter fields (`id, role, createdAt, status, ...`) plus `body`.
- `MessageRole: user | assistant`.
- `MessageStatus: complete | streaming | cancelled | failed`.
- `TimestampedName` — parse/format the `<timestamp>-<key>` scheme; comparable. Used for both conversation folder names and message file names (`.md` appended).

### `ConversationStore` (actor)

- `listConversations() -> [Conversation]` (sorted by `updated_at` desc)
- `create(title:) -> Conversation`
- `delete(_:)`
- `update(_:)`
- `messageIndex(for:) -> [MessageFileName]` — directory listing, sorted. Cheap; this is what pagination walks.
- `loadMessage(_:) -> Message`
- `loadMessages(_:in range)` — batch
- `write(_ message:in:)` — atomic
- No separate `appendStreaming` method: `write` already handles atomic rewrites regardless of status, and there's no disk-I/O difference between a streaming rewrite and any other write. The throttling ("rewrite at ~250ms cadence") is owned by the caller (`ModelSession`), which knows the real token/chunk cadence — adding an identically-behaved alias on the store would be ceremony, not abstraction.
- Cache: LRU of decoded `Message` values keyed by filename, bounded (e.g. 500 entries or ~N MB of body text). Eviction is the "unload from memory" the spec asks for. Index (filenames) is always resident — it's tiny.
- Optional: use `NSFilePresenter`/`FileCoordinator`? Probably not needed for single-process. Skip unless testing shows a problem.

### `ModelSession` (actor, wrapping `LanguageModelSession` via a `ChatBackend` seam)

- Availability: check `SystemLanguageModel.default.availability` at launch and on foreground. Surface every `.unavailable` reason as a real UI state (device unsupported, Apple Intelligence off, model downloading). Do not silently fail.
- **[verified]**: Apple's own `LanguageModel` protocol is not a lightweight testing seam — conforming to it means implementing a full `LanguageModelExecutor` (the request/response streaming internals real backends use). Faking it directly, as originally planned, is impractical. Implemented instead: a small first-party `ChatBackend` protocol (`identifier`, `availability`, `contextSize`, `tokenCount(for:instructions:)`, `streamResponse(history:instructions:prompt:)`) that `ModelSession` depends on. `SystemChatBackend` implements it for real, driving `SystemLanguageModel`/`LanguageModelSession` directly (never referencing `PrivateCloudComputeLanguageModel`). `FakeChatBackend` (test-only) implements it for Core tests, with no Apple Intelligence dependency.
- One `LanguageModelSession` per open conversation, built from the conversation's `instructions` folded into a rebuilt `Transcript`. Rebuilt on every send in v1 (simpler than caching a long-lived session across instruction changes; revisit if this proves too slow in practice).
- **[verified]** against the macOS 27 SDK: `SystemLanguageModel.contextSize: Int` and `SystemLanguageModel.tokenCount(for: some Collection<Transcript.Entry>) async throws -> Int` both exist (the "26.4+ context-size and token-counting APIs" this plan anticipated). `ModelSession.loadHistoryIfNeeded()` uses them to trim the oldest replayed messages until the remaining transcript fits `contextSize`, rather than a hardcoded count.
- **[verified]**: `GenerationError.exceededContextWindowSize` is deprecated as of 27 in favor of `LanguageModelError.contextSizeExceeded(_:)` (with a richer `ContextSizeExceeded { contextSize, tokenCount, debugDescription }` payload). `ModelSession` catches `LanguageModelError.contextSizeExceeded`: trims the oldest replayed message, retries once, surfaces (message `status: failed`) if it still fails.
- Streaming: `SystemChatBackend.streamResponse` iterates `LanguageModelSession.streamResponse(to:)`'s `ResponseStream<String>` and yields each `Snapshot.content` as the full text so far (not a delta). **[verified]** on real hardware, not just by API naming: this machine has Apple Intelligence enabled, and two live sends through the actual built app ("Say hello in exactly three words." → "Hello, world!"; "What color is the sky? One word answer." → "Blue.") round-tripped correctly end to end — real on-device model, real streamed write, real render, real persistence to disk. Cancellation via `Task` cancellation → mark message `cancelled`, tested (unit test) and confirmed the Stop button appears mid-stream in the live app.
- No tools, no guided generation, no `@Generable` for v1. Plain chat.
- **[verified]** against the macOS 27 SDK: yes, `SystemLanguageModel.Variant` exists (`.core3`, `.coreAdvanced3`, read via `SystemLanguageModel.default.variant`), confirming there *is* a model tier concept in 27 — but there is no initializer or API to choose one; it's determined by the device. Confirms the plan's default: don't choose, record `SystemLanguageModel.default.variant.displayName` as `model:` (`SystemChatBackend.identifier`).

## 5. Companion CLI (macOS only, bundled)

**Spike finding, corrected in Phase 5** (`spike/1-cli-model-app-group`, throwaway, not merged): a bare sandboxed Mach-O executable hung on launch from Terminal, stuck in dyld's pre-`main()` `_libsecinit_appsandbox` sandbox-init routine. That spike concluded bundling would fix it. **It didn't.** Phase 5 built the real thing — `monkey` embedded at `Monkey.app/Contents/Helpers/monkey`, correct entitlements, correct signing (all verified: `codesign -d --entitlements` shows exactly `app-sandbox` + `application-groups`, no network) — and it hung identically, same `_libsecinit_appsandbox.cold.6` stack, when exec'd directly from this agent's Bash tool shell. The decisive control test: **the main GUI app's own binary** (`Monkey.app/Contents/MacOS/Monkey`), which launches and runs correctly via `open` (proven repeatedly this session — real on-device model conversations, screenshotted), **also hangs when exec'd directly** from the same shell, identical stack trace. A maximally minimal one-line `print()` sandboxed binary with no project code at all hangs the same way.

**Verified outside the agent environment, on the repo owner's own physically-logged-in Mac, via `Terminal.app` — this is now a confirmed platform-level finding, not an agent artifact.** The agent's own shell showed an infinite hang (see above); a real Terminal.app session showed a different, more specific symptom: an immediate `trace trap` (SIGTRAP) crash. Five independent binaries were tested directly in the user's own Terminal to isolate the cause:

| Entitlements | Signing identity | Result |
|---|---|---|
| none | Apple Development | ✅ runs and exits cleanly |
| `app-sandbox` + `application-groups` + `get-task-allow` (the real, Xcode-built Debug CLI helper) | Apple Development | ❌ trace trap |
| `app-sandbox` + `application-groups`, `get-task-allow` manually stripped | Apple Development | ❌ trace trap |
| `app-sandbox` alone, no app-group | Apple Development | ❌ trace trap |
| `app-sandbox` alone, no app-group | Developer ID Application | ❌ trace trap |

This rules out `get-task-allow`, the app-group entitlement, and the signing identity as the cause. The only common factor across every failure is `com.apple.security.app-sandbox=true` on a **standalone (non-`.app`-bundle) executable** launched directly from Terminal — on this specific OS/toolchain pairing (macOS 27.0 build 26A428, Xcode 27.0 build 27A266a). This is a real, reproducible problem with this shipping macOS 27.0 release (not a beta — confirmed by the repo owner), not a defect in Monkey's code, not the app-group entitlement, and not (as an earlier draft of this note incorrectly concluded) an artifact of the coding agent's own shell — the user's ordinary interactive Terminal session hits it too, just with a different symptom (crash vs. hang).

**This is a hard blocker for Phase 5 as currently scoped** (a sandboxed CLI binary you run directly from Terminal). Apple has shipped sandboxed, Terminal-launched CLI tools for years, so this is very likely a regression specific to this release rather than an intentional platform change — but since 27.0 is shipping, not beta, there's no guarantee of a prompt fix via a "next seed." It cannot be worked around from the app's code. Options: (a) file Feedback with Apple including this exact repro table, (b) retest after any macOS 27.x point release, (c) consider an architecture that launches the helper via `launchd`/XPC rather than direct Terminal exec (LaunchServices-mediated launches of sandboxed `.app` bundles work fine, confirmed repeatedly this session) — though that would be a real design change from "run `monkey` directly from Terminal." Do not build out the CLI's command surface as if this works until one of those paths resolves it; the CLI's *logic* (argument parsing, `ConversationStore`/`ModelSession` usage) can still be built and unit-tested via `swift test`, which needs no sandboxed exec at all.

Ships inside the App Store bundle at `Monkey.app/Contents/Helpers/monkey`. Sandboxed with its own `app-sandbox` entitlement plus the shared app group; no network entitlement. Same rules as the app: no sockets, on-device model only. Built from `Sources/monkey` on `MonkeyCore`; zero UI code. Verified: `codesign -d --entitlements` on the built helper shows exactly `app-sandbox` + `application-groups`, no network.

**Two build-system gotchas found getting this far, both fixed, both worth remembering:**
- The Xcode target for the CLI is named `MonkeyCLI` in `App/project.yml`, not `monkey` — naming it `monkey` (matching the app target `Monkey` differing only in case) corrupted both targets' builds, because Xcode's DerivedData intermediate folders are named after the target and macOS's default APFS volume is case-insensitive: `monkey.build` and `Monkey.build` are the same directory on disk. `PRODUCT_NAME: monkey` still makes the actual output binary lowercase as the CLI spec requires; only the Xcode target identifier had to change.
- `Sources/monkey/main.swift` was renamed to `Monkey.swift`. A file literally named `main.swift` gets implicit top-level-code treatment that conflicts with `@main` when built as a native Xcode target (`error: 'main' attribute cannot be used in a module that contains top-level code`) — SwiftPM's own `swift build` tolerated the old name, but Xcode-native builds of the same target did not. Only `@main`-attributed entry files should avoid the literal name `main.swift`.

App group ID: `group.com.yourdomain.Monkey`, a placeholder matching the bundle ID placeholder convention from Phase 1 — hardcoded in both `Monkey.entitlements` and `monkey.entitlements` since entitlements plists don't support build-setting substitution the way xcconfig/Info.plist do. Update both files (and register the App Group in the Apple Developer portal) alongside `PRODUCT_BUNDLE_IDENTIFIER` before shipping.

Install: Settings → "Install command line tool…" opens an `NSSavePanel` defaulting to `/usr/local/bin/monkey` and writes a symlink to the bundled binary (user-granted write keeps it sandbox-legal). README also documents the manual symlink. Never write outside the sandbox without the panel — that is the one thing that would complicate review.

Conventions:

- Conversation references accept a full folder name or any unique prefix (`monkey open 2026-09-15`); ambiguous → list matches and exit 1.
- Message references: `<convo> <message>` where `<message>` is a message file name, a unique prefix, or a negative index (`-1` = last).
- `--json` on any listing/print command for piping. Default output is human-readable.
- stdin: if not a TTY, its contents are appended to the prompt (`cat file.md | monkey do "summarize"`).
- Exit codes: 0 ok, 1 usage/not found, 2 model unavailable (print the availability reason).

Commands (v1 unless marked):

- `monkey ls [--json]` — conversations, newest first: id, title, message count, updated.
- `monkey do <prompt…>` — one-shot. Creates a new conversation on disk (so it shows up in the app), streams the reply to stdout. `--ephemeral` to skip writing.
- `monkey chat [<convo>]` — REPL. No arg = new conversation; with arg = continue that one. `/quit`, `/id` (print the conversation id).
- `monkey cat <convo> [<message>]` — print a message body to stdout (`--raw` includes frontmatter). Without `<message>`, prints the whole conversation as one markdown stream. This is the piping/integration hook.
- `monkey open [<convo>]` — Reveal in Finder: the Conversations root, or one conversation folder.
- `monkey search <query> [--in <convo>]` — case-insensitive substring/regex over message bodies and titles; prints `convo  message  line` hits, `--json` for tooling. Body search is trivial from the CLI; the app UI still only searches titles in v1.
- `monkey see <path> [<prompt…>]` (v2) — image input to the on-device model. **[verify]** iOS/macOS 27 Foundation Models accept image input on-device; WWDC26 coverage says yes. Local paths only — a URL form would require network, which the CLI does not have; if wanted later, `curl … | monkey see -` covers it without changing the entitlements.

Non-goals: no daemon, no HTTP server, no `--model` selection, no cross-device anything (iCloud mode works because the CLI reads whichever root the app's Settings selected, via a shared preference in the group container).

## 6. UI

### Structure

- `NavigationSplitView`: sidebar = conversation list; detail = message thread. Collapses to stack on iPhone.
- Sidebar: new conversation, search by title, swipe/context-menu delete, rename.
- Thread: `LazyVStack` in a `ScrollView`, bottom-anchored. Newest N messages loaded initially (N ≈ 50); scrolling to top triggers `loadMessages` for the previous page. Messages far off-screen can be dropped from the view model's array and re-fetched from the store cache — this is the "unload from UI" half. Keep scroll position stable when prepending. **[verified]** against the macOS 27 SDK: `scrollPosition(id: Binding<(some Hashable)?>, anchor:)` and `defaultScrollAnchor(_:)` both still exist unchanged (they predate 27, and no newer replacement appeared in this SDK) — bind scroll position to the topmost visible message's ID so prepending older messages above it doesn't jump the viewport, and use `defaultScrollAnchor(.bottom)` for the initial bottom-anchored load.
- Composer: multiline `TextEditor`-style field, ⌘↩ to send on macOS, send button everywhere. Stop button while streaming.
- Markdown rendering: Textual `StructuredText` with the `.gitHub` style preset, text selection enabled (`.textual.structuredTextStyle(.gitHub)`, `.textual.textSelection(.enabled)`). **Important finding**: Textual's *default* image attachment loader (`.image()`, used automatically if you don't override it) fetches remote images over the network via `URLSession`-backed `ImageLoader.shared` — a silent, hard violation of this app's no-network rule the moment a message body contains a markdown image link. Fixed by supplying a custom `NoFetchImageAttachmentLoader` (registered once at the app root via `.textual.imageAttachmentLoader(...)`) that never performs I/O and renders a tappable `Link` showing the URL instead — this is both the network-safety fix and the "remote images as placeholder" UI behavior in one. Anyone touching Textual integration later must not remove this override. Deferred to a follow-up: a custom `codeBlockStyle` copy button (v1 ships with the plain `.gitHub` code block style, no copy button). Footnotes not supported by Textual's default parser; accepted for v1.
- Empty states: no conversations; model unavailable (with the actual reason and, where applicable, a link to Settings → Apple Intelligence).
- Settings: per-conversation instructions editor; global default instructions; Storage section — "On this device" / "iCloud Drive" picker with a plain-language explanation of what leaves the device in each mode, plus migration progress; "Show data folder" (macOS: Reveal in Finder; iOS: document the path); license/about.
- Keyboard: ⌘N new conversation, ⌘⌫ delete, ⌘F search sidebar.
- Liquid Glass: 27 SDK removes the opt-out; just build with standard components and check materials on all three platforms.

### App lifecycle notes (27 SDK)

- **[verified]** against Xcode 27's own SwiftUI multiplatform app template (`INFOPLIST_KEY_UILaunchScreen_Generation = YES` is still set for iOS destinations): a launch screen is still expected. Added an empty `UILaunchScreen` dict to `App/Monkey/Info.plist` (the hand-written-file equivalent of that generated key).
- **[verified]** against the macOS 27 SDK: `@State` is still `@frozen @propertyWrapper struct State<Value>` in `SwiftUICore` — it did not become a macro.

## 7. Phases

1. **Scaffold** — repo, package, app target, entitlements (sandbox on, no network), privacy manifest, CI-less (no network anyway; local `swift test`). Commit.
2. **Storage** — `FrontmatterDocument`, types, `MessageFileName`, `ConversationStore` with atomic writes and LRU. Full tests. Commit.
3. **Model** — availability handling, `ModelSession`, streaming into the store, transcript rebuild with context-window sizing, cancellation. Test with `FakeChatBackend` (a first-party seam, not a fake of Apple's `LanguageModel`, which isn't fakeable — see §4) so Core tests don't need Apple Intelligence. Done: 49 tests green, including cancellation and context-exceeded trim-and-retry. Commit.
4. **UI** — split view, list, thread with paging, composer, markdown, empty/unavailable states. Done: builds and runs; verified live on real hardware (see §4 ModelSession streaming note). Storage root for this phase is plain `FileManager.url(for: .applicationSupportDirectory, ...)` per §3, not yet the app-group container from §3a — switching to the app-group root is Phase 5's job, once the CLI needs to share it; changing `MonkeyApp`'s `ConversationStore(rootURL:)` call is the only change needed then. Known gaps, deliberately deferred rather than half-built: the sidebar's message count/`updated_at` can go stale while a conversation is actively open (the list view model only reloads on create/delete/rename/launch, not on every store write elsewhere — the on-disk data itself is correct, verified by test); Settings is minimal (default instructions + license only — no storage/iCloud picker, since that's Phase 6, and no "show data folder" yet); the model-unavailable screen has no deep link to Settings → Apple Intelligence (didn't want to guess the URL scheme unverified). Commit.
5. **CLI** — `monkey` target, entitlements, `ls`/`do`/`chat`/`cat`/`open`/`search`, install flow. Test that a Terminal-launched sandboxed binary reads the group container and reaches the model. Commit.
6. **iCloud sync (opt-in)** — ubiquity root, migration both directions, file coordination, metadata query, conflict handling for `conversation.yaml`. Test with two devices on one Apple ID and with iCloud signed out. Commit.
7. **Ship prep** — App Store screenshots, review notes explaining "no network by design", README with the on-disk format documented, LICENSE, version 1.0.0.

Each phase ends in a buildable, runnable app. Don't start UI until storage tests are green.

## 8. Explicit non-goals (v1)

- No multiple model backends, no PCC, no third-party models, no CoreAI.
- No tool calling, no image input, no attachments.
- No sync other than opt-in iCloud Drive. No CloudKit, no third-party sync, no import from other chat apps, no export beyond "the folder is the export".
- No themes beyond system light/dark.
- No footnotes (see UI section).
- No search inside message bodies in the app UI (title search only; `monkey search` covers bodies from the CLI). In-app body search is a v2 candidate — Spotlight indexing is the obvious route.

## 9. Decisions (resolved)

- Companion CLI ships inside the App Store bundle (not Homebrew), sharing data via an app group container.
- Network/storage story: air-gapped by default; iCloud Drive sync is an explicit opt-in the marketing will describe plainly. The "no network in the app process" rule holds in both modes.
- License: MIT.
- Conversation folder names use the same `<timestamp>-<key>` scheme as messages.
- Default instructions: blank.
- No IAP, no message limit. Free app.
- Naming: app name is "Monkey". `CFBundleDisplayName` = "Monkey" on macOS/iOS/iPadOS. App Store listing name = "Monkey — A Local Assistant" (26 chars; App Store limit is 30); fallback if unavailable: "Monkey Local Assistant". App Store names must be unique per storefront — check availability in App Store Connect early.
