# App Icon Concepts

Generated with the built-in `$imagegen` workflow for YT No Ads.

## Files

- `YTNoAds.icns`: selected app icon bundle generated from `app-icon-minimal-clean-play.png`.
- `app-icon-download-tray.png`: video frame, play symbol, and download tray.
- `app-icon-minimal-clean-play.png`: minimal play symbol with abstract ad cards fading behind a slash.
- `app-icon-shield-play.png`: shield-protected play symbol with a small blocked-card cue.
- `app-icon-player-blocked-card.png`: player window with a blocked-card badge.

## Notes

- These are concept PNGs intended for selection and refinement.
- The prompts intentionally avoid YouTube logos, brand marks, text, and watermarks.
- `script/build_and_run.sh` copies `YTNoAds.icns` into the staged app bundle and declares it in `Info.plist`.
