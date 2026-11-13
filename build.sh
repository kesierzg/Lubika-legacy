#!/bin/bash
# Build LubikaLegacy for a real armv7 iOS 6.1 device (iPhone 4S), using a modern
# Xcode toolchain. This bypasses several Xcode-15+/27 incompatibilities:
#   * theos' module-PCH won't compile against an old SDK  -> we invoke clang/ld directly
#   * Xcode removed libarclite                            -> we don't pass -fobjc-arc at link
#                                                            (iOS 6.1 libobjc has the ARC entrypoints)
#   * new ld rejects the theos SDK's .tbd stubs as        -> we patch the SDK copy to drop the
#     "iOS-simulator" (they list i386/x86_64 archs)          i386/x86_64 (simulator) archs
#   * stub tbds omit _objc_msgSend_stret & friends        -> we allow them as dynamic_lookup (-U)
#   * iOS 6.1 dyld + LC_MAIN jumps a *Thumb* main in ARM  -> we compile ARM (-marm) so the entry
#     mode and SIGILLs                                       point is valid in ARM mode
set -euo pipefail

PROJ="$(cd "$(dirname "$0")" && pwd)"
SRC="$PROJ/LubikaLegacy"
OUT="$PROJ/build"
RAW_SDK="${RAW_SDK:-/Users/grzesiek/theos/sdks/iPhoneOS10.3.sdk}"
PSDK="$PROJ/sdk/iPhoneOS10.3-device.sdk"   # patched, device-only SDK (kept in-project)
MINVER=6.1

# --- one-time: build a device-only patched copy of the SDK -------------------
if [ ! -d "$PSDK" ]; then
    echo "== preparing patched device SDK (one-time) =="
    mkdir -p "$PROJ/sdk"
    cp -a "$RAW_SDK" "$PSDK"
    # Drop simulator archs so the new linker classifies the .tbd stubs as iOS-device.
    find "$PSDK" -name '*.tbd' -print0 | xargs -0 perl -pi -e '
        s/\[ armv7, armv7s, arm64, i386, x86_64 \]/[ armv7, armv7s, arm64 ]/g;
        s/, i386, x86_64 \]/ ]/g; s/\[ i386, x86_64, /[ /g;
        s/, i386,/,/g; s/, x86_64,/,/g; s/, i386 \]/ ]/g; s/, x86_64 \]/ ]/g;'
fi

rm -rf "$OUT"; mkdir -p "$OUT/obj"
APP="$OUT/LubikaLegacy.app"; mkdir -p "$APP"

# --- compile (ARM, not Thumb) ------------------------------------------------
CFLAGS=(-arch armv7 -marm -isysroot "$PSDK" -miphoneos-version-min="$MINVER"
        -fobjc-arc -fno-modules -Wall -O2)
echo "== compiling (ARM) =="
OBJS=()
for m in "$SRC"/*.m; do
    o="$OUT/obj/$(basename "${m%.m}").o"
    echo "  $(basename "$m")"
    clang "${CFLAGS[@]}" -c "$m" -o "$o"
    OBJS+=("$o")
done

# --- link directly with ld, no arclite, deferring runtime-only objc symbols --
echo "== linking =="
ld -arch armv7 -platform_version ios "$MINVER" 10.3 -syslibroot "$PSDK" \
   -U _objc_msgSend_stret -U _objc_msgSend_fpret \
   -U _objc_msgSendSuper_stret -U _objc_msgSendSuper2_stret \
   -framework UIKit -framework Foundation -framework CoreGraphics -framework QuartzCore \
   -lobjc -lSystem \
   "${OBJS[@]}" -o "$APP/LubikaLegacy"

# --- bundle + pseudo-sign ----------------------------------------------------
cp "$SRC/Resources/Info.plist" "$APP/Info.plist"
# App icons, background watermark, and launch images.
for res in Icon.png "Icon@2x.png" Icon-Small.png "Icon-Small@2x.png" \
           watermark.png "watermark@2x.png" "Default@2x.png" "Default-568h@2x.png"; do
    [ -f "$SRC/Resources/$res" ] && cp "$SRC/Resources/$res" "$APP/$res"
done
cat > "$OUT/ent.plist" <<'ENT'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>get-task-allow</key><true/></dict></plist>
ENT
ldid -S"$OUT/ent.plist" "$APP/LubikaLegacy"

# --- package: .deb (jailbreak / dpkg) ---------------------------------------
# Metadata comes from ./control. postinst fixes ownership + registers the icon.
PKG=$(awk -F': *' '/^Package:/{print $2}' "$PROJ/control" | tr -d '\r')
VER=$(awk -F': *' '/^Version:/{print $2}'  "$PROJ/control" | tr -d '\r')
DEBROOT="$OUT/debroot"
rm -rf "$DEBROOT"; mkdir -p "$DEBROOT/DEBIAN" "$DEBROOT/Applications"
cp "$PROJ/control" "$DEBROOT/DEBIAN/control"
cat > "$DEBROOT/DEBIAN/postinst" <<'POST'
#!/bin/sh
chown -R root:wheel /Applications/LubikaLegacy.app
chmod +x /Applications/LubikaLegacy.app/LubikaLegacy
su mobile -c uicache 2>/dev/null || uicache 2>/dev/null || true
exit 0
POST
chmod 0755 "$DEBROOT/DEBIAN/postinst"
cp -R "$APP" "$DEBROOT/Applications/"
DEB="$OUT/${PKG}_${VER}_iphoneos-arm.deb"
dpkg-deb -Zgzip --root-owner-group -b "$DEBROOT" "$DEB" >/dev/null

# --- package: .ipa (zip of Payload/; installs on a JB device via AppSync) ----
rm -rf "$OUT/Payload"; mkdir -p "$OUT/Payload"
cp -R "$APP" "$OUT/Payload/"
( cd "$OUT" && rm -f LubikaLegacy.ipa && zip -qr LubikaLegacy.ipa Payload && rm -rf Payload )

echo "== done =="
file "$APP/LubikaLegacy"
nm -m "$APP/LubikaLegacy" | grep ' _main$'
echo "APP:     $APP"
echo "DEB:     $DEB   (jailbreak: dpkg -i)"
echo "IPA:     $OUT/LubikaLegacy.ipa   (sideload w/ AppSync)"
