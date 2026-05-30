# YT No Ads

A personal macOS SwiftUI app for searching YouTube with `yt-dlp`, starting playback from the growing download, then keeping the completed local file in the app cache.

## Requirements

- macOS 14 or newer
- Xcode command line tools
- `yt-dlp`

Install the helper:

```sh
brew install yt-dlp
```

## Run

Use the Codex Run action, or run:

```sh
./script/build_and_run.sh
```

The script builds the Swift package, stages `dist/YTNoAds.app`, and opens it as a native macOS app bundle.

## Test

```sh
swift test
```

## Notes

This is intended as a personal/local app. `yt-dlp` is detected from a user-provided path, `/opt/homebrew/bin/yt-dlp`, `/usr/local/bin/yt-dlp`, or `PATH`.

Quality modes:

- `Fast Start`: prefers a single progressive MP4 stream and starts playback during download.
- `720p`: prefers a single progressive stream up to 720p when available.
- `Best`: streams a fast preview URL immediately, downloads the highest-quality file in the background, then swaps playback to the final merged file. This may require `ffmpeg`.
