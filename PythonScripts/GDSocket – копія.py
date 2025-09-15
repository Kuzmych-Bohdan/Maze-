import asyncio
import websockets
import numpy as np
import json
from sklearn.linear_model import LinearRegression, Ridge
from sklearn.preprocessing import PolynomialFeatures
from sklearn.pipeline import make_pipeline
from sklearn.svm import SVR
from sklearn.ensemble import RandomForestRegressor

class PredictionServer:
    def __init__(self):
        self.data_history = {
            'clear_x': [],
            'clear_y': [],
            'wall_x': [],
            'wall_y': []
        }
        self.true_collisions = []
        self.finish_position = {"x": 0.0, "y": 0.0}

        self.models = {
            'linear': LinearRegression(),
            'polynomial': make_pipeline(PolynomialFeatures(degree=2), LinearRegression()),
            'ridge': Ridge(alpha=1.0),
            'svr': SVR(kernel='rbf', C=100, gamma=0.1, epsilon=.1),
            'random_forest': RandomForestRegressor(n_estimators=100)
        }

        self.min_data_points = 5
        self.max_data_points = 50
        self.prediction_window = 5

    async def handle_client(self, websocket, path):
        print("✅ Клієнт підключений")
        try:
            async for message in websocket:
                try:
                    print("\n--- Отримано нове повідомлення ---")
                    data = self._parse_message(message)
                    if not data:
                        await websocket.send(json.dumps({
                            "error": "Отримано порожні дані",
                            "status": "error"
                        }))
                        continue

                    self._update_data(data)

                    if len(self.data_history['clear_x']) >= self.min_data_points:
                        response = self._generate_predictions()
                    else:
                        response = {
                            "status": "waiting",
                            "message": f"Недостатньо даних (потрібно {self.min_data_points})",
                            "current_data": len(self.data_history['clear_x'])
                        }

                    await websocket.send(json.dumps(response))

                except json.JSONDecodeError:
                    await websocket.send(json.dumps({"error": "Невірний формат JSON", "status": "error"}))
                except Exception as e:
                    await websocket.send(json.dumps({"error": str(e), "status": "error"}))

        except websockets.exceptions.ConnectionClosed:
            print("🔌 Клієнт відключився")

    def _parse_message(self, message):
        try:
            data = json.loads(message)
            clear_x = data['clearSector'].get('positionClearSectorX', [])
            clear_y = data['clearSector'].get('positionClearSectorY', [])
            wall_x = data['wallSector'].get('positionWallSectorX', [])
            wall_y = data['wallSector'].get('positionWallSectorY', [])
            collisions = data.get('collisions', [])

            if not all(isinstance(lst, list) for lst in [clear_x, clear_y, wall_x, wall_y]):
                raise ValueError("Координати мають бути списками")

            return {
                'clear_x': [float(x) for x in clear_x],
                'clear_y': [float(y) for y in clear_y],
                'wall_x': [float(x) for x in wall_x],
                'wall_y': [float(y) for y in wall_y],
                'collisions': collisions
            }

        except Exception as e:
            raise ValueError(f"Помилка парсингу даних: {str(e)}")

    def _update_data(self, new_data):
        for key in self.data_history:
            self.data_history[key].extend(new_data[key])
            self.data_history[key] = self.data_history[key][-self.max_data_points:]

        if 'collisions' in new_data and new_data['collisions']:
            for collision in new_data['collisions']:
                # Стандартна обробка зіткнень
                if isinstance(collision, dict) and 'wall' in collision:
                    wall_status = collision.get('wall')
                    if wall_status in [0, 1]:
                        self.true_collisions.append(int(wall_status))
                        self.true_collisions = self.true_collisions[-self.max_data_points:]

                # Обробка координат фінішу
                if isinstance(collision, dict) and collision.get("type") == "finish_position":
                    finish_data = collision.get("data", {}).get("finish_position", {})
                    try:
                        self.finish_position["x"] = float(finish_data.get("x", 0.0))
                        self.finish_position["y"] = float(finish_data.get("y", 0.0))
     
                    except Exception as e:
                        print(f"⚠️ Не вдалося зчитати координати фінішу: {e}")

    def _generate_predictions(self):
        min_len = min(len(self.data_history[key]) for key in self.data_history)
        if min_len < self.prediction_window:
            raise ValueError("Недостатньо даних для прогнозу")

        print(f"[INFO] Кількість даних: {min_len} точок")

        finish_x = self.finish_position["x"]
        finish_y = self.finish_position["y"]

        # Формування X та y
        X = np.column_stack((
            self.data_history['clear_x'][:min_len],
            self.data_history['wall_x'][:min_len],
            self.data_history['wall_y'][:min_len],
            [finish_x] * min_len,
            [finish_y] * min_len
        ))

        y_y = np.array(self.data_history['clear_y'][:min_len])
        y_x = np.array(self.data_history['clear_x'][:min_len])

        results = {"status": "success", "models": {}}

        X_pred = np.column_stack((
            self.data_history['clear_x'][-self.prediction_window:],
            self.data_history['wall_x'][-self.prediction_window:],
            self.data_history['wall_y'][-self.prediction_window:],
            [finish_x] * self.prediction_window,
            [finish_y] * self.prediction_window
        ))

        for name, model in self.models.items():
            try:
                # Прогноз Y
                model.fit(X, y_y)
                y_pred = model.predict(X_pred).tolist()
                results["models"][f"{name}_Y"] = y_pred

                # Прогноз X
                model.fit(X, y_x)
                x_pred = model.predict(X_pred).tolist()
                results["models"][f"{name}_X"] = x_pred

                print(f"[{name.upper()}] Прогноз Y: {np.round(y_pred, 2)}")
                print(f"[{name.upper()}] Прогноз X: {np.round(x_pred, 2)}")

            except Exception as e:
                print(f"[ERROR] Модель {name} зламалась: {e}")
                results["models"][name] = {"error": str(e)}

        return results

async def main():
    server = PredictionServer()
    async with websockets.serve(server.handle_client, "localhost", 6000):
        print("🚀 Сервер запущено на ws://localhost:6000")
        await asyncio.Future()

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("🛑 Сервер зупинено")
