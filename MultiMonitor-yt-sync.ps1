param(
    [Parameter(Mandatory=$true)][string]$Url,
    [int]$Monitors           = 2,
    [int[]]$PortraitMonitors = $null,   # auto-detected if omitted
    [double]$Threshold       = 0.3,
    [int]$IntervalMs         = 500
)

$mpvExe = "C:\mpv\mpv.exe"

# ---- helpers ----

function Get-PortraitMonitorIndices {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Collections.Generic;

public static class DisplayHelper {
    const int ENUM_CURRENT_SETTINGS = -1;
    const int DISPLAY_DEVICE_ATTACHED_TO_DESKTOP = 0x00000001;

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Ansi)]
    struct DISPLAY_DEVICE {
        public int cb;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]  public string DeviceName;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string DeviceString;
        public int StateFlags;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string DeviceID;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string DeviceKey;
    }

    // Sequential layout maps directly to DEVMODEA offsets for display fields
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Ansi)]
    struct DEVMODE {
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string dmDeviceName; // 32 bytes
        public short dmSpecVersion;       // offset 32
        public short dmDriverVersion;     // offset 34
        public short dmSize;              // offset 36
        public short dmDriverExtra;       // offset 38
        public int   dmFields;            // offset 40
        public int   dmPositionX;         // offset 44
        public int   dmPositionY;         // offset 48
        public int   dmDisplayOrientation; // offset 52  (0=landscape, 1=90°, 2=180°, 3=270°)
    }

    [DllImport("user32.dll", CharSet = CharSet.Ansi)]
    static extern bool EnumDisplayDevicesA(string lpDevice, uint iDevNum, ref DISPLAY_DEVICE lpDisplayDevice, uint dwFlags);

    [DllImport("user32.dll", CharSet = CharSet.Ansi)]
    static extern bool EnumDisplaySettingsA(string lpszDeviceName, int iModeNum, ref DEVMODE lpDevMode);

    public static int[] GetPortraitIndices() {
        var result = new List<int>();
        uint devNum = 0;
        int monIdx = 0;
        while (true) {
            var dd = new DISPLAY_DEVICE();
            dd.cb = Marshal.SizeOf(typeof(DISPLAY_DEVICE));
            if (!EnumDisplayDevicesA(null, devNum++, ref dd, 0)) break;
            if ((dd.StateFlags & DISPLAY_DEVICE_ATTACHED_TO_DESKTOP) == 0) continue;
            var dm = new DEVMODE();
            dm.dmSize = (short)Marshal.SizeOf(typeof(DEVMODE));
            if (EnumDisplaySettingsA(dd.DeviceName, ENUM_CURRENT_SETTINGS, ref dm))
                if (dm.dmDisplayOrientation == 1 || dm.dmDisplayOrientation == 3)
                    result.Add(monIdx);
            monIdx++;
        }
        return result.ToArray();
    }
}
'@ -ErrorAction Stop
    return [DisplayHelper]::GetPortraitIndices()
}

if ($null -eq $PortraitMonitors) {
    $PortraitMonitors = Get-PortraitMonitorIndices
    if ($PortraitMonitors.Count -gt 0) {
        Write-Host "  [auto] portrait monitors detected: $($PortraitMonitors -join ', ')" -ForegroundColor DarkGray
    }
}

function New-PipeConn($name) {
    $pipe = New-Object System.IO.Pipes.NamedPipeClientStream(".", $name,
        [System.IO.Pipes.PipeDirection]::InOut,
        [System.IO.Pipes.PipeOptions]::None)
    $pipe.Connect(5000)
    $w = New-Object System.IO.StreamWriter($pipe); $w.AutoFlush = $true
    $r = New-Object System.IO.StreamReader($pipe)
    return @{ Pipe=$pipe; W=$w; R=$r }
}

# Send a command and always consume its response to keep the buffer clean
function Invoke-Cmd($conn, $json) {
    $conn.W.WriteLine($json)
    try { $conn.R.ReadLine() | Out-Null } catch {}
}

# Send a command and return the parsed response data
function Invoke-CmdRead($conn, $json) {
    try {
        $conn.W.WriteLine($json)
        $line = $conn.R.ReadLine()
        $obj  = $line | ConvertFrom-Json
        if ($obj.error -eq "success") { return $obj.data }
    } catch {}
    return $null
}

function Get-TimePos($conn) {
    return Invoke-CmdRead $conn '{"command":["get_property","time-pos"]}'
}

function Send-Seek($conn, [double]$t) {
    # seek without pausing — less stuttery than pause/seek/unpause
    Invoke-Cmd $conn ("{`"command`":[`"seek`",$t,`"absolute`"]}")
}

function Send-Pause($conn, [bool]$state) {
    $v = if ($state) { "true" } else { "false" }
    Invoke-Cmd $conn "{`"command`":[`"set_property`",`"pause`",$v]}"
}

# ---- launch ----

Write-Host ""
Write-Host "  MultiMonitor-yt-sync  |  monitors: $Monitors  |  threshold: ${Threshold}s" -ForegroundColor Cyan
Write-Host ""

$procs = @()
for ($i = 0; $i -lt $Monitors; $i++) {
    $mpvArgs = @(
        "--input-ipc-server=\\.\pipe\mpvsync$i",
        "--screen=$i",
        "--fs",
        "--fs-screen=$i",
        "--keep-open",
        "--pause",
        "--ytdl-format=bestvideo[height<=1080]+bestaudio/bestvideo+bestaudio/best",
        $Url
    )
    if ($i -gt 0) { $mpvArgs += "--no-audio" }
    if ($PortraitMonitors -contains $i) { $mpvArgs += "--panscan=1.0" }

    $p = Start-Process -FilePath $mpvExe -ArgumentList $mpvArgs -PassThru
    $procs += $p
    $tags = @()
    if ($i -gt 0)                          { $tags += "no audio" }
    if ($PortraitMonitors -contains $i)    { $tags += "portrait" }
    $tagStr = if ($tags.Count) { " ($($tags -join ', '))" } else { "" }
    Write-Host "  [mpv$i] PID $($p.Id)  monitor $i$tagStr" -ForegroundColor Gray
}

Write-Host ""
Write-Host "  Waiting for mpv to load..." -ForegroundColor DarkGray
Start-Sleep -Seconds 6

# ---- connect ----

$conns = @()
for ($i = 0; $i -lt $Monitors; $i++) {
    try {
        $c = New-PipeConn "mpvsync$i"
        $conns += $c
        Write-Host "  [OK] mpv$i connected" -ForegroundColor Green
    } catch {
        Write-Host "  [ERROR] mpv$i pipe failed: $_" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-Host "  Syncing start..." -ForegroundColor Cyan

# Seek all to 0, then start together
foreach ($c in $conns) { Send-Seek $c 0 }
Start-Sleep -Milliseconds 500
foreach ($c in $conns) { Send-Pause $c $false }

Write-Host "  Running. Press Ctrl+C to quit." -ForegroundColor Cyan
Write-Host ""

# ---- sync loop ----

try {
    while ($true) {
        $alive = $true
        foreach ($p in $procs) { if ($p.HasExited) { $alive = $false; break } }
        if (-not $alive) {
            Write-Host "  [INFO] mpv closed, exiting." -ForegroundColor DarkGray
            break
        }

        $masterTime = Get-TimePos $conns[0]
        if ($null -eq $masterTime) { Start-Sleep -Milliseconds $IntervalMs; continue }

        for ($i = 1; $i -lt $Monitors; $i++) {
            $slaveTime = Get-TimePos $conns[$i]
            if ($null -eq $slaveTime) { continue }

            $drift = $masterTime - $slaveTime
            if ([Math]::Abs($drift) -gt $Threshold) {
                Write-Host ("  [sync] monitor{0} drift {1:+0.000;-0.000}s -> correcting" -f $i, $drift) -ForegroundColor Yellow
                Send-Seek $conns[$i] $masterTime
            }
        }

        Start-Sleep -Milliseconds $IntervalMs
    }
}
finally {
    Write-Host ""
    Write-Host "  Cleaning up..." -ForegroundColor DarkGray
    foreach ($c in $conns) { try { $c.Pipe.Close() } catch {} }
    foreach ($p in $procs)  { try { if (-not $p.HasExited) { $p.Kill() } } catch {} }
    Write-Host "  Done." -ForegroundColor DarkGray
}
