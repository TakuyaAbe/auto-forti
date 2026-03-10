#!/bin/bash
# Rewrite all non-system dylib references to use @executable_path/../Frameworks/
# Usage: fix-dylib-paths.sh <binary> <frameworks-dir>
set -euo pipefail

BINARY="$1"
FRAMEWORKS_DIR="$2"

fix_refs() {
    local target="$1"
    # Get all linked dylibs, skip system ones (/usr/lib, /System)
    otool -L "$target" | tail -n +2 | awk '{print $1}' | while read -r lib; do
        case "$lib" in
            /usr/lib/*|/System/*|@*) continue ;;
        esac
        local basename
        basename=$(basename "$lib")
        echo "  Fixing $target: $lib -> @executable_path/../Frameworks/$basename"
        install_name_tool -change "$lib" "@executable_path/../Frameworks/$basename" "$target"
    done
}

echo "Fixing dylib paths for binary: $BINARY"
fix_refs "$BINARY"

echo "Fixing dylib paths for frameworks in: $FRAMEWORKS_DIR"
for dylib in "$FRAMEWORKS_DIR"/*.dylib; do
    [ -f "$dylib" ] || continue
    fix_refs "$dylib"
    # Also fix the install name (id) of the dylib itself
    local_name=$(basename "$dylib")
    install_name_tool -id "@executable_path/../Frameworks/$local_name" "$dylib"
done

echo "All dylib paths fixed."
