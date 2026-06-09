"""
hideout_ui.py - 은신처 로비, Stash, 상인 거래소, 가상 플리마켓 통합 UI
"""
import pygame
import math
import copy
from settings import Colors, TILE_SIZE
from renderer import draw_rounded_rect, draw_gradient_rect, draw_glow, ItemIconRenderer
from items import ITEM_DATABASE, ItemCategory, Inventory
from .fonts import FontManager
from i18n import t
from sounds import SoundGenerator

class HideoutUI:
    """은신처 및 경제 로비 통합 UI"""

    def __init__(self, screen_w, screen_h, flea_market):
        self.sw = screen_w
        self.sh = screen_h
        self.flea_market = flea_market

        # 탭 정의: "stash", "traders", "market", "raid"
        self.tabs = ["stash", "traders", "market", "raid"]
        self.active_tab = "stash"
        
        # 상인 정의
        self.traders = {
            "prapor": {"name": "프라포 (군수 상인)", "desc": "총기와 탄약, 방탄 장비를 판매합니다.", "rep": 0.2, "spent": 0},
            "therapist": {"name": "테라피스트 (의료 상인)", "desc": "치료제와 신선한 식료품을 판매합니다.", "rep": 0.2, "spent": 0},
            "fence": {"name": "펜스 (밀수 상인)", "desc": "온갖 잡동사니와 정체불명의 장비를 취급합니다.", "rep": 0.2, "spent": 0}
        }
        self.active_trader = "prapor"
        self.trader_sub_tab = "buy" # "buy" 또는 "sell"

        # 스크롤 오프셋
        self.stash_scroll = 0
        self.inv_scroll = 0
        self.market_scroll = 0
        self.trader_scroll = 0
        
        # 다중구매 hold 변수
        self.btn_hold_timer = 0.0
        self.btn_hold_action = None
        self.btn_hold_delay = 0.4
        self.btn_hold_interval = 0.05
        self.btn_hold_tick = 0.0

        # 선택된 아이템 정보 (Stash나 인벤토리에서 클릭 시)
        # {"source": "stash"|"inventory"|"equipped", "index": int, "item_name": str, "slot_name": str}
        self.selected_item = None
        self.selected_shop_item = None

        # 플리마켓 등록 다이얼로그 상태
        self.show_register_dialog = False
        self.register_price_input = ""
        self.register_target_item = None # (source, index, name)

        # 상인 등급 해금 조건
        self.loyalty_reqs = {
            2: {"level": 5, "rep": 0.40, "spent": 50000},
            3: {"level": 15, "rep": 0.70, "spent": 200000}
        }

        # 드래그 앤 드롭 상태
        self.dragging = False
        self.drag_item = None       # (item_name, count)
        self.drag_source = None     # 'inventory', 'stash', 'equipped_<slot>'
        self.drag_source_idx = -1
        self.drag_mouse_x = 0
        self.drag_mouse_y = 0

    def resize(self, w, h):
        self.sw = w
        self.sh = h

    def _add_log(self, player, text):
        if player and getattr(player, 'event_system', None):
            player.event_system.add_log(text)

    def update(self, dt):
        if self.btn_hold_action and self.selected_shop_item and self.selected_shop_item.get("action") == "buy":
            self.btn_hold_timer += dt
            if self.btn_hold_timer >= self.btn_hold_delay:
                self.btn_hold_tick += dt
                if self.btn_hold_tick >= self.btn_hold_interval:
                    self.btn_hold_tick = 0.0
                    if self.btn_hold_action == "plus":
                        self.selected_shop_item["buy_count"] = min(30, self.selected_shop_item.get("buy_count", 1) + 1)
                    elif self.btn_hold_action == "minus":
                        self.selected_shop_item["buy_count"] = max(1, self.selected_shop_item.get("buy_count", 1) - 1)

    def handle_event(self, event, player):
        if self.show_register_dialog:
            return self._handle_register_dialog_event(event, player)

        # 드래그 중 마우스 이동 추적
        if event.type == pygame.MOUSEMOTION and self.dragging:
            self.drag_mouse_x, self.drag_mouse_y = event.pos
            return None

        # 드래그 종료 (마우스 버튼 릴리즈)
        if event.type == pygame.MOUSEBUTTONUP and event.button == 1:
            self.btn_hold_action = None
            self.btn_hold_timer = 0.0
            if self.dragging:
                mx, my = event.pos
                self._handle_drag_drop(mx, my, player)
                return None

        if event.type == pygame.MOUSEBUTTONDOWN:
            mx, my = event.pos
            
            # 탭 클릭 검사
            for i, tab in enumerate(self.tabs):
                tx = 20 + i * 130
                ty = 15
                tw, th = 120, 35
                if tx <= mx <= tx + tw and ty <= my <= ty + th:
                    if self.dragging:
                        self._cancel_drag(player)
                    self.active_tab = tab
                    self.selected_item = None
                    self.selected_shop_item = None
                    self.stash_scroll = 0
                    self.inv_scroll = 0
                    self.market_scroll = 0
                    self.trader_scroll = 0
                    return None

            # 마우스 휠 스크롤
            if event.button == 4: # 스크롤 업
                if self.active_tab == "stash":
                    if mx < self.sw // 2:
                        self.inv_scroll = max(0, self.inv_scroll - 1)
                    else:
                        self.stash_scroll = max(0, self.stash_scroll - 1)
                elif self.active_tab == "traders":
                    self.trader_scroll = max(0, self.trader_scroll - 1)
                elif self.active_tab == "market":
                    self.market_scroll = max(0, self.market_scroll - 1)
            elif event.button == 5: # 스크롤 다운
                if self.active_tab == "stash":
                    if mx < self.sw // 2:
                        max_rows = math.ceil(player.inventory.slots / 4)
                        visible_rows = 8
                        self.inv_scroll = min(max(0, max_rows - visible_rows), self.inv_scroll + 1)
                    else:
                        max_rows = math.ceil(player.stash.slots / 8)
                        visible_rows = 11
                        self.stash_scroll = min(max(0, max_rows - visible_rows), self.stash_scroll + 1)
                elif self.active_tab == "traders":
                    self.trader_scroll += 1
                elif self.active_tab == "market":
                    self.market_scroll += 1

            # Stash 탭에서 좌클릭 시 드래그 시작 시도
            if event.button == 1 and self.active_tab == "stash":
                drag_started = self._try_start_drag(mx, my, player)
                if drag_started:
                    return None

            # 좌클릭일 때 세부 영역 처리
            if event.button == 1:
                return self._handle_tab_clicks(mx, my, player)

        elif event.type == pygame.KEYDOWN:
            # 다중구매 수량 입력 처리
            if self.active_tab == "traders" and self.selected_shop_item and self.selected_shop_item.get("action") == "buy":
                if event.key == pygame.K_BACKSPACE:
                    val_str = str(self.selected_shop_item.get("buy_count", 1))
                    if len(val_str) > 1:
                        self.selected_shop_item["buy_count"] = int(val_str[:-1])
                    else:
                        self.selected_shop_item["buy_count"] = 1
                    return None
                elif event.unicode and event.unicode.isdigit():
                    val_str = str(self.selected_shop_item.get("buy_count", 1))
                    new_val = int(val_str + event.unicode)
                    if new_val > 30:
                        new_val = 30
                    self.selected_shop_item["buy_count"] = new_val
                    return None

            if event.key == pygame.K_ESCAPE:
                if self.dragging:
                    self._cancel_drag(player)
                    return None
                if self.selected_item or self.selected_shop_item:
                    self.selected_item = None
                    self.selected_shop_item = None
                    return None
                # 아무것도 활성화되지 않은 상태에서 ESC 입력 시 포즈 화면 요청
                return "pause_game"
                
        return None

    def _try_start_drag(self, mx, my, player):
        """드래그 시작 시도 - 클릭한 위치에 아이템이 있으면 드래그 시작"""
        # 장비 슬롯 검사
        eq_slots = {"head": (30, 95), "body": (30, 137), "feet": (30, 179), "weapon": (120, 110), "back": (120, 155)}
        for slot, (ex, ey) in eq_slots.items():
            if ex <= mx <= ex + 38 and ey <= my <= ey + 38:
                item_name = player.equipped.get(slot)
                if item_name:
                    self.dragging = True
                    meta = copy.deepcopy(player.equipped_backpack_meta) if slot == "back" else {}
                    self.drag_item = (item_name, 1, meta)
                    self.drag_source = f"equipped_{slot}"
                    self.drag_source_idx = -1
                    self.drag_mouse_x = mx
                    self.drag_mouse_y = my
                    return True
                return False

        # 인벤토리 슬롯 검사 (스크롤 반영)
        inv_start_x, inv_start_y = 30, 250
        cols = 4
        for idx in range(player.inventory.slots):
            row = idx // cols
            col = idx % cols
            sx = inv_start_x + col * 42
            sy = inv_start_y + row * 42 - self.inv_scroll * 42
            if not (240 <= sy <= 570):
                continue
            if sx <= mx <= sx + 38 and sy <= my <= sy + 38:
                found_idx = -1
                for i, it in enumerate(player.inventory.items):
                    if len(it) > 2 and it[2].get("slot_idx") == idx:
                        found_idx = i
                        break
                if found_idx != -1:
                    item_tup = player.inventory.items[found_idx]
                    name, count = item_tup[0], item_tup[1]
                    meta = item_tup[2] if len(item_tup) > 2 else {}
                    self.dragging = True
                    self.drag_item = (name, count, copy.deepcopy(meta))
                    self.drag_source = "inventory"
                    self.drag_source_idx = idx
                    self.drag_mouse_x = mx
                    self.drag_mouse_y = my
                    return True
                return False

        # Stash 슬롯 검사
        stash_start_x = self.sw // 2 + 10
        stash_start_y = 110
        stash_cols = 8
        stash_rows = 11
        for idx in range(stash_cols * stash_rows):
            actual_idx = idx + self.stash_scroll * stash_cols
            row = idx // stash_cols
            col = idx % stash_cols
            sx = stash_start_x + col * 42
            sy = stash_start_y + row * 42
            if sx <= mx <= sx + 38 and sy <= my <= sy + 38:
                found_idx = -1
                for i, it in enumerate(player.stash.items):
                    if len(it) > 2 and it[2].get("slot_idx") == actual_idx:
                        found_idx = i
                        break
                if found_idx != -1:
                    item_tup = player.stash.items[found_idx]
                    name, count = item_tup[0], item_tup[1]
                    meta = item_tup[2] if len(item_tup) > 2 else {}
                    self.dragging = True
                    self.drag_item = (name, count, copy.deepcopy(meta))
                    self.drag_source = "stash"
                    self.drag_source_idx = actual_idx
                    self.drag_mouse_x = mx
                    self.drag_mouse_y = my
                    return True
                return False

        return False

    def _remove_source_item(self, player):
        if self.drag_source == "inventory":
            for idx, it in enumerate(player.inventory.items):
                if len(it) > 2 and it[2].get("slot_idx") == self.drag_source_idx:
                    player.inventory.items.pop(idx)
                    break
        elif self.drag_source == "stash":
            for idx, it in enumerate(player.stash.items):
                if len(it) > 2 and it[2].get("slot_idx") == self.drag_source_idx:
                    player.stash.items.pop(idx)
                    break
        elif self.drag_source.startswith("equipped_"):
            slot = self.drag_source.replace("equipped_", "")
            player.equipped[slot] = None

    def _handle_drag_drop(self, mx, my, player):
        """드래그 종료 - 드롭 대상 결정 및 아이템 이동"""
        if not self.dragging or not self.drag_item:
            self._cancel_drag(player)
            return

        item_name, count, item_meta = copy.deepcopy(self.drag_item)
        dropped = False

        # 가방 해제 시의 특수 메타데이터 백업 (롤백용)
        is_backpack_unequip = (self.drag_source == "equipped_back")
        orig_backpack_items = []
        orig_equipped_meta = {}
        
        if is_backpack_unequip:
            orig_equipped_meta = copy.deepcopy(getattr(player, "equipped_backpack_meta", {}))
            remaining_items = []
            for it in player.inventory.items:
                slot_idx = it[2].get("slot_idx", 0) if len(it) > 2 else 0
                if slot_idx >= 12:
                    orig_backpack_items.append(it)
                else:
                    remaining_items.append(it)
            # 드롭될 가방의 메타데이터 구성
            item_meta = copy.deepcopy(orig_equipped_meta)
            item_meta["backpack_items"] = orig_backpack_items
            
            # 일단 플레이어의 가방 인벤토리 일시 축소
            player.inventory.items = remaining_items
            player.inventory.slots = 12
            player.inventory.max_weight = 15.0
            player.equipped_backpack_meta = {}

        # 장비 슬롯에 드롭
        eq_slots = {"head": (30, 95), "body": (30, 137), "feet": (30, 179), "weapon": (120, 110), "back": (120, 155)}
        for slot, (ex, ey) in eq_slots.items():
            if ex <= mx <= ex + 38 and ey <= my <= ey + 38:
                data = ITEM_DATABASE.get(item_name, {})
                eq_slot = data.get("equip_slot")
                if not eq_slot and data.get("category") == ItemCategory.WEAPON:
                    eq_slot = "weapon"
                if eq_slot == slot:
                    src_inv = player.inventory if self.drag_source == "inventory" else (player.stash if self.drag_source == "stash" else None)
                    if player.equip_item(copy.deepcopy(item_name), player.stash, slot_idx=self.drag_source_idx, source_inventory=src_inv):
                        dropped = True
                    dropped = True
                break

        # Stash 영역에 드롭
        if not dropped:
            stash_start_x = self.sw // 2 + 10
            stash_start_y = 110
            stash_w = 8 * 42
            stash_h = 11 * 42
            if stash_start_x <= mx <= stash_start_x + stash_w and stash_start_y <= my <= stash_start_y + stash_h:
                col = (mx - stash_start_x) // 42
                row = (my - stash_start_y) // 42
                dest_slot_idx = row * 8 + col + self.stash_scroll * 8
                
                self._remove_source_item(player)
                
                dest_item = None
                for it in player.stash.items:
                    if len(it) > 2 and it[2].get("slot_idx") == dest_slot_idx:
                        dest_item = it
                        break
                
                if dest_item:
                    dest_item[2]["slot_idx"] = self.drag_source_idx if self.drag_source == "stash" else player.stash._get_first_free_slot()
                    item_meta["slot_idx"] = dest_slot_idx
                    player.stash.items.append((item_name, count, item_meta))
                else:
                    item_meta["slot_idx"] = dest_slot_idx
                    player.stash.items.append((item_name, count, item_meta))
                dropped = True

        # 인벤토리 영역에 드롭
        if not dropped:
            inv_start_x, inv_start_y = 30, 250
            inv_w = 4 * 42
            inv_h = (player.inventory.slots // 4 + 1) * 42
            if inv_start_x <= mx <= inv_start_x + inv_w and inv_start_y <= my <= inv_start_y + inv_h:
                col = (mx - inv_start_x) // 42
                row = (my - (inv_start_y - self.inv_scroll * 42)) // 42
                dest_slot_idx = row * 4 + col
                
                if 0 <= dest_slot_idx < player.inventory.slots:
                    self._remove_source_item(player)
                    
                    dest_item = None
                    for it in player.inventory.items:
                        if len(it) > 2 and it[2].get("slot_idx") == dest_slot_idx:
                            dest_item = it
                            break
                            
                    if dest_item:
                        dest_item[2]["slot_idx"] = self.drag_source_idx if self.drag_source == "inventory" else player.inventory._get_first_free_slot()
                        item_meta["slot_idx"] = dest_slot_idx
                        player.inventory.items.append((item_name, count, item_meta))
                    else:
                        item_meta["slot_idx"] = dest_slot_idx
                        player.inventory.items.append((item_name, count, item_meta))
                    dropped = True

        if not dropped:
            # 롤백 처리
            if is_backpack_unequip:
                player.inventory.slots = 24
                data = ITEM_DATABASE.get(item_name, {})
                player.inventory.max_weight = 15.0 + data.get("weight_bonus", 15.0)
                for it in orig_backpack_items:
                    player.inventory.items.append(it)
                player.equipped_backpack_meta = orig_equipped_meta
            self._cancel_drag(player)
            return

        self.dragging = False
        self.drag_item = None
        self.drag_source = None
        self.drag_source_idx = -1
        self.selected_item = None

    def _cancel_drag(self, player):
        self.dragging = False
        self.drag_item = None
        self.drag_source = None
        self.drag_source_idx = -1

    def _handle_register_dialog_event(self, event, player):
        """플리마켓 등록 팝업 이벤트 처리"""
        if event.type == pygame.MOUSEBUTTONDOWN and event.button == 1:
            mx, my = event.pos
            dialog_w, dialog_h = 320, 200
            dx = (self.sw - dialog_w) // 2
            dy = (self.sh - dialog_h) // 2

            # 등록 버튼 클릭
            if dx + 40 <= mx <= dx + 140 and dy + 140 <= my <= dy + 175:
                if self.register_price_input.isdigit() and int(self.register_price_input) > 0:
                    price = int(self.register_price_input)
                    source, idx, name = self.register_target_item
                    
                    # 아이템 개수 가져오기
                    inv = player.stash if source == "stash" else player.inventory
                    if idx < len(inv.items):
                        item_tup = copy.deepcopy(inv.items[idx])
                        item_name, count = item_tup[0], item_tup[1]
                        if self.flea_market.register_item(copy.deepcopy(item_name), copy.deepcopy(count), price):
                            inv.remove_item(copy.deepcopy(item_name), copy.deepcopy(count))
                            self._add_log(player, f"플리마켓에 {item_name} {count}개 등록 완료!")
                    
                    self.show_register_dialog = False
                    self.register_price_input = ""
                    self.register_target_item = None
            # 취소 버튼 클릭
            elif dx + 180 <= mx <= dx + 280 and dy + 140 <= my <= dy + 175:
                self.show_register_dialog = False
                self.register_price_input = ""
                self.register_target_item = None

        elif event.type == pygame.KEYDOWN:
            if event.key == pygame.K_ESCAPE:
                self.show_register_dialog = False
                self.register_price_input = ""
                self.register_target_item = None
            elif event.key == pygame.K_BACKSPACE:
                self.register_price_input = self.register_price_input[:-1]
            elif event.unicode and event.unicode.isdigit() and len(self.register_price_input) < 8:
                self.register_price_input += event.unicode
                
        return None

    def _handle_tab_clicks(self, mx, my, player):
        """각 탭 내부의 클릭 비즈니스 로직"""
        # === 1. STASH 탭 클릭 ===
        if self.active_tab == "stash":
            # 인벤토리 정렬 버튼 클릭 (160 <= mx <= 215, 220 <= my <= 240)
            if 160 <= mx <= 215 and 220 <= my <= 240:
                player.inventory.auto_sort()
                self.selected_item = None
                return None

            # Stash 정렬 버튼 클릭 (stash_start_x + 280 <= mx <= stash_start_x + 335, stash_start_y - 35 <= my <= stash_start_y - 15)
            stash_start_x = self.sw // 2 + 10
            stash_start_y = 110
            if stash_start_x + 280 <= mx <= stash_start_x + 335 and stash_start_y - 35 <= my <= stash_start_y - 15:
                player.stash.auto_sort()
                self.selected_item = None
                return None
            # 인벤토리 슬롯 클릭 (좌측, 스크롤 반영)
            inv_start_x = 30
            inv_start_y = 250
            cols = 4
            for idx in range(player.inventory.slots):
                row = idx // cols
                col = idx % cols
                sx = inv_start_x + col * 42
                sy = inv_start_y + row * 42 - self.inv_scroll * 42
                if not (240 <= sy <= 570):
                    continue
                if sx <= mx <= sx + 38 and sy <= my <= sy + 38:
                    found_idx = -1
                    for i, it in enumerate(player.inventory.items):
                        if len(it) > 2 and it[2].get("slot_idx") == idx:
                            found_idx = i
                            break
                    if found_idx != -1:
                        name = player.inventory.items[found_idx][0]
                        self.selected_item = {"source": "inventory", "index": found_idx, "item_name": name, "slot_idx": idx}
                    else:
                        self.selected_item = None
                    return None

            # Stash 슬롯 클릭 (우측)
            stash_start_x = self.sw // 2 + 10
            stash_start_y = 110
            stash_cols = 8
            for idx in range(120):
                actual_idx = idx + self.stash_scroll * stash_cols
                row = idx // stash_cols
                col = idx % stash_cols
                sx = stash_start_x + col * 42
                sy = stash_start_y + row * 42
                if sx <= mx <= sx + 38 and sy <= my <= sy + 38:
                    found_idx = -1
                    for i, it in enumerate(player.stash.items):
                        if len(it) > 2 and it[2].get("slot_idx") == actual_idx:
                            found_idx = i
                            break
                    if found_idx != -1:
                        name = player.stash.items[found_idx][0]
                        self.selected_item = {"source": "stash", "index": found_idx, "item_name": name, "slot_idx": actual_idx}
                    else:
                        self.selected_item = None
                    return None

            # 장비창 슬롯 클릭 (좌측 상단)
            eq_slots = {"head": (30, 95), "body": (30, 137), "feet": (30, 179), "weapon": (120, 110), "back": (120, 155)}
            for slot, (ex, ey) in eq_slots.items():
                if ex <= mx <= ex + 38 and ey <= my <= ey + 38:
                    item_name = player.equipped.get(slot)
                    if item_name:
                        self.selected_item = {"source": "equipped", "slot_name": slot, "item_name": item_name}
                    else:
                        self.selected_item = None
                    return None

            # 기능성 버튼 처리
            if self.selected_item:
                src = self.selected_item["source"]
                # Stash -> Inventory
                if src == "stash" and 210 <= mx <= 350 and 80 <= my <= 115:
                    idx = self.selected_item["index"]
                    item_tup = copy.deepcopy(player.stash.items[idx])
                    name, count, meta = item_tup[0], item_tup[1], item_tup[2]
                    if player.inventory.add_item(copy.deepcopy(name), copy.deepcopy(count), copy.deepcopy(meta)):
                        player.stash.items.pop(idx)
                        self.selected_item = None
                # Inventory -> Stash
                elif src == "inventory" and 210 <= mx <= 350 and 80 <= my <= 115:
                    idx = self.selected_item["index"]
                    item_tup = copy.deepcopy(player.inventory.items[idx])
                    name, count, meta = item_tup[0], item_tup[1], item_tup[2]
                    if player.stash.add_item(copy.deepcopy(name), copy.deepcopy(count), copy.deepcopy(meta)):
                        player.inventory.items.pop(idx)
                        self.selected_item = None
                # 장비 착용
                elif src in ("stash", "inventory") and 210 <= mx <= 350 and 130 <= my <= 165:
                    idx = self.selected_item["index"]
                    inv = player.stash if src == "stash" else player.inventory
                    name, count, meta = copy.deepcopy(inv.items[idx])
                    data = ITEM_DATABASE.get(name, {})
                    slot = data.get("equip_slot")
                    if not slot and data.get("category") == ItemCategory.WEAPON:
                        slot = "weapon"
                    if slot:
                        slot_idx = meta.get("slot_idx")
                        if player.equip_item(copy.deepcopy(name), player.stash, slot_idx=slot_idx, source_inventory=inv):
                            self.selected_item = None
                # 장비 해제
                elif src == "equipped" and 210 <= mx <= 350 and 130 <= my <= 165:
                    slot = self.selected_item["slot_name"]
                    if player.unequip_item(slot, player.stash):
                        self.selected_item = None
                    else:
                        self._add_log(player, "인벤토리 공간이 부족하여 해제할 수 없습니다.")
                # 플리마켓 등록 다이얼로그 호출
                elif src in ("stash", "inventory") and 210 <= mx <= 350 and 180 <= my <= 215:
                    self.show_register_dialog = True
                    self.register_price_input = str(ITEM_DATABASE.get(self.selected_item["item_name"], {}).get("value", 1000))
                    self.register_target_item = (src, self.selected_item["index"], self.selected_item["item_name"])
                # 장비 개별 보험 가입
                elif src == "equipped" and 210 <= mx <= 350 and 410 <= my <= 445:
                    slot = self.selected_item["slot_name"]
                    name = player.equipped[slot]
                    if name and not player.equipped_insured.get(slot):
                        cost = int(ITEM_DATABASE.get(name, {}).get("value", 1000) * 0.1)
                        if player.rubles >= cost:
                            player.rubles -= cost
                            player.equipped_insured[slot] = True
                            self._add_log(player, f"[{name}]에 보험을 가입했습니다.")
                            SoundGenerator.play("craft_complete")

        # === 2. TRADERS 탭 클릭 ===
        elif self.active_tab == "traders":
            # 프라포 수리 버튼 클릭 판정
            if self.active_trader == "prapor" and not self.selected_shop_item:
                info_x = 450
                info_y = 180
                if info_x + 180 <= mx <= info_x + 280:
                    repairable_slots = ["head", "body", "weapon"]
                    for r_idx, r_slot in enumerate(repairable_slots):
                        ry = info_y + 195 + r_idx * 45
                        if ry - 3 <= my <= ry + 19:
                            eq_name = player.equipped.get(r_slot)
                            if eq_name:
                                dur = player.equipped_durability.get(r_slot, 100.0)
                                base_val = ITEM_DATABASE.get(eq_name, {}).get("value", 1000)
                                cost = int(base_val * (1.0 - dur / 100.0) * 1.2)
                                if cost > 0 and player.rubles >= cost:
                                    player.rubles -= cost
                                    player.equipped_durability[r_slot] = 100.0
                                    player.spent_money["prapor"] = player.spent_money.get("prapor", 0) + cost
                                    self._add_log(player, f"[{eq_name}]을(를) {cost}루블에 수리했습니다.")
                                    SoundGenerator.play("craft_complete")

            # 상인 탭 전환
            for i, tid in enumerate(self.traders.keys()):
                tx = 30 + i * 140
                ty = 80
                if tx <= mx <= tx + 120 and ty <= my <= ty + 30:
                    self.active_trader = tid
                    self.selected_shop_item = None
                    return None
            
            # 구매/판매 서브 탭 전환
            if 30 <= mx <= 120 and 130 <= my <= 160:
                self.trader_sub_tab = "buy"
                self.selected_shop_item = None
            elif 135 <= mx <= 225 and 130 <= my <= 160:
                self.trader_sub_tab = "sell"
                self.selected_shop_item = None

            # 상인 상점 목록 클릭
            if self.trader_sub_tab == "buy":
                # 상인이 판매하는 아이템 목록 (Loyalty Level에 따름)
                items_to_sell = self._get_trader_items(self.active_trader, player)
                list_y = 180
                for idx, (item_name, price) in enumerate(items_to_sell):
                    ay = list_y + idx * 45 - self.trader_scroll * 45
                    if 180 <= ay <= self.sh - 80:
                        if 30 <= mx <= 420 and ay <= my <= ay + 40:
                            self.selected_shop_item = {"name": item_name, "price": price, "action": "buy", "buy_count": 1}
                            return None
            else:
                # 플레이어 창고(Stash) 아이템을 상인에게 즉시 판매
                list_y = 180
                for idx, item_tup in enumerate(player.stash.items):
                    item_name, count = item_tup[0], item_tup[1]
                    ay = list_y + idx * 45 - self.trader_scroll * 45
                    if 180 <= ay <= self.sh - 80:
                        if 30 <= mx <= 420 and ay <= my <= ay + 40:
                            # 기본 가격의 50% 수준으로 상인이 즉시 매입
                            price = int(ITEM_DATABASE.get(item_name, {}).get("value", 1000) * 0.5)
                            self.selected_shop_item = {"name": item_name, "price": price, "action": "sell", "index": idx}
                            return None

            # 상점 거래 버튼 클릭
            if self.selected_shop_item:
                action = self.selected_shop_item["action"]
                item_name = self.selected_shop_item["name"]
                price = self.selected_shop_item["price"]
                
                # 상인 아이템 구매
                if action == "buy":
                    info_x = 450
                    info_y = 180
                    # [-] 버튼 클릭 검사
                    if info_x + 180 <= mx <= info_x + 205 and info_y + 258 <= my <= info_y + 283:
                        self.selected_shop_item["buy_count"] = max(1, self.selected_shop_item.get("buy_count", 1) - 1)
                        self.btn_hold_action = "minus"
                        self.btn_hold_timer = 0.0
                        return None
                    # [+] 버튼 클릭 검사
                    if info_x + 245 <= mx <= info_x + 270 and info_y + 258 <= my <= info_y + 283:
                        self.selected_shop_item["buy_count"] = min(30, self.selected_shop_item.get("buy_count", 1) + 1)
                        self.btn_hold_action = "plus"
                        self.btn_hold_timer = 0.0
                        return None
                        
                    if 470 <= mx <= 730 and 490 <= my <= 525:
                        count = self.selected_shop_item.get("buy_count", 1)
                        total_price = price * count
                        if player.rubles >= total_price:
                            if player.stash.add_item(copy.deepcopy(item_name), count):
                                player.rubles -= total_price
                                # 누적 거래액 증가
                                player.spent_money[self.active_trader] = player.spent_money.get(self.active_trader, 0) + total_price
                                # 우호도 소폭 상승 (0.01)
                                player.reputation[self.active_trader] = min(1.0, player.reputation.get(self.active_trader, 0) + 0.005)
                                self._add_log(player, f"{item_name} {count}개를 {total_price}루블에 구매했습니다.")
                                self.selected_shop_item = None
                            else:
                                self._add_log(player, "Stash 창고가 가득 찼습니다.")
                        else:
                            self._add_log(player, "루블이 부족합니다.")
                
                # 내 Stash 아이템 상인 판매
                elif action == "sell" and 470 <= mx <= 730 and 490 <= my <= 525:
                    idx = self.selected_shop_item["index"]
                    if idx < len(player.stash.items):
                        item_tup = copy.deepcopy(player.stash.items[idx])
                        name, count = item_tup[0], item_tup[1]
                        if name == item_name:
                            # 1개씩 판매
                            player.stash.remove_item(copy.deepcopy(name), 1)
                            player.rubles += price
                            player.spent_money[self.active_trader] = player.spent_money.get(self.active_trader, 0) + price
                            self._add_log(player, f"{name} 1개를 {price}루블에 판매했습니다.")
                            self.selected_shop_item = None

        # === 3. FLEA MARKET 탭 클릭 ===
        elif self.active_tab == "market":
            # 가상 플리마켓 목록 클릭
            list_y = 100
            for idx, listing in enumerate(self.flea_market.listings):
                ay = list_y + idx * 45 - self.market_scroll * 45
                if 100 <= ay <= self.sh - 80:
                    if 30 <= mx <= 500 and ay <= my <= ay + 40:
                        self.selected_shop_item = {
                            "name": listing["item_name"],
                            "price": listing["price"],
                            "count": listing["count"],
                            "id": listing["id"],
                            "action": "market_buy"
                        }
                        return None

            # 플리마켓 구매 처리
            if self.selected_shop_item and self.selected_shop_item["action"] == "market_buy":
                if 540 <= mx <= 680 and 200 <= my <= 235:
                    price = self.selected_shop_item["price"]
                    count = self.selected_shop_item["count"]
                    name = self.selected_shop_item["name"]
                    lid = self.selected_shop_item["id"]
                    
                    # 마켓 매물이 여전히 존재하는지 검사
                    match_listing = None
                    for listing in self.flea_market.listings:
                        if listing["id"] == lid:
                            match_listing = listing
                            break
                            
                    if match_listing:
                        total_cost = price * count
                        if player.rubles >= total_cost:
                            # Stash에 추가
                            if player.stash.add_item(copy.deepcopy(name), copy.deepcopy(count)):
                                player.rubles -= total_cost
                                self.flea_market.listings.remove(match_listing)
                                self._add_log(player, f"플리마켓에서 {name} {count}개를 {total_cost}루블에 낙찰했습니다.")
                                self.selected_shop_item = None
                            else:
                                self._add_log(player, "Stash 창고가 가득 찼습니다.")
                        else:
                            self._add_log(player, "루블이 부족합니다.")
                    else:
                        self._add_log(player, "이미 다른 바이어가 사간 매물입니다.")
                        self.selected_shop_item = None

        # === 4. RAID 탭 클릭 ===
        elif self.active_tab == "raid":
            # "레이드 진입" 버튼 클릭
            panel_w = 400
            panel_h = 350
            px = (self.sw - panel_w) // 2
            py = (self.sh - panel_h) // 2
            
            # 일괄 보험 가입 버튼 클릭 판정
            ins_btn_w, ins_btn_h = 240, 35
            ins_bx = px + (panel_w - ins_btn_w) // 2
            ins_by = py + panel_h - 130
            if ins_bx <= mx <= ins_bx + ins_btn_w and ins_by <= my <= ins_by + ins_btn_h:
                total_cost = 0
                to_insure = []
                for slot, name in player.equipped.items():
                    if name and not player.equipped_insured.get(slot):
                        cost = int(ITEM_DATABASE.get(name, {}).get("value", 1000) * 0.1)
                        total_cost += cost
                        to_insure.append(slot)
                if total_cost > 0 and player.rubles >= total_cost:
                    player.rubles -= total_cost
                    for slot in to_insure:
                        player.equipped_insured[slot] = True
                    self._add_log(player, f"총 {total_cost}루블을 소모해 모든 장비의 보험에 가입했습니다.")
                    SoundGenerator.play("craft_complete")

            btn_w, btn_h = 240, 50
            bx = px + (panel_w - btn_w) // 2
            by = py + panel_h - 75
            if bx <= mx <= bx + btn_w and by <= my <= by + btn_h:
                # main.py 씬 전환 기동
                return "start_raid"

        return None

    def draw(self, surface, player):
        surface.fill((10, 12, 20))

        # 그라데이션 오버레이
        for y in range(self.sh):
            t_val = y / self.sh
            pygame.draw.line(surface, (15 + int(5 * t_val), 18 + int(8 * t_val), 28 + int(12 * t_val)), (0, y), (self.sw, y))

        font_btn = FontManager.get(13)
        font_title = FontManager.get(16)
        font_desc = FontManager.get(11)

        # 상단 우측 플레이어 루블 및 레벨 정보 표시
        info_font = FontManager.get(14)
        ruble_text = info_font.render(f"자금: {player.rubles:,} {t('ruble')}", True, (255, 215, 0))
        level_text = info_font.render(f"레벨: {player.level} (XP: {player.xp})", True, (150, 200, 255))
        surface.blit(ruble_text, (self.sw - ruble_text.get_width() - 20, 15))
        surface.blit(level_text, (self.sw - level_text.get_width() - 20, 35))

        # 1. 탭 버튼 그리기
        for i, tab in enumerate(self.tabs):
            tx = 20 + i * 130
            ty = 15
            tw, th = 120, 35
            is_active = tab == self.active_tab
            
            color = (35, 45, 65, 200) if not is_active else Colors.UI_ACCENT + (60,)
            border_color = Colors.UI_BORDER if not is_active else Colors.UI_ACCENT
            text_color = Colors.UI_TEXT_DIM if not is_active else Colors.UI_TEXT
            
            draw_rounded_rect(surface, color, (tx, ty, tw, th), radius=6)
            pygame.draw.rect(surface, border_color, (tx, ty, tw, th), 1, border_radius=6)
            
            label_map = {"stash": "창고 정리", "traders": "상인 거래", "market": "가상 플리마켓", "raid": "레이드 진입"}
            tab_label = font_btn.render(label_map.get(tab, tab), True, text_color)
            surface.blit(tab_label, (tx + (tw - tab_label.get_width()) // 2, ty + (th - tab_label.get_height()) // 2))

        # 2. 활성화된 탭 내용 렌더링
        if self.active_tab == "stash":
            self._draw_stash_tab(surface, player)
        elif self.active_tab == "traders":
            self._draw_traders_tab(surface, player)
        elif self.active_tab == "market":
            self._draw_market_tab(surface, player)
        elif self.active_tab == "raid":
            self._draw_raid_tab(surface, player)

        # 3. 플리마켓 등록 팝업 렌더링
        if self.show_register_dialog:
            self._draw_register_dialog(surface)

    def _draw_stash_tab(self, surface, player):
        """Stash 정리 탭 렌더링"""
        font = FontManager.get(13)
        font_small = FontManager.get(11)

        # 1. 플레이어 장비 슬롯 (좌측 상단)
        draw_rounded_rect(surface, (15, 18, 28, 120), (20, 70, 200, 145), radius=6)
        pygame.draw.rect(surface, Colors.UI_BORDER, (20, 70, 200, 145), 1, border_radius=6)
        
        eq_label = FontManager.get(12).render("장착 장비", True, Colors.UI_ACCENT)
        surface.blit(eq_label, (30, 75))

        # 장착 슬롯들
        eq_slots = {
            "head": (30, 95, "머리"),
            "body": (30, 137, "상체"),
            "feet": (30, 179, "신발"),
            "weapon": (120, 110, "무기"),
            "back": (120, 155, "가방")
        }
        for slot, (ex, ey, s_name) in eq_slots.items():
            draw_rounded_rect(surface, (25, 28, 38, 200), (ex, ey, 38, 38), radius=4)
            pygame.draw.rect(surface, Colors.UI_BORDER, (ex, ey, 38, 38), 1, border_radius=4)
            
            item_name = player.equipped.get(slot)
            if item_name:
                icon = ItemIconRenderer.get_icon(item_name)
                surface.blit(icon, (ex + 3, ey + 3))
            else:
                s_surf = font_small.render(s_name, True, (80, 85, 95))
                surface.blit(s_surf, (ex + (38 - s_surf.get_width()) // 2, ey + (38 - s_surf.get_height()) // 2))

        # 2. 플레이어 가방 인벤토리 (좌측 하단)
        draw_rounded_rect(surface, (15, 18, 28, 120), (20, 220, 200, 360), radius=6)
        pygame.draw.rect(surface, Colors.UI_BORDER, (20, 220, 200, 360), 1, border_radius=6)
        
        inv_label = FontManager.get(12).render(f"보안 & 가방 인벤토리 ({len(player.inventory.items)}/{player.inventory.slots})", True, Colors.UI_ACCENT)
        surface.blit(inv_label, (30, 225))
        
        # 인벤토리 정렬 버튼 그리기
        draw_rounded_rect(surface, (40, 50, 70, 180), (160, 222, 55, 18), radius=3)
        pygame.draw.rect(surface, Colors.UI_BORDER, (160, 222, 55, 18), 1, border_radius=3)
        btn_text = FontManager.get(9).render("정렬", True, Colors.UI_TEXT)
        surface.blit(btn_text, (160 + (55 - btn_text.get_width()) // 2, 222 + (18 - btn_text.get_height()) // 2))

        inv_start_x = 30
        inv_start_y = 250
        cols = 4
        
        # 가방 영역 클리핑 셋업 (20, 245, 200, 330)
        clip_rect = pygame.Rect(20, 245, 200, 330)
        old_clip = surface.get_clip()
        surface.set_clip(clip_rect)
        
        for idx in range(player.inventory.slots):
            row = idx // cols
            col = idx % cols
            sx = inv_start_x + col * 42
            sy = inv_start_y + row * 42 - self.inv_scroll * 42
            
            draw_rounded_rect(surface, (25, 28, 38, 200), (sx, sy, 38, 38), radius=4)
            pygame.draw.rect(surface, Colors.UI_BORDER, (sx, sy, 38, 38), 1, border_radius=4)

            if self.selected_item and self.selected_item["source"] == "inventory" and self.selected_item["index"] == idx:
                pygame.draw.rect(surface, Colors.UI_ACCENT, (sx - 1, sy - 1, 40, 40), 2, border_radius=4)

            found_item = None
            for i, it in enumerate(player.inventory.items):
                if len(it) > 2 and it[2].get("slot_idx") == idx:
                    found_item = it
                    break

            if found_item is not None:
                name, count = found_item[0], found_item[1]
                is_dragged = self.dragging and self.drag_source == "inventory" and self.drag_source_idx == idx
                if not is_dragged:
                    icon = ItemIconRenderer.get_icon(name)
                    surface.blit(icon, (sx + 3, sy + 3))
                    
                    if count > 1:
                        c_surf = font_small.render(str(count), True, Colors.WHITE)
                        surface.blit(c_surf, (sx + 36 - c_surf.get_width(), sy + 24))
        
        surface.set_clip(old_clip)

        # 가방 인벤토리 세로 스크롤바
        max_inv_scroll = max(0, math.ceil(player.inventory.slots / 4) - 8)
        if max_inv_scroll > 0:
            track_x = 203
            track_y = 250
            track_h = 320
            pygame.draw.rect(surface, (30, 32, 42, 100), (track_x, track_y, 4, track_h), border_radius=2)
            thumb_h = max(20, int(track_h * (8 / math.ceil(player.inventory.slots / 4))))
            thumb_y = track_y + int((track_h - thumb_h) * (self.inv_scroll / max_inv_scroll))
            pygame.draw.rect(surface, Colors.UI_ACCENT, (track_x, thumb_y, 4, thumb_h), border_radius=2)

        # 3. 영구 창고 Stash 그리드 (우측)
        stash_start_x = self.sw // 2 + 10
        stash_start_y = 110
        stash_cols = 8
        stash_rows = 11
        
        draw_rounded_rect(surface, (15, 18, 28, 120), (stash_start_x - 10, stash_start_y - 40, 355, 495), radius=6)
        pygame.draw.rect(surface, Colors.UI_BORDER, (stash_start_x - 10, stash_start_y - 40, 355, 495), 1, border_radius=6)
        
        stash_label = FontManager.get(13).render(f"보관 창고 (Global Stash) (휠 스크롤 지원)", True, Colors.UI_ACCENT_WARM)
        surface.blit(stash_label, (stash_start_x, stash_start_y - 30))

        # Stash 정렬 버튼 그리기
        draw_rounded_rect(surface, (40, 50, 70, 180), (stash_start_x + 280, stash_start_y - 35, 55, 18), radius=3)
        pygame.draw.rect(surface, Colors.UI_BORDER, (stash_start_x + 280, stash_start_y - 35, 55, 18), 1, border_radius=3)
        btn_text2 = FontManager.get(9).render("정렬", True, Colors.UI_TEXT)
        surface.blit(btn_text2, (stash_start_x + 280 + (55 - btn_text2.get_width()) // 2, stash_start_y - 35 + (18 - btn_text2.get_height()) // 2))

        for idx in range(stash_cols * stash_rows):
            actual_idx = idx + self.stash_scroll * stash_cols
            row = idx // stash_cols
            col = idx % stash_cols
            sx = stash_start_x + col * 42
            sy = stash_start_y + row * 42
            
            draw_rounded_rect(surface, (25, 28, 38, 200), (sx, sy, 38, 38), radius=4)
            pygame.draw.rect(surface, Colors.UI_BORDER, (sx, sy, 38, 38), 1, border_radius=4)

            if self.selected_item and self.selected_item["source"] == "stash" and self.selected_item["index"] == actual_idx:
                pygame.draw.rect(surface, Colors.UI_ACCENT, (sx - 1, sy - 1, 40, 40), 2, border_radius=4)

            found_item = None
            for it in player.stash.items:
                if len(it) > 2 and it[2].get("slot_idx") == actual_idx:
                    found_item = it
                    break

            if found_item is not None:
                name, count = found_item[0], found_item[1]
                is_dragged = self.dragging and self.drag_source == "stash" and self.drag_source_idx == actual_idx
                if not is_dragged:
                    icon = ItemIconRenderer.get_icon(name)
                    surface.blit(icon, (sx + 3, sy + 3))
                    if count > 1:
                        c_surf = font_small.render(str(count), True, Colors.WHITE)
                        surface.blit(c_surf, (sx + 36 - c_surf.get_width(), sy + 24))

        # 4. 중앙 아이템 상세 정보 및 기능 액션 패널
        info_x = 240
        info_y = 70
        draw_rounded_rect(surface, (15, 18, 28, 150), (info_x, info_y, 160, 510), radius=6)
        pygame.draw.rect(surface, Colors.UI_BORDER, (info_x, info_y, 160, 510), 1, border_radius=6)

        if self.selected_item:
            item_name = self.selected_item["item_name"]
            data = ITEM_DATABASE.get(item_name, {})
            src = self.selected_item["source"]
            
            # 아이템 아이콘 및 라벨
            large_icon = ItemIconRenderer.get_icon(item_name)
            surface.blit(large_icon, (info_x + 64, info_y + 15))
            
            name_surf = font.render(item_name, True, Colors.UI_TEXT)
            surface.blit(name_surf, (info_x + (160 - name_surf.get_width()) // 2, info_y + 55))
            
            # 카테고리/설명
            cat_surf = font_small.render(f"분류: {data.get('category', '기타')}", True, Colors.UI_TEXT_DIM)
            surface.blit(cat_surf, (info_x + 15, info_y + 80))
            
            val_surf = font_small.render(f"시세: {data.get('value', 1000):,} {t('ruble')}", True, (255, 215, 0))
            surface.blit(val_surf, (info_x + 15, info_y + 98))

            desc_start_y = 120
            # 내구도 및 보험 정보 표시 (장착품인 경우)
            if src == "equipped":
                slot = self.selected_item["slot_name"]
                dur = player.equipped_durability.get(slot, 100.0)
                dur_surf = font_small.render(f"내구도: {int(dur)}/100", True, (100, 255, 100) if dur > 20 else (255, 100, 100))
                surface.blit(dur_surf, (info_x + 15, info_y + 115))
                
                insured = player.equipped_insured.get(slot, False)
                ins_surf = font_small.render("보험: 가입완료" if insured else "보험: 미가입", True, (100, 255, 150) if insured else (180, 180, 180))
                surface.blit(ins_surf, (info_x + 15, info_y + 130))
                desc_start_y = 150

            # 설명 개행 처리
            desc = data.get("description", "")
            desc_lines = []
            for i in range(0, len(desc), 12):
                desc_lines.append(desc[i:i+12])
            for idx, d_line in enumerate(desc_lines[:6]):
                l_surf = font_small.render(d_line, True, (130, 135, 145))
                surface.blit(l_surf, (info_x + 15, info_y + desc_start_y + idx * 15))

            # 버튼: 이동 (Stash <-> Inventory)
            btn_color = Colors.UI_ACCENT + (40,)
            btn_lbl = "창고로 이동" if src == "inventory" else "가방으로 이동"
            if src == "equipped":
                btn_lbl = "해제 불가"
            
            if src != "equipped":
                draw_rounded_rect(surface, btn_color, (info_x + 10, info_y + 260, 140, 35), radius=6)
                pygame.draw.rect(surface, Colors.UI_ACCENT, (info_x + 10, info_y + 260, 140, 35), 1, border_radius=6)
                b_surf = font_small.render(btn_lbl, True, Colors.UI_TEXT)
                surface.blit(b_surf, (info_x + 10 + (140 - b_surf.get_width()) // 2, info_y + 270))

            # 버튼: 장착 / 해제
            is_equipable = "equip_slot" in data or data.get("category") == ItemCategory.WEAPON
            if is_equipable or src == "equipped":
                eq_btn_lbl = "장착하기" if src != "equipped" else "장착 해제"
                draw_rounded_rect(surface, (200, 120, 50, 40), (info_x + 10, info_y + 310, 140, 35), radius=6)
                pygame.draw.rect(surface, (200, 120, 50), (info_x + 10, info_y + 310, 140, 35), 1, border_radius=6)
                eq_surf = font_small.render(eq_btn_lbl, True, Colors.UI_TEXT)
                surface.blit(eq_surf, (info_x + 10 + (140 - eq_surf.get_width()) // 2, info_y + 320))

            # 버튼: 플리마켓 등록 (equipped가 아닐 때)
            if src in ("stash", "inventory"):
                draw_rounded_rect(surface, (50, 180, 120, 40), (info_x + 10, info_y + 360, 140, 35), radius=6)
                pygame.draw.rect(surface, (50, 180, 120), (info_x + 10, info_y + 360, 140, 35), 1, border_radius=6)
                m_surf = font_small.render("플리마켓 등록", True, Colors.UI_TEXT)
                surface.blit(m_surf, (info_x + 10 + (140 - m_surf.get_width()) // 2, info_y + 370))

            # 보험 가입 버튼 (equipped)
            if src == "equipped":
                slot = self.selected_item["slot_name"]
                insured = player.equipped_insured.get(slot, False)
                if insured:
                    draw_rounded_rect(surface, (40, 55, 45), (info_x + 10, info_y + 410, 140, 35), radius=6)
                    ins_btn_lbl = font_small.render("보험 가입됨", True, (100, 220, 140))
                    surface.blit(ins_btn_lbl, (info_x + 10 + (140 - ins_btn_lbl.get_width()) // 2, info_y + 420))
                else:
                    cost = int(ITEM_DATABASE.get(item_name, {}).get("value", 1000) * 0.1)
                    draw_rounded_rect(surface, (100, 80, 40), (info_x + 10, info_y + 410, 140, 35), radius=6)
                    pygame.draw.rect(surface, (150, 120, 50), (info_x + 10, info_y + 410, 140, 35), 1, border_radius=6)
                    ins_btn_lbl = font_small.render(f"보험 {cost} {t('ruble')}", True, Colors.WHITE)
                    surface.blit(ins_btn_lbl, (info_x + 10 + (140 - ins_btn_lbl.get_width()) // 2, info_y + 420))
        else:
            empty_surf = font_small.render("아이템을 선택하면", True, Colors.UI_TEXT_DIM)
            empty_surf2 = font_small.render("상세 정보와 기능이", True, Colors.UI_TEXT_DIM)
            empty_surf3 = font_small.render("여기에 나타납니다.", True, Colors.UI_TEXT_DIM)
            surface.blit(empty_surf, (info_x + 30, info_y + 180))
            surface.blit(empty_surf2, (info_x + 30, info_y + 200))
            surface.blit(empty_surf3, (info_x + 30, info_y + 220))

        # 드래그 중인 아이템 마우스 커서에 표시
        if self.dragging and self.drag_item:
            drag_name, drag_count = self.drag_item[0], self.drag_item[1]
            drag_surf = pygame.Surface((120, 28), pygame.SRCALPHA)
            drag_surf.fill((40, 45, 60, 210))
            pygame.draw.rect(drag_surf, Colors.UI_ACCENT, (0, 0, 120, 28), 1, border_radius=4)
            d_icon = ItemIconRenderer.get_icon(drag_name)
            drag_surf.blit(d_icon, (2, -2))
            d_text = font_small.render(drag_name[:8], True, (255, 255, 200))
            drag_surf.blit(d_text, (36, 6))
            if drag_count > 1:
                c_text = font_small.render(f"x{drag_count}", True, (200, 200, 200))
                drag_surf.blit(c_text, (100, 6))
            surface.blit(drag_surf, (self.drag_mouse_x - 60, self.drag_mouse_y - 14))

    def _draw_traders_tab(self, surface, player):
        """상인 거래 탭 렌더링"""
        font = FontManager.get(13)
        font_small = FontManager.get(11)

        # 1. 상인 탭 버튼 목록
        for i, (tid, data) in enumerate(self.traders.items()):
            tx = 30 + i * 140
            ty = 80
            is_active = tid == self.active_trader
            
            t_color = (25, 30, 45, 180) if not is_active else Colors.UI_ACCENT + (50,)
            border = Colors.UI_BORDER if not is_active else Colors.UI_ACCENT
            draw_rounded_rect(surface, t_color, (tx, ty, 130, 32), radius=5)
            pygame.draw.rect(surface, border, (tx, ty, 130, 32), 1, border_radius=5)
            
            lbl_surf = font.render(data["name"].split(" ")[0], True, Colors.UI_TEXT if is_active else Colors.UI_TEXT_DIM)
            surface.blit(lbl_surf, (tx + (130 - lbl_surf.get_width()) // 2, ty + 7))

        # 2. 거래 유형 (구매 / 판매) 서브 탭
        sub_tab_y = 130
        for i, sub in enumerate(["buy", "sell"]):
            is_active = sub == self.trader_sub_tab
            color = Colors.UI_ACCENT if is_active else Colors.UI_TEXT_DIM
            text = "아이템 구매" if sub == "buy" else "아이템 즉시 판매"
            surf = font.render(text, True, color)
            
            sx = 30 + i * 105
            surface.blit(surf, (sx, sub_tab_y))
            if is_active:
                pygame.draw.line(surface, Colors.UI_ACCENT, (sx, sub_tab_y + 20), (sx + surf.get_width(), sub_tab_y + 20), 2)

        # 3. 우측에 거래소 상세 정보 표시 (우호도, 거래 누적액, 거래 등급)
        info_x = 450
        info_y = 180
        draw_rounded_rect(surface, (15, 18, 28, 150), (info_x, info_y, 300, 360), radius=6)
        pygame.draw.rect(surface, Colors.UI_BORDER, (info_x, info_y, 300, 360), 1, border_radius=6)

        trader_data = self.traders[self.active_trader]
        rep = player.reputation.get(self.active_trader, 0.2)
        spent = player.spent_money.get(self.active_trader, 0)
        
        # 거래 등급(Loyalty Level) 산출
        lvl = 1
        if player.level >= 15 and rep >= 0.70 and spent >= 200000:
            lvl = 3
        elif player.level >= 5 and rep >= 0.40 and spent >= 50000:
            lvl = 2

        name_surf = FontManager.get(15).render(trader_data["name"], True, Colors.UI_ACCENT)
        surface.blit(name_surf, (info_x + 20, info_y + 15))
        
        desc_surf = font_small.render(trader_data["desc"], True, (130, 135, 145))
        surface.blit(desc_surf, (info_x + 20, info_y + 40))

        # 스탯 바
        pygame.draw.line(surface, (50, 55, 70), (info_x + 20, info_y + 65), (info_x + 280, info_y + 65), 1)
        
        rep_surf = font.render(f"우호도(Reputation): {rep:.2f}", True, Colors.UI_SUCCESS)
        spent_surf = font.render(f"누적 거래액(Spent): {spent:,} {t('ruble')}", True, (255, 215, 0))
        lvl_surf = FontManager.get(14).render(f"상인 신용 등급: Loyalty Level {lvl}", True, Colors.UI_ACCENT_WARM)
        
        surface.blit(rep_surf, (info_x + 20, info_y + 80))
        surface.blit(spent_surf, (info_x + 20, info_y + 105))
        surface.blit(lvl_surf, (info_x + 20, info_y + 130))

        # 다음 레벨 해금 조건
        if lvl < 3:
            req_lvl = lvl + 1
            reqs = self.loyalty_reqs[req_lvl]
            r_text = f"Level {req_lvl} 해금 조건:"
            r_lvl = f"  - 플레이어 레벨: {player.level} / {reqs['level']}"
            r_rep = f"  - 상인 우호도: {rep:.2f} / {reqs['rep']:.2f}"
            r_spent = f"  - 누적 거래액: {spent:,} / {reqs['spent']:,} {t('ruble')}"
            
            surface.blit(font_small.render(r_text, True, Colors.UI_TEXT_DIM), (info_x + 20, info_y + 165))
            surface.blit(font_small.render(r_lvl, True, Colors.UI_SUCCESS if player.level >= reqs["level"] else Colors.UI_TEXT_DIM), (info_x + 20, info_y + 185))
            surface.blit(font_small.render(r_rep, True, Colors.UI_SUCCESS if rep >= reqs["rep"] else Colors.UI_TEXT_DIM), (info_x + 20, info_y + 200))
            surface.blit(font_small.render(r_spent, True, Colors.UI_SUCCESS if spent >= reqs["spent"] else Colors.UI_TEXT_DIM), (info_x + 20, info_y + 215))

        # 선택 아이템 거래 버튼
        if self.selected_shop_item:
            s_item = self.selected_shop_item
            pygame.draw.line(surface, (50, 55, 70), (info_x + 20, info_y + 245), (info_x + 280, info_y + 245), 1)
            
            s_name_surf = font.render(f"선택: {s_item['name']}", True, Colors.UI_TEXT)
            
            if s_item.get("action") == "buy":
                count = s_item.get("buy_count", 1)
                total_price = s_item['price'] * count
                s_price_surf = FontManager.get(14).render(f"합계: {total_price:,} {t('ruble')}", True, (255, 215, 0))
                
                # 수량 조절 UI 그리기
                cnt_lbl = font.render("수량:", True, Colors.UI_TEXT_DIM)
                surface.blit(cnt_lbl, (info_x + 140, info_y + 260))
                
                # [-] 버튼
                draw_rounded_rect(surface, (50, 55, 70), (info_x + 180, info_y + 258, 25, 25), radius=4)
                minus_surf = font.render("-", True, Colors.WHITE)
                surface.blit(minus_surf, (info_x + 180 + (25 - minus_surf.get_width())//2, info_y + 258 + (25 - minus_surf.get_height())//2))
                
                # 수량 표시
                c_val = font.render(str(count), True, Colors.WHITE)
                surface.blit(c_val, (info_x + 215 + (20 - c_val.get_width())//2, info_y + 260))
                
                # [+] 버튼
                draw_rounded_rect(surface, (50, 55, 70), (info_x + 245, info_y + 258, 25, 25), radius=4)
                plus_surf = font.render("+", True, Colors.WHITE)
                surface.blit(plus_surf, (info_x + 245 + (25 - plus_surf.get_width())//2, info_y + 258 + (25 - plus_surf.get_height())//2))
            else:
                s_price_surf = FontManager.get(14).render(f"가격: {s_item['price']:,} {t('ruble')}", True, (255, 215, 0))
            
            surface.blit(s_name_surf, (info_x + 20, info_y + 260))
            surface.blit(s_price_surf, (info_x + 20, info_y + 280))

            # 거래 실행 버튼
            btn_lbl = "구매하기 (Stash 이송)" if s_item["action"] == "buy" else "즉시 판매하기"
            draw_rounded_rect(surface, Colors.UI_ACCENT + (40,), (info_x + 20, info_y + 310, 260, 35), radius=5)
            pygame.draw.rect(surface, Colors.UI_ACCENT, (info_x + 20, info_y + 310, 260, 35), 1, border_radius=5)
            btn_surf = font.render(btn_lbl, True, Colors.UI_TEXT)
            surface.blit(btn_surf, (info_x + 20 + (260 - btn_surf.get_width()) // 2, info_y + 322))

        # 4. 상점 매물 목록 (좌측)
        list_x = 30
        list_y = 180
        list_w = 400
        list_h = 360
        
        draw_rounded_rect(surface, (15, 18, 28, 120), (list_x - 5, list_y - 5, list_w + 10, list_h + 10), radius=6)
        pygame.draw.rect(surface, Colors.UI_BORDER, (list_x - 5, list_y - 5, list_w + 10, list_h + 10), 1, border_radius=6)

        if self.trader_sub_tab == "buy":
            items_to_sell = self._get_trader_items(self.active_trader, player)
            for idx, (item_name, price) in enumerate(items_to_sell):
                ay = list_y + idx * 45 - self.trader_scroll * 45
                if list_y <= ay <= list_y + list_h - 40:
                    is_hover = self.selected_shop_item and self.selected_shop_item["name"] == item_name and self.selected_shop_item["action"] == "buy"
                    bg_color = (35, 45, 65, 180) if not is_hover else Colors.UI_ACCENT + (40,)
                    border = Colors.UI_BORDER if not is_hover else Colors.UI_ACCENT
                    
                    draw_rounded_rect(surface, bg_color, (list_x, ay, list_w, 40), radius=5)
                    pygame.draw.rect(surface, border, (list_x, ay, list_w, 40), 1, border_radius=5)

                    # 아이콘
                    icon = ItemIconRenderer.get_icon(item_name)
                    surface.blit(icon, (list_x + 5, ay + 4))

                    # 텍스트
                    t_surf = font.render(item_name, True, Colors.UI_TEXT)
                    surface.blit(t_surf, (list_x + 45, ay + 12))
                    
                    p_surf = font.render(f"{price:,} {t('ruble')}", True, (255, 215, 0))
                    surface.blit(p_surf, (list_x + list_w - p_surf.get_width() - 15, ay + 12))
        else:
            # Stash 인벤토리 판매 대상 목록
            for idx, item_tup in enumerate(player.stash.items):
                item_name, count = item_tup[0], item_tup[1]
                ay = list_y + idx * 45 - self.trader_scroll * 45
                if list_y <= ay <= list_y + list_h - 40:
                    is_hover = self.selected_shop_item and self.selected_shop_item["name"] == item_name and self.selected_shop_item["action"] == "sell" and self.selected_shop_item["index"] == idx
                    bg_color = (35, 45, 65, 180) if not is_hover else Colors.UI_ACCENT + (40,)
                    border = Colors.UI_BORDER if not is_hover else Colors.UI_ACCENT
                    
                    draw_rounded_rect(surface, bg_color, (list_x, ay, list_w, 40), radius=5)
                    pygame.draw.rect(surface, border, (list_x, ay, list_w, 40), 1, border_radius=5)

                    icon = ItemIconRenderer.get_icon(item_name)
                    surface.blit(icon, (list_x + 5, ay + 4))

                    t_surf = font.render(f"{item_name} x{count}", True, Colors.UI_TEXT)
                    surface.blit(t_surf, (list_x + 45, ay + 12))
                    
                    price = int(ITEM_DATABASE.get(item_name, {}).get("value", 1000) * 0.5)
                    p_surf = font.render(f"{price:,} {t('ruble')}", True, (255, 215, 0))
                    surface.blit(p_surf, (list_x + list_w - p_surf.get_width() - 15, ay + 12))

    def _get_trader_items(self, trader_id, player):
        """우호도 레벨에 따라 상인이 파는 물품 정의"""
        # 우호도 산출
        rep = player.reputation.get(trader_id, 0.2)
        spent = player.spent_money.get(trader_id, 0)
        lvl = 1
        if player.level >= 15 and rep >= 0.70 and spent >= 200000:
            lvl = 3
        elif player.level >= 5 and rep >= 0.40 and spent >= 50000:
            lvl = 2

        items = []
        if trader_id == "prapor":
            # 무기 및 군수품
            items.append(("탄약", 180))
            items.append(("나이프", 2500))
            items.append(("파이프", 1200))
            if lvl >= 2:
                items.append(("야구방망이", 4000))
                items.append(("권총", 16000))
                items.append(("방탄조끼", 14000))
            if lvl >= 3:
                items.append(("도끼", 6500))
                items.append(("레버액션 소총", 32000))
        elif trader_id == "therapist":
            # 의료 및 식량
            items.append(("생수", 500))
            items.append(("마른 빵", 350))
            items.append(("붕대", 700))
            if lvl >= 2:
                items.append(("식량통조림", 1100))
                items.append(("에너지바", 750))
                items.append(("구급상자", 3800))
                items.append(("진통제", 2300))
            if lvl >= 3:
                items.append(("고기 구이", 1400))
                items.append(("고급 치료킷", 7500))
                items.append(("전투 식량", 2800))
        elif trader_id == "fence":
            # 잡동사니 밀수
            items.append(("나무", 350))
            items.append(("못", 120))
            items.append(("천", 250))
            items.append(("고철", 450))
            if lvl >= 2:
                items.append(("가방", 8500))
                items.append(("방독면", 6500))
                items.append(("손전등", 2200))
                items.append(("비상용 배터리", 1600))
            if lvl >= 3:
                items.append(("라디오 부품", 5500))
                items.append(("기계 부품", 2800))
                items.append(("군사 문서", 22000))

        return items

    def _draw_market_tab(self, surface, player):
        """가상 플리마켓 탭 렌더링"""
        font = FontManager.get(13)
        font_small = FontManager.get(11)

        # 1. 플리마켓 등록 매물 목록 (좌측)
        list_x = 30
        list_y = 100
        list_w = 480
        list_h = 440
        
        draw_rounded_rect(surface, (15, 18, 28, 120), (list_x - 5, list_y - 5, list_w + 10, list_h + 10), radius=6)
        pygame.draw.rect(surface, Colors.UI_BORDER, (list_x - 5, list_y - 5, list_w + 10, list_h + 10), 1, border_radius=6)

        title_surf = FontManager.get(14).render("가상 플리마켓 실시간 매물 (휠 스크롤)", True, Colors.UI_ACCENT)
        surface.blit(title_surf, (list_x, list_y - 30))

        for idx, listing in enumerate(self.flea_market.listings):
            ay = list_y + idx * 45 - self.market_scroll * 45
            if list_y <= ay <= list_y + list_h - 40:
                is_hover = self.selected_shop_item and self.selected_shop_item["action"] == "market_buy" and self.selected_shop_item["id"] == listing["id"]
                bg_color = (35, 45, 65, 180) if not is_hover else Colors.UI_ACCENT + (40,)
                border = Colors.UI_BORDER if not is_hover else Colors.UI_ACCENT
                
                draw_rounded_rect(surface, bg_color, (list_x, ay, list_w, 40), radius=5)
                pygame.draw.rect(surface, border, (list_x, ay, list_w, 40), 1, border_radius=5)

                # 아이콘
                icon = ItemIconRenderer.get_icon(listing["item_name"])
                surface.blit(icon, (list_x + 5, ay + 4))

                # 이름 및 개수
                t_surf = font.render(f"{listing['item_name']} x{listing['count']}", True, Colors.UI_TEXT)
                surface.blit(t_surf, (list_x + 45, ay + 12))

                # 판매자 닉네임
                s_surf = font_small.render(f"판매자: {listing['seller']}", True, (110, 115, 125))
                surface.blit(s_surf, (list_x + 220, ay + 14))

                # 가격
                total_p = listing["price"] * listing["count"]
                p_surf = font.render(f"{total_p:,} {t('ruble')} ({listing['price']}{t('ruble')}/개)", True, (255, 215, 0))
                surface.blit(p_surf, (list_x + list_w - p_surf.get_width() - 15, ay + 12))

        # 2. 우측 결제/정산 패널
        info_x = 540
        info_y = 100
        draw_rounded_rect(surface, (15, 18, 28, 150), (info_x, info_y, 220, 240), radius=6)
        pygame.draw.rect(surface, Colors.UI_BORDER, (info_x, info_y, 220, 240), 1, border_radius=6)

        if self.selected_shop_item and self.selected_shop_item["action"] == "market_buy":
            s_item = self.selected_shop_item
            name_surf = font.render(f"매물: {s_item['name']}", True, Colors.UI_TEXT)
            cnt_surf = font_small.render(f"수량: {s_item['count']}개", True, Colors.UI_TEXT_DIM)
            cost = s_item["price"] * s_item["count"]
            cost_surf = FontManager.get(15).render(f"총 합계: {cost:,} {t('ruble')}", True, (255, 215, 0))
            
            surface.blit(name_surf, (info_x + 15, info_y + 20))
            surface.blit(cnt_surf, (info_x + 15, info_y + 45))
            surface.blit(cost_surf, (info_x + 15, info_y + 70))

            # 플리마켓 구매 단추
            draw_rounded_rect(surface, Colors.UI_ACCENT + (40,), (info_x + 15, info_y + 110, 190, 35), radius=5)
            pygame.draw.rect(surface, Colors.UI_ACCENT, (info_x + 15, info_y + 110, 190, 35), 1, border_radius=5)
            btn_surf = font.render("매물 낙찰받기", True, Colors.UI_TEXT)
            surface.blit(btn_surf, (info_x + 15 + (190 - btn_surf.get_width()) // 2, info_y + 120))
        else:
            empty_surf = font_small.render("매물을 클릭하면", True, Colors.UI_TEXT_DIM)
            empty_surf2 = font_small.render("여기에 낙찰 패널이", True, Colors.UI_TEXT_DIM)
            empty_surf3 = font_small.render("활성화됩니다.", True, Colors.UI_TEXT_DIM)
            surface.blit(empty_surf, (info_x + 30, info_y + 60))
            surface.blit(empty_surf2, (info_x + 30, info_y + 80))
            surface.blit(empty_surf3, (info_x + 30, info_y + 100))

        # 3. 우측 하단 내가 등록한 매물 및 거래 대기 수량 노출
        my_panel_y = 360
        draw_rounded_rect(surface, (15, 18, 28, 150), (info_x, my_panel_y, 220, 180), radius=6)
        pygame.draw.rect(surface, Colors.UI_BORDER, (info_x, my_panel_y, 220, 180), 1, border_radius=6)
        
        my_title = FontManager.get(12).render("내가 등록한 거래 대기열", True, Colors.UI_ACCENT_WARM)
        surface.blit(my_title, (info_x + 15, my_panel_y + 15))

        for idx, listing in enumerate(self.flea_market.player_listings[:3]):
            ly = my_panel_y + 40 + idx * 42
            item_text = font_small.render(f"{listing['item_name']} x{listing['count']} ({listing['price']:,} {t('ruble')})", True, Colors.UI_TEXT)
            time_text = font_small.render(f"남은 기한: {listing['timer']:.1f}", True, Colors.UI_TEXT_DIM)
            surface.blit(item_text, (info_x + 15, ly))
            surface.blit(time_text, (info_x + 15, ly + 15))
            
        if not self.flea_market.player_listings:
            no_list = font_small.render("등록한 보류 대기열이 없습니다.", True, (90, 95, 105))
            surface.blit(no_list, (info_x + 15, my_panel_y + 60))

    def _draw_raid_tab(self, surface, player):
        """레이드 진입 탭 렌더링"""
        font = FontManager.get(14)
        font_big = FontManager.get(22)
        font_desc = FontManager.get(12)

        # 중앙 레이아웃 패널
        panel_w = 400
        panel_h = 350
        px = (self.sw - panel_w) // 2
        py = (self.sh - panel_h) // 2

        draw_rounded_rect(surface, (15, 18, 28, 160), (px, py, panel_w, panel_h), radius=10)
        pygame.draw.rect(surface, Colors.UI_BORDER, (px, py, panel_w, panel_h), 1, border_radius=10)

        # 맵 기획 정보
        map_title = font_big.render("폐허 구역 (Ruin Area)", True, Colors.UI_ACCENT)
        surface.blit(map_title, (px + (panel_w - map_title.get_width()) // 2, py + 30))

        # 세부 설명
        descs = [
            "  - 예상 출현 AI: Scav, 가상 PMC 경쟁자",
            "  - 주요 전리품: 기계 부품, 소총 및 의료 자재",
            "  - 레이드 제한 시간: 10분 (MIA 시 무장 전량 분실)",
            "  - 탈출 위치: 맵 외곽 경계 구역 (도로, 검문소 등)",
        ]
        
        for idx, desc in enumerate(descs):
            surf = font_desc.render(desc, True, Colors.UI_TEXT)
            surface.blit(surf, (px + 40, py + 90 + idx * 25))

        # 주의사항
        warn_surf = FontManager.get(11).render("⚠️  경고: 사망하거나 탈출 실패 시 인레이드 장비를 모두 잃습니다.", True, Colors.UI_DANGER)
        surface.blit(warn_surf, (px + (panel_w - warn_surf.get_width()) // 2, py + 210))

        # "레이드 진입" 버튼
        btn_w, btn_h = 240, 50
        bx = px + (panel_w - btn_w) // 2
        by = py + panel_h - 75
        
        draw_rounded_rect(surface, (200, 50, 50, 50), (bx, by, btn_w, btn_h), radius=8)
        pygame.draw.rect(surface, (200, 50, 50), (bx, by, btn_w, btn_h), 2, border_radius=8)
        
        btn_surf = FontManager.get(16).render("레이드 매칭 진입", True, Colors.WHITE)
        surface.blit(btn_surf, (bx + (btn_w - btn_surf.get_width()) // 2, by + (btn_h - btn_surf.get_height()) // 2))

    def _draw_register_dialog(self, surface):
        """플리마켓 등록 팝업 렌더링"""
        dialog_w, dialog_h = 320, 200
        dx = (self.sw - dialog_w) // 2
        dy = (self.sh - dialog_h) // 2

        # 반투명 어두운 오버레이
        overlay = pygame.Surface((self.sw, self.sh), pygame.SRCALPHA)
        overlay.fill((0, 0, 0, 180))
        surface.blit(overlay, (0, 0))

        # 다이얼로그 본체
        draw_rounded_rect(surface, (20, 22, 35, 240), (dx, dy, dialog_w, dialog_h), radius=10)
        pygame.draw.rect(surface, Colors.UI_BORDER, (dx, dy, dialog_w, dialog_h), 2, border_radius=10)

        font = FontManager.get(14)
        font_small = FontManager.get(12)
        font_input = FontManager.get(16)

        title = font.render("플리마켓 등록 가격 입력", True, Colors.UI_ACCENT)
        surface.blit(title, (dx + (dialog_w - title.get_width()) // 2, dy + 20))

        # 아이템명
        source, idx, name = self.register_target_item
        name_surf = font_small.render(f"대상: {name}", True, Colors.UI_TEXT_DIM)
        surface.blit(name_surf, (dx + 40, dy + 55))

        # 입력 필드 박스
        pygame.draw.rect(surface, Colors.UI_BORDER, (dx + 40, dy + 85, 240, 32), 1, border_radius=5)
        
        input_text = self.register_price_input + f" {t('ruble')}" if self.register_price_input else f" {t('ruble')}"
        input_surf = font_input.render(input_text, True, (255, 215, 0))
        surface.blit(input_surf, (dx + 50, dy + 92))

        # 등록 버튼
        draw_rounded_rect(surface, (50, 180, 120, 40), (dx + 40, dy + 140, 100, 35), radius=6)
        pygame.draw.rect(surface, (50, 180, 120), (dx + 40, dy + 140, 100, 35), 1, border_radius=6)
        btn_reg = font_small.render("등록하기", True, Colors.UI_TEXT)
        surface.blit(btn_reg, (dx + 40 + (100 - btn_reg.get_width()) // 2, dy + 150))

        # 취소 버튼
        draw_rounded_rect(surface, (70, 75, 85, 120), (dx + 180, dy + 140, 100, 35), radius=6)
        pygame.draw.rect(surface, Colors.UI_BORDER, (dx + 180, dy + 140, 100, 35), 1, border_radius=6)
        btn_cancel = font_small.render("취소", True, Colors.UI_TEXT)
        surface.blit(btn_cancel, (dx + 180 + (100 - btn_cancel.get_width()) // 2, dy + 150))
