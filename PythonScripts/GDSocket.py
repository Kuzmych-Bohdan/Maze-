import asyncio
import json
import numpy as np
import websockets

from sklearn.linear_model import LinearRegression
from sklearn.preprocessing import PolynomialFeatures
from sklearn.pipeline import make_pipeline
from sklearn.svm import SVR
from sklearn.ensemble import RandomForestRegressor


# ===============================
#   SERVER CLASS
# ===============================
class PredictionServer:

    def __init__(self):
        # ІСТОРІЯ ДАНИХ
        self.clear_x = []
        self.clear_y = []
        self.wall_x = []
        self.wall_y = []

        self.finish_position = {"x": 0.0, "y": 0.0}

        self.max_history = 200
        self.min_points = 10
        self.prediction_steps = 5

        # МОДЕЛІ
        self.models = {
            "linear": LinearRegression(),
            "poly": make_pipeline(PolynomialFeatures(2), LinearRegression()),
            "svr": SVR(C=100, gamma=0.1),
            "rf": RandomForestRegressor(n_estimators=100)
        }

    # ===============================
    #   WEBSOCKET HANDLER
    # ===============================
    async def handle_client(self, websocket):
        print("✅ Client connected")

        async for message in websocket:
            try:
                data = json.loads(message)
                self.update_data(data)

                print(f"📥 clear={len(self.clear_x)} wall={len(self.wall_x)} finish={self.finish_position}")

                if len(self.clear_x) < self.min_points:
                    await websocket.send(json.dumps({
                        "status": "waiting",
                        "count": len(self.clear_x)
                    }))
                    continue

                print("🧠 Predicting...")
                result = self.predict()
                await websocket.send(json.dumps(result))

            except Exception as e:
                print("❌ Server error:", e)
                await websocket.send(json.dumps({
                    "status": "error",
                    "message": str(e)
                }))

    # ===============================
    #   DATA UPDATE
    # ===============================
    def update_data(self, data):
        cs = data.get("clearSector", {})
        ws = data.get("wallSector", {})
        collisions = data.get("collisions", [])

        self.clear_x.extend(cs.get("positionClearSectorX", []))
        self.clear_y.extend(cs.get("positionClearSectorY", []))
        self.wall_x.extend(ws.get("positionWallSectorX", []))
        self.wall_y.extend(ws.get("positionWallSectorY", []))

        # ФІНІШ
        for c in collisions:
            if c.get("type") == "finish_position":
                self.finish_position = c["data"]["finish_position"]

        # ОБМЕЖЕННЯ ПАМʼЯТІ
        self.clear_x = self.clear_x[-self.max_history:]
        self.clear_y = self.clear_y[-self.max_history:]
        self.wall_x = self.wall_x[-self.max_history:]
        self.wall_y = self.wall_y[-self.max_history:]

    # ===============================
    #   WALL CHECK
    # ===============================
    def near_wall(self, x, y, threshold=12):
        for wx, wy in zip(self.wall_x, self.wall_y):
            if np.hypot(x - wx, y - wy) < threshold:
                return True
        return False

    # ===============================
    #   PREDICTION
    # ===============================
    def predict(self):
        X = np.column_stack((
            self.clear_x,
            self.clear_y,
            [self.finish_position["x"]] * len(self.clear_x),
            [self.finish_position["y"]] * len(self.clear_y)
        ))

        yx = np.array(self.clear_x)
        yy = np.array(self.clear_y)

        last_x = self.clear_x[-1]
        last_y = self.clear_y[-1]

        results = {
            "status": "success",
            "models": {}
        }

        for name, model in self.models.items():
            # Y
            model.fit(X, yy)
            pred_y = model.predict(X[-self.prediction_steps:])

            # X
            model.fit(X, yx)
            pred_x = model.predict(X[-self.prediction_steps:])

            path = []

            for px, py in zip(pred_x, pred_y):
                # РУХ ВПЕРЕД
                alpha = 0.6
                nx = last_x + alpha * (px - last_x)
                ny = last_y + alpha * (py - last_y)

                # УНИКНЕННЯ СТІН
                if self.near_wall(nx, ny):
                    nx += np.random.uniform(-25, 25)
                    ny += np.random.uniform(-25, 25)

                path.append([float(nx), float(ny)])
                last_x, last_y = nx, ny

            results["models"][name] = path

        return results


# ===============================
#   MAIN
# ===============================
async def main():
    server = PredictionServer()
    async with websockets.serve(server.handle_client, "localhost", 6000):
        print("🚀 Server running on ws://localhost:6000")
        await asyncio.Future()


if __name__ == "__main__":
    asyncio.run(main())
