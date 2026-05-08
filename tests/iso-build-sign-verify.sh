#!/bin/bash
#
# Sudoless ISO build + sign + verify driver. Builds the Ryoku ISO from
# the local checkout, signs it with a dedicated TEMPORARY GPG key in an
# isolated keyring (no touch to the user's real ~/.gnupg), verifies the
# signature, and writes a per-stage log with timestamps to
# tests/logs/iso-build-sign-verify-<TS>.log.
#
# Stages:
#   01 setup          : prep dirs, log, ephemeral GPG home, sudo shim
#   02 git-snapshot   : capture branch + HEAD + git status
#   03 keygen         : passphraseless test key (RSA 4096, 0 expiry)
#   04 build          : ./iso/bin/ryoku-iso-make --local-source --no-boot-offer
#   05 inspect        : verify ISO file exists, capture size + SHAs
#   06 sign           : detached-sig with the temp key, write .sig
#   07 verify         : gpg --verify against the temp key
#   08 cleanup-keys   : leave the iso/.sig + iso/.sha256 in place; the
#                       ephemeral GPG home is preserved for inspection
#                       under /tmp/ryoku-iso-test-gpg.
#
# Output:
#   tests/logs/iso-build-sign-verify-<TS>.log  (full transcript)
#   tests/logs/iso-build-sign-verify.summary    (last-run human summary)
#
# Exit codes:
#   0   all stages OK
#   >0  first failed stage exit code (other stages still attempted)

set -u

# ------------------------------------------------------------------ paths
REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TS="$(date +%Y%m%d-%H%M%S)"
LOG_DIR="$REPO_ROOT/tests/logs"
LOG_FILE="$LOG_DIR/iso-build-sign-verify-$TS.log"
SUMMARY_FILE="$LOG_DIR/iso-build-sign-verify.summary"
ISO_DIR="$REPO_ROOT/iso/release"

# Ephemeral GPG home for the test signing key. Survives the run so the
# user can inspect afterward, but is never the user's real ~/.gnupg.
TMP_GPG_HOME="/tmp/ryoku-iso-test-gpg"

# Sudo shim: a fake sudo that no-ops, prepended to PATH so the
# `sudo rm -rf /var/cache/pacman/pkg/*` line in ryoku-iso-make does not
# hang waiting for a password. Cache clean is harmless to skip.
SUDO_SHIM_DIR="/tmp/ryoku-iso-test-shim"

mkdir -p "$LOG_DIR" "$SUDO_SHIM_DIR"
cat > "$SUDO_SHIM_DIR/sudo" <<'EOF'
#!/bin/sh
# Sudoless test driver: pacman cache clean is harmless to skip.
# For other arguments, refuse politely so we surface unexpected sudo use.
case "$1" in
    rm) exit 0 ;;
    *)  echo "test-driver sudo shim: refusing $*" >&2; exit 0 ;;
esac
EOF
chmod +x "$SUDO_SHIM_DIR/sudo"

# ------------------------------------------------------------------ logging
exec > >(tee -a "$LOG_FILE") 2>&1

ts() { date +"%Y-%m-%d %H:%M:%S"; }
log() { printf '[%s] %s\n' "$(ts)" "$*"; }
section() {
    echo
    echo "================================================================"
    log "$*"
    echo "================================================================"
}

OVERALL_RC=0
STAGE_RESULTS=()

run_stage() {
    local name="$1"
    shift
    section "STAGE: $name"
    if "$@"; then
        log "STAGE OK : $name"
        STAGE_RESULTS+=("OK   $name")
    else
        local rc=$?
        log "STAGE FAIL ($rc) : $name"
        STAGE_RESULTS+=("FAIL $name (rc=$rc)")
        if [[ $OVERALL_RC -eq 0 ]]; then OVERALL_RC=$rc; fi
    fi
}

# ------------------------------------------------------------------ stages

stage_setup() {
    log "log file:        $LOG_FILE"
    log "iso output dir:  $ISO_DIR"
    log "ephemeral gpg:   $TMP_GPG_HOME"
    log "sudo shim:       $SUDO_SHIM_DIR/sudo"
    log "host:            $(hostname) ($(uname -srm))"
    log "user:            $USER (uid $(id -u))"
    log "in docker grp:   $(id -nG | grep -wq docker && echo yes || echo no)"
    log "docker version:  $(docker version --format '{{.Server.Version}}' 2>/dev/null || echo unavailable)"
    log "disk free:       $(df -BG /home | awk 'NR==2{print $4 " of " $2}')"
    return 0
}

stage_git_snapshot() {
    cd "$REPO_ROOT"
    log "branch:    $(git branch --show-current)"
    log "head:      $(git log -1 --oneline)"
    log "remote:    $(git remote get-url origin 2>/dev/null || echo none)"
    local dirty
    dirty=$(git status --porcelain | wc -l)
    log "dirty:     $dirty file(s)"
    if [[ $dirty -gt 0 ]]; then
        log "(dirty files; build will use HEAD via --local-source so this matters)"
        git status --short | head -20
    fi
    return 0
}

stage_keygen() {
    rm -rf "$TMP_GPG_HOME"
    mkdir -m 700 -p "$TMP_GPG_HOME"
    export GNUPGHOME="$TMP_GPG_HOME"
    log "keyring at: $GNUPGHOME"

    cat > "$TMP_GPG_HOME/keygen.batch" <<'EOF'
%no-protection
Key-Type: RSA
Key-Length: 4096
Subkey-Type: RSA
Subkey-Length: 4096
Name-Real: Ryoku ISO Test Signer
Name-Email: ryoku-iso-test@example.invalid
Name-Comment: ephemeral test key, not for release
Expire-Date: 0
%commit
EOF

    log "generating 4096-bit RSA test key (no passphrase)..."
    if ! gpg --batch --gen-key "$TMP_GPG_HOME/keygen.batch" 2>&1; then
        log "key gen failed"
        return 1
    fi

    log "test public key fingerprint:"
    gpg --list-keys --keyid-format=long
    log "test secret key:"
    gpg --list-secret-keys --keyid-format=long
    return 0
}

stage_build() {
    cd "$REPO_ROOT"
    # Path-shim sudo so the cache-clean line in ryoku-iso-make does not
    # block on a password prompt. Run with stdin redirected from /dev/null.
    log "starting cold build (this can take ~30 minutes on a clean cache)..."
    PATH="$SUDO_SHIM_DIR:$PATH" \
        ./iso/bin/ryoku-iso-make --local-source --no-boot-offer </dev/null
}

stage_inspect() {
    cd "$REPO_ROOT"
    if [[ ! -d "$ISO_DIR" ]]; then
        log "iso/release/ does not exist - build did not produce output"
        return 1
    fi
    local iso
    iso=$(\ls -t "$ISO_DIR"/*.iso 2>/dev/null | head -n1)
    if [[ -z "$iso" ]]; then
        log "no .iso file found in $ISO_DIR"
        ls -la "$ISO_DIR" || true
        return 1
    fi
    ISO_PATH="$iso"
    log "iso:       $ISO_PATH"
    log "size:      $(du -h "$ISO_PATH" | cut -f1)"
    log "computing checksums (sha256 + sha512)..."
    sha256sum "$ISO_PATH" > "$ISO_PATH.sha256"
    sha512sum "$ISO_PATH" > "$ISO_PATH.sha512"
    log "sha256:    $(cut -d' ' -f1 "$ISO_PATH.sha256")"
    log "sha512:    $(cut -d' ' -f1 "$ISO_PATH.sha512")"
    return 0
}

stage_sign() {
    if [[ -z "${ISO_PATH:-}" ]]; then
        log "no ISO_PATH set (inspect stage failed); skipping sign"
        return 1
    fi
    export GNUPGHOME="$TMP_GPG_HOME"
    local key
    key=$(gpg --list-secret-keys --with-colons | awk -F: '/^sec:/{print $5; exit}')
    if [[ -z "$key" ]]; then
        log "no secret key in ephemeral keyring"
        return 1
    fi
    log "signing $ISO_PATH with key $key"
    gpg --batch --yes --local-user "$key" \
        --output "$ISO_PATH.sig" --detach-sig "$ISO_PATH"
    log "signature: $ISO_PATH.sig ($(du -h "$ISO_PATH.sig" | cut -f1))"
    return 0
}

stage_verify() {
    if [[ -z "${ISO_PATH:-}" ]]; then
        log "no ISO_PATH; skipping verify"
        return 1
    fi
    export GNUPGHOME="$TMP_GPG_HOME"
    log "gpg --verify $ISO_PATH.sig $ISO_PATH"
    if ! gpg --verify "$ISO_PATH.sig" "$ISO_PATH" 2>&1; then
        log "signature verification FAILED - signing chain is broken"
        return 1
    fi
    log "signature verified successfully"
    log "round-trip: signed by ephemeral key, verified by ephemeral key, OK"

    # Round-trip sha check: re-hash the iso and compare
    log "re-checking SHAs to confirm the file did not change after signing..."
    local re_sha
    re_sha=$(sha256sum "$ISO_PATH" | cut -d' ' -f1)
    local saved_sha
    saved_sha=$(cut -d' ' -f1 "$ISO_PATH.sha256")
    if [[ "$re_sha" != "$saved_sha" ]]; then
        log "sha256 changed during signing - signing chain is INTEGRITY-BROKEN"
        log "  before: $saved_sha"
        log "  after:  $re_sha"
        return 1
    fi
    log "sha256 stable across signing pass: $saved_sha"
    return 0
}

stage_cleanup_keys() {
    log "ephemeral GPG home left at $TMP_GPG_HOME for inspection"
    log "(remove manually with: rm -rf $TMP_GPG_HOME)"
    return 0
}

# ------------------------------------------------------------------ run
section "RYOKU ISO BUILD + SIGN + VERIFY DRIVER"
log "started at: $(ts)"
log "log:        $LOG_FILE"

run_stage "01 setup"          stage_setup
run_stage "02 git-snapshot"   stage_git_snapshot
run_stage "03 keygen"         stage_keygen
run_stage "04 build"          stage_build
run_stage "05 inspect"        stage_inspect
run_stage "06 sign"           stage_sign
run_stage "07 verify"         stage_verify
run_stage "08 cleanup-keys"   stage_cleanup_keys

# ------------------------------------------------------------------ summary
section "SUMMARY"
{
    echo "Run:       $TS"
    echo "Log:       $LOG_FILE"
    echo "ISO:       ${ISO_PATH:-<none>}"
    echo "SHA256:    $( [[ -n "${ISO_PATH:-}" ]] && cut -d' ' -f1 "$ISO_PATH.sha256" 2>/dev/null )"
    echo "Signature: $( [[ -n "${ISO_PATH:-}" ]] && [[ -f "$ISO_PATH.sig" ]] && echo "$ISO_PATH.sig" || echo "<not produced>" )"
    echo
    echo "Stages:"
    for line in "${STAGE_RESULTS[@]}"; do
        echo "  $line"
    done
    echo
    echo "Overall RC: $OVERALL_RC"
} | tee "$SUMMARY_FILE"

exit "$OVERALL_RC"
