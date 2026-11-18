#!/bin/bash
# Schȅi release signing (owner 17/11, controllo-mainnet G3). The OWNER runs these, never Claude:
# the password is typed only here, by the owner, and is never written in any file or command line.
#
#   bash contrib/android/schei_keys.sh create            # once: makes the Android release key
#   bash contrib/android/schei_keys.sh sign <unsigned.apk> # each release: zipalign + sign
#   bash contrib/android/schei_keys.sh check <signed.apk>  # shows the certificate fingerprint
#
# The key lives in ~/schei-keys/schei-release.keystore (WSL). KEEP A BACKUP of that file and of its
# password in a safe place (two copies, offline): without them Schȅi can NEVER be updated again.
set -e
KEYDIR="$HOME/schei-keys"
KS="schei-release.keystore"
ALIAS="schei"
IMG="electrum-android-builder-img"
BT="/opt/android/android-sdk/build-tools/36.0.0"
mkdir -p "$KEYDIR"
chmod 700 "$KEYDIR"

case "$1" in
create)
    if [ -f "$KEYDIR/$KS" ]; then
        echo "The key already exists: $KEYDIR/$KS (not overwritten)." >&2
        exit 1
    fi
    docker run --rm -it -v "$KEYDIR":/k "$IMG" \
        keytool -genkeypair -v -keystore "/k/$KS" -alias "$ALIAS" -keyalg RSA -keysize 4096 \
        -validity 36500 -dname "CN=SAFE21, O=SAFE21, C=IT"
    chmod 600 "$KEYDIR/$KS"
    echo
    echo "Done. NOW make the backup copies of $KEYDIR/$KS and of its password."
    ;;
sign)
    IN=$(readlink -f "$2")
    [ -f "$IN" ] || { echo "usage: $0 sign <unsigned.apk>" >&2; exit 1; }
    D=$(dirname "$IN"); B=$(basename "$IN" .apk)
    OUT="$B-signed.apk"
    docker run --rm -it -v "$KEYDIR":/k:ro -v "$D":/w "$IMG" bash -c "
        set -e
        $BT/zipalign -f -p 4 /w/$B.apk /w/$B-aligned.apk
        $BT/apksigner sign --ks /k/$KS --ks-key-alias $ALIAS --out /w/$OUT /w/$B-aligned.apk
        rm -f /w/$B-aligned.apk
        $BT/apksigner verify --print-certs /w/$OUT"
    echo
    echo "Signed: $D/$OUT"
    ;;
check)
    IN=$(readlink -f "$2")
    docker run --rm -v "$(dirname "$IN")":/w "$IMG" $BT/apksigner verify --print-certs "/w/$(basename "$IN")"
    ;;
*)
    sed -n 2,12p "$0"
    exit 1
    ;;
esac
