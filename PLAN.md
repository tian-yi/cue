# macOS YouTube Companion App Plan

## Positioning

Build a native macOS app for searching YouTube and watching videos in a smooth desktop interface. The app should not be designed as an ad-blocking or YouTube restriction-bypass tool. For YouTube-hosted playback, use permitted APIs and playback surfaces. For "download first, then show", support only media the app is allowed to fetch: user-owned uploads, user-imported files, explicitly licensed sources, or URLs/services with download permission.

This keeps the product shippable and avoids a brittle dependency on YouTube scraping/downloader behavior that can violate YouTube terms, break unexpectedly, or create legal risk.

For a personal-only app, the implementation can offer an optional local `yt-dlp`
adapter. Treat it as a user-installed helper, not a bundled commercial feature.
The app should detect whether `yt-dlp` is available, show the resolved version,
and route eligible/user-authorized downloads through that adapter. In this mode,
the MVP can avoid Google credentials entirely by using `yt-dlp` for both search
and metadata probing.

## Core Requirements

### 1. User can search YouTube

Use the YouTube Data API v3 for search and metadata.

User flow:

1. User enters a search query in the toolbar/search field.
2. App requests YouTube search results.
3. Results show title, channel, thumbnail, duration, publish date, and view count where available.
4. User can refine by relevance, upload date, duration, channel, or saved filters.
5. User selects a video to open the detail/player pane.

Implementation notes:

- `search.list` returns candidate video IDs.
- `videos.list` hydrates duration, statistics, content details, and thumbnails.
- Cache metadata locally to reduce quota usage.
- Store recent searches and selected filters locally.

Personal `yt-dlp` mode can replace the official search API:

- Use `yt-dlp` search URLs such as `ytsearch20:<query>`.
- Use flat metadata probing for fast result lists.
- Hydrate the selected result only when the user opens it.
- This avoids an API key/OAuth requirement for the private MVP.

### 2. Clicking a video downloads it first, then shows it

Use an explicit playback eligibility layer before downloading.

Supported playback modes:

- **Local media mode:** user imports a video file or a URL that legally permits direct download. The app downloads/caches first, then plays via `AVPlayer`.
- **Personal helper mode:** if `yt-dlp` is installed locally, the app can call it for user-authorized downloads in a private/local workflow, then play the completed file with `AVPlayer`.
- **Owned/licensed YouTube mode:** user authenticates and selects videos they own or have rights to download through an approved export/source. The app caches first, then plays locally.
- **YouTube embedded mode:** for normal YouTube videos where direct download is not permitted, the app opens the official YouTube player in a `WKWebView` or external browser. This may include YouTube's normal monetization behavior.

State machine:

1. `selected`
2. `checkingEligibility`
3. `downloadQueued` or `embeddedPlaybackRequired`
4. `downloading(progress)`
5. `verifyingFile`
6. `readyToPlay`
7. `playing`
8. `failed(reason, recoveryAction)`

## Product Shape

Main window:

- Native macOS `WindowGroup`.
- `NavigationSplitView`.
- Sidebar for search, saved searches, local library, and downloads.
- Content list for search results or library items.
- Detail pane for selected video, metadata, download state, and player.

Settings window:

- YouTube API key/OAuth status.
- Cache location and max cache size.
- Download quality preference for permitted sources.
- Privacy controls: clear history, clear cache, disable search history.

Menus and shortcuts:

- `Cmd+L`: focus search.
- `Cmd+F`: search within current result set if needed.
- `Space`: play/pause when player focused.
- `Cmd+Shift+D`: show downloads.
- `Cmd+,`: settings.

## Technical Architecture

Target platform:

- macOS native app using SwiftUI.
- Minimum target: macOS 14 unless there is a reason to support older versions.
- AVKit/AVFoundation for local playback.
- URLSession for API and permitted media downloads.
- SwiftData or SQLite for metadata, cache index, search history, and download records.

Suggested module layout:

```text
YTNoAds/
  App/
    YTNoAdsApp.swift
  Models/
    VideoSummary.swift
    VideoDetails.swift
    PlaybackSource.swift
    DownloadJob.swift
  Views/
    ContentView.swift
    SidebarView.swift
    SearchResultsView.swift
    VideoDetailView.swift
    PlayerView.swift
    DownloadsView.swift
    SettingsView.swift
  Stores/
    SearchStore.swift
    LibraryStore.swift
    DownloadStore.swift
    PreferencesStore.swift
  Services/
    YouTubeSearchService.swift
    VideoMetadataService.swift
    PlaybackEligibilityService.swift
    YTDLPService.swift
    DownloadManager.swift
    CacheManager.swift
  Support/
    DurationFormatter.swift
    ThumbnailCache.swift
    ErrorPresentation.swift
```

Service responsibilities:

- `YouTubeSearchService`: search requests, pagination, result normalization.
- `VideoMetadataService`: hydrate video IDs with details and statistics.
- `PlaybackEligibilityService`: decide whether local download/playback is allowed.
- `YTDLPService`: detect `yt-dlp`, search, read metadata, start downloads, parse progress, and surface errors.
- `DownloadManager`: queue, pause, resume, retry, and progress reporting.
- `CacheManager`: file placement, eviction, file integrity checks, cache size accounting.
- `LibraryStore`: local playable assets and completed downloads.

## Data Model

`VideoSummary`:

- `id`
- `title`
- `channelTitle`
- `thumbnailURL`
- `publishedAt`
- `duration`
- `source`

`PlaybackSource`:

- `youtubeEmbedded(videoID)`
- `localFile(url)`
- `ytDlp(url, metadata)`
- `permittedRemoteDownload(url, licenseInfo)`
- `unavailable(reason)`

`DownloadJob`:

- `id`
- `videoID` or `sourceURL`
- `status`
- `progress`
- `destinationURL`
- `createdAt`
- `completedAt`
- `failureReason`

## UX Details

Search:

- Search field in the toolbar using native `.searchable` where practical.
- Results should feel like a desktop list: thumbnail, title, channel, metadata, and status.
- Selection should be stable across refreshes.

Download-first playback:

- On click, show a compact detail pane immediately.
- If the item is eligible, start download automatically and show progress.
- If personal helper mode is enabled, route the job through `yt-dlp` and parse progress into the same download state machine.
- When the file is ready, transition to local `AVPlayer` playback.
- If not eligible for download, show official embedded playback instead of failing silently.
- Provide clear labels such as "Playable locally" or "YouTube playback required".

Library:

- Completed permitted downloads appear in a local library.
- Library supports search, sorting, reveal in Finder, and delete.
- Cache eviction should never delete user-imported files unless the user explicitly chooses that.

## Implementation Phases

### Phase 1: Native shell and search

- Create SwiftUI app scaffold.
- Add `NavigationSplitView`.
- Implement search input and results list.
- Wire YouTube Data API search and metadata hydration.
- Add basic local metadata cache.

Exit criteria:

- User can search YouTube.
- Results render with thumbnails and metadata.
- Selecting a result opens the detail pane.

### Phase 2: Playback eligibility and player

- Add `PlaybackEligibilityService`.
- Add `PlayerView` with AVKit for local media.
- Add official YouTube embedded playback fallback.
- Add detail states for eligible, unavailable, and embedded-only content.
- Add personal-helper setting for enabling local `yt-dlp` use.

Exit criteria:

- App chooses the correct playback path for each selected video.
- Local test files play through `AVPlayer`.
- Normal YouTube results use official playback fallback.

### Phase 3: Download manager and cache

- Implement queue, progress, cancellation, retry.
- Implement `YTDLPService` using Swift `Process`.
- Detect `yt-dlp` at common Homebrew locations and allow a custom binary path in settings.
- Use `yt-dlp --dump-json` for metadata probing and normal download commands for eligible/user-authorized jobs.
- Store downloads under Application Support or user-selected cache folder.
- Verify file exists and is playable before marking ready.
- Add cache size settings and eviction.

Exit criteria:

- Eligible remote assets download before playback.
- Progress is visible and cancellable.
- Completed assets appear in local library.

### Phase 4: Account and owned-media support

- Add OAuth if needed for user-owned YouTube content.
- Add account status in settings.
- Support importing/exporting user-owned media from approved sources.

Exit criteria:

- User can authenticate.
- App distinguishes owned/licensed media from general public videos.
- Download-first playback works for allowed assets.

### Phase 5: Polish and reliability

- Add keyboard shortcuts, menus, toolbar actions, and context menus.
- Add robust error states.
- Add tests for parsing, eligibility, cache, and download state transitions.
- Add UI smoke tests for search, selection, download progress, and playback fallback.

Exit criteria:

- Main flows are test-covered.
- Download failures recover cleanly.
- The app feels like a real macOS app, not a web wrapper.

## Libraries and APIs

Use:

- YouTube Data API v3 for search and metadata when using official API mode.
- SwiftUI for app shell and views.
- AVKit/AVFoundation for local playback.
- URLSession for network and downloads.
- `yt-dlp` as an optional locally installed helper for a personal app.
- SwiftData or SQLite for local metadata.
- Keychain for API tokens/OAuth credentials.

Avoid:

- Shipping a YouTube ad blocker as the core product.
- Bundling YouTube scraping/downloading utilities as a public/commercial feature.
- Depending on private YouTube endpoints as the primary architecture.

## Personal `yt-dlp` Integration

For a private app, the lowest-friction route is to require the user to install
`yt-dlp` separately, usually with Homebrew:

```sh
brew install yt-dlp
```

Discovery order:

1. User-configured binary path.
2. `/opt/homebrew/bin/yt-dlp`.
3. `/usr/local/bin/yt-dlp`.
4. `PATH` lookup.

Swift integration:

- Use `Process` and pipe stdout/stderr.
- Never block the main actor while a process runs.
- Parse newline-delimited progress output into `DownloadJob.progress`.
- Write each download into a temporary folder first, then atomically move into the app cache when complete.
- Store the exact `yt-dlp --version` used for each completed download for debugging.

Recommended commands to wrap:

```sh
yt-dlp --version
yt-dlp --dump-single-json --flat-playlist "ytsearch20:<query>"
yt-dlp --dump-json <url>
yt-dlp --newline -o <temp-output-template> <url>
```

App settings:

- Enable/disable personal helper mode.
- Binary path with "Auto-detect" and "Choose..." actions.
- Download format preference.
- Cache location and max size.
- Clear completed downloads.

## Testing Plan

Unit tests:

- Search response parsing.
- Metadata hydration.
- Playback eligibility decisions.
- Download state machine.
- Cache eviction rules.

Integration tests:

- Search query returns normalized results using fixture data.
- Eligible download completes and becomes playable.
- Ineligible video falls back to official YouTube playback.
- Cache survives app restart.

Manual QA:

- Search empty/error/loading states.
- Network interruption during download.
- Large cache cleanup.
- Light and dark mode.
- Keyboard navigation and menu commands.

## Open Questions

1. Should the app require user login from the start, or begin with API-key search only?
2. What content sources are in scope for permitted download-first playback besides user-imported files?
3. Is this intended for personal/local use only, or eventual distribution?
4. Should completed local media be permanent library items or disposable cache entries?
5. What minimum macOS version should be supported?

## Recommended First Build

Start with a native SwiftUI search and detail app:

1. Search YouTube through the official API.
2. Show results in a native list.
3. Select a video.
4. If a local/permitted asset is available, download and play with `AVPlayer`.
5. Otherwise, show the official embedded player fallback.

For the personal `yt-dlp` MVP, playback starts from the growing download once a
playable local file exists. The app then swaps to the final cached file when the
download completes.

That gives the app the desired shape while keeping the risky part behind a clear eligibility boundary.
