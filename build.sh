#!/usr/bin/env bash
# Build script for the Dracula ImageGlass theme packs (bash, cross-platform).
# Sources of truth:
#   icons/    - single set of SVG toolbar icons (Tabler Icons, MIT; recolored to
#               the Dracula palette - see README "Icons" section)
#   configs/  - manifest sources per version (igtheme.v8.xml, igtheme.v9.json,
#               igtheme.v10.json) plus the static preview.jpg
# Builds 2 packs by copying the right configs ({{NAME}} token substituted) + icons,
# then zips:
#   Dracula.igtheme          dual v8+v9 (official repo pattern)
#   Dracula.igtheme.zip      v10
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
ICON_DIR="$ROOT/icons"
CONF_DIR="$ROOT/configs"
SCRATCH="$ROOT/.build"

# Resolve a working python interpreter (python3 may be the Windows Store stub).
PY_CMD=""
for candidate in python3 python; do
    if command -v "$candidate" >/dev/null 2>&1 && "$candidate" -c 'pass' >/dev/null 2>&1; then
        PY_CMD="$candidate"
        break
    fi
done

# Convert a POSIX path to a Windows-native path when cygpath is available
# (Git Bash / MSYS only); pass it through unchanged everywhere else.
to_win() {
    if command -v cygpath >/dev/null 2>&1; then
        cygpath -w "$1"
    else
        printf '%s\n' "$1"
    fi
}

# ---------------------------------------------------------------- validate
# Validate that every icon/preview/logo referenced by a manifest exists in the
# pack folder. Uses python when available (always true on GitHub runners);
# otherwise falls back to a warning and skips validation.
validate_pack() {
    local dir="$1"
    if [ -n "$PY_CMD" ]; then
        "$PY_CMD" - "$dir" <<'PY'
import json, sys, os
try:
    import xml.etree.ElementTree as ET
except ImportError:
    ET = None

d = sys.argv[1]
missing = []

def check(name):
    if name and not os.path.isfile(os.path.join(d, name)):
        missing.append(name)

xmlf = os.path.join(d, 'igtheme.xml')
if os.path.isfile(xmlf) and ET is not None:
    root = ET.parse(xmlf).getroot()
    ti = root.find('./Theme/toolbar_icon')
    if ti is None:
        sys.exit('[%s] invalid XML manifest: <toolbar_icon> missing' % d)
    for v in ti.attrib.values():
        check(v)
    info = root.find('./Theme/Info')
    if info is None:
        sys.exit('[%s] invalid XML manifest: <Info> missing' % d)
    check(info.get('preview'))
    main = root.find('./Theme/main')
    if main is None:
        sys.exit('[%s] invalid XML manifest: <main> missing' % d)
    check(main.get('logo'))

jsonf = os.path.join(d, 'igtheme.json')
if os.path.isfile(jsonf):
    data = json.load(open(jsonf, encoding='utf-8'))
    for v in data.get('ToolbarIcons', {}).values():
        check(v)
    settings = data.get('Settings', {})
    check(settings.get('PreviewImage'))
    check(settings.get('AppLogo'))

if missing:
    sys.exit('[%s] missing referenced files: %s' % (d, ', '.join(missing)))
PY
    fi
}

# ---------------------------------------------------------------- pack
# pack <folder> <display-name> <extension> <config>...
pack() {
    local folder="$1"       # inner folder name (also zip entry prefix)
    local display="$2"      # display name ({{NAME}} token substitute)
    local ext="$3"          # archive extension (.igtheme / .igtheme.zip)
    local configs=("${@:4}") # manifest sources

    local dir="$SCRATCH/$folder"
    local pack_file="$ROOT/$folder.$ext"

    rm -rf "$dir"
    rm -f "$pack_file"
    mkdir -p "$dir"

    echo "preparing $display ($folder/)"
    cp "$ICON_DIR"/*.svg "$dir/"
    cp "$CONF_DIR/preview.jpg" "$dir/preview.jpg"

    # copy + substitute manifest configs ({{NAME}} - full display name like
    # "Dracula" / "Dracula 10")
    local src target
    for src in "${configs[@]}"; do
        target="igtheme.xml"
        [[ "$src" == *.json ]] && target="igtheme.json"
        sed "s|{{NAME}}|$display|g" "$CONF_DIR/$src" > "$dir/$target"
    done

    validate_pack "$dir"

    # zip with inner folder preserved at archive root
    if command -v zip >/dev/null 2>&1; then
        (cd "$SCRATCH" && zip -qr "$pack_file" "$folder")
    elif command -v tar >/dev/null 2>&1 && [ -f "${WINDIR:-}/System32/tar.exe" ]; then
        # Windows' built-in bsdtar creates real zip archives and keeps the pack
        # folder at the archive root (same layout as `zip -qr pack folder`).
        wscratch="$(to_win "$SCRATCH")"
        wpack="$(to_win "$pack_file")"
        "${WINDIR:-}/System32/tar.exe" --format zip -cf "$wpack" -C "$wscratch" "$folder"
    elif [ -n "$PY_CMD" ]; then
        "$PY_CMD" - "$(to_win "$dir")" "$(to_win "$pack_file")" <<'PY'
import sys, zipfile, os
src, dst = sys.argv[1], sys.argv[2]
folder = os.path.basename(os.path.abspath(src))
with zipfile.ZipFile(dst, 'w', zipfile.ZIP_DEFLATED) as z:
    for root, _, files in os.walk(src):
        for f in files:
            p = os.path.join(root, f)
            arc = os.path.join(folder, os.path.relpath(p, src)).replace(os.sep, '/')
            z.write(p, arc)
PY
    else
        powershell.exe -NoProfile -Command "Add-Type -AssemblyName System.IO.Compression.FileSystem; [System.IO.Compression.ZipFile]::CreateFromDirectory('$(to_win "$dir")', '$(to_win "$pack_file")')"
    fi
    echo "  packed $folder.$ext"
}

# ---------------------------------------------------------------- build all
pack 'Dracula' 'Dracula' 'igtheme'     igtheme.v8.xml igtheme.v9.json
pack 'Dracula' 'Dracula' 'igtheme.zip' igtheme.v10.json

# cleanup scratch
rm -rf "$SCRATCH"

echo "all packs built successfully."
