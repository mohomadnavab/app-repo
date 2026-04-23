from flask import Flask, jsonify
import os

app = Flask(__name__)

# APP_VERSION is injected at runtime by Kubernetes (from deployment.yaml env var)
APP_VERSION = os.getenv("APP_VERSION", "unknown")


@app.route("/")
def index():
    return jsonify({
        "status": "ok",
        "message": "GitOps EKS Demo Application",
        "version": APP_VERSION,
    })


@app.route("/health")
def health():
    return jsonify({"status": "healthy"}), 200


if __name__ == "__main__":
    # For local development only — gunicorn is used in production
    app.run(host="0.0.0.0", port=8080)
# initial deployment trigger
