"""Fetch official Windows templates using bounded HTTP ranges, not the 1.2 GB all-platform archive."""
from __future__ import annotations

import argparse
import json
import os
import re
import struct
import urllib.request
import zlib
from pathlib import Path


def request_bytes(url: str, start: int, end: int) -> bytes:
    request = urllib.request.Request(url, headers={"Range": f"bytes={start}-{end}", "User-Agent": "FutaGameBuild/1"})
    with urllib.request.urlopen(request, timeout=90) as response:
        if response.status != 206 or not response.headers.get("Content-Range", "").startswith(f"bytes {start}-{end}/"):
            raise RuntimeError("Server did not honor the bounded range request")
        data = response.read(end - start + 2)
    if len(data) != end - start + 1:
        raise RuntimeError("Incomplete template download")
    return data


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--version", default="4.7.2-stable")
    args = parser.parse_args()
    if not re.fullmatch(r"\d+\.\d+\.\d+-stable", args.version):
        raise SystemExit("Expected a pinned stable Godot version")
    destination = Path(os.environ["APPDATA"]) / "Godot" / "export_templates" / args.version.replace("-", ".")
    destination.mkdir(parents=True, exist_ok=True)
    api = f"https://api.github.com/repos/godotengine/godot/releases/tags/{args.version}"
    with urllib.request.urlopen(urllib.request.Request(api, headers={"User-Agent": "FutaGameBuild/1"}), timeout=30) as response:
        release = json.load(response)
    name = f"Godot_v{args.version}_export_templates.tpz"
    asset = next(item for item in release["assets"] if item["name"] == name)
    url, length = asset["browser_download_url"], asset["size"]
    tail = request_bytes(url, max(0, length - 65557), length - 1)
    offset = tail.rfind(b"PK\x05\x06")
    if offset < 0:
        raise RuntimeError("Archive directory signature missing")
    eocd = struct.unpack_from("<4s4H2LH", tail, offset)
    directory_size, directory_offset = eocd[5], eocd[6]
    if directory_size > 4_000_000:
        raise RuntimeError("Unexpected archive directory size")
    directory = request_bytes(url, directory_offset, directory_offset + directory_size - 1)
    entries, cursor = [], 0
    while cursor < len(directory):
        record = struct.unpack_from("<4s6H3L5H2L", directory, cursor)
        if record[0] != b"PK\x01\x02":
            raise RuntimeError("Malformed archive directory")
        filename = directory[cursor + 46:cursor + 46 + record[10]].decode("utf-8")
        base = filename.rsplit("/", 1)[-1]
        if re.fullmatch(r"windows_(debug|release)_x86_64(_console)?\.exe", base):
            entries.append((base, record))
        cursor += 46 + record[10] + record[11] + record[12]
    if not any(base == "windows_release_x86_64.exe" for base, _ in entries):
        raise RuntimeError("Official Windows release template missing")
    manifest = {"version": args.version, "source": url, "archive_size": length, "validation": "HTTPS official release; ZIP CRC32 and uncompressed size for each ranged entry", "templates": []}
    for base, record in entries:
        target = destination / base
        if target.exists() and target.stat().st_size == record[9] and (zlib.crc32(target.read_bytes()) & 0xFFFFFFFF) == record[7]:
            print(f"Verified cached {base}")
        else:
            local_offset = record[16]
            header = request_bytes(url, local_offset, local_offset + 29)
            local = struct.unpack("<4s5H3L2H", header)
            if local[0] != b"PK\x03\x04" or record[3] & 1 or record[8] > 200_000_000:
                raise RuntimeError("Unsupported template entry")
            data_offset = local_offset + 30 + local[9] + local[10]
            compressed = request_bytes(url, data_offset, data_offset + record[8] - 1)
            data = zlib.decompress(compressed, -15) if record[4] == 8 else compressed
            if len(data) != record[9] or (zlib.crc32(data) & 0xFFFFFFFF) != record[7]:
                raise RuntimeError(f"Template integrity failed: {base}")
            target.write_bytes(data)
            print(f"Saved {base}: {len(data):,} bytes")
        manifest["templates"].append({"name": base, "bytes": record[9], "crc32": f"{record[7]:08x}"})
    (destination / "night-crossing-manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print(destination)


if __name__ == "__main__":
    main()
