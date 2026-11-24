# res://systems/self_updater_helper.gd
extends RefCounted

## 부트 자체 업데이터 버전 메타데이터·에셋 선별·바이너리 검증·PowerShell 패치 스크립트 생성 헬퍼


static func load_local_version_info() -> Dictionary:
	var fallback_ver: String = String(ProjectSettings.get_setting("application/config/version", "1.0.0")).strip_edges()
	if fallback_ver == "":
		fallback_ver = "1.0.0"
	var info: Dictionary = {
		"tag_name": "v" + VersionUtils.normalize_version(fallback_ver),
		"version": VersionUtils.normalize_version(fallback_ver)
	}

	var exe_dir: String = OS.get_executable_path().get_base_dir()
	var ver_file_path: String = exe_dir.path_join("version.json")
	if FileAccess.file_exists(ver_file_path):
		var file: FileAccess = FileAccess.open(ver_file_path, FileAccess.READ)
		if file:
			var parsed: Variant = JSON.parse_string(file.get_as_text().trim_prefix("\ufeff"))
			file.close()
			if parsed is Dictionary:
				var f_tag: String = String(parsed.get("tag_name", "")).strip_edges()
				var f_ver: String = String(parsed.get("version", "")).strip_edges()
				if f_tag != "":
					info["tag_name"] = f_tag
				if f_ver != "":
					info["version"] = f_ver
				elif f_tag != "":
					info["version"] = VersionUtils.normalize_version(f_tag)
	return info


static func select_windows_asset(assets: Array) -> Dictionary:
	for a in assets:
		if a is Dictionary and String(a.get("name", "")).to_lower() == "ruinharvest.exe":
			return a
	for a in assets:
		if a is Dictionary:
			var n: String = String(a.get("name", "")).to_lower()
			if n.ends_with(".exe") and not n.contains("console") and not n.contains("debug"):
				return a
	for a in assets:
		if a is Dictionary:
			var n: String = String(a.get("name", "")).to_lower()
			if n.ends_with(".zip") and (n.contains("win") or n.contains("ruinharvest")) and not n.contains("mac") and not n.contains("darwin") and not n.contains("linux"):
				return a
	for a in assets:
		if a is Dictionary:
			var n: String = String(a.get("name", "")).to_lower()
			if n.ends_with(".zip") and not n.contains("mac") and not n.contains("darwin") and not n.contains("linux"):
				return a
	return {}


static func is_install_dir_writable() -> bool:
	var install_dir: String = OS.get_executable_path().get_base_dir()
	var probe_path: String = install_dir.path_join(".ruinharvest_write_probe.tmp")
	var f: FileAccess = FileAccess.open(probe_path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string("ok")
	f.close()
	DirAccess.remove_absolute(probe_path)
	return true


static func get_temp_dir() -> String:
	var t: String = OS.get_environment("TEMP").strip_edges()
	if t == "":
		t = OS.get_environment("TMP").strip_edges()
	if t == "":
		t = ProjectSettings.globalize_path("user://")
	return t


static func verify_downloaded_file(path: String, asset_name: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var length: int = f.get_length()
	if length < 65536:
		f.close()
		return false
	var magic: PackedByteArray = f.get_buffer(2)
	f.close()
	if magic.size() < 2:
		return false
	if asset_name.to_lower().ends_with(".zip"):
		return magic[0] == 0x50 and magic[1] == 0x4B
	return magic[0] == 0x4D and magic[1] == 0x5A


static func esc_ps(val: String) -> String:
	return val.replace("'", "''")


static func build_apply_update_ps1(
	old_pid: int,
	install_dir: String,
	download_path: String,
	asset_name: String,
	remote_tag: String,
	clean_ver: String,
	self_script: String
) -> String:
	var lines := PackedStringArray([
		"$ErrorActionPreference = 'Stop'",
		"$oldPid = %d" % old_pid,
		"$installDir = '%s'" % esc_ps(install_dir),
		"$downloadPath = '%s'" % esc_ps(download_path),
		"$assetName = '%s'" % esc_ps(asset_name),
		"$remoteTag = '%s'" % esc_ps(remote_tag),
		"$cleanVer = '%s'" % esc_ps(clean_ver),
		"$selfScript = '%s'" % esc_ps(self_script),
		"$targetExe = Join-Path $installDir 'RuinHarvest.exe'",
		"",
		"try { Wait-Process -Id $oldPid -Timeout 20 -ErrorAction SilentlyContinue } catch {}",
		"Start-Sleep -Milliseconds 400",
		"",
		"$replaced = $false",
		"for ($i = 0; $i -lt 10; $i++) {",
		"    try {",
		"        if ($assetName -match '\\.zip$') {",
		"            $stage = Join-Path $env:TEMP ('rh-upd-' + [guid]::NewGuid().ToString('N'))",
		"            Expand-Archive -LiteralPath $downloadPath -DestinationPath $stage -Force",
		"            $foundExe = Get-ChildItem -Path $stage -Filter '*.exe' -Recurse | Where-Object { $_.Name -notmatch 'console' } | Select-Object -First 1",
		"            if (-not $foundExe) { throw 'No executable found in update archive.' }",
		"            Copy-Item -Path (Join-Path $foundExe.Directory.FullName '*') -Destination $installDir -Recurse -Force",
		"            if ($foundExe.Name -ine 'RuinHarvest.exe') {",
		"                Copy-Item -LiteralPath (Join-Path $installDir $foundExe.Name) -Destination $targetExe -Force",
		"            }",
		"            Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue",
		"        } else {",
		"            Copy-Item -LiteralPath $downloadPath -Destination $targetExe -Force",
		"        }",
		"        $replaced = $true",
		"        break",
		"    } catch {",
		"        Start-Sleep -Milliseconds 500",
		"    }",
		"}",
		"",
		"if ($replaced) {",
		"    $verMeta = [ordered]@{ tag_name = $remoteTag; version = $cleanVer; asset_name = $assetName } | ConvertTo-Json",
		"    [System.IO.File]::WriteAllText((Join-Path $installDir 'version.json'), $verMeta, (New-Object System.Text.UTF8Encoding($false)))",
		"    $regPath = 'HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\RuinHarvest'",
		"    if (Test-Path -Path $regPath) {",
		"        Set-ItemProperty -Path $regPath -Name 'DisplayVersion' -Value $cleanVer -ErrorAction SilentlyContinue",
		"        $totalBytes = (Get-ChildItem -Path $installDir -Recurse -File | Measure-Object -Property Length -Sum).Sum",
		"        $estKb = [int][Math]::Max(1, [Math]::Ceiling($totalBytes / 1024))",
		"        Set-ItemProperty -Path $regPath -Name 'EstimatedSize' -Value $estKb -Type DWord -ErrorAction SilentlyContinue",
		"    }",
		"}",
		"",
		"Remove-Item -LiteralPath $downloadPath -Force -ErrorAction SilentlyContinue",
		"if (Test-Path -LiteralPath $targetExe) {",
		"    Start-Process -FilePath $targetExe -WorkingDirectory $installDir",
		"}",
		"Remove-Item -LiteralPath $selfScript -Force -ErrorAction SilentlyContinue"
	])
	return "\n".join(lines)
