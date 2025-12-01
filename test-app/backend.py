import os
from flask import Flask, jsonify

app = Flask(__name__)

MY_HOST = os.uname()[1]


@app.route("/health", methods=["GET"])
def health_check():
    """Health check endpoint used by load balancers."""
    return "ok", 200


@app.route("/info", methods=["GET"])
def info():
    """Return backend service information."""
    return jsonify(backend_host=MY_HOST), 200


if __name__ == "__main__":
    host = os.getenv("HOST", "0.0.0.0")
    port = int(os.getenv("PORT", "5501"))
    print(f"Running backend REST server on {host}:{port}")
    app.run(host=host, port=port, debug=False)
