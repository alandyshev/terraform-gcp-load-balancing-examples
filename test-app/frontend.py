import os
import requests
from flask import Flask

app = Flask(__name__)

MY_HOST = os.uname()[1]

# Adjust BACKEND_URL value with the IP address of your Internal Load Balancer.
BACKEND_URL = os.getenv("BACKEND_URL", "http://localhost:5501/info")


@app.route("/health", methods=["GET"])
def health_check():
    """Health check endpoint used by load balancers."""
    return "ok", 200


@app.route("/info", methods=["GET"])
def info():
    """
    Call the backend /info endpoint, combine backend+frontend hostnames,
    and return them in a simple human-readable response.
    """
    try:
        response = requests.get(BACKEND_URL, timeout=3)
        response.raise_for_status()

        backend_data = response.json()
        backend_host = backend_data.get("backend_host", "unknown")

        result = (
            f"Frontend: {MY_HOST}\n"
            f"Backend: {backend_host}\n"
        )
        return result, 200

    except requests.exceptions.RequestException as exc:
        print(f"[frontend:{MY_HOST}] Error calling backend {BACKEND_URL}: {exc}")

        result = (
            f"Frontend: {MY_HOST}\n"
            f"Backend: unavailable\n"
        )
        return result, 502


if __name__ == "__main__":
    host = os.getenv("HOST", "0.0.0.0")
    port = int(os.getenv("PORT", "5500"))
    print(f"Running frontend REST server on {host}:{port}")
    app.run(host=host, port=port, debug=False)
