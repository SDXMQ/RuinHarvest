"""
flea_market.py - 가상 플리마켓 및 시뮬레이션 경제 시스템
"""
import random
import math
from items import ITEM_DATABASE, ItemCategory

class FleaMarket:
    """가상 플리마켓 시뮬레이터"""

    def __init__(self):
        # 아이템별 장기 추세 변수 (R_trend)
        self.trends = {}
        # 아이템별 현재 가격 변동 배율 (P_current / P_base 비율)
        self.price_multipliers = {}
        # 가상 마켓 등록 매물 목록: [{"id": int, "item_name": str, "count": int, "price": int, "seller": str}]
        self.listings = []
        # 플레이어 등록 매물 목록: [{"item_name": str, "count": int, "price": int, "timer": float, "id": int}]
        self.player_listings = []
        
        self.next_listing_id = 1
        self.next_player_listing_id = 1

        # 가상 닉네임 풀
        self.nicknames = [
            "PMC_Killa", "Scav_Lover", "Nikita_Fan", "LootGoblin", "Tarkov_Pro",
            "Rat_Pack", "Chad_Alpha", "SledgeHammer", "Bandit_99", "Trader_Joe",
            "Prapor_Junior", "Stash_Master", "PMC_1982", "Scav_Boss_Fan", "Ruin_Harvester"
        ]

        self.initialize_market()

    def initialize_market(self):
        """마켓 초기화"""
        for name, data in ITEM_DATABASE.items():
            # 장기 추세 초기화 (-0.15 ~ +0.20)
            self.trends[name] = random.uniform(-0.15, 0.20)
            self.price_multipliers[name] = 1.0
        
        self.update_market_prices()
        self.refresh_listings()

    def get_current_price(self, item_name):
        """아이템의 현재 시장 시세 연산"""
        data = ITEM_DATABASE.get(item_name)
        if not data:
            return 1000
        
        base_price = data.get("value", 1000)
        mult = self.price_multipliers.get(item_name, 1.0)
        return max(10, int(base_price * mult))

    def update_market_prices(self, in_game_day=1):
        """현실 시간 경과 또는 레이드 완료 시 시세 변동 업데이트"""
        # 날짜 기반 시드 고정으로 세이브 리롤 방지
        saved_state = random.getstate()
        for name, data in ITEM_DATABASE.items():
            # 아이템별 + 날짜별 고정 시드
            random.seed(in_game_day * 10007 + hash(name) % 100003)
            # 장기 추세 점진적 갱신
            if random.random() < 0.2:
                self.trends[name] = random.uniform(-0.15, 0.30)
            
            # 카테고리별 변동 표준편차 설정 (무기, 장비, 퀘스트는 고위험군 0.15, 나머지는 0.05)
            category = data.get("category")
            if category in (ItemCategory.WEAPON, ItemCategory.EQUIPMENT, ItemCategory.QUEST):
                sigma = 0.15
            else:
                sigma = 0.05
            
            # 가우시안 노이즈 생성
            noise = random.gauss(0, sigma)
            
            # 시세 배율 연산 (하한선 0.4, 상한선 2.5)
            r_trend = self.trends[name]
            mult = 1.0 + r_trend + noise
            self.price_multipliers[name] = max(0.4, min(2.5, mult))
        # 다른 인게임 난수에 영향을 주지 않도록 원복
        random.setstate(saved_state)

    def refresh_listings(self, in_game_day=1):
        """가상 매물 재생성 및 갱신"""
        # 날짜 기반 시드 고정
        saved_state = random.getstate()
        random.seed(in_game_day * 20011 + self.next_listing_id)
        self.listings = []
        
        # 전체 아이템 데이터베이스에서 무작위로 매물 스폰
        all_items = list(ITEM_DATABASE.keys())
        # 마켓 크기: 15 ~ 25개 매물 유지
        num_listings = random.randint(15, 25)
        
        for _ in range(num_listings):
            item_name = random.choice(all_items)
            data = ITEM_DATABASE[item_name]
            
            # 플리마켓 거래 불가 물품 제외
            if item_name == "Scav 식별줄(Dogtag)":
                continue
                
            current_price = self.get_current_price(item_name)
            
            # 가격 편차 85% ~ 115%
            price_factor = random.uniform(0.85, 1.15)
            price = max(5, int(current_price * price_factor))
            
            # 개수 결정
            if data.get("stackable"):
                max_stack = data.get("max_stack", 5)
                count = random.randint(1, max(2, max_stack // 2))
            else:
                count = 1
                
            seller = random.choice(self.nicknames)
            if random.random() < 0.3:
                seller = f"PMC_{random.randint(1000, 9999)}"
                
            self.listings.append({
                "id": self.next_listing_id,
                "item_name": item_name,
                "count": count,
                "price": price,
                "seller": seller
            })
            self.next_listing_id += 1

        # 시세보다 현저히 싼(90% 이하) 매물은 시뮬레이션 중 20% 확률로 소거 처리 (누군가 사감)
        self.listings.sort(key=lambda x: x["price"])
        # 난수 상태 원복
        random.setstate(saved_state)

    def process_player_sales(self, player):
        """레이드 복귀 시 플레이어가 등록해둔 매물 판매 판정"""
        completed_sales = []
        failed_sales = []
        still_pending = []

        for sale in self.player_listings:
            item_name = sale["item_name"]
            p_register = sale["price"]
            count = sale["count"]
            
            p_current = self.get_current_price(item_name)
            p_min = p_current * 0.8
            p_max = p_current * 1.2
            
            # 판매 성공 확률 연산
            denom = p_max - p_min
            if denom <= 0:
                pr_buy = 0.5
            else:
                pr_buy = 1.0 - ((p_register - p_min) / denom)
                
            pr_buy = max(0.01, min(0.99, pr_buy))
            
            # 가상 구매자가 구매했는지 판정 (확률 계산)
            if random.random() < pr_buy:
                # 판매 성공! 금액 획득
                earned = p_register * count
                # 플리마켓 수수료 5% 제외
                net_earned = int(earned * 0.95)
                player.rubles += net_earned
                completed_sales.append({
                    "item_name": item_name,
                    "count": count,
                    "earned": net_earned
                })
            else:
                # 판매 실패 시 만료 (시간 타이머 차감)
                sale["timer"] -= 1.0  # 레이드 1회 종료마다 타이머 1.0 차감
                if sale["timer"] <= 0:
                    # 유찰되어 플레이어 Stash로 반환되게 분류
                    failed_sales.append(sale)
                else:
                    still_pending.append(sale)

        self.player_listings = still_pending
        return completed_sales, failed_sales

    def register_item(self, item_name, count, price):
        """플레이어가 플리마켓에 매물 등록"""
        if item_name == "Scav 식별줄(Dogtag)":
            return False
        # 기본 등록 기한 2.0 (레이드 2회 분량)
        self.player_listings.append({
            "id": self.next_player_listing_id,
            "item_name": item_name,
            "count": count,
            "price": price,
            "timer": 2.0
        })
        self.next_player_listing_id += 1
        return True
