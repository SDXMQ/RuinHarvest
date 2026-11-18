$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Invoke-RuinHarvestInstall {
    $appName = 'RuinHarvest'
    $repo = 'SDXMQ/RuinHarvest'
    $exeName = 'RuinHarvest.exe'
    $installDir = Join-Path $env:LOCALAPPDATA 'Programs\RuinHarvest'
    $startMenuDir = [Environment]::GetFolderPath('Programs')
    $startMenuShortcut = Join-Path $startMenuDir "$appName.lnk"
    $desktopDir = [Environment]::GetFolderPath('Desktop')
    $desktopShortcut = Join-Path $desktopDir "$appName.lnk"
    $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\$appName"

    $programFilesRoot = if ($env:ProgramW6432) { $env:ProgramW6432 } else { $env:ProgramFiles }
    $legacyDir = Join-Path $programFilesRoot $appName
    if (Test-Path -LiteralPath $legacyDir) {
        Write-Host "[NOTE] Legacy installation detected at '$legacyDir'." -ForegroundColor Yellow
        Write-Host "       You can remove it via Windows Installed Apps or '$legacyDir\uninstall.ps1'." -ForegroundColor Yellow
    }

    $running = Get-Process -Name 'RuinHarvest' -ErrorAction SilentlyContinue
    if ($running) {
        throw 'RuinHarvest is currently running. Please close the game and try again.'
    }

    Write-Host "[1/5] Checking latest GitHub release for $repo..." -ForegroundColor Cyan
    $headers = @{
        'User-Agent' = 'RuinHarvest-Installer'
        'Accept'     = 'application/vnd.github+json'
    }

    $release = $null
    $latestUrl = "https://api.github.com/repos/$repo/releases/latest"

    try {
        $release = Invoke-RestMethod -Uri $latestUrl -Headers $headers
    } catch {
        $statusCode = $null
        if ($_.Exception.Response -and $_.Exception.Response.StatusCode) {
            $statusCode = [int]$_.Exception.Response.StatusCode
        }
        if ($statusCode -ne 404) {
            throw "Failed to query GitHub Releases: $($_.Exception.Message)"
        }
    }

    if (-not $release) {
        try {
            $allReleases = @(Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases?per_page=10" -Headers $headers)
            $release = $allReleases | Where-Object { -not $_.draft } | Select-Object -First 1
        } catch {
            $statusCode = $null
            if ($_.Exception.Response -and $_.Exception.Response.StatusCode) {
                $statusCode = [int]$_.Exception.Response.StatusCode
            }
            if ($statusCode -eq 404) {
                throw "Repository or releases not accessible at https://github.com/$repo/releases (check that the repository is public)."
            }
            throw "Failed to query GitHub Releases: $($_.Exception.Message)"
        }
    }

    if (-not $release) {
        throw "No GitHub Release found at https://github.com/$repo/releases. Publish a release with $exeName (or a Windows .zip) first."
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

    $version = if ($release.tag_name) { (($release.tag_name -replace '^v', '') -replace '-.*$', '') } else { '1.0.0' }
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

        $rawTag = if ($release.tag_name) { [string]$release.tag_name } else { "v$version" }
        $versionMeta = [ordered]@{
            tag_name   = $rawTag
            version    = $version
            asset_name = [string]$selectedAsset.name
        } | ConvertTo-Json
        Set-Content -LiteralPath (Join-Path $installDir 'version.json') -Value $versionMeta -Encoding UTF8

        $uninstallerPath = Join-Path $installDir 'uninstall.ps1'
        $uninstallTemplate = @'
param(
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'

$appName = 'RuinHarvest'
$installDir = '__INSTALL_DIR__'
$exePath = Join-Path $installDir 'RuinHarvest.exe'
$versionPath = Join-Path $installDir 'version.json'
$startMenuShortcut = '__START_MENU_SHORTCUT__'
$desktopShortcut = '__DESKTOP_SHORTCUT__'
$regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\$appName"

if (Get-Process -Name 'RuinHarvest' -ErrorAction SilentlyContinue) {
    Write-Host 'RuinHarvest is currently running. Please close it first.' -ForegroundColor Red
    if (-not $Quiet) { Read-Host 'Press Enter to exit' }
    exit 1
}

if (Test-Path -LiteralPath $startMenuShortcut) { Remove-Item -LiteralPath $startMenuShortcut -Force }
if (Test-Path -LiteralPath $desktopShortcut) { Remove-Item -LiteralPath $desktopShortcut -Force }
if (Test-Path -LiteralPath $regPath) { Remove-Item -Path $regPath -Recurse -Force }
if (Test-Path -LiteralPath $versionPath) { Remove-Item -LiteralPath $versionPath -Force }
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
    }
}

Invoke-RuinHarvestInstall
