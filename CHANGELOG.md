# Changelog

Notable public releases will be documented here.

This project uses GitHub Releases for downloadable macOS builds. Release tags use the `vX.Y.Z` format.

## Unreleased

## 0.4.1 - 2026-07-21

- Added in-app update checking through a signed, direct-download release feed.
- Fixed content-zoom keyboard shortcuts so they work across keyboard layouts.
- Fixed editor timeline track durations for captures with startup frames or shorter sources.
- Improved source-window zoom and fit behavior in the canvas.
- Refined transcript handling and project library interactions.

## 0.4.0 - 2026-07-16

- Added a Projects library with playback, multi-selection, rename, delete, Finder access, and export workflows.
- Added optional on-device transcription with speaker timelines, searchable transcripts, editable speaker details, and generated project titles.
- Expanded the editor with a visual filmstrip, clearer scene changes, source crop and zoom controls, canvas padding, screen corners, and shadows.
- Added export controls for format, resolution, quality, bitrate estimates, and destination placement.
- Improved recording settings, screen-source zoom, permission recovery, microphone startup, audio finalization, and capture error reporting.
- Refined iPhone companion pairing state and recording-library cleanup controls.

## 0.3.0 - 2026-07-15

- Redesigned the recording studio and editor around a shared native control system.
- Added synchronized full-timeline playback for screen, camera, microphone, and system audio.
- Improved recording startup, finalization, source selection, permission recovery, and error reporting.
- Fixed editor refresh, crop, frame-ratio, scene resizing, and export placement behavior.
- Added a sandbox-safe DMG packaging fallback for current macOS releases.
