# MediaPipe IO Demo — iOS

A SwiftUI counterpart to the Android [`mediapipe-io-demo`](https://github.com/Tangchenchen-tina/mediapipe-io-demo)
app: the same three-section smart-notepad concept (Chats / Archive / Email), built on MediaPipe's
on-device GenAI text tasks — **Text Summarizer**, **Text Proofreader**, and **Text Embedder**
(EmbeddingGemma-300m) — all via the real `MediaPipeTasksText` CocoaPod, not placeholders.

## Setup

```
sh RunScripts/download_models.sh   # fetches the 3 model bundles (~420MB total)
xcodegen generate                  # generates MediaPipeIODemo.xcodeproj from project.yml
pod install                        # installs MediaPipeTasksText, produces the .xcworkspace
open MediaPipeIODemo.xcworkspace
```

Then build & run the `MediaPipeIODemo` scheme. Requires Xcode 16+, iOS 17 deployment target.
`xcodegen` and `cocoapods` are both installable via Homebrew (`brew install xcodegen cocoapods`).

**Re-run `pod install` after every `xcodegen generate`** — regenerating the project from
`project.yml` doesn't preserve CocoaPods' integration, so the two steps have to happen in that
order every time the project is regenerated.

## What each section does

- **Chats** — a message-thread inbox. The top-level search bar does semantic search across all
  threads; open a thread and its own search bar searches within just that conversation. A
  "History Summarizer" panel (TL;DR / Keypoints) summarizes the whole thread on demand. Each row
  and message bubble shows an embedded/not-embedded status badge, and there's a "Re-embed" action
  (per-thread, and "Re-embed all" on the list) with a live progress bar showing count and
  items/sec.
- **Archive** — a grid of PDF documents. At first launch, each bundled PDF's first two pages are
  text-extracted (via PDFKit's real text layer, not OCR) and embedded, powering archive-wide
  search. Open a document, swipe through pages, tap "Select this page" on any page, and summarize
  just that page. Tap **Import** to pull in a PDF from anywhere the Files app can reach — including
  a Mac's Desktop, if iCloud Drive desktop sync is on — which gets copied into the app's own
  storage and indexed the same way bundled documents are.
- **Email** — an inbox with the same semantic search pattern. Each email supports Summarize
  (TL;DR / Keypoints / Raw Text) and Proofread — the sample emails contain real grammar mistakes
  on purpose, so Proofread has something to fix; the result renders as an inline diff.

## Architecture

```
MediaPipeIODemo/
  App/            AppContainer (composition root) + the @main App entry point
  Models/         SwiftData @Model types: ChatThread, ChatMessage, EmailItem, ArchiveDocument,
                  EmbeddingRecord
  ML/             TextSummarizerEngine / TextProofreaderEngine / TextEmbedderEngine protocols +
                  their real MediaPipeTasksText-backed actor implementations
  Search/         EmbeddingScope, SemanticSearchService (actor), VectorIndex (cosine similarity)
  Data/
    Local         (SwiftData handles persistence directly via the Models — no separate DAO layer)
    Storage/      PdfTextExtractor + PdfPageRenderer (PDFKit), DocumentImporter, DocumentLocator
    Repository/   ChatRepository, EmailRepository, ArchiveRepository — one per section, @MainActor
    Seed/         DemoDataSeeder — sample chats/emails/PDFs + the "initialization stage" scan
  UI/
    Chats/        List + thread detail screens (chat bubbles with tails, timestamps, grouping)
    Archive/      Grid + document viewer screens
    Email/        List + detail screens
    Components/   SemanticSearchBar, SummarizerPanel, ProofreaderPanel, WordDiff, EmbeddingStatus
    Navigation/   RootTabView
  Util/           Date/time formatting
  Resources/      SampleArchive/*.pdf, Models/*.litertlm|*.task (gitignored), Assets.xcassets
MediaPipeIODemoTests/
  WordDiffTests.swift, VectorIndexTests.swift — pure-Swift logic, no MediaPipe dependency
```

### The semantic search model

One SwiftData table (`EmbeddingRecord`) backs global search in all three sections *and* local,
in-thread chat search — `EmbeddingScope` tags what a vector is *of*, and `SemanticSearchService`
filters by scope (and, for chat messages, by parent thread) before ranking by cosine similarity.
`indexIfNeeded` is idempotent, so `DemoDataSeeder` calling it on every launch only does real work
once.

`SemanticSearchService` is an `actor` around its own background `ModelContext` — SwiftData
contexts aren't safe to use off the queue they were created on, so the context is built lazily on
first real access *from inside the actor*, not eagerly in `init` (which runs on whichever actor
constructs the service — the main actor, via `AppContainer`). Building it eagerly would bind it to
the main queue and then get used off that queue here, which is exactly what SwiftData's runtime
"Unbinding from the main queue" warning flags — this was a real bug caught and fixed during
initial device testing (see `Search/SemanticSearchService.swift`'s doc comment for detail).

### Composition root

`AppContainer` wires everything by hand (no DI framework) — `@Observable`, injected into the
SwiftUI environment once in `MediaPipeIODemoApp`. Repositories hold the app's main `ModelContext`
(the same one `@Query` uses in views) and must stay `@MainActor`; the search/embedding path is the
one thing that hops onto its own actor for background work.

## Tests

```
xcodebuild -workspace MediaPipeIODemo.xcworkspace -scheme MediaPipeIODemo \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' test
```

`MediaPipeIODemoTests/` covers `WordDiff` (the LCS diff behind the Proofreader's view) and
`VectorIndex` (the cosine-similarity ranking every search feature depends on). These are compiled
directly into the test target rather than reached via `@testable import MediaPipeIODemo` —
`@testable import` would pull in the whole app module's `MediaPipeTasksText` dependency, and
linking that pod a second time into the test bundle crashes at launch (MediaPipe's native
calculators aren't safe to register twice in one process). Both files are pure Swift with no
MediaPipe dependency, so compiling them into both targets sidesteps the whole problem — see
`project.yml`'s `MediaPipeIODemoTests` target for detail.

## Notes on iOS MediaPipe support vs. the Android sibling app

Android's `com.google.mediapipe:tasks-text:1.0.0` and iOS's `MediaPipeTasksText` pod (also
`1.0.0`) both ship real `TextSummarizer`, `TextProofreader`, and `TextEmbedder` classes with
equivalent capability — confirmed directly against the local `mediapipe-samples/examples/{text_summarizer,text_proofreader,text_embedder}/ios`
reference apps rather than assumed from docs (an earlier GitHub source-tree check had suggested
iOS lacked Summarizer/Proofreader entirely; the local reference apps corrected that). All three
models are the same `.litertlm`/`.task` bundle files as the Android app uses — genuinely
cross-platform formats, not separate iOS-specific downloads.
