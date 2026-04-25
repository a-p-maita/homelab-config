"""
Patch spotdl/types/song.py to use .get() for all Spotify API fields that are
sometimes omitted in API responses (v4.4.3 upstream bug).
"""

path = "/app/spotdl/types/song.py"
with open(path) as f:
    src = f.read()

replacements = [
    # genres — album and artist may omit this field
    (
        'raw_album_meta["genres"] + raw_artist_meta["genres"]',
        'raw_album_meta.get("genres", []) + raw_artist_meta.get("genres", [])',
    ),
    # label — not always present (e.g. singles, non-label releases)
    (
        'publisher=raw_album_meta["label"]',
        'publisher=raw_album_meta.get("label")',
    ),
    # copyrights — conditional check AND data access both need .get()
    (
        'raw_album_meta["copyrights"][0]["text"]\n                if raw_album_meta["copyrights"]',
        'raw_album_meta.get("copyrights", [])[0]["text"]\n                if raw_album_meta.get("copyrights")',
    ),
    # popularity — omitted on some regional/market-restricted tracks
    (
        'popularity=raw_track_meta["popularity"]',
        'popularity=raw_track_meta.get("popularity", 0)',
    ),
    # images — cover art sometimes absent
    (
        'max(raw_album_meta["images"], key=lambda i: i["width"] * i["height"])[\n                    "url"\n                ]\n                if raw_album_meta["images"]',
        'max(raw_album_meta.get("images", []), key=lambda i: i["width"] * i["height"])[\n                    "url"\n                ]\n                if raw_album_meta.get("images")',
    ),
    # disc_count — tracks/items may be absent for compilations/non-album singles
    (
        'disc_count=int(raw_album_meta["tracks"]["items"][-1]["disc_number"])',
        'disc_count=int((raw_album_meta.get("tracks", {}).get("items") or [{"disc_number": 1}])[-1]["disc_number"])',
    ),
]

for old, new in replacements:
    if old in src:
        src = src.replace(old, new)
        print(f"Patched: {old[:60]!r}...")
    else:
        print(f"WARNING: pattern not found (already patched?): {old[:60]!r}...")

with open(path, "w") as f:
    f.write(src)

print("song.py patched successfully.")
