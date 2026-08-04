#Requires -Version 5.1
#Requires -RunAsAdministrator:$false
# ========================================
#  FTP Phone Photo Backup Tool v1.2
#  https://github.com/zeesparkbenson/FTP-Phone-Photo-Backup
# ========================================

# --- Default Configuration (edit these or create config.json) ---
$defaultFtp   = 'ftp://192.168.1.243:3721/DCIM/Camera/'
$defaultBase  = 'D:\手机相册\2025-0221-20260316'
$defaultConfig = Join-Path $PSScriptRoot 'config.json'

# --- Load config.json if exists ---
if (Test-Path -LiteralPath $defaultConfig) {
    try {
        $config = Get-Content -LiteralPath $defaultConfig -Raw | ConvertFrom-Json
        if ($config.ftpUrl)   { $defaultFtp = $config.ftpUrl }
        if ($config.baseDir)  { $defaultBase = $config.baseDir }
    } catch {}
}

$baseDir      = $defaultBase
$failedListFile = Join-Path $baseDir '_failed_list.txt'

$photoExts   = @('.jpg','.jpeg','.png','.heic','.heif','.gif','.bmp','.webp','.raw','.dng','.cr2','.nef')
$videoExts   = @('.mp4','.mov','.avi','.3gp','.mkv','.flv','.wmv','.m4v','.mts','.ts')
$allExts     = $photoExts + $videoExts

# --- Utility Functions ---
function Write-ColorLine($text, $color = 'White') {
    Write-Host $text -ForegroundColor $color
}

function Get-YearMonth($fileName) {
    foreach ($pattern in @('(\d{4})(\d{2})(\d{2})', '(\d{4})[-_]?(\d{2})[-_]?(\d{2})')) {
        if ($fileName -match $pattern) {
            $year  = $matches[1]
            $month = $matches[2]
            if (($year -eq '2024' -or $year -eq '2025' -or $year -eq '2026') -and $month -ge '01' -and $month -le '12') {
                return ($year + $month)
            }
        }
    }
    return 'Unknown'
}

# --- Ensure target directory exists ---
if (!(Test-Path -LiteralPath $baseDir)) {
    New-Item -ItemType Directory -Path $baseDir -Force | Out-Null
}

# --- Load previous failed list (priority queue) ---
$priorityFiles = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
if (Test-Path -LiteralPath $failedListFile) {
    Get-Content -LiteralPath $failedListFile | ForEach-Object {
        $trimmed = $_.Trim()
        if ($trimmed) { $priorityFiles.Add($trimmed) | Out-Null }
    }
}
$priorityCount = $priorityFiles.Count

# --- Print header ---
Write-ColorLine '========================================' 'Cyan'
Write-ColorLine '      Phone Album Auto Backup Tool v1.2'       'Cyan'
Write-ColorLine '========================================' 'Cyan'
Write-ColorLine ''

# --- Interactive FTP address prompt ---
Write-ColorLine "Default FTP: $defaultFtp" 'Yellow'
Write-ColorLine 'Press Enter to use default,' 'White'
Write-ColorLine 'or type a new FTP URL and press Enter.' 'White'
$userInput = Read-Host 'FTP address'

if ([string]::IsNullOrWhiteSpace($userInput)) {
    $ftpServer = $defaultFtp
} else {
    $ftpServer = $userInput.Trim()
}

if (!$ftpServer.EndsWith('/')) {
    $ftpServer = $ftpServer + '/'
}

Write-ColorLine ''
Write-ColorLine "FTP Source : $ftpServer"              'Yellow'
Write-ColorLine "Backup Target : $baseDir"                  'Yellow'
if ($priorityCount -gt 0) {
    Write-ColorLine "Priority queue : $priorityCount files from last run" 'Magenta'
}
Write-ColorLine ''
Write-ColorLine 'Connecting to FTP server...'               'Green'

# --- Get FTP file list ---
try {
    $ftpReq = [System.Net.FtpWebRequest]::Create($ftpServer)
    $ftpReq.Method       = [System.Net.WebRequestMethods+Ftp]::ListDirectoryDetails
    $ftpReq.Credentials  = New-Object System.Net.NetworkCredential('anonymous','anonymous')
    $ftpReq.UsePassive   = $true
    $ftpReq.UseBinary    = $true
    $ftpReq.KeepAlive    = $true
    $ftpReq.Timeout      = 300000
    $ftpReq.ReadWriteTimeout = 300000

    $resp   = $ftpReq.GetResponse()
    $stream = $resp.GetResponseStream()
    $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::UTF8)

    $lines = @()
    while ($null -ne ($line = $reader.ReadLine())) {
        $lines += $line
    }

    $reader.Close()
    $stream.Close()
    $resp.Close()

} catch {
    Write-ColorLine ''
    Write-ColorLine '[Error] FTP connection failed!' 'Red'
    Write-ColorLine "Reason: $_" 'Red'
    Write-ColorLine ''
    Write-ColorLine 'Please check:' 'Yellow'
    Write-ColorLine '  1. Phone and PC on same WiFi' 'Yellow'
    Write-ColorLine '  2. Phone FTP service is running' 'Yellow'
    Write-ColorLine '  3. IP address is correct' 'Yellow'
    Write-ColorLine ''
    Read-Host 'Press any key to exit'
    exit 1
}

# --- Parse filenames ---
$allFiles = [System.Collections.Generic.List[string]]::new()
foreach ($line in $lines) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    $trimmed = $line.Trim()
    if ($trimmed.StartsWith('d') -or $trimmed.StartsWith('-')) {
        $parts = $trimmed -split '\s+'
        if ($parts.Count -ge 9) {
            $fileName = $parts[-1]
            if ($fileName -ne '.' -and $fileName -ne '..') {
                $allFiles.Add($fileName)
            }
        }
    } elseif ($trimmed -match '^\d{2}-\d{2}-\d{2}\s+\d{2}:\d{2}(AM|PM)?\s+(&lt;DIR&gt;|\d+)\s+(.+)$') {
        $fileName = $matches[3]
        if ($fileName -ne '.' -and $fileName -ne '..') {
            $allFiles.Add($fileName)
        }
    } else {
        $parts = $trimmed -split '\s+'
        if ($parts.Count -gt 0) {
            $fileName = $parts[-1]
            if ($fileName -ne '.' -and $fileName -ne '..') {
                $allFiles.Add($fileName)
            }
        }
    }
}

# --- Filter and sort (priority first) ---
$mediaFiles = [System.Collections.Generic.List[string]]::new()
foreach ($f in $allFiles) {
    $ext = [System.IO.Path]::GetExtension($f).ToLower()
    if ($allExts -contains $ext) { $mediaFiles.Add($f) }
}

$sortedFiles = [System.Collections.Generic.List[string]]::new()
foreach ($f in $mediaFiles) {
    if ($priorityFiles.Contains($f)) { $sortedFiles.Add($f) }
}
foreach ($f in $mediaFiles) {
    if (!$priorityFiles.Contains($f)) { $sortedFiles.Add($f) }
}

$totalMedia = $sortedFiles.Count

Write-ColorLine "Total FTP files: $($allFiles.Count)" 'White'
Write-ColorLine "Media files : $totalMedia" 'White'
Write-ColorLine ''
Write-ColorLine 'Starting backup (adaptive throttle)...' 'Green'
Write-ColorLine '  - Full speed when healthy' 'DarkGray'
Write-ColorLine '  - Auto-slowdown if failures detected' 'DarkGray'
Write-ColorLine ''

# --- Statistics ---
$downloaded       = 0
$skipped          = 0
$failed           = 0
$failedList       = [System.Collections.Generic.List[string]]::new()
$current          = 0
$consecutiveFails = 0
$consecutiveOKs   = 0
$throttleMode     = $false

foreach ($fileName in $sortedFiles) {
    $current++
    $yearMonth = Get-YearMonth -fileName $fileName

    $targetDir = Join-Path $baseDir $yearMonth
    if (!(Test-Path -LiteralPath $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }

    $targetFile = Join-Path $targetDir $fileName

    # Skip if already exists
    if (Test-Path -LiteralPath $targetFile) {
        $skipped++
        $priorityFiles.Remove($fileName) | Out-Null
        continue
    }

    # --- Adaptive throttle ---
    if ($throttleMode) {
        Start-Sleep -Milliseconds 300
    }

    # --- Download with retry (up to 3 times) ---
    $success = $false
    $fileUrl = $ftpServer + $fileName

    for ($retry = 0; $retry -lt 3; $retry++) {
        try {
            $dlReq = [System.Net.FtpWebRequest]::Create($fileUrl)
            $dlReq.Method      = [System.Net.WebRequestMethods+Ftp]::DownloadFile
            $dlReq.Credentials = New-Object System.Net.NetworkCredential('anonymous','anonymous')
            $dlReq.UsePassive  = $true
            $dlReq.UseBinary   = $true
            $dlReq.KeepAlive   = $true
            $dlReq.Timeout     = 300000
            $dlReq.ReadWriteTimeout = 300000

            $dlResp   = $dlReq.GetResponse()
            $expectedSize = $dlResp.ContentLength
            $dlStream = $dlResp.GetResponseStream()
            $fs       = [System.IO.File]::Create($targetFile)

            $buffer = New-Object byte[] 8192
            $read = 0
            while (($read = $dlStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
                $fs.Write($buffer, 0, $read)
            }

            $fs.Close()
            $dlStream.Close()
            $dlResp.Close()

            # --- Size validation ---
            if ($expectedSize -gt 0) {
                $localSize = (Get-Item -LiteralPath $targetFile).Length
                if ($localSize -ne $expectedSize) {
                    Remove-Item -LiteralPath $targetFile -Force -ErrorAction SilentlyContinue
                    if ($retry -lt 2) {
                        Write-ColorLine "  [$current/$totalMedia] Size mismatch, retrying..." 'Yellow'
                        Start-Sleep -Milliseconds 1500
                        continue
                    } else {
                        throw "Size mismatch after retries"
                    }
                }
            }

            $success = $true
            break

        } catch {
            if (Test-Path -LiteralPath $targetFile) {
                Remove-Item -LiteralPath $targetFile -Force -ErrorAction SilentlyContinue
            }
            if ($retry -lt 2) {
                Start-Sleep -Milliseconds 1500
            }
        }
    }

    if ($success) {
        $downloaded++
        $consecutiveFails = 0
        $consecutiveOKs++
        $priorityFiles.Remove($fileName) | Out-Null
        Write-ColorLine "  [$current/$totalMedia] OK: $fileName -> $yearMonth\" 'Green'

        # Exit throttle mode after 5 consecutive successes
        if ($consecutiveOKs -ge 5 -and $throttleMode) {
            $throttleMode = $false
            Write-ColorLine "  [i] Connection stable, resuming full speed..." 'DarkGray'
        }
    } else {
        $failed++
        $consecutiveFails++
        $consecutiveOKs = 0
        $failedList.Add($fileName)
        Write-ColorLine "  [$current/$totalMedia] Failed: $fileName" 'Red'

        # Enable throttle after 2 consecutive failures
        if ($consecutiveFails -ge 2 -and !$throttleMode) {
            $throttleMode = $true
            Write-ColorLine "  [!] Failures detected, enabling adaptive slowdown..." 'Magenta'
        }

        # Hard cooldown after 5 consecutive failures
        if ($consecutiveFails -ge 5) {
            Write-ColorLine "  [!] 5 consecutive failures, cooling down 10s..." 'Magenta'
            Start-Sleep -Seconds 10
            $consecutiveFails = 0
        }
    }
}

# --- Save failed list for next run ---
if ($failedList.Count -gt 0) {
    $failedList | Set-Content -LiteralPath $failedListFile -Encoding UTF8
    Write-ColorLine ''
    Write-ColorLine "Failed list saved to: $failedListFile" 'Yellow'
    Write-ColorLine "These files will be retried first next run." 'Yellow'
} else {
    if (Test-Path -LiteralPath $failedListFile) {
        Remove-Item -LiteralPath $failedListFile -Force -ErrorAction SilentlyContinue
    }
}

# --- Summary ---
Write-ColorLine ''
Write-ColorLine '========================================' 'Cyan'
Write-ColorLine '         Backup Complete!' 'Cyan'
Write-ColorLine '========================================' 'Cyan'
Write-ColorLine "Media files processed : $current" 'White'
Write-ColorLine "Successfully downloaded: $downloaded" 'Green'
Write-ColorLine "Skipped (existing) : $skipped" 'Yellow'
Write-ColorLine "Download failed : $failed" 'Red'
Write-ColorLine ''
Read-Host 'Press any key to close'
