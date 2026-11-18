$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Invoke-RuinHarvestInstall {
    param(
        [string]$DesktopPath = '',
        [string]$TempScriptPath = ''
    )

    $appName = 'RuinHarvest'
    $repo = 'SDXMQ/RuinHarvest'
    $exeName = 'RuinHarvest.exe'
    $programFilesRoot = if ($env:ProgramW6432) { $env:ProgramW6432 } else { $env:ProgramFiles }
    $installDir = Join-Path $programFilesRoot $appName
    $startMenuDir = [Environment]::GetFolderPath('CommonPrograms')
    $startMenuShortcut = Join-Path $startMenuDir "$appName.lnk"
    if ([string]::IsNullOrWhiteSpace($DesktopPath)) {
        $DesktopPath = [Environment]::GetFolderPath('CommonDesktopDirectory')
    }
    $desktopShortcut = Join-Path $DesktopPath "$appName.lnk"
    $regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$appName"

    $running = Get-Process -Name 'RuinHarvest' -ErrorAction SilentlyContinue
    if ($running) {
        throw 'RuinHarvest is currently running. Please close the game and try again.'
    }

    Write-Host "[1/5] Checking latest GitHub release for $repo..." -ForegroundColor Cyan
    $headers = @{
        'User-Agent' = 'RuinHarvest-Installer'
        'Accept'     = 'application/vnd.github+json'
    }
    $releaseUrl = "https://api.github.com/repos/$repo/releases/latest"

    try {
        $release = Invoke-RestMethod -Uri $releaseUrl -Headers $headers
    } catch {
        $statusCode = $null
        if ($_.Exception.Response -and $_.Exception.Response.StatusCode) {
            $statusCode = [int]$_.Exception.Response.StatusCode
        }
        if ($statusCode -eq 404) {
            throw "No GitHub Release found at https://github.com/$repo/releases. Publish a release with $exeName (or a Windows .zip) first."
        }
        throw "Failed to query GitHub Releases: $($_.Exception.Message)"
    }

    $assets = @($release.assets)
    $exeAsset = $assets | Where-Object { $_.name -ieq $exeName } | Select-Object -First 1
    if (-not $exeAsset) {
        $exeAsset = $assets | Where-Object { $_.name -match '\.exe$' -and $_.name -notmatch 'console|debug' } | Select-Object -First 1
    }
    $zipAsset = $null
    if (-not $exeAsset) {
        $zipAsset = $assets | Where-Object { $_.name -match '\.zip$' -and $_.name -match 'win|windows|ruinharvest' -and $_.name -notmatch 'mac|darwin|linux' } | Select-Object -First 1
        if (-not $zipAsset) {
            $zipAsset = $assets | Where-Object { $_.name -match '\.zip$' -and $_.name -notmatch 'mac|darwin|linux' } | Select-Object -First 1
        }
    }

    $selectedAsset = if ($exeAsset) { $exeAsset } else { $zipAsset }
    if (-not $selectedAsset) {
        throw "No Windows release asset (.exe or .zip) found in release '$($release.tag_name)'."
    }

    $version = if ($release.tag_name) { ($release.tag_name -replace '^v', '') } else { '1.0.0' }
    if ($version -notmatch '^\d+(\.\d+)*$') {
        $version = '1.0.0'
    }

    $stagingDir = Join-Path $env:TEMP ("ruinharvest-stage-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $stagingDir -Force | Out-Null

    try {
        $downloadPath = Join-Path $stagingDir $selectedAsset.name
        Write-Host "[2/5] Downloading $($selectedAsset.name) ($($release.tag_name))..." -ForegroundColor Cyan
        Invoke-WebRequest -Uri $selectedAsset.browser_download_url -OutFile $downloadPath -Headers @{ 'User-Agent' = 'RuinHarvest-Installer' }

        Write-Host "[3/5] Installing to $installDir..." -ForegroundColor Cyan
        New-Item -ItemType Directory -Path $installDir -Force | Out-Null

        if ($selectedAsset.name -match '\.zip$') {
            $extractDir = Join-Path $stagingDir 'extracted'
            Expand-Archive -Path $downloadPath -DestinationPath $extractDir -Force
            $foundExe = Get-ChildItem -Path $extractDir -Filter '*.exe' -Recurse | Where-Object { $_.Name -notmatch 'console' } | Select-Object -First 1
            if (-not $foundExe) {
                throw "Downloaded archive '$($selectedAsset.name)' does not contain an .exe file."
            }
            $sourceRoot = $foundExe.Directory.FullName
            Copy-Item -Path (Join-Path $sourceRoot '*') -Destination $installDir -Recurse -Force
            if ($foundExe.Name -ine $exeName) {
                Copy-Item -Path (Join-Path $installDir $foundExe.Name) -Destination (Join-Path $installDir $exeName) -Force
            }
        } else {
            Copy-Item -Path $downloadPath -Destination (Join-Path $installDir $exeName) -Force
        }

        $installedExe = Join-Path $installDir $exeName
        if (-not (Test-Path -LiteralPath $installedExe)) {
            throw "Installation failed: $installedExe was not found after copying."
        }

        $uninstallerPath = Join-Path $installDir 'uninstall.ps1'
        $uninstallTemplate = @'
param(
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    $psExe = (Get-Process -Id $PID).Path
    $argString = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    if ($Quiet) { $argString += ' -Quiet' }
    try {
        $proc = Start-Process -FilePath $psExe -Verb RunAs -Wait -PassThru -ArgumentList $argString
        exit $proc.ExitCode
    } catch {
        exit 1
    }
}

$appName = 'RuinHarvest'
$installDir = '__INSTALL_DIR__'
$exePath = Join-Path $installDir 'RuinHarvest.exe'
$startMenuShortcut = '__START_MENU_SHORTCUT__'
$desktopShortcut = '__DESKTOP_SHORTCUT__'
$commonDesktopShortcut = Join-Path ([Environment]::GetFolderPath('CommonDesktopDirectory')) "$appName.lnk"
$regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$appName"

if (Get-Process -Name 'RuinHarvest' -ErrorAction SilentlyContinue) {
    Write-Host 'RuinHarvest is currently running. Please close it first.' -ForegroundColor Red
    if (-not $Quiet) { Read-Host 'Press Enter to exit' }
    exit 1
}

if (Test-Path -LiteralPath $startMenuShortcut) { Remove-Item -LiteralPath $startMenuShortcut -Force }
if (Test-Path -LiteralPath $desktopShortcut) { Remove-Item -LiteralPath $desktopShortcut -Force }
if (Test-Path -LiteralPath $commonDesktopShortcut) { Remove-Item -LiteralPath $commonDesktopShortcut -Force }
if (Test-Path -LiteralPath $regPath) { Remove-Item -Path $regPath -Recurse -Force }
if (Test-Path -LiteralPath $exePath) { Remove-Item -LiteralPath $exePath -Force }

Write-Host 'RuinHarvest has been uninstalled. (Save data in %APPDATA%\Godot\app_userdata\RuinHarvest was preserved.)' -ForegroundColor Green
if (-not $Quiet) { Read-Host 'Press Enter to close' }

Set-Location -LiteralPath $env:TEMP
if (Test-Path -LiteralPath $installDir) {
    Start-Process -FilePath 'cmd.exe' -WindowStyle Hidden -ArgumentList "/c ping -n 2 127.0.0.1 >nul & rmdir /s /q `"$installDir`""
}
'@
        $uninstallContent = $uninstallTemplate.
            Replace('__INSTALL_DIR__', $installDir.Replace("'", "''")).
            Replace('__START_MENU_SHORTCUT__', $startMenuShortcut.Replace("'", "''")).
            Replace('__DESKTOP_SHORTCUT__', $desktopShortcut.Replace("'", "''"))
        Set-Content -LiteralPath $uninstallerPath -Value $uninstallContent -Encoding UTF8

        Write-Host '[4/5] Creating Start Menu and Desktop shortcuts...' -ForegroundColor Cyan
        $wsh = New-Object -ComObject WScript.Shell
        foreach ($lnkPath in @($startMenuShortcut, $desktopShortcut)) {
            $lnkParent = Split-Path -Path $lnkPath -Parent
            if (-not (Test-Path -LiteralPath $lnkParent)) {
                New-Item -ItemType Directory -Path $lnkParent -Force | Out-Null
            }
            $sc = $wsh.CreateShortcut($lnkPath)
            $sc.TargetPath = $installedExe
            $sc.WorkingDirectory = $installDir
            $sc.IconLocation = "$installedExe,0"
            $sc.Description = 'RuinHarvest - Hardcore Singleplayer Extraction Shooter'
            $sc.Save()
        }

        Write-Host '[5/5] Registering in Windows Installed Apps...' -ForegroundColor Cyan
        $totalBytes = (Get-ChildItem -Path $installDir -Recurse -File | Measure-Object -Property Length -Sum).Sum
        $estimatedKb = [int][Math]::Max(1, [Math]::Ceiling($totalBytes / 1024))

        New-Item -Path $regPath -Force | Out-Null
        Set-ItemProperty -Path $regPath -Name 'DisplayName' -Value $appName
        Set-ItemProperty -Path $regPath -Name 'DisplayVersion' -Value $version
        Set-ItemProperty -Path $regPath -Name 'Publisher' -Value 'SDXMQ'
        Set-ItemProperty -Path $regPath -Name 'InstallLocation' -Value $installDir
        Set-ItemProperty -Path $regPath -Name 'DisplayIcon' -Value "$installedExe,0"
        Set-ItemProperty -Path $regPath -Name 'URLInfoAbout' -Value "https://github.com/$repo"
        Set-ItemProperty -Path $regPath -Name 'UninstallString' -Value "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$uninstallerPath`""
        Set-ItemProperty -Path $regPath -Name 'QuietUninstallString' -Value "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$uninstallerPath`" -Quiet"
        Set-ItemProperty -Path $regPath -Name 'NoModify' -Value 1 -Type DWord
        Set-ItemProperty -Path $regPath -Name 'NoRepair' -Value 1 -Type DWord
        Set-ItemProperty -Path $regPath -Name 'EstimatedSize' -Value $estimatedKb -Type DWord

        Write-Host ""
        Write-Host "RuinHarvest ($($release.tag_name)) installed successfully to:" -ForegroundColor Green
        Write-Host "  $installDir" -ForegroundColor White
    } finally {
        if (Test-Path -LiteralPath $stagingDir) {
            Remove-Item -LiteralPath $stagingDir -Recurse -Force -ErrorAction SilentlyContinue
        }
        if (-not [string]::IsNullOrWhiteSpace($TempScriptPath) -and (Test-Path -LiteralPath $TempScriptPath)) {
            Remove-Item -LiteralPath $TempScriptPath -Force -ErrorAction SilentlyContinue
        }
    }
}

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$callerDesktop = [Environment]::GetFolderPath('Desktop')

if (-not $isAdmin) {
    Write-Host 'Requesting Administrator permission (UAC) to install into C:\Program Files\RuinHarvest...' -ForegroundColor Yellow
    $tempScript = Join-Path $env:TEMP ("ruinharvest-install-" + [guid]::NewGuid().ToString('N') + '.ps1')
    $fnBody = (Get-Command Invoke-RuinHarvestInstall).Definition
    $escapedDesktop = $callerDesktop.Replace("'", "''")
    $escapedTemp = $tempScript.Replace("'", "''")

    $elevatedPayload = @"
`$ErrorActionPreference = 'Stop'
`$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Invoke-RuinHarvestInstall {
$fnBody
}

`$exitCode = 0
try {
    Invoke-RuinHarvestInstall -DesktopPath '$escapedDesktop' -TempScriptPath '$escapedTemp'
} catch {
    `$exitCode = 1
    Write-Host ''
    Write-Host "[ERROR] `$(`$_.Exception.Message)" -ForegroundColor Red
} finally {
    Write-Host ''
    Read-Host 'Press Enter to close this window'
}
exit `$exitCode
"@
    Set-Content -LiteralPath $tempScript -Value $elevatedPayload -Encoding UTF8

    try {
        $psExe = (Get-Process -Id $PID).Path
        $argString = "-NoProfile -ExecutionPolicy Bypass -File `"$tempScript`""
        $proc = Start-Process -FilePath $psExe -Verb RunAs -Wait -PassThru -ArgumentList $argString
        if ($proc.ExitCode -ne 0) {
            Write-Host "Installer exited with code $($proc.ExitCode)." -ForegroundColor Yellow
        }
    } catch {
        if (Test-Path -LiteralPath $tempScript) {
            Remove-Item -LiteralPath $tempScript -Force -ErrorAction SilentlyContinue
        }
        Write-Host "[ERROR] Administrator permission is required to install into C:\Program Files\RuinHarvest. ($($_.Exception.Message))" -ForegroundColor Red
    }
} else {
    Invoke-RuinHarvestInstall -DesktopPath $callerDesktop
}
