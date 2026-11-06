# Uploads images and sounds to Roblox as Fridae Studios group assets through Open Cloud,
# and records each file's asset id. PNGs upload as Image, sounds as Audio.
#
# The API key is read from the ROBLOX_API_KEY environment variable and never written anywhere.
# Use a key created in the group's settings with permission to write assets.
#
#   python tools/upload-group-assets.py results.json file1.wav file2.png ...
#
# Re-running with the same results file skips files already uploaded. Put the new ids in
# src/shared/Guns/SoundIds.luau, OutpostAssets.luau or Hud/FontImages.luau.
import json
import os
import sys
import time
import urllib.error
import urllib.request
import uuid

GROUP_ID = "237720778"  # Fridae Studios
API = "https://apis.roblox.com/assets/v1"
TYPES = {
    ".png": ("Image", "image/png"),
    ".wav": ("Audio", "audio/wav"),
    ".mp3": ("Audio", "audio/mpeg"),
    ".ogg": ("Audio", "audio/ogg"),
}


def call(key, method, url, body=None, content_type=None):
    for attempt in range(8):
        request = urllib.request.Request(url, data=body, method=method)
        request.add_header("x-api-key", key)
        if content_type:
            request.add_header("Content-Type", content_type)
        try:
            with urllib.request.urlopen(request, timeout=120) as response:
                return response.status, json.loads(response.read().decode("utf-8") or "{}")
        except urllib.error.HTTPError as error:
            text = error.read().decode("utf-8", "replace")
            if error.code == 429 or error.code >= 500:
                time.sleep(15 * (attempt + 1))
                continue
            return error.code, {"error": text}
        except urllib.error.URLError:
            time.sleep(10 * (attempt + 1))
    return 0, {"error": "gave up after retries"}


def upload(key, path):
    file = os.path.basename(path)
    asset_type, mime = TYPES[os.path.splitext(file)[1].lower()]
    meta = {
        "assetType": asset_type,
        "displayName": f"SplitDeck {os.path.splitext(file)[0]}"[:50],
        "description": "Split Deck game asset",
        "creationContext": {"creator": {"groupId": GROUP_ID}},
    }
    boundary = uuid.uuid4().hex
    with open(path, "rb") as handle:
        data = handle.read()
    body = b"".join([
        f"--{boundary}\r\nContent-Disposition: form-data; name=\"request\"\r\n\r\n{json.dumps(meta)}\r\n".encode(),
        f"--{boundary}\r\nContent-Disposition: form-data; name=\"fileContent\"; filename=\"{file}\"\r\nContent-Type: {mime}\r\n\r\n".encode(),
        data,
        f"\r\n--{boundary}--\r\n".encode(),
    ])
    status, reply = call(key, "POST", f"{API}/assets", body, f"multipart/form-data; boundary={boundary}")
    if status >= 300 or "path" not in reply:
        return {"error": f"{status} {reply.get('error', reply)}"[:600]}
    operation = reply["path"]
    for _ in range(90):
        time.sleep(3)
        status, reply = call(key, "GET", f"{API}/{operation}")
        if reply.get("done"):
            response = reply.get("response", {})
            if response.get("assetId"):
                return {"assetId": response["assetId"], "moderation": response.get("moderationResult", {}).get("moderationState")}
            return {"error": json.dumps(reply.get("error", reply))[:600]}
    return {"error": "timed out waiting for " + operation}


def main():
    key = os.environ.get("ROBLOX_API_KEY")
    if not key or len(sys.argv) < 3:
        sys.exit("Set ROBLOX_API_KEY, then run: python tools/upload-group-assets.py results.json <files...>")
    results_path, paths = sys.argv[1], sys.argv[2:]
    results = {}
    if os.path.exists(results_path):
        with open(results_path, "r", encoding="utf-8") as handle:
            results = json.load(handle)
    failures = 0
    for index, path in enumerate(paths, 1):
        if results.get(path, {}).get("assetId"):
            continue
        outcome = upload(key, path)
        results[path] = outcome
        with open(results_path, "w", encoding="utf-8") as handle:
            json.dump(results, handle, indent=1)
        print(f"{index}/{len(paths)} {path} {outcome}", flush=True)
        failures = failures + 1 if "error" in outcome else 0
        if failures >= 3:
            sys.exit("Stopped after three failures in a row: check the key's permissions and the upload limit.")


main()
