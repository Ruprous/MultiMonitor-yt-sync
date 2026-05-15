# MultiMonitor-yt-sync

Play a YouTube video across multiple monitors in sync — one click, no drift.

## Overview

Launches one mpv instance per monitor, connects them via Named Pipe IPC, and continuously corrects playback position so all screens stay in sync.

- Master monitor plays with audio; slaves run silent
- Portrait monitors auto-detected and cropped to fill the screen
- Sync correction every 500 ms with a 0.3 s threshold

## Requirements

| Tool | Notes |
|------|-------|
| [mpv](https://mpv.io/) | Place at `C:\mpv\mpv.exe` |
| [yt-dlp](https://github.com/yt-dlp/yt-dlp) | Place at `C:\Python312\Scripts\yt-dlp.exe` |
| Windows 10 / 11 | PowerShell 5.1+ |

## Usage

### GUI (recommended)

Double-click `launch.bat` → paste a YouTube URL → set monitor count → **Play**.

### PowerShell

```powershell
.\MultiMonitor-yt-sync.ps1 -Url "https://youtu.be/..." -Monitors 2
```

### Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `-Url` | *(required)* | YouTube URL |
| `-Monitors` | `2` | Number of monitors to use |
| `-PortraitMonitors` | auto | Monitor indices in portrait orientation (e.g. `1` or `1,2`). Auto-detected if omitted. |
| `-Threshold` | `0.3` | Drift in seconds before a sync correction is applied |
| `-IntervalMs` | `500` | How often to check sync, in milliseconds |

## How it works

1. Each mpv instance is launched paused with `--screen=N` and a Named Pipe IPC server
2. After all pipes connect, all instances seek to 0 and unpause simultaneously
3. A loop reads the master's `time-pos` every 500 ms and issues absolute seek commands to any slave that has drifted past the threshold
4. Portrait monitors are detected via `EnumDisplaySettings` (`dmDisplayOrientation`) and receive `--panscan=1.0` to crop-fill the screen

## License

MIT — see [LICENSE](LICENSE)

> This project calls [mpv](https://mpv.io/) (LGPLv2.1+) and [yt-dlp](https://github.com/yt-dlp/yt-dlp) (Unlicense) as external processes. Their licenses do not affect this script.
