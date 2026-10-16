"""Subset original OFL fonts against all native and authored game text."""
from pathlib import Path
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont
from fontTools import subset

ROOT = Path(__file__).resolve().parents[1]
characters = set(chr(n) for n in range(32, 127))
characters.update("∞→×·：，。；！？—（）壹贰叁肆〇")
for path in (ROOT / "godot").rglob("*"):
    if path.suffix in (".gd", ".json", ".tscn") and ".godot" not in path.parts:
        characters.update(path.read_text(encoding="utf-8"))
for name, source_name, family in (
    ("NightRoadNotes", "LXGWWenKai-Medium", "NightRoad Notes"),
    ("NightRoadInscription", "MaShanZheng", "NightRoad Inscription"),
):
    source = ROOT / "tools" / "_sources" / (source_name + "-source.ttf")
    if not source.exists():
        raise SystemExit(f"Original font required: {source}")
    font = TTFont(source)
    if "fvar" in font:
        font = instantiateVariableFont(font, {"wght": 500}, inplace=True)
    options = subset.Options()
    options.layout_features = ["*"]
    options.name_IDs = [0, 1, 2, 3, 4, 5, 6, 13, 14]
    selector = subset.Subsetter(options=options)
    selector.populate(text="".join(characters))
    selector.subset(font)
    # Subsets are modified fonts; honor the upstream reserved family names.
    for record in font["name"].names:
        if record.nameID in (1, 3, 4, 6, 16):
            value = name if record.nameID == 6 else family
            record.string = value.encode(record.getEncoding(), errors="replace")
    output = ROOT / "godot" / "assets" / "fonts" / (name + ".ttf")
    font.save(output)
    missing = {ord(c) for c in characters if 0x4E00 <= ord(c) <= 0x9FFF} - set(font.getBestCmap())
    if missing and name == "NightRoadNotes":
        raise SystemExit(f"Missing Chinese characters: {''.join(map(chr, sorted(missing)))}")
    print(name, len(characters), output.stat().st_size)
