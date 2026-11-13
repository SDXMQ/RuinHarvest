'''
2026-04-14 과제
week3_1.py의 좀비 서바이벌 게임을 객체지향으로 리마스터링했습니다.

적용된 객체지향 시스템:
- 슈퍼클래스(Location, Event)와 상속 클래스를 활용한 구조 설계
- 캡슐화: Player, Inventory 등 데이터와 로직을 클래스 내부에 응집
- 다형성: 각 Location/Event 하위 클래스가 동일한 인터페이스로 다르게 동작
- 컴포지션: GameManager가 Player, Location, Event 객체들을 조합하여 게임 실행

추가된 컨텐츠:
- 새로운 탐색 장소: 경찰서
- 새로운 랜덤 이벤트: 야생 동물, 다른 생존자 조우
- 배고픔 시스템: 매일 허기가 쌓이며 식량 관리 필요
- 게임 로그: 매일의 행동과 결과를 기록
- 새로운 엔딩 추가

UX 개선:
- 인벤토리를 {아이템: 개수} 딕셔너리로 관리하여 중복 표시 제거
- 잘못된 입력 시 재입력 요청 (무한루프 방지)
- 스탯 변동 시 변동량을 시각적으로 표시
- 구분선 및 아이콘을 활용한 가독성 향상
'''

import time
import sys
import random


# ──────────────────────────────────────────────
#  유틸리티 함수
# ──────────────────────────────────────────────

def print_slow(text, delay=0.01):
    """글자를 하나씩 천천히 출력하는 함수"""
    for char in text:
        sys.stdout.write(char)
        sys.stdout.flush()
        time.sleep(delay)
    print()

def get_choice(prompt, valid_options):
    """유효한 입력을 받을 때까지 반복하는 입력 함수 (UX 개선)"""
    while True:
        choice = input(prompt)
        if choice in valid_options:
            return choice
        print(f"  ⚠ 올바른 선택지를 입력해주세요: {', '.join(valid_options)}")

def stat_change_text(name, amount):
    """스탯 변동량을 시각적으로 보여주는 텍스트 생성 (UX 개선)"""
    if amount > 0:
        return f"  ↑ {name} +{amount}"
    elif amount < 0:
        return f"  ↓ {name} {amount}"
    return ""


# ══════════════════════════════════════════════
#  Inventory 클래스 (UX 개선: 중복 아이템 해결)
# ══════════════════════════════════════════════

class Inventory:
    """딕셔너리 기반 인벤토리 - 아이템을 {이름: 개수}로 관리하여 중복 표시를 제거"""
    
    def __init__(self):
        self._items = {}  # {"아이템명": 개수}
    
    def add(self, item_name, count=1):
        """아이템 추가"""
        self._items[item_name] = self._items.get(item_name, 0) + count
        print(f"  📦 [{item_name}] +{count} 획득!")
    
    def remove(self, item_name, count=1):
        """아이템 제거. 성공 시 True, 부족 시 False 반환"""
        if self._items.get(item_name, 0) >= count:
            self._items[item_name] -= count
            if self._items[item_name] <= 0:
                del self._items[item_name]
            print(f"  📦 [{item_name}] -{count} 사용")
            return True
        return False
    
    def has(self, item_name):
        """아이템 보유 여부 확인"""
        return self._items.get(item_name, 0) > 0
    
    def count(self, item_name):
        """특정 아이템 보유 개수 확인"""
        return self._items.get(item_name, 0)
    
    def total_count(self):
        """전체 아이템 총 개수"""
        return sum(self._items.values())
    
    def display(self):
        """인벤토리를 보기 좋게 출력 (UX 개선)"""
        if not self._items:
            return "  🎒 가방이 비어 있습니다."
        parts = []
        for name, qty in self._items.items():
            if qty > 1:
                parts.append(f"{name}(x{qty})")
            else:
                parts.append(name)
        return "  🎒 " + " | ".join(parts)


# ══════════════════════════════════════════════
#  Player 클래스 (캡슐화)
# ══════════════════════════════════════════════

class Player:
    """플레이어 상태를 캡슐화하는 클래스"""
    
    def __init__(self):
        self.hp = 100
        self.stress = 0
        self.hunger = 0           # 추가 컨텐츠: 배고픔
        self.shelter_defense = 10
        self.inventory = Inventory()
        self.inventory.add("생수", 1)
        self.is_alive = True
        self.game_log = []        # 추가 컨텐츠: 게임 로그
    
    def adjust_hp(self, amount):
        """체력 조정 및 범위 보정"""
        old = self.hp
        self.hp = max(0, min(100, self.hp + amount))
        actual = self.hp - old
        if actual != 0:
            print(stat_change_text("체력", actual))
        if self.hp <= 0:
            self.is_alive = False
    
    def adjust_stress(self, amount):
        """스트레스 조정 및 범위 보정"""
        old = self.stress
        self.stress = max(0, min(100, self.stress + amount))
        actual = self.stress - old
        if actual != 0:
            print(stat_change_text("스트레스", actual))
        if self.stress >= 100:
            self.is_alive = False
    
    def adjust_hunger(self, amount):
        """배고픔 조정 (추가 컨텐츠)"""
        old = self.hunger
        self.hunger = max(0, min(100, self.hunger + amount))
        actual = self.hunger - old
        if actual != 0:
            print(stat_change_text("허기", actual))
    
    def log(self, message):
        """게임 로그에 기록 (추가 컨텐츠)"""
        self.game_log.append(message)
    
    def status_bar(self, day):
        """현재 상태를 시각적으로 출력 (UX 개선)"""
        hp_bar = "█" * (self.hp // 5) + "░" * (20 - self.hp // 5)
        stress_bar = "█" * (self.stress // 5) + "░" * (20 - self.stress // 5)
        hunger_bar = "█" * (self.hunger // 5) + "░" * (20 - self.hunger // 5)
        
        print(f"\n{'═' * 60}")
        print_slow(f"  🗓 [생존 {day}일차]", 0.005)
        print(f"  ❤ 체력     [{hp_bar}] {self.hp}/100")
        print(f"  😰 스트레스 [{stress_bar}] {self.stress}/100")
        print(f"  🍖 허기     [{hunger_bar}] {self.hunger}/100")
        print(f"  🛡 방어도   {self.shelter_defense}")
        print(self.inventory.display())
        print(f"{'═' * 60}")


# ══════════════════════════════════════════════
#  Location 슈퍼클래스 및 상속 클래스들
# ══════════════════════════════════════════════

class Location:
    """슈퍼클래스: 탐색 가능한 모든 장소의 공통 인터페이스 정의"""
    
    def __init__(self, name, risk_level, description):
        self.name = name
        self.risk_level = risk_level      # 위험도 표시 (UX 개선)
        self.description = description
    
    def menu_text(self):
        """메뉴에 표시할 텍스트 (UX 개선: 위험도 아이콘)"""
        risk_icons = {"낮음": "🟢", "중간": "🟡", "높음": "🔴", "매우 높음": "🔴🔴"}
        icon = risk_icons.get(self.risk_level, "⚪")
        return f"{self.name} {icon} (위험도: {self.risk_level}) - {self.description}"
    
    def explore(self, player):
        """각 하위 클래스에서 오버라이딩할 탐색 메서드"""
        print_slow(f"\n  ── {self.name}에 도착했습니다 ──")


class Downtown(Location):
    """상속클래스: 도시 중심부 탐색"""
    
    ITEM_POOL = ["식량통조림", "구급상자", "방독면", "손전등", "비상용 배터리",
                 "무기", "운동화", "지도", "방탄조끼", "진통제"]
    
    def __init__(self):
        super().__init__("도시 중심부", "높음", "보상이 많지만 위험이 도사리는 곳")
    
    def explore(self, player):
        super().explore(player)
        print_slow("위험으로 가득한 도시 중심부로 나섰습니다.")
        encounter = random.randint(1, 10)
        
        if encounter <= 5:  # 좀비 무리 조우
            print_slow("거대한 변이 좀비 무리와 마주쳤습니다!")
            print("  1. 숨 죽이고 기다린다")
            print("  2. '무기'와 '방탄조끼'를 믿고 정면 돌파한다")
            print("  3. 소리를 내어 유인한 틈을 타 아이템만 훔친다")
            c = get_choice("  >> 행동 선택: ", ['1', '2', '3'])
            
            if c == '1':
                if player.inventory.has("지도"):
                    print_slow("갖고 있던 '지도'를 참고해 뒷골목으로 안전하게 빠져나갔습니다.")
                    print_slow("운 좋게 뒷골목 쓰레기통에서 '식량통조림'을 주웠습니다.")
                    player.inventory.add("식량통조림")
                    player.log("도시 탐색 - 지도를 이용해 안전하게 빠져나옴")
                else:
                    print_slow("길을 몰라 오랫동안 갇혀 있었습니다. 굶주림과 공포에 시달립니다.")
                    player.adjust_hp(-15)
                    player.adjust_stress(10)
                    player.log("도시 탐색 - 길을 잃어 굶주림/공포")
            elif c == '2':
                if player.inventory.has("무기") and player.inventory.has("방탄조끼"):
                    print_slow("당신의 무쌍 난무! 좀비 무리를 뚫고 엄청난 전리품을 얻었습니다.")
                    gain = random.choice(self.ITEM_POOL)
                    player.inventory.add(gain)
                    player.inventory.add("라디오 부품")
                    player.log("도시 탐색 - 정면돌파 성공, 전리품 획득")
                elif player.inventory.has("무기"):
                    print_slow("무기가 있지만 방어구가 뚫려 상처를 입었습니다.")
                    player.adjust_hp(-30)
                    gain = random.choice(self.ITEM_POOL)
                    player.inventory.add(gain)
                    player.log("도시 탐색 - 무기만으로 돌파, 부상")
                else:
                    print_slow("무기 없이 덤비다 치명상을 입었습니다!!")
                    player.adjust_hp(-50)
                    player.log("도시 탐색 - 무모한 돌격, 치명상")
            else:  # '3'
                if player.inventory.has("운동화"):
                    print_slow("빠른 발을 이용해 놈들을 따돌리고 기민하게 버려진 트렁크를 털었습니다.")
                    gain = random.choice(self.ITEM_POOL)
                    player.inventory.add(gain)
                    player.log("도시 탐색 - 운동화로 유인작전 성공")
                else:
                    print_slow("도망치는 속도가 느려 덜미를 잡힐 뻔했습니다.")
                    player.adjust_stress(20)
                    player.log("도시 탐색 - 유인작전 실패, 스트레스")
                    
        elif encounter <= 8:  # 마트 파밍
            print_slow("버려진 대형 마트 지하실에 진입했습니다.")
            chance = random.randint(1, 100)
            if chance <= 60:
                print_slow("완전히 털리지 않았습니다! 식량통조림과 생수를 얻습니다.")
                player.inventory.add("식량통조림")
                player.inventory.add("생수")
                player.log("도시 탐색 - 마트에서 식량 확보")
            else:
                print_slow("마트 안에는 생존자들이 설치한 악랄한 부비트랩이 있었습니다. 쾅!!")
                player.adjust_hp(-20)
                if player.inventory.has("구급상자"):
                    print_slow("재빨리 구급상자로 찢어진 살점을 봉합합니다.")
                    player.adjust_hp(15)
                    player.inventory.remove("구급상자")
                player.log("도시 탐색 - 부비트랩에 당함")
        else:  # 시체 발견
            print_slow("참혹하게 찢겨진 다른 생존자 시체를 발견했습니다... 우울감에 휩싸입니다.")
            player.adjust_stress(10)
            print_slow("그의 가방을 수색해보니 '지도'와 '손전등'이 있었습니다.")
            if not player.inventory.has("지도"):
                player.inventory.add("지도")
            if not player.inventory.has("손전등"):
                player.inventory.add("손전등")
            player.log("도시 탐색 - 시체에서 지도/손전등 발견")


class Hospital(Location):
    """상속클래스: 버려진 병원 파밍"""
    
    def __init__(self):
        super().__init__("버려진 병원", "중간", "약품 획득 확률이 높은 곳")
    
    def explore(self, player):
        super().explore(player)
        print_slow("코를 찌르는 악취와 부패한 시체 썩는 냄새가 섞여 구토를 유발합니다.")
        
        if player.inventory.has("방독면"):
            print_slow("방독면 덕분에 오염된 공기를 완벽히 차단했습니다. 안전하게 2층 약국으로 직행합니다!")
            finds = random.sample(["구급상자", "진통제", "비상용 배터리"], random.randint(2, 3))
            for f in finds:
                player.inventory.add(f)
            player.log("병원 탐색 - 방독면 착용, 대량 약품 확보")
        else:
            print_slow("지독한 냄새로 호흡이 가빠지며 환각이 보입니다.")
            player.adjust_stress(15)
            print("  1. 위험을 무릅쓰고 지하 영안실까지 털어본다")
            print("  2. 1층 안내데스크만 탐색하고 나간다")
            c = get_choice("  >> 행동 선택: ", ['1', '2'])
            
            if c == '1':
                if random.randint(1, 2) == 1:
                    print_slow("가까스로 감염된 의사 좀비를 처치하고 전리품을 얻었습니다!")
                    player.inventory.add("구급상자")
                    player.inventory.add("무기")
                    player.log("병원 탐색 - 영안실 탐색 성공")
                else:
                    print_slow("어둠 속에서 튀어나온 거미 모양의 좀비에게 물려 독이 퍼집니다!")
                    player.adjust_hp(-30)
                    player.log("병원 탐색 - 영안실에서 공격당함")
            else:
                print_slow("안전을 택했지만, 부서진 캐비닛에서 쓸만한 '진통제' 1개를 구했습니다.")
                player.inventory.add("진통제")
                player.log("병원 탐색 - 안전하게 진통제 확보")


class Shelter(Location):
    """상속클래스: 은신처 정비 및 휴식"""
    
    def __init__(self):
        super().__init__("은신처", "낮음", "은신처를 보수하거나 휴식을 취합니다")
    
    def explore(self, player):
        super().explore(player)
        print_slow("오늘은 무리하지 않고 은신처 내부를 정비합니다.")
        print("  1. 바리케이드를 강화하고 함정을 설치한다 (방어도 증가)")
        print("  2. 모아둔 식량을 먹고 명상하며 푹 쉰다 (체력/스트레스/허기 회복)")
        print("  3. 주변을 정리하고 간단한 물건을 만든다 (아이템 제작)")
        c = get_choice("  >> 행동 선택: ", ['1', '2', '3'])
        
        if c == '1':
            print_slow("망치와 못줄, 철창을 이용해 문과 창문을 요새처럼 단단히 막습니다.")
            defense_gain = random.randint(10, 25)
            player.shelter_defense += defense_gain
            print(f"  🛡 방어도 +{defense_gain} (현재: {player.shelter_defense})")
            player.adjust_stress(-5)
            player.log(f"은신처 - 바리케이드 강화 (방어도 +{defense_gain})")
        elif c == '2':
            if player.inventory.has("식량통조림") and player.inventory.has("생수"):
                print_slow("오랜만에 따뜻한 고기 통조림과 깨끗한 물로 배를 든든히 채웁니다.")
                player.adjust_hp(30)
                player.adjust_stress(-30)
                player.adjust_hunger(-40)
                player.inventory.remove("식량통조림")
                player.inventory.remove("생수")
                player.log("은신처 - 식량+생수로 풀 회복")
            elif player.inventory.has("식량통조림"):
                print_slow("물은 없지만 통조림으로 주린 배를 간신히 달랩니다.")
                player.adjust_hp(15)
                player.adjust_stress(-10)
                player.adjust_hunger(-25)
                player.inventory.remove("식량통조림")
                player.log("은신처 - 통조림만으로 식사")
            else:
                print_slow("식량이 없어 꼬르륵 소리와 함께 추적추적 내리는 빗소리만 듣다 잠에 듭니다...")
                player.adjust_hp(10)
                player.adjust_stress(10)
                player.log("은신처 - 식량 없이 휴식")
        else:  # '3' - 추가 컨텐츠: 아이템 제작
            print_slow("주변의 잡동사니를 뒤져 쓸만한 것을 만들어봅니다.")
            if player.inventory.has("비상용 배터리") and not player.inventory.has("손전등"):
                print_slow("배터리와 유리병으로 즉석 손전등을 만들었습니다!")
                player.inventory.remove("비상용 배터리")
                player.inventory.add("손전등")
                player.log("은신처 - 손전등 제작")
            elif player.inventory.count("생수") >= 2:
                print_slow("생수로 상처를 소독하고 천 조각으로 간이 구급상자를 만들었습니다.")
                player.inventory.remove("생수", 2)
                player.inventory.add("구급상자")
                player.log("은신처 - 구급상자 제작")
            else:
                print_slow("마땅한 재료가 없어 간단한 덫 정도만 만들 수 있었습니다.")
                player.shelter_defense += 5
                print(f"  🛡 방어도 +5 (현재: {player.shelter_defense})")
                player.log("은신처 - 간단한 덫 설치")


class RadioTower(Location):
    """상속클래스: 통신 중계소 탐색"""
    
    def __init__(self):
        super().__init__("통신 중계소", "매우 높음", "탈출에 필수적인 라디오 부품을 찾는 곳")
    
    def explore(self, player):
        super().explore(player)
        print_slow("생존을 위한 유일한 희망, 통신 중계소가 위치한 산 정상으로 험난한 등반을 시작합니다.")
        print_slow("안개가 걷힌 틈을 타 야생 늑대(감염체) 무리를 만났습니다!!")
        
        if player.inventory.has("손전등") and player.inventory.has("비상용 배터리"):
            print_slow("손전등에 비상용 배터리를 연결해 강력한 섬광으로 야생 늑대들의 눈을 멀게 했습니다!")
            print_slow("무사히 중계소 안테나 근처에 도달해 '라디오 부품' 2개를 수거합니다!")
            player.inventory.add("라디오 부품", 2)
            player.log("중계소 - 섬광으로 늑대 퇴치, 부품 2개 확보")
        elif player.inventory.has("무기") and player.inventory.has("방탄조끼"):
            print_slow("방탄조끼가 늑대의 이빨을 막아주는 사이 무기로 늑대를 사냥했습니다!")
            print_slow("피 냄새를 맡고 다른 놈들이 오기 전에 '라디오 부품' 1개를 쥐고 도망칩니다.")
            player.inventory.add("라디오 부품")
            player.log("중계소 - 전투 후 부품 1개 확보")
        elif player.inventory.has("무기"):
            print_slow("무기로 늑대 한 마리에게 상처를 입혔지만 무리 전체를 이길 순 없어 굴러서 도망쳤습니다.")
            print_slow("우연히 굴러떨어진 곳에서 '라디오 부품' 1개를 발견합니다.")
            player.adjust_hp(-20)
            player.inventory.add("라디오 부품")
            player.log("중계소 - 부상 입으며 부품 1개 확보")
        else:
            print_slow("맨몸으로 감염된 늑대와 마주해 이곳저곳 무참히 물어뜯겼습니다!!")
            player.adjust_hp(-45)
            player.adjust_stress(30)
            print_slow("간신히 절벽으로 뛰어내려 목숨만은 건진 채 은신처에 돌아왔습니다.")
            player.log("중계소 - 맨몸으로 늑대 조우, 중상")


class PoliceStation(Location):
    """상속클래스: 경찰서 탐색 (추가 컨텐츠)"""
    
    def __init__(self):
        super().__init__("경찰서", "높음", "무기와 방어 장비를 찾을 확률이 높은 곳")
    
    def explore(self, player):
        super().explore(player)
        print_slow("반쯤 무너진 경찰서 건물에 진입합니다. 총성 자국과 핏자국이 곳곳에...")
        
        encounter = random.randint(1, 10)
        
        if encounter <= 4:  # 무기고 발견
            print_slow("지하 무기고를 발견했습니다! 하지만 전자 잠금장치가 걸려 있습니다.")
            if player.inventory.has("비상용 배터리"):
                print_slow("비상용 배터리로 잠금장치에 전력을 공급해 문을 열었습니다!")
                player.inventory.add("무기")
                player.inventory.add("방탄조끼")
                player.log("경찰서 - 무기고 해제 성공")
            else:
                print_slow("전력이 없어 잠금을 해제할 수 없습니다. 주변에서 쓸만한 것만 주워갑니다.")
                player.inventory.add("진통제")
                player.log("경찰서 - 무기고 진입 실패")
        elif encounter <= 7:  # 생존 경찰관 시체
            print_slow("경찰관의 시신을 발견했습니다. 방탄조끼와 권총이 남아 있습니다.")
            print("  1. 장비를 챙긴다 (방탄조끼 획득)")
            print("  2. 무전기 주파수를 확인해본다 (정보 획득)")
            c = get_choice("  >> 행동 선택: ", ['1', '2'])
            
            if c == '1':
                player.inventory.add("방탄조끼")
                player.log("경찰서 - 경찰관 시신에서 장비 획득")
            else:
                print_slow("무전기에서 마지막 교신 내용이 들립니다...")
                print_slow("'...구조 헬기... 30일 후... 좌표 전송 필요...'")
                print_slow("라디오 부품의 중요성을 다시 한번 깨닫습니다. 스트레스 감소.")
                player.adjust_stress(-10)
                player.log("경찰서 - 무전기 정보 획득")
        else:  # 좀비 경찰관 조우
            print_slow("감염된 좀비 경찰관이 방탄복을 입은 채로 달려듭니다! 단단해서 잘 쓰러지지 않습니다!")
            if player.inventory.has("무기"):
                print_slow("무기로 약점을 공략해 간신히 해치웠습니다.")
                player.adjust_hp(-10)
                player.inventory.add("방탄조끼")
                player.log("경찰서 - 좀비 경찰 퇴치 성공")
            else:
                print_slow("맨손으론 방탄복 좀비를 상대할 수 없었습니다... 도망쳤지만 크게 다쳤습니다.")
                player.adjust_hp(-35)
                player.adjust_stress(15)
                player.log("경찰서 - 좀비 경찰에게 도주, 부상")


# ══════════════════════════════════════════════
#  Event 슈퍼클래스 및 상속 클래스들
# ══════════════════════════════════════════════

class Event:
    """슈퍼클래스: 모든 랜덤 이벤트의 공통 인터페이스"""
    
    def __init__(self, name):
        self.name = name
    
    def trigger(self, player):
        """이벤트 발생 - 하위 클래스에서 오버라이딩"""
        pass


class WeatherEvent(Event):
    """상속클래스: 날씨 이벤트"""
    
    def __init__(self):
        super().__init__("날씨")
    
    def trigger(self, player):
        weather = random.randint(1, 100)
        if weather <= 15:
            print_slow("🌧 [날씨] 오늘은 폭우가 쏟아집니다. 탐색 시 부상 위험이 증가하며, 은신처에 비가 새어 춥습니다.")
            player.adjust_stress(5)
            player.adjust_hp(-5)
        elif weather <= 30:
            print_slow("🌫 [날씨] 짙은 안개가 끼었습니다. 시야가 차단되어 습격당할 확률이 높아집니다.")
        elif weather <= 45:
            print_slow("☀ [날씨] 화창한 날씨입니다. 간만에 기분이 좋아져 스트레스가 감소합니다.")
            player.adjust_stress(-5)
        elif weather <= 55:
            print_slow("🌨 [날씨] 차가운 눈보라가 몰아칩니다. 몸이 얼어붙어 체력이 소모됩니다.")
            player.adjust_hp(-8)
            player.adjust_hunger(5)
        # 그 외는 평범한 날씨 (출력 없음)


class RaidEvent(Event):
    """상속클래스: 심야 습격 이벤트"""
    
    def __init__(self):
        super().__init__("습격")
    
    def trigger(self, player):
        if random.randint(1, 10) <= 2:
            print_slow("⚠ [경고] 간밤에 은신처로 침입을 시도한 흔적이 있습니다!")
            if player.shelter_defense > 20:
                print_slow("튼튼한 바리케이드 덕분에 놈들이 포기하고 돌아갔습니다.")
            else:
                print_slow("방어도가 낮아 문이 일부 부서졌고 극도의 공포에 떨었습니다.")
                player.adjust_stress(15)
                player.shelter_defense = max(0, player.shelter_defense - 5)
                print(f"  🛡 방어도 -5 (현재: {player.shelter_defense})")


class WildAnimalEvent(Event):
    """상속클래스: 야생 동물 조우 이벤트 (추가 컨텐츠)"""
    
    def __init__(self):
        super().__init__("야생 동물")
    
    def trigger(self, player):
        if random.randint(1, 10) <= 1:
            animal = random.choice(["야생 고양이", "부상당한 개", "까마귀 떼"])
            if animal == "야생 고양이":
                print_slow("🐱 [이벤트] 야생 고양이가 은신처 근처에 왔습니다. 귀여운 모습에 잠시 위안을 얻습니다.")
                player.adjust_stress(-8)
            elif animal == "부상당한 개":
                print_slow("🐕 [이벤트] 부상당한 개를 발견했습니다.")
                print("  1. 구급상자로 치료해준다")
                print("  2. 무시하고 지나간다")
                c = get_choice("  >> 선택: ", ['1', '2'])
                if c == '1' and player.inventory.has("구급상자"):
                    print_slow("개를 치료해주자 감사하다는 듯 꼬리를 흔들며 어딘가를 안내합니다.")
                    print_slow("숨겨진 물자 더미를 발견했습니다!")
                    player.inventory.remove("구급상자")
                    player.inventory.add("식량통조림", 2)
                    player.inventory.add("생수")
                else:
                    print_slow("개는 슬픈 눈으로 당신을 바라보다 어둠 속으로 사라졌습니다.")
                    player.adjust_stress(5)
            else:
                print_slow("🐦 [이벤트] 까마귀 떼가 기괴한 울음소리를 내며 머리 위를 선회합니다. 불길한 징조...")
                player.adjust_stress(5)


class SurvivorEvent(Event):
    """상속클래스: 다른 생존자 조우 이벤트 (추가 컨텐츠)"""
    
    def __init__(self):
        super().__init__("생존자 조우")
    
    def trigger(self, player):
        if random.randint(1, 10) <= 1:
            print_slow("👤 [이벤트] 은신처 밖에서 인기척이 느껴집니다. 다른 생존자입니다!")
            print("  1. 문을 열어 맞이한다")
            print("  2. 조용히 숨는다")
            c = get_choice("  >> 선택: ", ['1', '2'])
            
            if c == '1':
                outcome = random.randint(1, 3)
                if outcome == 1:
                    print_slow("생존자: '고맙습니다... 이거라도 드릴게요.' 감사의 표시로 식량을 나눠줍니다.")
                    player.inventory.add("식량통조림")
                    player.inventory.add("생수")
                    player.adjust_stress(-10)
                elif outcome == 2:
                    print_slow("생존자는 유용한 생존 정보를 알려줍니다.")
                    print_slow("'경찰서 지하 무기고에 장비가 있다는 걸 알고 있나요? 배터리면 열 수 있어요.'")
                    player.adjust_stress(-5)
                else:
                    print_slow("생존자인 줄 알았는데... 약탈자였습니다! 물건을 빼앗기고 도망칩니다!")
                    stolen = None
                    for item in ["식량통조림", "생수", "구급상자"]:
                        if player.inventory.has(item):
                            player.inventory.remove(item)
                            stolen = item
                            break
                    if stolen:
                        print_slow(f"'{stolen}'을(를) 빼앗겼습니다!")
                    player.adjust_stress(15)
                    player.adjust_hp(-10)
            else:
                print_slow("숨을 죽이고 있자 그는 얼마 후 사라졌습니다. 안도의 한숨...")


class HungerEvent(Event):
    """상속클래스: 매일 허기 증가 이벤트 (추가 컨텐츠)"""
    
    def __init__(self):
        super().__init__("허기")
    
    def trigger(self, player):
        player.adjust_hunger(8)  # 매일 허기 증가
        if player.hunger >= 80:
            print_slow("⚠ [위험] 극심한 배고픔에 시달리고 있습니다! 체력이 줄어듭니다.")
            player.adjust_hp(-10)
        elif player.hunger >= 50:
            print_slow("🍖 [배고픔] 배가 고파 집중력이 떨어집니다. 스트레스가 증가합니다.")
            player.adjust_stress(5)


class MerchantEvent(Event):
    """상속클래스: 떠돌이 상인 이벤트"""
    
    def __init__(self):
        super().__init__("떠돌이 상인")
        self.appeared = False
    
    def check_appearance(self):
        """상인 등장 여부 결정"""
        self.appeared = random.randint(1, 10) <= 3
        return self.appeared
    
    def trigger(self, player):
        print_slow("상인: '여어 반가워! 좋은 물건 많이 캐왔어. 운이 좋군.'")
        if player.inventory.has("식량통조림"):
            print_slow("상인이 당신의 '식량통조림'을 원합니다. 생존에 직결되는 장비와 바꾸자고 합니다.")
            print("  1. 식량 1개를 내주고 '방독면'을 받는다")
            print("  2. 식량 1개를 내주고 '방탄조끼'를 받는다")
            print("  3. 식량 1개를 내주고 '비상용 배터리'를 받는다")
            print("  4. 식량 1개를 내주고 '운동화'를 받는다")
            print("  5. 거래를 거절한다")
            trade = get_choice("  >> 행동 선택: ", ['1', '2', '3', '4', '5'])
            trade_map = {'1': '방독면', '2': '방탄조끼', '3': '비상용 배터리', '4': '운동화'}
            
            if trade in trade_map:
                player.inventory.remove("식량통조림")
                player.inventory.add(trade_map[trade])
                print_slow(f"상인은 만족스럽게 '{trade_map[trade]}'을(를) 넘겼습니다.")
                player.log(f"상인 거래 - 식량→{trade_map[trade]}")
            else:
                print_slow("당신의 쌀쌀맞은 거절에 상인은 입맛을 다시며 안개 속으로 사라졌습니다.")
                player.log("상인 거래 - 거절")
        else:
            print_slow("상인: '쯧, 식량통조림도 없는 거지였군그래.' 상인은 당신을 한심하게 쳐다보곤 가버렸습니다.")
            player.adjust_stress(5)
            player.log("상인 - 거래 불발 (식량 없음)")


# ══════════════════════════════════════════════
#  GameManager 클래스 (게임 전체 흐름 관리)
# ══════════════════════════════════════════════

class GameManager:
    """게임의 메인 루프와 전체 흐름을 관리하는 매니저 클래스"""
    
    TOTAL_DAYS = 30
    
    def __init__(self):
        self.player = Player()
        
        # Location 상속 클래스들을 딕셔너리로 관리
        self.locations = {
            '1': Downtown(),
            '2': Hospital(),
            '3': Shelter(),
            '4': RadioTower(),
            '5': PoliceStation()   # 추가 컨텐츠
        }
        
        # Event 상속 클래스들을 리스트로 관리
        self.morning_events = [
            WeatherEvent(),
            RaidEvent(),
            WildAnimalEvent(),     # 추가 컨텐츠
            SurvivorEvent(),       # 추가 컨텐츠
            HungerEvent()          # 추가 컨텐츠
        ]
        self.merchant = MerchantEvent()
    
    def show_intro(self):
        """게임 인트로 출력"""
        print_slow("■■■ 30일간의 고립 극복 좀비 서바이벌 ■■■")
        print_slow("당신은 구조대가 오기까지 30일 동안 폐허 속에서 살아남아야 합니다.")
        print_slow("매 순간의 선택, 우연한 만남, 그리고 보유한 아이템이 당신의 생사를 결정합니다.")
        print("=" * 60)
    
    def check_survival(self):
        """생존 여부 검사"""
        if self.player.hp <= 0:
            print_slow("\n💀 체력이 바닥나 쓰러졌습니다... 당신은 감염자가 되었습니다.")
            self.player.is_alive = False
            return False
        if self.player.stress >= 100:
            print_slow("\n💀 극심한 스트레스로 심연에 빠져 이성을 잃고 밖으로 뛰쳐나갔습니다... 생존 실패.")
            self.player.is_alive = False
            return False
        if self.player.hunger >= 100:
            print_slow("\n💀 극심한 굶주림에 더 이상 몸을 가눌 수 없습니다... 의식이 꺼져갑니다.")
            self.player.is_alive = False
            return False
        return True
    
    def process_morning_events(self):
        """아침 랜덤 이벤트 처리"""
        for event in self.morning_events:
            event.trigger(self.player)
    
    def apply_passive_effects(self):
        """아이템 자동 효과 적용"""
        if self.player.hp < 40 and self.player.inventory.has("진통제"):
            print_slow("💊 [자동 효과] 체력이 너무 낮아 '진통제'를 투여합니다. 고통이 사라집니다.")
            self.player.adjust_hp(40)
            self.player.inventory.remove("진통제")
        
        # 추가 컨텐츠: 구급상자 자동 사용 (체력 20 이하)
        if self.player.hp <= 20 and self.player.inventory.has("구급상자"):
            print_slow("🏥 [긴급 자동 치료] 체력이 위험 수준! 구급상자를 사용합니다.")
            self.player.adjust_hp(30)
            self.player.inventory.remove("구급상자")
    
    def display_menu(self):
        """일일 행동 메뉴 출력"""
        print("\n  오늘 당신은 무엇을 하시겠습니까?")
        print("  ─────────────────────────────────")
        for key, loc in self.locations.items():
            print(f"  {key}. {loc.menu_text()}")
        
        valid = list(self.locations.keys())
        
        # 떠돌이 상인 이벤트 체크
        if self.merchant.check_appearance():
            print(f"  6. 🏪 [이벤트] 떠돌이 상인이 거래를 제안합니다!")
            valid.append('6')
        
        print("  ─────────────────────────────────")
        return valid
    
    def show_endings(self):
        """엔딩 판정 (다중 엔딩 시스템)"""
        if not self.player.is_alive:
            print("\n" + "☠" * 35)
            print_slow("당신의 여정은 여기서 끝났습니다...")
            print("☠" * 35)
            self._show_game_log()
            return
        
        print("\n" + "★" * 35)
        print_slow("최후의 30일차! 잿빛 구름이 걷히며 하늘 반대편에서 대형 군용 헬기의 소음이 들려옵니다!!")
        
        radio_count = self.player.inventory.count("라디오 부품")
        p = self.player
        
        if radio_count >= 3:
            print_slow("당신은 부품 3개를 짜맞춰 장거리 고출력 무전기를 완벽하게 만들어 냈습니다!")
            print_slow("정확한 좌표와 신호를 송신하여 헬리콥터가 은신처 지붕 위로 정확히 하강합니다.")
            print(f"\n  📊 최종 스펙 - ❤체력: {p.hp} | 🛡방어도: {p.shelter_defense} | 🎒아이템: {p.inventory.total_count()}개")
            print_slow("\n  ▶▶▶ [진(眞) 엔딩: 인류의 희망, 완벽한 사령관] ◀◀◀")
            print_slow("  당신의 철저한 생존 일지는 후세에 백과사전으로 남게 될 것입니다.")
            
        elif radio_count >= 1 and p.inventory.has("손전등") and p.inventory.has("비상용 배터리"):
            print_slow("무전기는 불안정했지만, 야밤에 손전등에 비상 배터리를 연결해 강렬한 빛기둥으로 SOS를 쏘아올렸습니다!")
            print_slow("수색대의 눈에 그 빛이 닿았고, 조종사가 옥상으로 밧줄을 내려 당신을 구출해냅니다.")
            print_slow("\n  ▶▶▶ [해피 엔딩: 기지를 발휘한 드라마틱한 구출] ◀◀◀")
            
        elif p.shelter_defense >= 60 and p.inventory.has("식량통조림"):
            print_slow("헬기는 신호를 눈치채지 못하고 무심히 지나쳐갔습니다...")
            print_slow("하지만 당신은 실망하지 않습니다. 당신의 은신처는 좀비 군단이 와도 뚫리지 않는 강철 요새가 되었습니다.")
            print_slow("수북한 식량과 함께, 당신은 이 지역의 왕이 되기로 결심하며 와인을 따릅니다.")
            print_slow("\n  ▶▶▶ [노말 엔딩: 폐허 위에 군림하는 철의 군주] ◀◀◀")
            
        elif p.hp >= 80 and p.inventory.has("무기") and p.inventory.has("방탄조끼"):
            print_slow("구조는 실패했습니다. 군부대도 이 지역을 포기한 듯합니다.")
            print_slow("하지만 당신은 무기와 방어구로 완전 무장한 채 은신처 밖으로 걸어나갑니다.")
            print_slow("넘치는 체력과 전투 경험. 살아남는 것 자체가 목적이 된 당신의 또 다른 여정이 시작됩니다...")
            print_slow("\n  ▶▶▶ [노말 엔딩: 매드맥스, 끝없는 여정] ◀◀◀")
        
        elif p.shelter_defense >= 40 and p.hp >= 60 and radio_count >= 1:
            # 추가 엔딩
            print_slow("불안정한 라디오로 단편적인 좌표를 보냈습니다.")
            print_slow("헬기는 근처까지 왔지만 정확한 위치를 찾지 못해 물자만 투하하고 돌아갑니다.")
            print_slow("투하된 물자 속에 메모가 있습니다: '일주일 후 다시 온다. 버텨라.'")
            print_slow("\n  ▶▶▶ [노말 엔딩: 희망의 불씨] ◀◀◀")
            
        else:
            print_slow("헬기가 지나가는 것을 그저 허망하게 하늘을 보며 눈물만 흘립니다...")
            print_slow("라디오도, 빛을 낼 수단도, 더 이상 방어할 힘과 식량도 남아있지 않습니다.")
            print_slow("점점 닫히는 은신처 문 너머로, 수천 마리의 좀비 떼가 내는 끔찍한 파열음만이 귓가를 맴돕니다.")
            print_slow("\n  ▶▶▶ [배드 엔딩: 잊혀진 자의 고독한 최후] ◀◀◀")
        
        print("★" * 35)
        self._show_game_log()
    
    def _show_game_log(self):
        """게임 종료 후 생존 로그 출력 (추가 컨텐츠)"""
        if self.player.game_log:
            print("\n  📋 ── 생존 기록 ──")
            for i, entry in enumerate(self.player.game_log, 1):
                print(f"    {i}. {entry}")
            print()
    
    def start(self):
        """게임 메인 루프"""
        self.show_intro()
        
        for day in range(1, self.TOTAL_DAYS + 1):
            # 상태 출력
            self.player.status_bar(day)
            
            # 생존 체크
            if not self.check_survival():
                break
            
            # 아침 이벤트
            self.process_morning_events()
            if not self.check_survival():
                break
            
            time.sleep(0.5)
            
            # 행동 선택
            valid_options = self.display_menu()
            choice = get_choice("  >> 선택: ", valid_options)
            
            if choice in self.locations:
                self.locations[choice].explore(self.player)
            elif choice == '6':
                self.merchant.trigger(self.player)
            
            # 패시브 아이템 효과
            self.apply_passive_effects()
            
            if not self.check_survival():
                break
            
            time.sleep(1)
        
        # 엔딩 표시
        self.show_endings()


# ══════════════════════════════════════════════
#  게임 실행
# ══════════════════════════════════════════════

if __name__ == "__main__":
    game = GameManager()
    game.start()
