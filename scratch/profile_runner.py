import sys
import os
import cProfile
import pstats

# 저장소 루트 및 src 디렉토리를 path에 추가
current_dir = os.path.dirname(os.path.abspath(__file__))
repo_root = os.path.dirname(current_dir)
src_dir = os.path.join(repo_root, 'src')
sys.path.insert(0, src_dir)

# 하위 폴더들 추가
subdirs = ['core', 'world', 'entities', 'systems', 'graphics']
for subdir in subdirs:
    path = os.path.join(src_dir, subdir)
    if path not in sys.path:
        sys.path.insert(0, path)

def run_game():
    from main import Game
    game = Game()
    game.run()

if __name__ == '__main__':
    print("=" * 60)
    print(" 30일간의 생존 - 성능 프로파일링 실행 도구")
    print("=" * 60)
    print(" 게임이 켜지면 테스트 플레이(이동, 레이드 진입 등)를 가볍게 하신 후")
    print(" 게임 창을 닫아주시면(ESC -> 메인메뉴 -> 종료 혹은 창 닫기) 분석 결과가 출력됩니다.")
    print("=" * 60)
    
    profile_file = os.path.join(current_dir, 'game_profile.prof')
    
    # cProfile을 통해 메인 게임 구동
    cProfile.run('run_game()', profile_file)
    
    print("\n" + "=" * 60)
    print(" 누적 실행 시간 기준 상위 30개 함수 (Cumulative Time)")
    print("=" * 60)
    p = pstats.Stats(profile_file)
    p.strip_dirs().sort_stats('cumulative').print_stats(30)

    print("\n" + "=" * 60)
    print(" 자체 실행 시간 기준 상위 30개 함수 (Internal/Self Time)")
    print("=" * 60)
    p.strip_dirs().sort_stats('tottime').print_stats(30)
