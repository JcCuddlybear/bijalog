# bijalog_setup.ps1 - the setup window for Bijalog on Windows.
# Launched by bijalog_setup.bat. If this cannot run (locked-down machine,
# PowerShell blocked by policy) the .bat falls back to its text-mode setup
# and nobody gets stuck. ASCII only on purpose: PowerShell 5.1 reads .ps1
# files as ANSI when there is no BOM, and stray Unicode turns to mojibake.

$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path

# Tell the .bat we got this far, so it does not also run text mode.
$flag = Join-Path $env:TEMP "bijalog_gui.flag"
Set-Content -Path $flag -Value "1" -Encoding ASCII

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# ---------------------------------------------------------------- helpers

function Find-Python {
    # Returns a hashtable with Path and Version, or $null.
    foreach ($name in @("python", "py")) {
        $cmd = Get-Command $name -ErrorAction SilentlyContinue
        if (-not $cmd) { continue }
        # Skip the Microsoft Store stub: it is named python.exe but only
        # opens the Store, and reports no version. A classic dead end.
        if ($cmd.Source -like "*\WindowsApps\*") { continue }
        try {
            $out = & $cmd.Source --version 2>&1
            if ("$out" -match "Python 3") {
                return @{ Path = $cmd.Source; Version = ("$out").Trim() }
            }
        } catch { }
    }
    # Last resort, mirroring bijalog.bat: Blender ships a working Python.
    $bl = "C:\Program Files\Blender Foundation\Blender 5.0\5.0\python\bin\python.exe"
    if (Test-Path $bl) {
        try {
            $out = & $bl --version 2>&1
            if ("$out" -match "Python 3") {
                return @{ Path = $bl; Version = ("$out").Trim() + " (bundled with Blender)" }
            }
        } catch { }
    }
    return $null
}

function Have-Winget {
    $c = Get-Command winget -ErrorAction SilentlyContinue
    return ($null -ne $c)
}

function Run-SelfTest($pythonPath) {
    # The same eight checks as test_bijalog.bat, run silently in a scratch
    # folder. Returns a hashtable: Passed, Failed, Lines.
    $scratch = Join-Path $env:TEMP ("bijalog_selftest_" + (Get-Random))
    $root = Join-Path $scratch "projects"
    New-Item -ItemType Directory -Force -Path $root | Out-Null
    $bj = Join-Path $here "bijalog.py"
    $script:pass = 0
    $script:fail = 0
    $script:lines = @()
    $old = $env:BIJALOG_APPROVER
    $env:BIJALOG_APPROVER = "selftest"

    function Bij($argList) {
        return (& $pythonPath $bj --root $root @argList 2>&1 | Out-String)
    }
    function Check($label, $ok) {
        if ($ok) { $script:pass++; $script:lines += "  PASS  $label" }
        else     { $script:fail++; $script:lines += "  FAIL  $label" }
    }

    try {
        $o = Bij @("add", "my-story", "The main character is called Alex.", "--topic", "characters")
        Check "writes a PROPOSED line" ($o -match "\[PROPOSED\]")

        $o = Bij @("add", "my-story", "Alex lives in Hastings.", "--topic", "setting", "--approved")
        Check "writes an ACTIVE line, stamped with your name" ($o -match "approved-by:selftest")

        $v1 = Join-Path $root "my-story/log/my-story_v001.txt"
        $v2 = Join-Path $root "my-story/log/my-story_v002.txt"
        Check "keeps every version, overwrites nothing" ((Test-Path $v1) -and (Test-Path $v2))

        $lineId = ""
        if (Test-Path $v2) {
            foreach ($l in (Get-Content $v2)) {
                if ($l -match "PROPOSED") { $lineId = ($l -split "\|")[1].Trim(); break }
            }
        }
        Check "can read the id of a proposed line back" ($lineId.Length -eq 26)

        $o = Bij @("approve", "my-story", $lineId)
        Check "turns a PROPOSED line into ACTIVE" ($o -match "approved")

        $o = Bij @("verify")
        Check "verify reports the decks are intact" ($o -match "(?m)^OK:")

        $o = Bij @("state", "my-story")
        Check "state shows what is true right now" (($o -match "\[characters\]") -and ($o -match "\[setting\]"))

        $v3 = Join-Path $root "my-story/log/my-story_v003.txt"
        $sup = $false
        if ((Test-Path $v3) -and $lineId) {
            $sup = (Select-String -Path $v3 -SimpleMatch ("supersedes:" + $lineId) -Quiet) -eq $true
        }
        Check "the new line supersedes the old one, which stays" $sup
    } catch {
        $script:fail++
        $script:lines += ("  FAIL  unexpected error: " + $_.Exception.Message)
    } finally {
        $env:BIJALOG_APPROVER = $old
        try { Remove-Item -Recurse -Force $scratch -ErrorAction SilentlyContinue } catch { }
    }
    return @{ Passed = $script:pass; Failed = $script:fail; Lines = $script:lines }
}

# ---------------------------------------------------------------- the form

$form                = New-Object System.Windows.Forms.Form
$form.Text           = "Bijalog Setup"
$form.Size           = New-Object System.Drawing.Size(600, 560)
$form.StartPosition  = "CenterScreen"
$form.FormBorderStyle= "FixedDialog"
$form.MaximizeBox    = $false
$form.Font           = New-Object System.Drawing.Font("Segoe UI", 9)
$form.BackColor      = [System.Drawing.Color]::White

function Add-Label($text, $x, $y, $w, $h, $bold, $size, $colour) {
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $text
    $l.Location = New-Object System.Drawing.Point($x, $y)
    $l.Size = New-Object System.Drawing.Size($w, $h)
    $style = [System.Drawing.FontStyle]::Regular
    if ($bold) { $style = [System.Drawing.FontStyle]::Bold }
    $l.Font = New-Object System.Drawing.Font("Segoe UI", $size, $style)
    if ($colour) { $l.ForeColor = $colour }
    $form.Controls.Add($l)
    return $l
}

$grey  = [System.Drawing.Color]::FromArgb(100, 100, 100)
$green = [System.Drawing.Color]::FromArgb(0, 130, 60)
$red   = [System.Drawing.Color]::FromArgb(190, 40, 40)

Add-Label "Bijalog Setup" 24 20 400 32 $true 16 $null | Out-Null
Add-Label "Three things, then you are done. No typing of commands." 26 52 520 20 $false 9 $grey | Out-Null

# --- 1. Python
Add-Label "1.  Python" 24 96 200 20 $true 10 $null | Out-Null
$lblPy = Add-Label "checking..." 44 118 400 20 $false 9 $grey
$btnPy = New-Object System.Windows.Forms.Button
$btnPy.Text = "Install Python"
$btnPy.Location = New-Object System.Drawing.Point(430, 112)
$btnPy.Size = New-Object System.Drawing.Size(130, 30)
$btnPy.Visible = $false
$form.Controls.Add($btnPy)

# --- 2. Folder
Add-Label "2.  Where your Bijalog files should live" 24 160 420 20 $true 10 $null | Out-Null
$txtDir = New-Object System.Windows.Forms.TextBox
$txtDir.Location = New-Object System.Drawing.Point(44, 184)
$txtDir.Size = New-Object System.Drawing.Size(376, 24)
$txtDir.Text = (Join-Path ([Environment]::GetFolderPath("MyDocuments")) "Bijalog")
$form.Controls.Add($txtDir)
$btnDir = New-Object System.Windows.Forms.Button
$btnDir.Text = "Browse..."
$btnDir.Location = New-Object System.Drawing.Point(430, 182)
$btnDir.Size = New-Object System.Drawing.Size(130, 28)
$form.Controls.Add($btnDir)

# --- 3. Name
Add-Label "3.  Your name" 24 226 420 20 $true 10 $null | Out-Null
Add-Label "Goes on every decision you approve, so you can tell them apart later." 44 248 500 18 $false 8 $grey | Out-Null
$txtName = New-Object System.Windows.Forms.TextBox
$txtName.Location = New-Object System.Drawing.Point(44, 270)
$txtName.Size = New-Object System.Drawing.Size(376, 24)
if ($env:BIJALOG_APPROVER) { $txtName.Text = $env:BIJALOG_APPROVER }
elseif ($env:USERNAME)     { $txtName.Text = $env:USERNAME }
$form.Controls.Add($txtName)

# --- go
$btnGo = New-Object System.Windows.Forms.Button
$btnGo.Text = "Set up Bijalog"
$btnGo.Location = New-Object System.Drawing.Point(44, 314)
$btnGo.Size = New-Object System.Drawing.Size(516, 40)
$btnGo.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($btnGo)

# --- results
$txtLog = New-Object System.Windows.Forms.TextBox
$txtLog.Location = New-Object System.Drawing.Point(44, 366)
$txtLog.Size = New-Object System.Drawing.Size(516, 108)
$txtLog.Multiline = $true
$txtLog.ReadOnly = $true
$txtLog.ScrollBars = "Vertical"
$txtLog.BackColor = [System.Drawing.Color]::FromArgb(248, 248, 248)
$txtLog.Font = New-Object System.Drawing.Font("Consolas", 9)
$form.Controls.Add($txtLog)

$btnOpen = New-Object System.Windows.Forms.Button
$btnOpen.Text = "Show me the folder"
$btnOpen.Location = New-Object System.Drawing.Point(44, 484)
$btnOpen.Size = New-Object System.Drawing.Size(180, 30)
$btnOpen.Enabled = $false
$form.Controls.Add($btnOpen)

$btnClose = New-Object System.Windows.Forms.Button
$btnClose.Text = "Close"
$btnClose.Location = New-Object System.Drawing.Point(460, 484)
$btnClose.Size = New-Object System.Drawing.Size(100, 30)
$form.Controls.Add($btnClose)

function Log($line) {
    $txtLog.AppendText($line + "`r`n")
}

# ---------------------------------------------------------------- wiring

$script:python = $null

function Refresh-Python {
    $script:python = Find-Python
    if ($script:python) {
        $lblPy.Text = "Found " + $script:python.Version
        $lblPy.ForeColor = $green
        $btnPy.Visible = $false
        $btnGo.Enabled = $true
    } else {
        $lblPy.Text = "Not found - Bijalog needs it. Click Install Python."
        $lblPy.ForeColor = $red
        $btnPy.Visible = $true
        $btnGo.Enabled = $false
    }
}

$btnPy.Add_Click({
    if (Have-Winget) {
        $btnPy.Enabled = $false
        $lblPy.Text = "Installing Python, this takes a minute..."
        $lblPy.ForeColor = $grey
        $form.Refresh()
        Log "Installing Python via the Windows package manager..."
        try {
            $p = Start-Process -FilePath "winget" -ArgumentList @(
                "install", "--id", "Python.Python.3.12", "-e",
                "--accept-package-agreements", "--accept-source-agreements"
            ) -Wait -PassThru -WindowStyle Hidden
            Log ("winget finished (code " + $p.ExitCode + ")")
        } catch {
            Log "The package manager could not run. Opening python.org instead."
            Start-Process "https://www.python.org/downloads/"
        }
        # A fresh install is not on this process's PATH yet; look again in
        # the places the installer actually puts it.
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                    [System.Environment]::GetEnvironmentVariable("Path", "User")
        $btnPy.Enabled = $true
        Refresh-Python
        if (-not $script:python) {
            Log "Still not visible. Close this window and run bijalog_setup.bat again."
        }
    } else {
        Log "Opening python.org."
        Log "IMPORTANT: tick 'Add python.exe to PATH' on the first screen of"
        Log "the installer, or Bijalog will not find it afterwards."
        Start-Process "https://www.python.org/downloads/"
        [System.Windows.Forms.MessageBox]::Show(
            "On the first screen of the Python installer, tick" + [Environment]::NewLine +
            "'Add python.exe to PATH' before clicking Install." + [Environment]::NewLine + [Environment]::NewLine +
            "Then close this window and run bijalog_setup.bat again.",
            "One thing to watch for", "OK", "Information") | Out-Null
    }
})

$btnDir.Add_Click({
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    $dlg.Description = "Choose or create a folder for Bijalog"
    $dlg.ShowNewFolderButton = $true
    if ($dlg.ShowDialog() -eq "OK") { $txtDir.Text = $dlg.SelectedPath }
})

$script:madeDir = $null

$btnGo.Add_Click({
    $txtLog.Clear()
    $dir = $txtDir.Text.Trim()
    $name = $txtName.Text.Trim()
    if (-not $dir)  { Log "Fill in a folder first."; return }
    if (-not $name) { Log "Fill in your name first."; return }
    if (-not $script:python) { Log "Python is still missing."; return }

    $btnGo.Enabled = $false
    $form.Refresh()
    try {
        $projects = Join-Path $dir "projects"
        $inbox    = Join-Path $dir "inbox"
        New-Item -ItemType Directory -Force -Path $projects | Out-Null
        New-Item -ItemType Directory -Force -Path $inbox | Out-Null
        Log "Folders ready:"
        Log ("  " + $projects)
        Log ("  " + $inbox)

        [Environment]::SetEnvironmentVariable("BIJALOG_ROOT", $projects, "User")
        [Environment]::SetEnvironmentVariable("BIJALOG_APPROVER", $name, "User")
        Log ("Saved your settings. Approvals will be stamped: " + $name)

        # One "unknown publisher" prompt instead of one per file.
        try { Get-ChildItem -Path $here -Recurse -File | Unblock-File -ErrorAction SilentlyContinue } catch { }

        Log ""
        Log "Checking it actually works..."
        $form.Refresh()
        $r = Run-SelfTest $script:python.Path
        foreach ($l in $r.Lines) { Log $l }
        Log ""
        if ($r.Failed -eq 0) {
            Log ("All " + $r.Passed + " checks passed. Bijalog is ready.")
        } else {
            Log ($r.Failed.ToString() + " check(s) failed, " + $r.Passed + " passed.")
            Log "Copy this box and send it to whoever gave you Bijalog."
        }
        $script:madeDir = $dir
        $btnOpen.Enabled = $true
    } catch {
        Log ("Setup stopped: " + $_.Exception.Message)
    }
    $btnGo.Enabled = $true
})

$btnOpen.Add_Click({ if ($script:madeDir) { Start-Process "explorer.exe" $script:madeDir } })
$btnClose.Add_Click({ $form.Close() })

Refresh-Python
if ($script:python) { Log "Ready. Check the folder and name above, then click Set up Bijalog." }
else { Log "Python is missing. Click Install Python above, then come back here." }

[void]$form.ShowDialog()
exit 0
