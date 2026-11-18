# Pubblicare Schȅi (con l'eredità) — procedura

Decisa con il proprietario il 17/11/2026 (controllo mainnet, punto G3). Solo versioni con eredità.

## Le due firme
1. **Firma Android** (per installare e aggiornare): chiave nuova e segreta del proprietario,
   `~/schei-keys/schei-release.keystore` (WSL), alias `schei`. Creata una volta sola con
   `bash contrib/android/schei_keys.sh create`. La password la scrive SOLO il proprietario.
   Senza questo file e la sua password Schȅi non si potrà più aggiornare: due copie di
   sicurezza, fuori dal computer.
2. **Firma GPG SAFE21dev** (per chi scarica e vuole verificare): come per Easy Heirs,
   chiave `206C20114CA96172` in Gpg4win, firma il file APK pubblicato (.asc).

La vecchia pre-release v0.1.0-prova era firmata con la chiave di prova di Electrum (password
pubblica): chi la usa deve disinstallarla e rimettere le parole nella versione nuova.

## Versione
`contrib/android/SCHEI_VERSION` (es. `1.0.0`): da alzare a ogni pubblicazione. Il versionCode
Android è 50 000 000 + (maggiore·10000 + minore·100 + patch)·10 + architettura (arm64 = 3),
sempre sopra quello della pre-release (45 408 033).

## Passi
1. Alzare `SCHEI_VERSION`; test (tests/qml, tests/schei_bridge, controlli pagine e misure).
2. Compilare SENZA firma, in modalità release (niente «debuggable»):
   `cd contrib/android && ./build.sh qml arm64-v8a release-unsigned`
   (nessun SCHEI_TESTNET4 / SCHEI_EREDITA4: pacchetto io.safe21.easyheirs.electrum, rete vera).
3. Il proprietario firma: `bash contrib/android/schei_keys.sh sign dist/<apk>` (chiede la password).
4. Controllo: `bash contrib/android/schei_keys.sh check <apk-signed>`: l'impronta deve essere
   sempre la stessa (annotarla la prima volta).
5. sha256 del file firmato; firma GPG del proprietario (PowerShell, Gpg4win):
   `gpg --local-user 206C20114CA96172 --armor --detach-sign <apk-signed>`.
6. Prova sul telefono del proprietario; solo dopo il suo OK la Release su GitHub (prima in bozza).
