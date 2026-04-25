FROM spotdl/spotify-downloader:latest
# Fix KeyError crashes in v4.4.3 — Spotify API randomly omits optional fields
# (genres, label, copyrights, popularity, images, tracks) for some results.
# Patch song.py to use .get() with safe defaults for all optional fields.
COPY patch_song.py /tmp/patch_song.py
RUN python3 /tmp/patch_song.py && rm /tmp/patch_song.py
