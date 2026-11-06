# Downloads the group's published SplitDeck place through Open Cloud's Asset Delivery API,
# for tools/build-place.luau to build on:
#
#   python tools/download-place.py build/base.rbxl
#   lune run tools/build-place build/base.rbxl
#
# The key is read from the ROBLOX_API_KEY environment variable and never written anywhere.
# It needs the Legacy Asset permission (legacy-asset:manage). Group-owned keys are refused that
# scope, so use a user key from someone with access to the group's experience.
import gzip
import json
import os
import sys
import urllib.error
import urllib.request

PLACE_ID = "70756985983915"  # SplitDeck's root place, owned by Fridae Studios


def main():
    key = os.environ.get("ROBLOX_API_KEY")
    if not key or len(sys.argv) not in (2, 3):
        sys.exit("Set ROBLOX_API_KEY, then run: python tools/download-place.py <out.rbxl> [version]")
    # Without a version Roblox can serve an old copy for a while after a publish.
    version = f"/version/{sys.argv[2]}" if len(sys.argv) == 3 else ""
    request = urllib.request.Request(
        f"https://apis.roblox.com/asset-delivery-api/v1/assetId/{PLACE_ID}{version}",
        headers={"x-api-key": key},
    )
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            info = json.loads(response.read().decode())
    except urllib.error.HTTPError as error:
        sys.exit(f"Roblox refused the download: {error.code} {error.read().decode('utf-8', 'replace')[:200]}")
    location = info.get("location")
    if not location:
        sys.exit(f"No download location in the reply: {json.dumps(info)[:200]}")
    with urllib.request.urlopen(location, timeout=120) as response:
        data = response.read()
    if data[:2] == b"\x1f\x8b":
        data = gzip.decompress(data)  # Roblox serves the place gzipped
    if not data.startswith(b"<roblox"):
        sys.exit("The download isn't a place file.")
    os.makedirs(os.path.dirname(sys.argv[1]) or ".", exist_ok=True)
    with open(sys.argv[1], "wb") as handle:
        handle.write(data)
    print(f"Downloaded place {PLACE_ID} to {sys.argv[1]} ({len(data)} bytes)")


main()
