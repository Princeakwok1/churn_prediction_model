from flask import Flask, request, jsonify
import joblib
import pandas as pd

app = Flask(__name__)

# Load the trained model bundle
MODEL_PATH = "model_bundle.pkl"
bundle = joblib.load(MODEL_PATH)
model = bundle["model"]
features = bundle["features"]

# Health check route for ECS/ALB
@app.route("/", methods=["GET"])
def home():
    return {"status": "ok"}, 200   # ✅ Health check passes

# Prediction route
@app.route("/predict", methods=["POST"])
def predict():
    try:
        data = request.get_json()
        input_features = data.get("features", {})

        # Convert dict to DataFrame with correct columns
        df = pd.DataFrame([input_features])

        preds = model.predict(df)[0]
        return jsonify({"prediction": int(preds)})
    except Exception as e:
        return jsonify({"error": f"Model prediction error: {str(e)}"}), 400


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
