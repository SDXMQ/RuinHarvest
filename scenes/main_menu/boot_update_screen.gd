# res://scenes/main_menu/boot_update_screen.gd
extends Control

## 앱 시작 시 GitHub Releases 최신 버전을 확인하고 필수 업데이트를 적용하는 부트 스크린

const MAIN_MENU_SCENE: String = "res://scenes/main_menu/main_menu.tscn"
const REPO_SLUG: String = "SDXMQ/RuinHarvest"
const LATEST_RELEASE_URL: String = "https://api.github.com/repos/SDXMQ/RuinHarvest/releases/latest"
const RELEASES_LIST_URL: String = "https://api.github.com/repos/SDXMQ/RuinHarvest/releases?per_page=10"
const RELEASES_WEB_URL: String = "https://github.com/SDXMQ/RuinHarvest/releases"
const CHECK_TIMEOUT_SEC: float = 3.5

@onready var version_label: Label = $UpdateFrame/Margin/VBox/VersionLabel
@onready var status_label: Label = $UpdateFrame/Margin/VBox/StatusLabel
@onready var progress_bar: ProgressBar = $UpdateFrame/Margin/VBox/ProgressBar
@onready var buttons_hbox: HBoxContainer = $UpdateFrame/Margin/VBox/ButtonsHBox
@onready var retry_button: Button = $UpdateFrame/Margin/VBox/ButtonsHBox/RetryButton
@onready var open_release_button: Button = $UpdateFrame/Margin/VBox/ButtonsHBox/OpenReleaseButton
@onready var quit_button: Button = $UpdateFrame/Margin/VBox/ButtonsHBox/QuitButton

var _check_http: HTTPRequest = null
var _dl_http: HTTPRequest = null
var _checking_fallback: bool = false
var _is_downloading: bool = false
var _transitioning: bool = false

var _local_version_info: Dictionary = {}
var _pending_tag: String = ""
var _pending_asset: Dictionary = {}
var _download_path: String = ""


func _ready() -> void:
	retry_button.pressed.connect(_on_retry_pressed)
	open_release_button.pressed.connect(_on_open_release_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	_apply_localized_button_texts()
	_local_version_info = _load_local_version_info()

	if _should_skip_update_check():
		_proceed_to_main_menu.call_deferred()
		return

	_start_version_check()


func _process(_delta: float) -> void:
	if not _is_downloading or not is_instance_valid(_dl_http):
		return
	var dl_bytes: int = _dl_http.get_downloaded_bytes()
	var total_bytes: int = _dl_http.get_body_size()
	if total_bytes <= 0:
		total_bytes = int(_pending_asset.get("size", 0))
	if total_bytes > 0:
		var pct: float = clampf((float(dl_bytes) / float(total_bytes)) * 100.0, 0.0, 100.0)
		progress_bar.value = pct
		var cur_mb: float = float(dl_bytes) / 1048576.0
		var tot_mb: float = float(total_bytes) / 1048576.0
		status_label.text = _tr("update_downloading", [int(round(pct)), "%.1f" % cur_mb, "%.1f" % tot_mb])


func _should_skip_update_check() -> bool:
	if OS.has_feature("editor"):
		return true
	if DisplayServer.get_name() == "headless":
		return true
	if OS.get_name() != "Windows":
		return true
	return false


func _apply_localized_button_texts() -> void:
	retry_button.text = _tr("update_retry_btn")
	open_release_button.text = _tr("update_open_release_btn")
	quit_button.text = _tr("update_quit_btn")


func _tr(key: String, args: Array = []) -> String:
	if I18nManager:
		return I18nManager.t(key, args)
	return key


func _load_local_version_info() -> Dictionary:
	var fallback_ver: String = String(ProjectSettings.get_setting("application/config/version", "1.0.0")).strip_edges()
	if fallback_ver == "":
		fallback_ver = "1.0.0"
	var info := {
		"tag_name": "v" + VersionUtils.normalize_version(fallback_ver),
		"version": VersionUtils.normalize_version(fallback_ver)
	}

	var exe_dir: String = OS.get_executable_path().get_base_dir()
	var ver_file_path: String = exe_dir.path_join("version.json")
	if FileAccess.file_exists(ver_file_path):
		var file := FileAccess.open(ver_file_path, FileAccess.READ)
		if file:
			var parsed = JSON.parse_string(file.get_as_text())
			file.close()
			if parsed is Dictionary:
				var f_tag := String(parsed.get("tag_name", "")).strip_edges()
				var f_ver := String(parsed.get("version", "")).strip_edges()
				if f_tag != "":
					info["tag_name"] = f_tag
				if f_ver != "":
					info["version"] = f_ver
				elif f_tag != "":
					info["version"] = VersionUtils.normalize_version(f_tag)
	return info


func _start_version_check() -> void:
	_is_downloading = false
	_checking_fallback = false
	buttons_hbox.visible = false
	progress_bar.visible = true
	progress_bar.value = 0.0

	var local_tag: String = String(_local_version_info.get("tag_name", ""))
	version_label.text = local_tag
	status_label.text = _tr("update_checking")

	if is_instance_valid(_check_http):
		_check_http.queue_free()
	_check_http = HTTPRequest.new()
	_check_http.timeout = CHECK_TIMEOUT_SEC
	add_child(_check_http)
	_check_http.request_completed.connect(_on_check_request_completed)

	var err: Error = _check_http.request(LATEST_RELEASE_URL, _get_api_headers())
	if err != OK:
		_proceed_to_main_menu()


func _request_github_releases_fallback() -> void:
	if not is_instance_valid(_check_http):
		_proceed_to_main_menu()
		return
	var err: Error = _check_http.request(RELEASES_LIST_URL, _get_api_headers())
	if err != OK:
		_proceed_to_main_menu()


func _get_api_headers() -> PackedStringArray:
	return PackedStringArray([
		"User-Agent: RuinHarvest-Updater",
		"Accept: application/vnd.github+json"
	])


func _on_check_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if _transitioning:
		return

	if result != HTTPRequest.RESULT_SUCCESS:
		_proceed_to_main_menu()
		return

	if not _checking_fallback and response_code == 404:
		_checking_fallback = true
		_request_github_releases_fallback.call_deferred()
		return

	if response_code != 200:
		_proceed_to_main_menu()
		return

	var json_data = JSON.parse_string(body.get_string_from_utf8())
	var release_dict: Dictionary = {}
	if not _checking_fallback:
		if json_data is Dictionary:
			release_dict = json_data
	else:
		if json_data is Array:
			for item in json_data:
				if item is Dictionary and not bool(item.get("draft", false)):
					release_dict = item
					break

	if release_dict.is_empty():
		_proceed_to_main_menu()
		return

	var remote_tag: String = String(release_dict.get("tag_name", "")).strip_edges()
	var local_tag: String = String(_local_version_info.get("tag_name", ""))
	var local_ver: String = String(_local_version_info.get("version", ""))

	if not VersionUtils.is_remote_newer(remote_tag, local_tag, local_ver):
		_proceed_to_main_menu()
		return

	var assets: Array = release_dict.get("assets", []) if release_dict.get("assets") is Array else []
	var selected_asset: Dictionary = _select_windows_asset(assets)
	if selected_asset.is_empty():
		_proceed_to_main_menu()
		return

	_pending_tag = remote_tag
	_pending_asset = selected_asset

	var cur_display: String = local_tag if local_tag != "" else ("v" + local_ver)
	version_label.text = _tr("update_found", [remote_tag, cur_display])
	status_label.text = _tr("update_mandatory_desc")
	buttons_hbox.visible = false

	if not _is_install_dir_writable():
		_show_update_error(_tr("update_not_writable"))
		return

	_start_asset_download(selected_asset)


func _select_windows_asset(assets: Array) -> Dictionary:
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


func _is_install_dir_writable() -> bool:
	var install_dir: String = OS.get_executable_path().get_base_dir()
	var probe_path: String = install_dir.path_join(".ruinharvest_write_probe.tmp")
	var f := FileAccess.open(probe_path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string("ok")
	f.close()
	DirAccess.remove_absolute(probe_path)
	return true


func _get_temp_dir() -> String:
	var t := OS.get_environment("TEMP").strip_edges()
	if t == "":
		t = OS.get_environment("TMP").strip_edges()
	if t == "":
		t = ProjectSettings.globalize_path("user://")
	return t


func _start_asset_download(asset: Dictionary) -> void:
	var dl_url: String = String(asset.get("browser_download_url", "")).strip_edges()
	var asset_name: String = String(asset.get("name", "RuinHarvest.exe")).strip_edges()
	if dl_url == "":
		_show_update_error("Missing download URL.")
		return

	_download_path = _get_temp_dir().path_join("ruinharvest-update-%d-%s" % [Time.get_unix_time_from_system(), asset_name])
	if FileAccess.file_exists(_download_path):
		DirAccess.remove_absolute(_download_path)

	if is_instance_valid(_dl_http):
		_dl_http.queue_free()
	_dl_http = HTTPRequest.new()
	_dl_http.use_threads = true
	_dl_http.timeout = 0.0
	_dl_http.download_file = _download_path
	add_child(_dl_http)
	_dl_http.request_completed.connect(_on_download_completed)

	_is_downloading = true
	progress_bar.value = 0.0
	var err: Error = _dl_http.request(dl_url, PackedStringArray(["User-Agent: RuinHarvest-Updater"]))
	if err != OK:
		_is_downloading = false
		_show_update_error("HTTPRequest error: %d" % err)


func _on_download_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	_is_downloading = false

	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_cleanup_temp_download()
		_show_update_error("HTTP %d (result %d)" % [response_code, result])
		return

	if not _verify_downloaded_file(_download_path, String(_pending_asset.get("name", ""))):
		_cleanup_temp_download()
		_show_update_error("Downloaded file verification failed.")
		return

	_launch_self_update_and_quit()


func _verify_downloaded_file(path: String, asset_name: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var f := FileAccess.open(path, FileAccess.READ)
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


func _cleanup_temp_download() -> void:
	if _download_path != "" and FileAccess.file_exists(_download_path):
		DirAccess.remove_absolute(_download_path)


func _launch_self_update_and_quit() -> void:
	status_label.text = _tr("update_applying")
	progress_bar.value = 100.0

	var temp_dir: String = _get_temp_dir()
	var script_path: String = temp_dir.path_join("ruinharvest-apply-update-%d.ps1" % Time.get_unix_time_from_system())
	var install_dir: String = OS.get_executable_path().get_base_dir()
	var asset_name: String = String(_pending_asset.get("name", "RuinHarvest.exe"))
	var clean_ver: String = VersionUtils.normalize_version(_pending_tag)
	if clean_ver == "":
		clean_ver = "1.0.0"

	var ps_script: String = _build_apply_update_ps1(
		OS.get_process_id(),
		install_dir,
		_download_path,
		asset_name,
		_pending_tag,
		clean_ver,
		script_path
	)

	var sf := FileAccess.open(script_path, FileAccess.WRITE)
	if sf == null:
		_show_update_error("Failed to create updater helper script.")
		return
	sf.store_string(ps_script)
	sf.close()

	var pid: int = OS.create_process("powershell.exe", PackedStringArray([
		"-NoProfile",
		"-ExecutionPolicy", "Bypass",
		"-WindowStyle", "Hidden",
		"-File", script_path
	]))
	if pid <= 0:
		DirAccess.remove_absolute(script_path)
		_show_update_error("Failed to launch updater process.")
		return

	get_tree().quit()


func _esc_ps(val: String) -> String:
	return val.replace("'", "''")


func _build_apply_update_ps1(
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
		"$installDir = '%s'" % _esc_ps(install_dir),
		"$downloadPath = '%s'" % _esc_ps(download_path),
		"$assetName = '%s'" % _esc_ps(asset_name),
		"$remoteTag = '%s'" % _esc_ps(remote_tag),
		"$cleanVer = '%s'" % _esc_ps(clean_ver),
		"$selfScript = '%s'" % _esc_ps(self_script),
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
		"    Set-Content -LiteralPath (Join-Path $installDir 'version.json') -Value $verMeta -Encoding UTF8",
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


func _show_update_error(reason: String) -> void:
	progress_bar.visible = false
	status_label.text = _tr("update_failed", [reason])
	buttons_hbox.visible = true


func _on_retry_pressed() -> void:
	if SoundManager:
		SoundManager.play("menu_select")
	_start_version_check()


func _on_open_release_pressed() -> void:
	if SoundManager:
		SoundManager.play("menu_select")
	OS.shell_open(RELEASES_WEB_URL)


func _on_quit_pressed() -> void:
	get_tree().quit()


func _proceed_to_main_menu() -> void:
	if _transitioning:
		return
	_transitioning = true
	if is_inside_tree() and get_tree():
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)
