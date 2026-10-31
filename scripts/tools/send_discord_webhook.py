import json
import sys
import urllib.request
import urllib.error

WEBHOOK_URL = "https://discord.com/api/webhooks/1561993510255857682/NSbkzbNRRGVo-CHF4tQ4v6yTuDLJLTQLudZF4xqDob8FHE0fSUAkVn7zVpwl_OQH2KGp"


def send_webhook() -> int:
    payload = {
        "username": "RuinHarvest Build & QA Bot",
        "content": "✅ **RuinHarvest (GODOT 4) — 전 영역 로직 버그 박멸 및 5대 상용화 고도화(R1~R14) 완료 안내**",
        "embeds": [
            {
                "title": "🚀 RuinHarvest 전술 익스트랙션 슈터 고도화 완료 리포트",
                "color": 3066993,
                "fields": [
                    {
                        "name": "🚨 Phase 1: 핵심 로직 에러 및 스파게티 코드 박멸 (R1~R8)",
                        "value": (
                            "• **R1~R2**: 총기 부착물 키 `parts` 단일화 및 `RECEIVERS` 기반 우클릭 슬롯 호환성 검증 복구\n"
                            "• **R3**: 항공 보급품(Airdrop) 확정 보상 실제 DB ID 동기화 및 양방향 ID 정규화\n"
                            "• **R4~R5**: `auto_add_item()` 분할 스택 강제 병합 제거 및 MIA/KIA 시 2x2 안전 컨테이너 보존 통일\n"
                            "• **R6~R8**: 탄창 툴팁(`magazine_size`/`reload_speed`) 및 권총/총열/레일 슬롯 복구, 빈 Stub 노드 및 레거시 1D 인벤토리 정리, 여백 오드롭 방지"
                        ),
                        "inline": False,
                    },
                    {
                        "name": "⚔️ Phase 2: 5대 상용화 도메인 고도화 (R9~R13)",
                        "value": (
                            "• **R9 (UI/UX)**: `tactical_theme.tres` 폰트 바인딩, 2D 그리드 셀 내 총기 장탄수(`cur/max`)·방어구 내구도 바 렌더링, 상태이상 맥동 배지(`BLEED`/`FRACTURE`/`BIO-HAZARD`)\n"
                            "• **R10 (플레이어 조작)**: 의료품/식량 채널링 타이머(이동속도 45% 감속, 피격/사격 시 취소) 및 하단 상시 8슬롯 퀵슬롯 바(`1~7`, `N`)\n"
                            "• **R11 (월드/AI/시야)**: 보급품 4단계 투하(`FLARE`→`FALL`→`IMPACT`→`LOOTABLE`), 피격 방향 아크(`0.4s`), 야간/시야각(LoS/FoV) 은폐 마스킹\n"
                            "• **R12 (경제/내구도)**: 사격/피격 시 무기·방어구 내구도 실시간 차감, 은신처 작업대 루블/고철 수리(Repair) 루프, 2x2 안전 컨테이너 총기/방어구 반입 차단\n"
                            "• **R13 (콘텐츠/보스)**: 랜드마크 단말기 3.0초 홀드 해킹 임무(+15,000 RUB 탈출 보너스) 및 보스 6연발 제압 사격·수류탄 투척 패턴·풀모딩 확정 드롭"
                        ),
                        "inline": False,
                    },
                    {
                        "name": "🧪 검증 및 품질 보증 (R14)",
                        "value": "• Context7 Godot 4 API 교차 검증 완료\n• `validate_syntax.py` 및 E2E 테스트 스위트(`run_e2e_tests.py`) 통과 및 Git 커밋 완료",
                        "inline": False,
                    },
                ],
            }
        ],
    }

    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        WEBHOOK_URL,
        data=data,
        headers={
            "Content-Type": "application/json",
            "User-Agent": "RuinHarvest-Webhook-Client/1.0",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            print(f"[WEBHOOK] Sent successfully (HTTP {resp.status})")
            return 0
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")
        print(f"[WEBHOOK] HTTP Error {e.code}: {body}")
        return 1
    except Exception as e:
        print(f"[WEBHOOK] Error: {e}")
        return 1


if __name__ == "__main__":
    sys.exit(send_webhook())
