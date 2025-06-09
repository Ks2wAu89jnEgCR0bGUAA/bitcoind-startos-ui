from flask import Flask, jsonify, render_template
import requests
import time
import os
import yaml

app = Flask(__name__, static_folder='static', template_folder='templates')

#Load Start9 RPC credentials from the correct config path and keys
def load_rpc_credentials():
    config_path = "/root/.bitcoin/start9/config.yaml"  # 🛠 Corrected file path
    if not os.path.exists(config_path):
        raise FileNotFoundError("Start9 config not found at /root/.bitcoin/start9/config.yaml")

    with open(config_path, "r") as f:
        cfg = yaml.safe_load(f)

    rpc_user = cfg.get("rpc", {}).get("username", "")  # 🛠 Fixed nested YAML keys
    rpc_password = cfg.get("rpc", {}).get("password", "")  # 🛠 Same as above
    rpc_host = "bitcoind.embassy"
    rpc_port = 8332

    url = f"http://{rpc_host}:{rpc_port}"
    return url, rpc_user, rpc_password

# Load the RPC config once at startup
RPC_URL, RPC_USER, RPC_PASS = load_rpc_credentials()

def rpc(method, params=[]):
    """Make a raw RPC call to bitcoind"""
    response = requests.post(RPC_URL,
        json={"jsonrpc": "1.0", "id": "curl", "method": method, "params": params},
        headers={"content-type": "application/json"},
        auth=(RPC_USER, RPC_PASS)
    )
    result = response.json()
    if "error" in result and result["error"]:
        raise Exception(result["error"])
    return result["result"]

def seconds_to_dhms(seconds):
    days = seconds // 86400
    hours = (seconds % 86400) // 3600
    minutes = (seconds % 3600) // 60
    seconds = seconds % 60
    return f"{days}d {hours}h {minutes}m {seconds}s"

@app.route("/")
def index():
    return render_template("index.html")

@app.route("/stats")
def stats():
    try:
        info = rpc("getblockchaininfo")
        mempool = rpc("getmempoolinfo")
        net = rpc("getnetworkinfo")
        uptime = rpc("uptime")

        connections = net.get("connections", 0)
        inbound = net.get("connections_in", 0)
        outbound = net.get("connections_out", 0)

        headers = info.get("headers", 1)
        blocks = info.get("blocks", 0)
        sync_percent = round((blocks / headers) * 100, 2) if headers > 0 else 0.0

        return jsonify({
            "version": net.get("subversion", "").strip("/").replace("Satoshi:", ""),
            "blocks": blocks,
            "headers": headers,
            "sync_percent": sync_percent,
            "disk_size": round(info.get("size_on_disk", 0) / 1e9, 2),
            "mempool_size": round(mempool.get("usage", 0) / 1024 / 1024, 2),
            "connections": f"{connections} ({inbound} in / {outbound} out)",
            "uptime": seconds_to_dhms(uptime)
        })
    except Exception as e:
        print("❌ Error in /stats:", e)
        return jsonify({"error": str(e)}), 500

if __name__ == "__main__":
    app.run(debug=False, port=5006, host='0.0.0.0')
