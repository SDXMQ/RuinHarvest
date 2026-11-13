'''
프로그램 목표:
- 30일 동안 생존하기
- 체력과 스트레스를 관리하기
- 아이템을 수집하고 활용하기
- 다양한 이벤트에 대응하기
- 여러 엔딩 보기
'''

import time
import sys
import random

def print_slow(text, delay=0.01):
    for char in text:
        sys.stdout.write(char)
        sys.stdout.flush()
        time.sleep(delay)
    print()

print_slow("■■■ 30일간의 고립 극복 좀비 서바이벌 ■■■")
print_slow("당신은 구조대가 오기까지 30일 동안 폐허 속에서 살아남아야 합니다.")
print_slow("매 순간의 선택, 우연한 만남, 그리고 보유한 아이템이 당신의 생사를 결정합니다.")
print("=" * 60)

# 플레이어 기본 스탯 및 상태
hp = 100
stress = 0
shelter_defense = 10 # 은신처 방어도
inventory = ["생수"] # 시작 아이템
is_alive = True

# 획득 가능한 무작위 아이템 풀
item_pool = ["식량통조림", "구급상자", "방독면", "손전등", "비상용 배터리", "무기", "운동화", "지도", "방탄조끼", "진통제"]

# 게임의 턴 관리 (30일 생존)
for day in range(1, 31):
    print("\n" + "=" * 60)
    print_slow(f"[생존 {day}일차] | 체력: {hp}/100 | 스트레스: {stress}/100 | 방어도: {shelter_defense}", 0.005)
    print(f"가진 아이템: {inventory}")
    print("=" * 60)
    
    # 상태 이상(사망 및 게임오버) 검사
    if hp <= 0:
        print_slow("체력이 바닥나 쓰러졌습니다... 당신은 감염자가 되었습니다.")
        is_alive = False
        break
        
    if stress >= 100:
        print_slow("극심한 스트레스로 심연에 빠져 이성을 잃고 밖으로 뛰쳐나갔습니다... 생존 실패.")
        is_alive = False
        break

    # [랜덤 이벤트 1: 아침 날씨 및 상황]
    weather = random.randint(1, 100)
    if weather <= 15:
        print_slow("[날씨] 오늘은 폭우가 쏟아집니다. 탐색 시 부상 위험이 증가하며, 은신처에 비가 새어 춥습니다.")
        stress += 5
        hp -= 5
    elif weather <= 30:
        print_slow("[날씨] 짙은 안개가 끼었습니다. 시야가 차단되어 습격당할 확률이 높아집니다.")
    elif weather <= 45:
        print_slow("[날씨] 화창한 날씨입니다. 간만에 기분이 좋아져 스트레스가 5 감소합니다.")
        stress -= 5
    
    # [랜덤 이벤트 2: 간밤의 습격]
    if random.randint(1, 10) <= 2:
        print_slow("[경고] 간밤에 은신처로 침입을 시도한 흔적이 있습니다!")
        if shelter_defense > 20:
            print_slow("튼튼한 바리케이드 덕분에 놈들이 포기하고 돌아갔습니다.")
        else:
            print_slow("방어도가 낮아 문이 일부 부서졌고 극도의 공포에 떨었습니다. 스트레스 15 증가.")
            stress += 15

    # 통계 보정 (스탯이 범위를 벗어나지 않게)
    if stress < 0: stress = 0
    if hp > 100: hp = 100
    
    time.sleep(0.5)
    
    print("\n오늘 당신은 무엇을 하시겠습니까?")
    print("1. 도시 중심부 탐색 (위험도: 높음, 보상: 많음)")
    print("2. 버려진 병원 파밍 (위험도: 중간, 약품 획득 확률 확보)")
    print("3. 은신처 보수 및 휴식 (생존 본연에 집중)")
    print("4. 통신 중계소로 이동해 라디오 부품 탐색 (탈출 필수 코스)")
    
    # [랜덤 이벤트 3: 떠돌이 상인 등장]
    merchant_appeared = random.randint(1, 10) <= 3
    if merchant_appeared:
        print("5. [이벤트] 문 밖에서 떠돌이 상인이 몰래 다가와 거래를 제안합니다!")
    
    choice1 = input(">> 선택: ")

    # --------- 메인 분기 로직 시작 ---------
    if choice1 == '1': # 도시 중심부 탐색
        print_slow("위험으로 가득한 도시 중심부로 나섰습니다.")
        encounter = random.randint(1, 10)
        
        if encounter <= 5: # 좀비 무리 조우
            print_slow("거대한 변이 좀비 무리와 마주쳤습니다!")
            print("1. 숨 죽이고 기다린다")
            print("2. '무기'와 '방탄조끼'를 믿고 정면 돌파한다")
            print("3. 소리를 내어 유인한 틈을 타 아이템만 훔친다")
            c2 = input(">> 행동 선택(1/2/3): ")
            
            if c2 == '1':
                if "지도" in inventory:
                    print_slow("갖고 있던 '지도'를 참고해 뒷골목으로 안전하게 빠져나갔습니다.")
                    print_slow("운 좋게 뒷골목 쓰레기통에서 '식량통조림'을 주웠습니다.")
                    inventory.append("식량통조림")
                else:
                    print_slow("길을 몰라 오랫동안 갇혀 있었습니다. 굶주림과 공포로 체력 15, 스트레스 10 증가.")
                    hp -= 15
                    stress += 10
            elif c2 == '2':
                if "무기" in inventory and "방탄조끼" in inventory:
                    print_slow("당신의 무쌍 난무! 좀비 무리를 뚫고 엄청난 전리품을 얻었습니다.")
                    gain = random.choice(item_pool)
                    inventory.extend([gain, "라디오 부품"])
                    print_slow(f"[{gain}]와 [라디오 부품]을 획득했습니다!")
                elif "무기" in inventory:
                    print_slow("무기가 있지만 방어구가 뚫려 상처를 입었습니다. 체력이 30 깎였지만 전리품은 얻었습니다.")
                    hp -= 30
                    gain = random.choice(item_pool)
                    inventory.append(gain)
                    print_slow(f"고통 속에서 [{gain}]을 획득했습니다.")
                else:
                    print_slow("무기 없이 덤비다 치명상을 입었습니다!! 체력 50 리스크.")
                    hp -= 50
            elif c2 == '3':
                if "운동화" in inventory:
                    print_slow("빠른 발을 이용해 놈들을 따돌리고 기민하게 버려진 트렁크를 털었습니다.")
                    gain = random.choice(item_pool)
                    inventory.append(gain)
                    print_slow(f"[{gain}] 획득 완료!")
                else:
                    print_slow("도망치는 속도가 느려 덜미를 잡힐 뻔했습니다. 기를 쓰고 도망치느라 스트레스 20 증가.")
                    stress += 20
            else:
                print_slow("우물쭈물하다가 공격을 당했습니다. 체력 20 감소.")
                hp -= 20
                
        elif encounter <= 8: # 마트 파밍
            print_slow("버려진 대형 마트 지하실에 진입했습니다.")
            chance = random.randint(1, 100)
            if chance <= 60:
                print_slow("완전히 털리지 않았습니다! 식량통조림과 생수를 얻습니다.")
                inventory.extend(["식량통조림", "생수"])
            else:
                print_slow("마트 안에는 생존자들이 설치한 악랄한 부비트랩이 있었습니다. 쾅!! 체력이 20 떨어집니다.")
                hp -= 20
                if "구급상자" in inventory:
                    print_slow("재빨리 구급상자로 찢어진 살점을 봉합합니다. 체력을 15 회복했습니다.")
                    hp += 15
                    inventory.remove("구급상자")
        else: # 시체 발견
            print_slow("참혹하게 찢겨진 다른 생존자 시체를 발견했습니다... 우울감에 휩싸입니다. (스트레스 10 증가)")
            stress += 10
            print_slow("그의 가방을 수색해보니 '지도'와 '손전등'이 있었습니다.")
            if "지도" not in inventory: inventory.append("지도")
            if "손전등" not in inventory: inventory.append("손전등")

    elif choice1 == '2': # 병원 파밍
        print_slow("음산한 기운이 감도는 버려진 대형 병원에 진입합니다.")
        print_slow("코를 찌르는 악취와 부패한 시체 썩는 냄새가 섞여 구토를 유발합니다.")
        if "방독면" in inventory:
            print_slow("방독면 덕분에 오염된 공기를 완벽히 차단했습니다. 안전하게 2층 약국으로 직행합니다!")
            finds = random.sample(["구급상자", "진통제", "구급상자", "진통제", "비상용 배터리"], random.randint(2, 3))
            for f in finds: inventory.append(f)
            print_slow(f"놀라운 수확입니다! {finds}를 획득했습니다.")
        else:
            print_slow("지독한 냄새로 호흡이 가빠지며 환각이 보입니다. (스트레스 15 증가)")
            stress += 15
            print("1. 위험을 무릅쓰고 지하 영안실까지 털어본다")
            print("2. 1층 안내데스크만 탐색하고 나간다")
            c_h = input(">> 행동 선택(1/2): ")
            
            if c_h == '1':
                if random.randint(1, 2) == 1:
                    print_slow("가까스로 감염된 의사 좀비를 처치하고 '구급상자'와 '무기'를 얻었습니다!")
                    inventory.extend(["구급상자", "무기"])
                else:
                    print_slow("어둠 속에서 튀어나온 거미 모양의 좀비에게 물려 독이 퍼집니다! 체력 30 감소.")
                    hp -= 30
            else:
                print_slow("안전을 택했지만, 부서진 캐비닛에서 쓸만한 '진통제' 1개를 구했습니다.")
                inventory.append("진통제")

    elif choice1 == '3': # 휴식 및 방어도 보수
        print_slow("오늘은 무리하지 않고 은신처 내부를 정비합니다.")
        print("1. 바리케이드를 강화하고 함정을 설치한다 (방어도 대폭 증가)")
        print("2. 모아둔 식량을 먹고 명상하며 푹 쉰다 (체력/스트레스 회복)")
        c3 = input(">> 행동 선택(1/2): ")
        
        if c3 == '1':
            print_slow("망치와 못줄, 철창을 이용해 문과 창문을 요새처럼 단단히 막습니다.")
            defense_gain = random.randint(10, 25)
            shelter_defense += defense_gain
            print_slow(f"방어도가 {defense_gain}만큼 증가했습니다! (현재 방어도: {shelter_defense})")
            stress -= 5
        elif c3 == '2':
            if "식량통조림" in inventory and "생수" in inventory:
                print_slow("오랜만에 따뜻한 고기 통조림과 깨끗한 물로 배를 든든히 채웁니다.")
                hp += 30
                stress -= 30
                inventory.remove("식량통조림")
                inventory.remove("생수")
            elif "식량통조림" in inventory:
                print_slow("물은 없지만 통조림으로 주린 배를 간신히 달랩니다.")
                hp += 15
                stress -= 10
                inventory.remove("식량통조림")
            else:
                print_slow("식량이 없어 꼬르륵 소리와 함께 추적추적 내리는 빗소리만 듣다 잠에 듭니다...")
                hp += 10
                stress += 10
        else:
            print_slow("아무것도 안 하고 허공을 보며 멍을 때립니다.")
            stress += 5

    elif choice1 == '4': # 라디오 부품 탐색
        print_slow("생존을 위한 유일한 희망, 통신 중계소가 위치한 산 정상으로 험난한 등반을 시작합니다.")
        print_slow("안개가 걷힌 틈을 타 야생 늑대(감염체) 무리를 만났습니다!!")
        
        if "손전등" in inventory and "비상용 배터리" in inventory:
            print_slow("손전등에 비상용 배터리를 연결해 강력한 섬광으로 야생 늑대들의 눈을 멀게 했습니다!")
            print_slow("무사히 중계소 안테나 근처에 도달해 '라디오 부품' 2개를 수거합니다!")
            inventory.extend(["라디오 부품", "라디오 부품"])
        elif "무기" in inventory and "방탄조끼" in inventory:
            print_slow("방탄조끼가 늑대의 이빨을 막아주는 사이 무기로 늑대를 사냥했습니다!")
            print_slow("피 냄새를 맡고 다른 놈들이 오기 전에 '라디오 부품' 1개를 쥐고 도망칩니다.")
            inventory.append("라디오 부품")
        elif "무기" in inventory:
            print_slow("무기로 늑대 한 마리에게 상처를 입혔지만 무리 전체를 이길 순 없어 굴러서 도망쳤습니다.")
            print_slow("우연히 굴러떨어진 곳에서 '라디오 부품' 1개를 발견합니다. 체력 20 감소.")
            hp -= 20
            inventory.append("라디오 부품")
        else:
            print_slow("맨몸으로 감염된 늑대와 마주해 이곳저곳 무참히 물어뜯겼습니다!!")
            hp -= 45
            stress += 30
            print_slow("간신히 절벽으로 뛰어내려 목숨만은 건진 채 은신처에 돌아왔습니다.")

    elif choice1 == '5' and merchant_appeared: # 랜덤 이벤트 상인 거래
        print_slow("상인: '여어 반가워! 좋은 물건 많이 캐왔어. 운이 좋군.'")
        if "식량통조림" in inventory:
            print_slow("상인이 당신의 '식량통조림'을 원합니다. 생존에 직결되는 장비와 바꾸자고 합니다.")
            print("1. 식량 1개를 내주고 '방독면'을 받는다.")
            print("2. 식량 1개를 내주고 '방탄조끼'를 받는다.")
            print("3. 식량 1개를 내주고 '비상용 배터리'를 받는다.")
            print("4. 거래를 거절한다.")
            trade = input(">> 행동 선택(1/2/3/4): ")
            if trade == '1':
                inventory.remove("식량통조림")
                inventory.append("방독면")
                print_slow("상인은 만족스런 미소를 지으며 방독면을 넘겼습니다.")
            elif trade == '2':
                inventory.remove("식량통조림")
                inventory.append("방탄조끼")
                print_slow("상인은 무거운 방탄조끼를 넘겼습니다. 방어력이 크게 오라갈 것입니다.")
            elif trade == '3':
                inventory.remove("식량통조림")
                inventory.append("비상용 배터리")
                print_slow("유용한 비상용 배터리를 받았습니다.")
            else:
                print_slow("당신의 쌀쌀맞은 거절에 상인은 입맛을 다시며 안개 속으로 사라졌습니다.")
        else:
            print_slow("상인: '쯧, 식량통조림도 없는 거지였군그래.' 상인은 당신을 한심하게 쳐다보곤 가버렸습니다.")
            stress += 5
    
    else:
        print_slow("허튼 짓을 하다가 귀중한 하루를 어이없이 허비했습니다. 우울증 폭발. 스트레스 15 증가.")
        stress += 15

    # [아이템 효과: 자동 진통제 투여]
    if hp < 40 and "진통제" in inventory:
        print_slow("[아이템 효과 작동] 체력이 너무 낮아 남몰래 챙겨둔 '진통제'를 투여합니다. 상처의 고통이 사라집니다. 체력 40 회복.")
        hp += 40
        inventory.remove("진통제")

    # 최대 수치 보정
    if hp > 100: hp = 100
    if stress < 0: stress = 0
    time.sleep(1)

# 결말 처리 다중 엔딩 시스템
if is_alive:
    print("\n" + "*" * 70)
    print_slow("최후의 30일차! 잿빛 구름이 걷히며 하늘 반대편에서 대형 군용 헬기의 소음이 들려옵니다!!")
    
    radio_count = inventory.count("라디오 부품")
    
    if radio_count >= 3:
        print_slow("당신은 부품 3개를 짜맞춰 장거리 고출력 무전기를 완벽하게 만들어 냈습니다!")
        print_slow("정확한 좌표와 신호를 송신하여 헬리콥터가 은신처 지붕 위로 정확히 하강합니다.")
        print_slow(f"당신의 경이로운 생존 스펙 - 체력: {hp}, 방어도: {shelter_defense}, 보유 아이템: {len(inventory)}개")
        print_slow("\n▶▶▶ [진(眞) 엔딩: 인류의 희망, 완벽한 사령관] ◀◀◀")
        print_slow("당신의 철저한 생존 일지는 후세에 백과사전으로 남게 될 것입니다.")
        
    elif radio_count >= 1 and "손전등" in inventory and "비상용 배터리" in inventory:
        print_slow("무전기는 불안정했지만, 야밤에 손전등에 비상 배터리를 연결해 강렬한 빛기둥으로 SOS를 쏘아올렸습니다!")
        print_slow("수색대의 눈에 그 빛이 닿았고, 조종사가 옥상으로 밧줄을 내려 당신을 구출해냅니다.")
        print_slow("\n▶▶▶ [해피 엔딩: 기지를 발휘한 드라마틱한 구출] ◀◀◀")
        
    elif shelter_defense >= 60 and "식량통조림" in inventory:
        print_slow("헬기는 신호를 눈치채지 못하고 무심히 지나쳐갔습니다...")
        print_slow("하지만 당신은 실망하지 않습니다. 당신의 은신처는 좀비 군단이 와도 뚫리지 않는 강철 요새가 되었습니다.")
        print_slow("수북한 식량과 함께, 당신은 이 지역의 왕이 되기로 결심하며 와인을 따릅니다.")
        print_slow("\n▶▶▶ [노말 엔딩: 폐허 위에 군림하는 철의 군주] ◀◀◀")
        
    elif hp >= 80 and "무기" in inventory and "방탄조끼" in inventory:
        print_slow("구조는 실패했습니다. 군부대도 이 지역을 포기한 듯합니다.")
        print_slow("하지만 당신은 무기와 방어구로 완전 무장한 채 은신처 밖으로 걸어나갑니다.")
        print_slow("넘치는 체력과 전투 경험. 살아남는 것 자체가 목적이 된 당신의 또 다른 여정이 시작됩니다...")
        print_slow("\n▶▶▶ [노말 엔딩: 매드맥스, 끝없는 여정] ◀◀◀")
        
    else:
        print_slow("헬기가 지나가는 것을 그저 허망하게 하늘을 보며 눈물만 흘립니다...")
        print_slow("라디오도, 빛을 낼 수단도, 더 이상 방어할 힘과 식량도 남아있지 않습니다.")
        print_slow("점점 닫히는 은신처 문 너머로, 수천 마리의 좀비 떼가 내는 끔찍한 파열음만이 귓가를 맴돕니다.")
        print_slow("\n▶▶▶ [배드 엔딩: 잊혀진 자의 고독한 최후] ◀◀◀")
    print("*" * 70)
