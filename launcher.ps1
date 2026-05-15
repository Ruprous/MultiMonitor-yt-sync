Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$form                  = New-Object System.Windows.Forms.Form
$form.Text             = "MultiMonitor-yt-sync"
$form.ClientSize       = New-Object System.Drawing.Size(360, 148)
$form.StartPosition    = "CenterScreen"
$form.FormBorderStyle  = "FixedDialog"
$form.MaximizeBox      = $false
$form.MinimizeBox      = $false
$form.Font             = New-Object System.Drawing.Font("Segoe UI", 9)

$lblUrl          = New-Object System.Windows.Forms.Label
$lblUrl.Text     = "YouTube URL"
$lblUrl.Location = New-Object System.Drawing.Point(16, 16)
$lblUrl.AutoSize = $true

$txtUrl          = New-Object System.Windows.Forms.TextBox
$txtUrl.Location = New-Object System.Drawing.Point(16, 34)
$txtUrl.Size     = New-Object System.Drawing.Size(328, 23)

$lblMon          = New-Object System.Windows.Forms.Label
$lblMon.Text     = "Monitors"
$lblMon.Location = New-Object System.Drawing.Point(16, 70)
$lblMon.AutoSize = $true

$numMon          = New-Object System.Windows.Forms.NumericUpDown
$numMon.Location = New-Object System.Drawing.Point(16, 88)
$numMon.Size     = New-Object System.Drawing.Size(56, 23)
$numMon.Minimum  = 1
$numMon.Maximum  = 6
$numMon.Value    = 2

$btnCancel               = New-Object System.Windows.Forms.Button
$btnCancel.Text          = "Cancel"
$btnCancel.Size          = New-Object System.Drawing.Size(88, 28)
$btnCancel.Location      = New-Object System.Drawing.Point(184, 106)
$btnCancel.DialogResult  = [System.Windows.Forms.DialogResult]::Cancel

$btnPlay               = New-Object System.Windows.Forms.Button
$btnPlay.Text          = "Play"
$btnPlay.Size          = New-Object System.Drawing.Size(72, 28)
$btnPlay.Location      = New-Object System.Drawing.Point(280, 106)
$btnPlay.DialogResult  = [System.Windows.Forms.DialogResult]::OK

$form.AcceptButton = $btnPlay
$form.CancelButton = $btnCancel
$form.Controls.AddRange(@($lblUrl, $txtUrl, $lblMon, $numMon, $btnCancel, $btnPlay))

$form.Add_Shown({ $txtUrl.Focus() })

if ($form.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { exit 0 }

$url = $txtUrl.Text.Trim()
if ($url -eq "") {
    [System.Windows.Forms.MessageBox]::Show("Please enter a YouTube URL.", "MultiMonitor-yt-sync", "OK", "Warning") | Out-Null
    exit 1
}

& "$PSScriptRoot\MultiMonitor-yt-sync.ps1" -Url $url -Monitors ([int]$numMon.Value)
