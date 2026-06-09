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

        # напрямки: вперед + 8 сторін
        directions = [
            direction,
            np.array([direction[1], -direction[0]]),   # вправо
            np.array([-direction[1], direction[0]]),   # вліво
            -direction,
            np.array([1, 0]),
            np.array([-1, 0]),
            np.array([0, 1]),
            np.array([0, -1])
        ]

        best = None
        best_dist = 999999

        for d in directions:
            candidate = current + d * step

            if self.near_wall(candidate[0], candidate[1]):
                continue

            if self.was_here(candidate[0], candidate[1]):
                continue

            dist = np.linalg.norm(finish - candidate)

            if dist < best_dist:
                best = candidate
                best_dist = dist

        # якщо все погано → таймер і рандом
        if best is None:
            self.stuck_timer += 1

            rand = current + np.random.uniform(-60, 60, size=2)

            if self.stuck_timer > 10:
                self.last_positions.clear()
                self.stuck_timer = 0

            return self.build(rand)

        else:
            self.stuck_timer = 0

        self.last_positions.append((best[0], best[1]))
        self.last_positions = self.last_positions[-30:]

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