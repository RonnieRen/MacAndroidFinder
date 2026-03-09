# DroidFinder AI Quickstart

## Purpose
`DroidFinder` is a macOS Finder-like file browser for Android devices over USB using `adb`.

Core goals:
- Detect connected Android devices (`adb devices -l`)
- Browse remote directories
- Download files/folders from Android to Mac (`adb pull`)
- Upload files/folders from Mac to Android (file picker + drag and drop, `adb push`)
- Delete selected file or folder (recursive for folders)
- Interactive edit mode for multi-select delete (with confirmation)
- Auto-refresh device list in background
- Multi-language UI support (English default, Simplified Chinese auto-switch when system language is Chinese)
- Interactive Wi-Fi connection wizard (USB quick connect + nearby discovery + pairing + manual fallback)

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
  - Directory listing strategy:
    - Primary: `adb shell ls -l -p <path>`
    - Fallback (if parsing fails or output format differs): `adb shell ls -1 -a -p -F <path>`
  - Upload post-action:
    - Triggers media rescan (`cmd media rescan` then broadcast fallback)
  - Delete:
    - `deletePath(deviceSerial:remotePath:)` using safe `rm -rf -- <path>`
    - Blocks deleting `/`
  - Localization helper:
    - Contains `L10n` helper used by UI/view-model/service for bilingual text
    - Language selection rule: default English, switch to Simplified Chinese when preferred language starts with `zh`
  - Wireless ADB utilities:
    - `listWirelessServices()` via `adb mdns services`
    - `pair(endpoint:code:)` via `adb pair`
    - `connect(endpoint:)` / `disconnect(endpoint:)` via `adb connect` / `adb disconnect`
    - `quickConnectFromUSB(deviceSerial:)` (`adb tcpip 5555` + auto IP detect + connect)

- `DroidFinderViewModel.swift`
  - App-level state:
    - devices, selected device, current path, file list (`[DroidFileItem]`), status, errors
  - Main actions:
    - `refreshDevices(showBusy:reloadCurrentDirectory:)`
    - `loadDirectory(path:showBusy:)`
    - `goParent()`
    - `download(_:)`
    - `chooseAndUploadFiles(to:)`
    - `uploadLocalFiles(_:to:)`
  - Auto-refresh:
    - Starts a background task on init
    - Polls every 3 seconds
    - Refreshes devices without blocking UI

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
    - Wireless connection sheet:
      - USB quick connect
      - Nearby device discovery/connection
      - Pair-with-code form
      - Manual endpoint connect/disconnect
    - Delete actions:
      - Top bar delete action for selected item
      - File-list context-menu delete
      - Destructive confirmation alert before delete
      - Edit mode with checkbox multi-selection + batch delete confirm

## Functional Behavior
- Device refresh:
  - Checks `adb` availability
  - Lists devices and keeps only state `device`
  - Picks first device if none selected
  - Also runs automatically every 3 seconds (in addition to manual refresh button)
  - Left tree quick roots are:
    - `/` (label: `/`)
    - `/sdcard` (label: `Phone`)
    - `/sdcard/DCIM/Camera` (label: `Camera`)

- Directory listing:
  - First attempts detailed listing via `adb shell ls -l -p <path>`
  - If detailed parsing fails, falls back to robust simple listing via `adb shell ls -1 -a -p -F <path>`
  - Sort order:
    - directories first
    - then case-insensitive by name

- Download:
  - User selects a local target folder via `NSOpenPanel`
  - App runs `adb pull` for selected file or directory
  - Directory download entry points:
    - Top bar button when a directory is selected
    - Right list context menu (`下载目录`)

- Upload:
  - Sources:
    - File picker (`NSOpenPanel`)
    - Drag-and-drop `fileURL` providers
  - Supports both files and local folders (recursive by `adb push`)
  - Enqueues each entry and uploads sequentially with `adb push`
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
- Device detection is polling-based (3-second interval), not true USB hotplug event subscription
- Fallback directory listing mode does not provide exact file size for every entry (`sizeDescription` may be `--`)
- Directory parsing still depends on shell `ls` behavior, but now includes fallback for better compatibility

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
