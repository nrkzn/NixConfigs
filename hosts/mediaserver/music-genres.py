"""Normalize the music library's tags after Lidarr.

1. One genre per album: Lidarr writes every MusicBrainz genre of an album
   into the files (up to 15), which some players show as one long joined
   string. Each of the album's genres is mapped to a broad category below;
   the category named most often wins (ties: the one listed first by
   Lidarr), and every track of the album gets exactly that one GENRE.
   Albums without a mappable genre are left untouched.
2. Stray artist fields from the original torrent files (ALBUM ARTIST with a
   space, ARTISTS, ALBUMARTISTS) are removed: they can disagree with the
   ALBUMARTIST/ARTIST Lidarr writes and make players split albums/artists.

Only files that actually change are written.
Usage: music-genres [--dry-run] [LIBRARY_DIR]
"""

import os
import re
import sys
from collections import Counter

import mutagen
from mutagen.id3 import ID3

# Checked in this order for each genre string; first match wins. Specific
# styles come before the generic words they contain ("hardcore hip hop"
# must become Hip Hop, not Punk; "pop rap" Hip Hop, not Pop).
RULES = [
    ("Hip Hop", r"hip ?hop|rap\b|trap\b|drill|boom bap|g-funk|grime|crunk"),
    ("Metal", r"metal|doom|thrash|sludge|djent"),
    ("Punk", r"punk|hardcore\b|emo\b|oi!"),
    ("Electronic", r"electronic|electro|house|techno|trance|edm|dubstep|"
                   r"drum and bass|jungle|trip hop|downtempo|ambient|synth|idm|breakbeat"),
    ("R&B/Soul", r"r&b|rnb|rhythm and blues|soul|funk|motown|new jack swing"),
    ("Reggae", r"reggae|dancehall|ska\b|dub\b|rocksteady"),
    ("Jazz", r"jazz|bebop|swing|bossa nova"),
    ("Blues", r"blues"),
    ("Country", r"country|bluegrass|americana"),
    ("Folk", r"folk|singer-songwriter|acoustic"),
    ("Latin", r"latin|reggaeton|salsa|cumbia"),
    ("Classical", r"classical|orchestral|baroque|opera|symphon"),
    ("Soundtrack", r"soundtrack|score|musical"),
    ("Rock", r"rock|grunge|indie|alternative|britpop|shoegaze|new wave|post-"),
    ("Pop", r"pop|dance|disco"),
]
RULES = [(name, re.compile(rx, re.I)) for name, rx in RULES]
AUDIO = (".flac", ".mp3", ".m4a", ".ogg", ".opus")
STRAY_VORBIS = ("album artist", "artists", "albumartists")       # lower-case keys
STRAY_ID3_TXXX = {"ALBUM ARTIST", "ARTISTS", "ALBUMARTISTS"}


def category(genre):
    for name, rx in RULES:
        if rx.search(genre):
            return name
    return None


def album_genre(genres):
    """Majority vote over the mapped categories; ties go to the earliest."""
    cats = [c for c in map(category, genres) if c]
    if not cats:
        return None
    counts = Counter(cats)
    best = max(counts.values())
    return next(c for c in cats if counts[c] == best)


def split(vals):
    out = []
    for v in vals:
        out += [p.strip() for p in re.split(r"[;/|]", str(v)) if p.strip()]
    return out


def read_genres(path):
    f = mutagen.File(path, easy=True)
    if f is None or f.tags is None:
        return []
    return split(f.tags.get("genre", []))


def fix_file(path, target, dry):
    """Set the single genre and drop stray artist fields. Returns what changed."""
    changes = []
    f = mutagen.File(path, easy=True)
    if f is None or f.tags is None:
        return changes
    if target and split(f.tags.get("genre", [])) != [target]:
        changes.append("genre")
        if not dry:
            f.tags["genre"] = [target]
    if path.lower().endswith(".mp3"):
        if not dry and changes:
            f.save()
        tags = ID3(path)
        stray = [k for k in tags.keys() if k.startswith("TXXX:") and k[5:].upper() in STRAY_ID3_TXXX]
        if stray:
            changes.append("stray")
            if not dry:
                for k in stray:
                    del tags[k]
                tags.save(path)
        return changes
    stray = [k for k in list(f.tags.keys()) if k.lower() in STRAY_VORBIS]
    if stray:
        changes.append("stray")
        if not dry:
            for k in stray:
                del f.tags[k]
    if changes and not dry:
        f.save()
    return changes


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    dry = "--dry-run" in sys.argv
    root = args[0] if args else "/data/media/library/music"
    stats = Counter()
    per_genre = Counter()
    for dirpath, _, files in sorted(os.walk(root)):
        tracks = sorted(os.path.join(dirpath, n) for n in files if n.lower().endswith(AUDIO))
        if not tracks:
            continue
        stats["albums"] += 1
        try:
            genres = read_genres(tracks[0])
        except Exception as e:  # unreadable file: leave the album alone
            print(f"SKIP unreadable {tracks[0]}: {e}")
            continue
        target = album_genre(genres)
        if target:
            per_genre[target] += 1
        else:
            stats["albums without mappable genre"] += 1
        shown = False
        for t in tracks:
            try:
                ch = fix_file(t, target, dry)
            except Exception as e:
                print(f"ERROR {t}: {e}")
                stats["errors"] += 1
                continue
            for c in ch:
                stats[f"files with {c} change"] += 1
            if dry and "genre" in ch and not shown:
                print(f"{os.path.relpath(dirpath, root)}: {'; '.join(genres)[:70]} -> {target}")
                shown = True
    mode = "DRY RUN — nothing written" if dry else "written"
    print(f"\n[{mode}] " + ", ".join(f"{k}: {v}" for k, v in stats.items()))
    print("albums per genre: " + ", ".join(f"{g} {n}" for g, n in per_genre.most_common()))


if __name__ == "__main__":
    main()
