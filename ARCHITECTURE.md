# NoteApp architecture

An offline note app with media attachments. Notes live on the device; there is no
server.

## The rule

Dependencies point inward. `Features` knows `Domain`. `Data` knows `Domain`.
`Domain` knows nothing.

```
NoteApp/
├── App/          composition root — the only file that names concrete types
├── Features/     SwiftUI views + @Observable models, one folder per screen
├── Domain/       value types and protocols; no SwiftData, no SwiftUI
├── Data/         SwiftData entities, the repository, the file store
└── Support/      small shared utilities
```

`Domain` importing only `Foundation` is the load-bearing part. It is what lets
the storage engine change without touching a view, and what lets a view model be
tested against a hand-written fake repository in a few lines.

## How data flows

```
NoteListView ─┐                       ┌─ NoteEntity (@Model)
              ├─ NoteListModel ─┐     │
              │                 ├─ NoteRepository ─── SwiftDataNoteRepository ─┤
NoteEditorView┘  NoteEditorModel┘        (protocol)                            └─ AttachmentEntity
                                                              │
                                                              └─ AttachmentStore ── files on disk
```

Views hold no data. Models hold state and talk to protocols. Only
`SwiftDataNoteRepository` has ever heard of SwiftData.

## Four decisions worth knowing

**Views never see a `@Model` object.** `NoteEntity` maps to a `Note` struct at
the repository boundary. A `@Model` is a live, context-bound reference type —
handing one to a view means the view can write to the database by assigning to a
property, and it faults the object graph while scrolling. `EntityMapping.swift`
is the only place the conversion happens.

**The list loads `NoteSummary`, not `Note`.** A summary carries a snippet and an
attachment count. Fetching whole notes to draw a list means loading every
attachment relationship, which is how note apps get slow once video is involved.

**Media goes on disk; the database stores a relative path.** Blobs in a database
make every query slow and every backup enormous. `FileAttachmentStore` owns
`Application Support/Media/{images,audios,videos,files}/`. Paths are stored
relative because the container's absolute path changes between installs.

**The repository is an `actor`.** `ModelContext` is not thread-safe, and once
notes carry media, database work has no business on the main thread. Every
mutation funnels through one `commit()` that saves and then fires
`repository.changes`, so a screen never has to guess when its data went stale —
including changes it did not cause itself.

## Adding things

**A new screen** — add a folder under `Features/`, an `@Observable @MainActor`
model taking `NoteRepository` in its initializer, and a view that reads the
container from the environment.

**Audio recording** — add `NSMicrophoneUsageDescription` to the target's Info
settings, record with `AVAudioRecorder` to a temporary file, then hand the
repository `AttachmentDraft(kind: .audio, source: .fileURL(url), duration:)`. No
other layer changes; `AttachmentPreviewView` already plays audio.

**Other file types** — `AttachmentKind` is the only switch.

**Tests** — `AppContainer.ephemeral()` gives an in-memory store and a scratch
media directory with the same code paths as the real thing.

## Not here

No server, no sync, no accounts, no network code of any kind. Notes and media
live on the device and nowhere else.
