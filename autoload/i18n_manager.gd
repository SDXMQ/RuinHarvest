# res://autoload/i18n_manager.gd
extends Node

## 다국어(i18n) 시스템 매니저

var current_lang: String = "ko"

const STRINGS: Dictionary = {
	"ko": {
		# 메인 메뉴
		"game_title": "RuinHarvest",
		"game_subtitle": "하드코어 싱글플레이 익스트랙션 슈터",
		"new_game": "새 레이드 시작",
		"load_game": "은신처 이어하기",
		"settings": "설정",
		"quit": "종료",
		"version_info": "v1.1  |  Godot 4.7 Engine",

		# 월드 생성
		"world_creation_title": "새 월드 생성",
		"world_name": "월드 이름:",
		"difficulty": "난이도:",
		"day_length": "하루 길이(분)",
		"resource_density": "자원 밀도",
		"weather_variability": "날씨 변동성",
		"enemy_activity": "적대 세력 활동량",
		"building_density": "건물 밀도",
		"survival_days": "생존 일수",
		"start_world": "월드 생성 시작",
		"back": "◀ 뒤로",

		# 설정
		"settings_title": "설정",
		"resolution": "해상도:",
		"screen_mode": "화면 모드:",
		"fullscreen": "전체화면",
		"windowed": "창 모드",
		"particle_quality": "파티클 품질:",
		"particle_none": "끔",
		"particle_low": "낮음",
		"particle_normal": "보통",
		"particle_high": "높음",
		"shader_effects": "후처리 셰이더:",
		"enabled": "켜짐",
		"disabled": "꺼짐",
		"language": "언어:",
		"apply": "적용",

		# HUD
		"hp": "HP",
		"hunger": "배고픔",
		"thirst": "갈증",
		"stress": "스트레스",
		"stamina": "스태미나",
		"defense": "방어도",
		"kills": "처치",
		"day": "일차",
		"fist": "주먹",
		"exhausted": "탈진!",

		# 인벤토리
		"inventory": "인벤토리",
		"equipment": "장비",
		"weight": "무게",
		"left_click_use": "좌클릭: 사용",
		"right_click_equip": "우클릭: 장착",

		# 크래프팅
		"crafting": "크래프팅",

		# 상호작용
		"press_e_interact": "E: 상호작용",
		"press_e_enter": "E: 건물 진입",
		"press_e_exit": "E: 나가기",
		"press_e_search": "E: 탐색",
		"controls_hint": "E:상호작용  Tab:인벤토리  C:크래프팅  M:지도  ESC:메뉴",

		# 건물 내부
		"entering_building": "건물에 진입합니다...",
		"exiting_building": "건물에서 나갑니다...",
		"searched_already": "이미 탐색한 가구입니다.",
		"found_nothing": "아무것도 발견하지 못했습니다.",
		"found_items": "발견: ",
		"enemy_intrusion": "적대 세력이 건물 안으로 침입했습니다!",
		"enemy_followed": "적대 세력이 따라 들어왔습니다!",
		"enemy_followed_outside": "적대 세력이 문을 열고 밖으로 쫓아나왔습니다!",

		# 세이브 슬롯
		"save_slots_title": "세이브 파일",
		"save_slot_empty": "빈 슬롯",
		"save_slot_day": "Day {0}",
		"save_slot_created": "생성: {0}",
		"save_slot_last_played": "최근: {0}",
		"save_slot_funds": "{0} 루블",
		"ruble": "루블",
		"save_slot_delete_confirm": "정말 삭제하시겠습니까?",
		"save_slot_yes": "예",
		"save_slot_no": "아니오",
		"save_slot_no_saves": "저장된 게임이 없습니다",
		"save_slot_page": "{0} / {1}",

		# 일시정지
		"paused": "일시정지",
		"resume": "계속하기",
		"save_game": "저장하기",
		"save_and_quit": "저장 후 종료",
		"quit_no_save": "저장하지 않고 종료",

		# 이벤트
		"game_saved": "게임이 저장되었습니다.",
		"new_day": "{0}일차가 밝았습니다.",
		"enemy_horde": "적대 세력 무리가 접근합니다!",
		"found_survivor": "생존자를 발견했습니다!",

		# 난이도
		"peaceful": "평화로움",
		"easy": "쉬움",
		"normal": "보통",
		"hard": "어려움",
		"hardcore": "하드코어",
		"challenge": "악몽 챌린지",

		# 엔딩
		"ending_survived": "생환 성공!",
		"ending_died": "사망 (KIA)...",
		"ending_mia": "실종 (MIA)...",

		# 가구
		"furniture_냉장고": "냉장고",
		"furniture_선반": "선반",
		"furniture_서랍장": "서랍장",
		"furniture_침대밑": "침대 밑",
		"furniture_약품장": "약품장",
		"furniture_진열대": "진열대",
		"furniture_카운터": "카운터",
		"furniture_사물함": "사물함",
		"furniture_무기함": "무기함",
		"furniture_군용상자": "군용 상자",
		"furniture_통신장비": "통신 장비",

		# 추가 라벨 및 힌트
		"equip_head": "머리",
		"equip_body": "상의",
		"equip_feet": "신발",
		"equip_weapon": "무기",
		"equip_back": "가방",
		"inventory_hint": "좌클릭: 사용  |  드래그: 장착/해제  |  우클릭: 버리기",
		"defense_label": "방어도: {0}",
		"kills_label": "처치: {0}",
		"stealth_mode": "◆ 은신 중 ◆",
		"weather_label": "날씨: {0}",
		"extracting_label": "탈출 대기 중... {0}초",
		"extraction_point": "탈출구",
		"requires_key": "열쇠 필요",
		"time_locked": "시간 제한",

		# 은신처 및 플리마켓
		"hideout_title": "은신처 (Hideout)",
		"tab_stash": "창고 (Stash)",
		"tab_traders": "상인 (Traders)",
		"tab_market": "플리마켓 (Market)",
		"tab_raid": "레이드 출격 (Raid)",
		"raid_briefing": "폐허 구역 레이드",
		"raid_duration_desc": "작전 제한 시간: 10분  |  생환 성공 시 획득품 영구 보존",
		"start_raid_btn": "레이드 진입",
		"insure_all_btn": "전체 보험 가입",
		"repair_btn": "수리",
		"buy_btn": "구매",
		"sell_btn": "판매",
		"list_item_btn": "매물 등록"
	},
	"en": {
		# Main Menu
		"game_title": "RuinHarvest",
		"game_subtitle": "Hardcore Singleplayer Extraction Shooter",
		"new_game": "New Raid",
		"load_game": "Continue Hideout",
		"settings": "Settings",
		"quit": "Quit",
		"version_info": "v1.1  |  Godot 4.7 Engine",

		# World Creation
		"world_creation_title": "Create New World",
		"world_name": "World Name:",
		"difficulty": "Difficulty:",
		"day_length": "Day Length (min)",
		"resource_density": "Resource Density",
		"weather_variability": "Weather Variability",
		"enemy_activity": "Enemy Activity",
		"building_density": "Building Density",
		"survival_days": "Survival Days",
		"start_world": "Start World Creation",
		"back": "◀ Back",

		# Settings
		"settings_title": "Settings",
		"resolution": "Resolution:",
		"screen_mode": "Screen Mode:",
		"fullscreen": "Fullscreen",
		"windowed": "Windowed",
		"particle_quality": "Particle Quality:",
		"particle_none": "Off",
		"particle_low": "Low",
		"particle_normal": "Normal",
		"particle_high": "High",
		"shader_effects": "Post-processing:",
		"enabled": "Enabled",
		"disabled": "Disabled",
		"language": "Language:",
		"apply": "Apply",

		# HUD
		"hp": "HP",
		"hunger": "Hunger",
		"thirst": "Thirst",
		"stress": "Stress",
		"stamina": "Stamina",
		"defense": "Defense",
		"kills": "Kills",
		"day": "Day",
		"fist": "Fist",
		"exhausted": "Exhausted!",

		# Inventory
		"inventory": "Inventory",
		"equipment": "Equipment",
		"weight": "Weight",
		"left_click_use": "L-Click: Use",
		"right_click_equip": "R-Click: Equip",

		# Crafting
		"crafting": "Crafting",

		# Interaction
		"press_e_interact": "E: Interact",
		"press_e_enter": "E: Enter Building",
		"press_e_exit": "E: Exit",
		"press_e_search": "E: Search",
		"controls_hint": "E:Interact  Tab:Inventory  C:Craft  M:Map  ESC:Menu",

		# Building Interior
		"entering_building": "Entering building...",
		"exiting_building": "Exiting building...",
		"searched_already": "Already searched.",
		"found_nothing": "Found nothing.",
		"found_items": "Found: ",
		"enemy_intrusion": "Enemies have entered the building!",
		"enemy_followed": "An enemy followed you inside!",
		"enemy_followed_outside": "An enemy opened the door and chased you outside!",

		# Save Slots
		"save_slots_title": "Save Files",
		"save_slot_empty": "Empty Slot",
		"save_slot_day": "Day {0}",
		"save_slot_created": "Created: {0}",
		"save_slot_last_played": "Last: {0}",
		"save_slot_funds": "{0} RUB",
		"ruble": "RUB",
		"save_slot_delete_confirm": "Delete this save file?",
		"save_slot_yes": "Yes",
		"save_slot_no": "No",
		"save_slot_no_saves": "No saved games found",
		"save_slot_page": "{0} / {1}",

		# Pause
		"paused": "Paused",
		"resume": "Resume",
		"save_game": "Save Game",
		"save_and_quit": "Save & Quit",
		"quit_no_save": "Quit without Saving",

		# Events
		"game_saved": "Game saved.",
		"new_day": "Day {0} has dawned.",
		"enemy_horde": "A hostile horde is approaching!",
		"found_survivor": "Found a survivor!",

		# Difficulty
		"peaceful": "Peaceful",
		"easy": "Easy",
		"normal": "Normal",
		"hard": "Hard",
		"hardcore": "Hardcore",
		"challenge": "Nightmare",

		# Ending
		"ending_survived": "Survived!",
		"ending_died": "Killed In Action (KIA)...",
		"ending_mia": "Missing In Action (MIA)...",

		# Furniture
		"furniture_냉장고": "Refrigerator",
		"furniture_선반": "Shelf",
		"furniture_서랍장": "Drawer",
		"furniture_침대밑": "Under Bed",
		"furniture_약품장": "Medicine Cabinet",
		"furniture_진열대": "Display Rack",
		"furniture_카운터": "Counter",
		"furniture_사물함": "Locker",
		"furniture_무기함": "Gun Safe",
		"furniture_군용상자": "Military Crate",
		"furniture_통신장비": "Radio Gear",

		# Labels & Hints
		"equip_head": "Head",
		"equip_body": "Body",
		"equip_feet": "Feet",
		"equip_weapon": "Weapon",
		"equip_back": "Backpack",
		"inventory_hint": "L-Click: Use  |  Drag: Equip/Move  |  R-Click: Drop",
		"defense_label": "Defense: {0}",
		"kills_label": "Kills: {0}",
		"stealth_mode": "◆ Stealth ◆",
		"weather_label": "Weather: {0}",
		"extracting_label": "Extracting... {0}s",
		"extraction_point": "Extraction Point",
		"requires_key": "Key Required",
		"time_locked": "Time Locked",

		# Hideout & Flea Market
		"hideout_title": "Hideout",
		"tab_stash": "Stash",
		"tab_traders": "Traders",
		"tab_market": "Flea Market",
		"tab_raid": "Enter Raid",
		"raid_briefing": "Raid Briefing",
		"raid_duration_desc": "Operation Time Limit: 10 min  |  Keep all loot upon survival",
		"start_raid_btn": "Start Raid",
		"insure_all_btn": "Insure All",
		"repair_btn": "Repair",
		"buy_btn": "Buy",
		"sell_btn": "Sell",
		"list_item_btn": "List Item"
	}
}

func _ready() -> void:
	if GameSettings:
		current_lang = GameSettings.language

func set_language(lang: String) -> void:
	if STRINGS.has(lang):
		current_lang = lang
		if GameSettings:
			GameSettings.language = lang
			GameSettings.save_settings()

func t(key: String, args: Array = []) -> String:
	var lang_dict: Dictionary = STRINGS.get(current_lang, STRINGS["ko"])
	var text: String = ""
	
	if lang_dict.has(key):
		text = lang_dict[key]
	elif lang_dict.has("item_" + key):
		text = lang_dict["item_" + key]
	elif STRINGS["ko"].has(key):
		text = STRINGS["ko"][key]
	else:
		text = key

	if args.size() > 0:
		return text.format(args)
	return text
