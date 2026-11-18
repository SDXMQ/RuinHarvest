# res://systems/version_utils.gd
class_name VersionUtils
extends RefCounted

## SemVer 버전 파싱 및 원격 릴리스 대소 비교 유틸리티


static func normalize_version(ver_str: String) -> String:
	var s := ver_str.strip_edges()
	if s.begins_with("v") or s.begins_with("V"):
		s = s.substr(1)
	var plus_idx := s.find("+")
	if plus_idx != -1:
		s = s.substr(0, plus_idx)
	var dash_idx := s.find("-")
	if dash_idx != -1:
		s = s.substr(0, dash_idx)
	return s.strip_edges()


static func get_prerelease_suffix(ver_str: String) -> String:
	var s := ver_str.strip_edges()
	if s.begins_with("v") or s.begins_with("V"):
		s = s.substr(1)
	var plus_idx := s.find("+")
	if plus_idx != -1:
		s = s.substr(0, plus_idx)
	var dash_idx := s.find("-")
	if dash_idx == -1:
		return ""
	return s.substr(dash_idx + 1).strip_edges()


static func parse_semver(ver_str: String) -> Array[int]:
	var core := normalize_version(ver_str)
	var parts := core.split(".", false)
	var result: Array[int] = [0, 0, 0]
	for i in range(mini(3, parts.size())):
		var seg := parts[i].strip_edges()
		if seg.is_valid_int():
			result[i] = seg.to_int()
	return result


static func compare_versions(ver_a: String, ver_b: String) -> int:
	var a_nums := parse_semver(ver_a)
	var b_nums := parse_semver(ver_b)
	for i in range(3):
		if a_nums[i] > b_nums[i]:
			return 1
		if a_nums[i] < b_nums[i]:
			return -1

	var a_pre := get_prerelease_suffix(ver_a)
	var b_pre := get_prerelease_suffix(ver_b)
	if a_pre == "" and b_pre == "":
		return 0
	if a_pre == "" and b_pre != "":
		return 1
	if a_pre != "" and b_pre == "":
		return -1

	var a_low := a_pre.to_lower()
	var b_low := b_pre.to_lower()
	if a_low == b_low:
		return 0
	return 1 if a_low > b_low else -1


static func is_remote_newer(remote_tag: String, local_tag: String, local_version: String = "") -> bool:
	var r_tag := remote_tag.strip_edges()
	var l_tag := local_tag.strip_edges()
	if r_tag == "":
		return false
	if l_tag != "" and r_tag.to_lower() == l_tag.to_lower():
		return false
	var l_base := l_tag if l_tag != "" else local_version.strip_edges()
	if l_base == "":
		return false
	return compare_versions(r_tag, l_base) > 0
