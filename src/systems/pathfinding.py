import heapq
import math

def find_path(start, end, world):
    """
    A* 알고리즘을 사용한 최단 경로 탐색
    start: (start_x, start_y)
    end: (end_x, end_y)
    world: World 인스턴스 (is_walkable 메소드를 제공해야 함)
    반환값: [(x1, y1), (x2, y2), ...] 월드 좌표 리스트 (각 타일의 중심점)
    """
    start_t = (int(start[0]), int(start[1]))
    end_t = (int(end[0]), int(end[1]))

    # 시작점과 끝점이 같으면 바로 빈 경로 반환
    if start_t == end_t:
        return []

    # 끝점이 걸어갈 수 없는 타일인 경우, 끝점 주변의 걸어갈 수 있는 가장 가까운 타일로 끝점 변경 시도
    if not world.is_walkable(end_t[0] + 0.5, end_t[1] + 0.5):
        found_alternative = False
        # 8방향 주변 탐색
        for dx, dy in [(-1, 0), (1, 0), (0, -1), (0, 1), (-1, -1), (-1, 1), (1, -1), (1, 1)]:
            nx, ny = end_t[0] + dx, end_t[1] + dy
            if world.is_walkable(nx + 0.5, ny + 0.5):
                end_t = (nx, ny)
                found_alternative = True
                break
        if not found_alternative:
            return []

    # 8방향 이동 정의 (dx, dy, cost)
    neighbors = [
        (-1, 0, 1.0), (1, 0, 1.0), (0, -1, 1.0), (0, 1, 1.0),
        (-1, -1, 1.414), (-1, 1, 1.414), (1, -1, 1.414), (1, 1, 1.414)
    ]

    # 휴리스틱: 대각선 거리(Octile Distance)
    def heuristic(p1, p2):
        dx = abs(p1[0] - p2[0])
        dy = abs(p1[1] - p2[1])
        return (dx + dy) + (1.414 - 2) * min(dx, dy)

    # open_set: (f_score, g_score, (x, y))
    open_set = []
    heapq.heappush(open_set, (heuristic(start_t, end_t), 0.0, start_t))
    
    # parent dict for path reconstruction
    came_from = {}
    
    # g_score: (x, y) -> cost
    g_score = {start_t: 0.0}

    # open_set에 들어온 횟수 제한 (성능 방어선)
    nodes_explored = 0
    MAX_NODES = 150

    best_node = start_t
    best_h = heuristic(start_t, end_t)

    while open_set:
        nodes_explored += 1
        if nodes_explored > MAX_NODES:
            # 시간 초과 시 그나마 가장 가까웠던 노드 기준으로 경로 재구성
            end_t = best_node
            break

        current_f, current_g, current = heapq.heappop(open_set)

        # 이미 더 좋은 경로를 찾은 노드는 무시
        if current_g > g_score.get(current, float('inf')):
            continue

        if current == end_t:
            break

        # 현재 노드가 목표지점과 가장 가까운지 기록
        h_val = heuristic(current, end_t)
        if h_val < best_h:
            best_h = h_val
            best_node = current

        for dx, dy, move_cost in neighbors:
            neighbor = (current[0] + dx, current[1] + dy)

            # 맵 범위 밖이거나 걸어갈 수 없는 타일은 제외
            # 대각선 이동 시 코너 끼임 현상 방지: 대각선 이동 시 인접 수평/수직 타일 모두 걸을 수 있어야 함
            if dx != 0 and dy != 0:
                if not world.is_walkable(current[0] + dx + 0.5, current[1] + 0.5) or \
                   not world.is_walkable(current[0] + 0.5, current[1] + dy + 0.5):
                    continue

            if not world.is_walkable(neighbor[0] + 0.5, neighbor[1] + 0.5):
                continue

            tentative_g = current_g + move_cost
            if tentative_g < g_score.get(neighbor, float('inf')):
                came_from[neighbor] = current
                g_score[neighbor] = tentative_g
                f = tentative_g + heuristic(neighbor, end_t)
                heapq.heappush(open_set, (f, tentative_g, neighbor))

    # 경로 재구성
    if end_t not in came_from and start_t != end_t:
        return []

    path = []
    curr = end_t
    while curr in came_from:
        path.append((curr[0] + 0.5, curr[1] + 0.5))
        curr = came_from[curr]
    path.reverse()
    
    return path
