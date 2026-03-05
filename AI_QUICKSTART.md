# DroidFinder AI Quickstart

## Purpose
`DroidFinder` is a macOS Finder-like file browser for Android devices over USB using `adb`.

Core goals:
- Detect connected Android devices (`adb devices -l`)
- Browse remote directories
- Download files from Android to Mac (`adb pull`)
- Upload files from Mac to Android (file picker + drag and drop, `adb push`)

## Project Layout
- `DroidFinder/`:
  Xcode app source (main target used by `DroidFinder.xcodeproj`)
- `Sources/DroidFinder/`:
  SwiftPM mirror of the same source files
- `DroidFinder.xcodeproj`:
  Xcode project
- `Package.swift`:
  SwiftPM executable target
- `scripts/build_dmg.sh`:
  Build + package `.app` into `.dmg`

Note: `DroidFinder/` and `Sources/DroidFinder/` are currently duplicated and in sync.

## Main Components
- `DroidADBService.swift`
  - Locates `adb` from common paths and env vars
  - Executes ADB commands via `Process`
  - Provides:
    - `listDevices()`
    - `listDirectory(deviceSerial:path:)`
    - `pullFile(deviceSerial:remotePath:localDirectory:)`
    - `pushFile(deviceSerial:localFile:remoteDirectory:)`

- `DroidFinderViewModel.swift`
  - App-level state:
    - devices, selected device, current path, file list (`[DroidFileItem]`), status, errors
  - Main actions:
    - `refreshDevices()`
    - `loadDirectory(path:)`
    - `goParent()`
    - `download(_:)`
    - `chooseAndUploadFiles(to:)`
    - `uploadLocalFiles(_:to:)`

- `DirectoryTreeStore` (inside `DroidFinderViewModel.swift`)
  - Lazy-load remote subdirectories
  - Caches children per path
  - Tracks loading paths

- `UploadQueueStore` (inside `DroidFinderViewModel.swift`)
  - Queues uploads and processes sequentially
  - Tracks status: pending/uploading/completed/failed
  - Reports progress and completion callbacks

- `ContentView.swift`
  - Finder-like UI:
    - Top bar (device picker, refresh, parent, upload/download)
    - Breadcrumb navigation
    - Split view (left: directory tree, right: file list)
    - Drag-and-drop upload zone on file list
    - Floating upload queue panel with progress

## Functional Behavior
- Device refresh:
  - Checks `adb` availability
  - Lists devices and keeps only state `device`
  - Picks first device if none selected
  - Left tree quick roots are:
    - `/` (label: `/`)
    - `/sdcard` (label: `Phone`)
    - `/sdcard/DCIM/Camera` (label: `Camera`)

- Directory listing:
  - Calls `adb shell ls -l -p <path>`
  - Parses Unix-style `ls` output into file entries
  - Sort order:
    - directories first
    - then case-insensitive by name

- Download:
  - User selects a local target folder via `NSOpenPanel`
  - App runs `adb pull` for selected file

- Upload:
  - Sources:
    - File picker (`NSOpenPanel`)
    - Drag-and-drop `fileURL` providers
  - Enqueues each file and uploads sequentially with `adb push`
  - After each push, app triggers Android media rescan for the uploaded file path (best effort) so Gallery apps can discover new media
  - Refreshes touched remote directories after batch completion

## UX Details
- Left tree uses manual row selection (not `List(selection:)`):
  - Clicking empty area in the tree should not select all rows
- Double-click directory in file list: enter directory
- Double-click file in file list: download file
- Single-click in right file list should select immediately (explicit single-tap selection + simultaneous double-tap open/download)
- Context menu on entries: open/download action
- Status/error shown in footer + alert
- Upload queue panel behavior:
  - Shows when uploads are added (button upload or drag/drop)
  - Can be closed via header `X`
  - Tapping outside the panel closes it

## Current Limitations
- No recursive folder upload (upload is file-based)
- No directory download action (download is file-only)
- Device detection is refresh-based, not USB hotplug event-driven
- Directory parsing relies on `ls -l` text format (can vary by device shell behavior)

## Build / Run
- Xcode:
  - Open `DroidFinder.xcodeproj`
  - Run scheme `DroidFinder` on `My Mac`
- SwiftPM:
  - `swift build`
- DMG:
  - `./scripts/build_dmg.sh`

## Runtime Requirements
- macOS 13+
- `adb` installed (Android Platform Tools)
- Android device with USB debugging enabled and authorized on first connect
