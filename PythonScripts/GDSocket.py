import asyncio
import json
import numpy as np
import websockets
import time


class PredictionServer:

    def __init__(self):
        self.clear_x = []
        self.clear_y = []
        self.wall_x = []
        self.wall_y = []

        self.finish_position = {"x": 0.0, "y": 0.0}

        self.max_history = 200
        self.min_points = 5

        # анти-зациклення
        self.last_positions = []
        self.stuck_timer = 0
        self.stuck_limit = 8

        # запам'ятовуємо області довгих зупинок, щоб не повертатися в те саме місце
        self.area_history = []
        self.area_size = 80
        self.area_repeat_limit = 4

    async def handle_client(self, websocket):
        print("✅ Client connected")

        async for message in websocket:
            try:
                data = json.loads(message)
                self.update_data(data)

                if len(self.clear_x) < self.min_points:
                    await websocket.send(json.dumps({"status": "waiting"}))
                    continue

                result = self.predict()
                await websocket.send(json.dumps(result))

            except Exception as e:
                print("❌ Error:", e)
                await websocket.send(json.dumps({"status": "error"}))

    def update_data(self, data):
        cs = data.get("clearSector", {})
        ws = data.get("wallSector", {})
        collisions = data.get("collisions", [])

        self.clear_x.extend(cs.get("positionClearSectorX", []))
        self.clear_y.extend(cs.get("positionClearSectorY", []))

        self.wall_x.extend(ws.get("positionWallSectorX", []))
        self.wall_y.extend(ws.get("positionWallSectorY", []))

        for c in collisions:
            print("EVENT:", c)
            if c.get("type") == "finish_position":
                self.finish_position = {
                    "x": c["data"]["x"],
                    "y": c["data"]["y"]
                }
            elif c.get("type") == "wall_hit":
                # Wall hit already tracked in Godot, just acknowledge
                pass

        self.clear_x = self.clear_x[-self.max_history:]
        self.clear_y = self.clear_y[-self.max_history:]
        self.wall_x = self.wall_x[-self.max_history:]
        self.wall_y = self.wall_y[-self.max_history:]

    def near_wall(self, x, y, threshold=25):
        for wx, wy in zip(self.wall_x, self.wall_y):
            if np.hypot(x - wx, y - wy) < threshold:
                return True
        return False

    def was_here(self, x, y):
        for px, py in self.last_positions:
            if np.hypot(x - px, y - py) < 20:
                return True
        return False

    def area_key(self, x, y, size=None):
        if size is None:
            size = self.area_size
        return (int(round(x / size)), int(round(y / size)))

    def remember_area(self, x, y):
        self.area_history.append(self.area_key(x, y))
        self.area_history = self.area_history[-200:]

    def is_repeated_area(self, x, y):
        area = self.area_key(x, y)
        recent = self.area_history[-80:]
        return sum(1 for item in recent if item == area) >= self.area_repeat_limit

    def rotate_vector(self, vector, angle_deg):
        angle = np.deg2rad(angle_deg)
        c, s = np.cos(angle), np.sin(angle)
        x = vector[0] * c - vector[1] * s
        y = vector[0] * s + vector[1] * c
        return np.array([x, y], dtype=float)

    def choose_alternative_move(self, current, finish):
        current = np.asarray(current, dtype=float)
        finish = np.asarray(finish, dtype=float)

        direction = finish - current
        if np.linalg.norm(direction) == 0:
            return None

        direction = direction / np.linalg.norm(direction)
        stop_plane_margin = 2.0
        search_radii = [200, 120, 180]

        print("🔎 Alternative path search started at radius:", search_radii)

        for alt_radius in search_radii:
            candidates = []

            for angle in [-180, -150, -120, -90, -60, -30, 0, 30, 60, 90, 120, 150, 180]:
                d = self.rotate_vector(direction, angle)
                candidate = current + d * alt_radius

                if self.near_wall(candidate[0], candidate[1]):
                    continue

                if self.was_here(candidate[0], candidate[1]):
                    continue

                if self.last_positions:
                    stop_distance = min(np.hypot(candidate[0] - px, candidate[1] - py) for px, py in self.last_positions)
                    if stop_distance <= stop_plane_margin:
                        continue

                dist = np.linalg.norm(finish - candidate)
                candidates.append((dist, candidate))

            if candidates:
                candidates.sort(key=lambda item: item[0])
                return candidates[0][1]

        return None

    def predict(self):
        last_x = self.clear_x[-1]
        last_y = self.clear_y[-1]

        finish = np.array([
            self.finish_position["x"],
            self.finish_position["y"]
        ])

        current = np.array([last_x, last_y])
        direction = finish - current

        if np.linalg.norm(direction) == 0:
            return self.build(current)

        direction = direction / np.linalg.norm(direction)
        step = 40

        directions = [
            direction,
            self.rotate_vector(direction, 30),
            self.rotate_vector(direction, -30),
            self.rotate_vector(direction, 90),
            self.rotate_vector(direction, -90),
            self.rotate_vector(direction, 135),
            self.rotate_vector(direction, -135),
            -direction,
            np.array([1, 0]),
            np.array([-1, 0]),
            np.array([0, 1]),
            np.array([0, -1])
        ]

        best = None
        best_dist = 999999
        stop_margin = 2

        for d in directions:
            candidate = current + d * step

            if self.near_wall(candidate[0], candidate[1]):
                continue

            if self.was_here(candidate[0], candidate[1]):
                continue

            if self.is_repeated_area(candidate[0], candidate[1]):
                continue

            # пріоритет альтернативних вільних напрямків, коли об'єкт ще близько до місць стоянок
            near_stop = any(np.hypot(candidate[0] - px, candidate[1] - py) <= stop_margin for px, py in self.last_positions)
            dist = np.linalg.norm(finish - candidate)

            if near_stop:
                if best is None or dist < best_dist:
                    best = candidate
                    best_dist = dist
            elif dist < best_dist:
                best = candidate
                best_dist = dist

        if best is None:
            self.stuck_timer += 1
            self.remember_area(current[0], current[1])
            alternative = self.choose_alternative_move(current, finish)

            if alternative is not None and self.stuck_timer >= self.stuck_limit:
                self.stuck_timer = 0
                self.last_positions.clear()
                self.last_positions.append((alternative[0], alternative[1]))
                self.last_positions = self.last_positions[-30:]
                self.remember_area(alternative[0], alternative[1])
                return self.build(alternative)

            if self.stuck_timer > self.stuck_limit * 2:
                self.last_positions.clear()
                self.stuck_timer = 0

            rand = current + np.random.uniform(-60, 60, size=2)
            self.remember_area(rand[0], rand[1])
            return self.build(rand)

        self.stuck_timer = 0

        self.last_positions.append((best[0], best[1]))
        self.last_positions = self.last_positions[-30:]
        self.remember_area(best[0], best[1])

        return self.build(best)

    def build(self, pos):
        return {
            "status": "success",
            "models": {
                "linear": [[float(pos[0]), float(pos[1])]]
            }
        }


async def main():
    server = PredictionServer()
    async with websockets.serve(server.handle_client, "localhost", 6000):
        print("🚀 Server running on ws://localhost:6000")
        await asyncio.Future()


if __name__ == "__main__":
    asyncio.run(main())