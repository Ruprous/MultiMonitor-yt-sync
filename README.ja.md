# MultiMonitor-yt-sync

> [English version here](README.md)

YouTube動画を複数のモニターにズレなく同期再生 — ワンクリックで起動。

## 概要

モニターの数だけ mpv を起動し、Named Pipe IPC で接続。再生位置を常に補正することで、全画面が同期した状態を保ちます。

- マスターモニターが音声付きで再生、スレーブは無音
- 縦向き（ポートレート）モニターを自動検出してクロップ表示
- 500ms ごとに同期チェック、0.3秒以上ズレたら自動補正

## 必要なもの

| ツール | 備考 |
|--------|------|
| [mpv](https://mpv.io/) | `C:\mpv\mpv.exe` に配置 |
| [yt-dlp](https://github.com/yt-dlp/yt-dlp) | `C:\Python312\Scripts\yt-dlp.exe` に配置 |
| Windows 10 / 11 | PowerShell 5.1+ |

## 使い方

### GUI（推奨）

`launch.bat` をダブルクリック → YouTube URL をペースト → モニター数を設定 → **Play**。

### PowerShell

```powershell
.\MultiMonitor-yt-sync.ps1 -Url "https://youtu.be/..." -Monitors 2
```

### パラメーター

| パラメーター | デフォルト | 説明 |
|-------------|-----------|------|
| `-Url` | *(必須)* | YouTube URL |
| `-Monitors` | `2` | 使用するモニター数 |
| `-PortraitMonitors` | 自動 | 縦向きモニターのインデックス（例: `1` または `1,2`）。省略で自動検出 |
| `-Threshold` | `0.3` | 補正を行うズレの閾値（秒） |
| `-IntervalMs` | `500` | 同期チェックの間隔（ミリ秒） |

## 仕組み

1. 各 mpv を `--pause` + `--screen=N` + Named Pipe IPC サーバーで起動
2. 全パイプ接続後、全インスタンスを 0 秒にシークして一斉再生開始
3. 500ms ごとにマスターの `time-pos` を取得し、閾値を超えたスレーブに絶対シークを送信
4. 縦向きモニターは `EnumDisplaySettings`（`dmDisplayOrientation`）で検出し、`--panscan=1.0` でクロップ表示

## ライセンス

MIT — [LICENSE](LICENSE) を参照

> このプロジェクトは [mpv](https://mpv.io/)（LGPLv2.1+）と [yt-dlp](https://github.com/yt-dlp/yt-dlp)（Unlicense）を外部プロセスとして呼び出しています。それらのライセンスはこのスクリプト自体には適用されません。
