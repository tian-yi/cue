# YT No Ads

YT No Ads is a personal macOS SwiftUI app for searching YouTube through a user-installed `yt-dlp` helper, starting playback quickly, and keeping completed videos in a local cache.

The app is built as a native Swift package executable with a small app-bundle staging script. It is intended for private/local use with media you are allowed to access or download.

## Features

- Search YouTube from a native macOS interface.
- Browse results as a gallery or list with thumbnails, channels, durations, and view counts.
- Select a result to start playback while the file is being cached when possible.
- Choose between fast-start, 720p, and best-quality download modes.
- Track active, completed, and failed downloads.
- Replay completed downloads from the local library.
- Reveal cached files in Finder or delete completed downloads.
- Open the original video on YouTube when needed.
- Use AVKit playback with fullscreen and Picture in Picture support.
- Enable a same-Wi-Fi web remote with QR pairing for phone playback controls.

## Requirements

- macOS 14 or newer
- Xcode command line tools with Swift 5.9+
- [`yt-dlp`](https://github.com/yt-dlp/yt-dlp)
- Optional: `ffmpeg` for best-quality merged downloads

Install the helpers with Homebrew:

```sh
brew install yt-dlp ffmpeg
```

`yt-dlp` is detected from:

1. The path set in the app's Settings window.
2. `/opt/homebrew/bin/yt-dlp`
3. `/usr/local/bin/yt-dlp`
4. The current `PATH`

## Quick Start

Build and launch the app bundle:

```sh
./script/build_and_run.sh
```

The script runs `swift build`, stages `dist/YTNoAds.app`, and opens it as a native macOS app.

You can also run the executable directly during development:

```sh
swift run YTNoAds
```

## Build Script Modes

```sh
./script/build_and_run.sh              # build and open the app
./script/build_and_run.sh --verify     # build, open, and verify the process launched
./script/build_and_run.sh --debug      # build and start lldb
./script/build_and_run.sh --logs       # stream app logs
./script/build_and_run.sh --telemetry  # stream telemetry logs
```

## Phone Remote

Open the Remote section in the sidebar and enable the LAN remote. The app shows a QR code that includes a private pairing token. Scan it from a phone on the same Wi-Fi to control play/pause, seek, volume, fullscreen, close player, and quality selection.

The remote is local-network only; it does not use a cloud service or account. If the phone cannot connect, make sure both devices are on the same Wi-Fi and allow incoming connections if macOS prompts.

## Tests

Run the Swift test suite:

```sh
swift test
```

The current tests cover `yt-dlp` search decoding, progress parsing, quality selectors, stream URL resolution, and download manager file handling with a fake helper binary.

## How It Works

Search uses `yt-dlp` flat playlist metadata through `ytsearch20:<query>`. The app decodes video entries into local `VideoSummary` models and renders them in the search view.

When a result is selected, the app queues a `DownloadJob`, asks `yt-dlp` for a playable preview URL when possible, and starts a background download into the app cache. Completed files are moved into the cache's `Downloads` directory and appear in the Library view.

The default cache directory is:

```text
~/Library/Application Support/YTNoAds
```

You can reveal the cache location from Settings.

## Quality Modes

- `Fast Start`: prefers a single progressive MP4 stream and starts playback as soon as possible.
- `720p`: prefers a single progressive stream up to 720p when available.
- `Best`: streams a fast preview first, downloads the highest-quality video/audio pair in the background, then swaps to the final merged MP4. This mode may require `ffmpeg`.

## Keyboard Shortcuts

- `Command-L`: run the current search.
- `Return`: submit the search field.
- `Command-Shift-D`: show Downloads.
- `Command-,`: open Settings.

## Project Layout

```text
Sources/YTNoAds/
  App/          App entry point and delegate
  Models/       App sections, video summaries, downloads, playback, remote models
  Services/     yt-dlp integration, downloads, playback, fullscreen, remote control server
  Stores/       Main observable app model and state transitions
  Support/      Formatting and networking helpers
  Views/        SwiftUI screens and reusable controls
Tests/
  YTNoAdsTests/ Unit tests
script/
  build_and_run.sh
```

## Development Notes

- Swift package dependencies are managed by SwiftPM.
- Hummingbird and Hummingbird WebSocket are used by the local remote-control server code.
- The app stores settings such as `yt-dlp` path, layout mode, and selected quality in `UserDefaults`.
- The app does not bundle `yt-dlp`; users provide and update their own local helper.

## Local-Use Note

This project is designed as a personal companion app. Use it only with content and services where you have the rights and permission to download or cache media, and respect the terms of the sites you access.
