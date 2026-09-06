#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
SOURCE_REPO="$(cd -- "${SCRIPT_DIR}/.." && pwd -P)"
PROFILE=release
TARGET="$(rustc -vV | sed -n 's/^host: //p')"
INSTALL_PATH=""
JOBS="${CARGO_BUILD_JOBS:-}"

usage() {
  cat <<'EOF'
Usage: scripts/build_obscura.sh [options]

Builds the Obscura CLI in the source checkout. Cross builds use the target
Rusty V8 archive/binding selected by RUSTY_V8_ARCHIVE_<TARGET> and
RUSTY_V8_SRC_BINDING_PATH_<TARGET>.

Options:
  --target TARGET       Rust target triple (default: the host triple)
  --debug               Build an unoptimized debug binary
  --release             Build an optimized release binary (default)
  --jobs N              Set CARGO_BUILD_JOBS
  --install [PATH]      Install the resulting binary to PATH; when omitted,
                        use $PREFIX/bin on Termux or $HOME/.local/bin on Linux
  -h, --help            Show this help

Cross-build variables:
  RUSTY_V8_SOURCE       Rusty V8 checkout; required for target-specific V8
                        archive selection when TARGET differs from the host
  RUSTY_V8_ARCHIVE_<TARGET> and RUSTY_V8_ARCHIVE_<HOST>
  RUSTY_V8_SRC_BINDING_PATH_<TARGET> and RUSTY_V8_SRC_BINDING_PATH_<HOST>
  ANDROID_CLANG, ANDROID_BUILTINS, ANDROID_TMP_DIR
  OBSCURA_CROSS_MKSNAPSHOT
EOF
}

die() { echo "build_obscura.sh: $*" >&2; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      [[ $# -ge 2 ]] || die "--target requires a target triple"
      TARGET="$2"; shift 2 ;;
    --target=*) TARGET="${1#*=}"; shift ;;
    --debug) PROFILE=debug; shift ;;
    --release) PROFILE=release; shift ;;
    --jobs)
      [[ $# -ge 2 ]] || die "--jobs requires a positive integer"
      JOBS="$2"; shift 2 ;;
    --jobs=*) JOBS="${1#*=}"; shift ;;
    --install)
      if [[ $# -ge 2 && "$2" != -* ]]; then INSTALL_PATH="$2"; shift 2; else INSTALL_PATH=__DEFAULT__; shift; fi ;;
    --install=*) INSTALL_PATH="${1#*=}"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
done

[[ -n "$TARGET" ]] || die "target must not be empty"
if [[ -n "$JOBS" && ! "$JOBS" =~ ^[1-9][0-9]*$ ]]; then
  die "jobs must be a positive integer"
fi

HOST="$(rustc -vV | sed -n 's/^host: //p')"
TARGET_KEY="${TARGET^^}"
TARGET_KEY="${TARGET_KEY//-/_}"
HOST_KEY="${HOST^^}"
HOST_KEY="${HOST_KEY//-/_}"
host_archive_var="RUSTY_V8_ARCHIVE_${HOST_KEY}"
host_binding_var="RUSTY_V8_SRC_BINDING_PATH_${HOST_KEY}"
archive_var="RUSTY_V8_ARCHIVE_${TARGET_KEY}"
binding_var="RUSTY_V8_SRC_BINDING_PATH_${TARGET_KEY}"

if [[ -n "${!archive_var:-}" ]]; then
  : "${!binding_var:?${binding_var} must be set with ${archive_var}}"
fi
if [[ -n "${!host_archive_var:-}" || -n "${RUSTY_V8_ARCHIVE_HOST:-}" || -n "${RUSTY_V8_ARCHIVE:-}" ]]; then
  export "${host_archive_var}=${!host_archive_var:-${RUSTY_V8_ARCHIVE_HOST:-${RUSTY_V8_ARCHIVE:-}}}"
fi
if [[ -n "${!host_binding_var:-}" || -n "${RUSTY_V8_SRC_BINDING_PATH_HOST:-}" || -n "${RUSTY_V8_SRC_BINDING_PATH:-}" ]]; then
  export "${host_binding_var}=${!host_binding_var:-${RUSTY_V8_SRC_BINDING_PATH_HOST:-${RUSTY_V8_SRC_BINDING_PATH:-}}}"
fi

if [[ "$TARGET" != "$HOST" ]]; then
  [[ -n "${RUSTY_V8_SOURCE:-}" ]] || die "cross builds require RUSTY_V8_SOURCE"
  [[ -d "$RUSTY_V8_SOURCE" ]] || die "RUSTY_V8_SOURCE is not a directory: $RUSTY_V8_SOURCE"
  [[ -n "${!archive_var:-}" ]] || die "set ${archive_var} for cross compilation"
  [[ -n "${!binding_var:-}" ]] || die "set ${binding_var} for cross compilation"
  [[ -n "${!host_archive_var:-${RUSTY_V8_ARCHIVE_HOST:-${RUSTY_V8_ARCHIVE:-}}}" ]] || die "set ${host_archive_var} or RUSTY_V8_ARCHIVE for cross compilation"
  [[ -n "${!host_binding_var:-${RUSTY_V8_SRC_BINDING_PATH_HOST:-${RUSTY_V8_SRC_BINDING_PATH:-}}}" ]] || die "set ${host_binding_var} or RUSTY_V8_SRC_BINDING_PATH for cross compilation"
fi

if [[ -n "${!archive_var:-}" || -n "${RUSTY_V8_ARCHIVE:-}" ]]; then
  export "${archive_var}=${!archive_var:-${RUSTY_V8_ARCHIVE:-}}"
fi
if [[ -n "${!binding_var:-}" || -n "${RUSTY_V8_SRC_BINDING_PATH:-}" ]]; then
  export "${binding_var}=${!binding_var:-${RUSTY_V8_SRC_BINDING_PATH:-}}"
fi

if [[ "$TARGET" != "$HOST" ]]; then
  cargo_args=(--config "patch.crates-io.v8.path=\"${RUSTY_V8_SOURCE}\"")
else
  cargo_args=()
fi
if [[ -n "$JOBS" ]]; then export CARGO_BUILD_JOBS="$JOBS"; fi

cd "$SOURCE_REPO"
cargo "${cargo_args[@]}" build --profile "$PROFILE" --target "$TARGET" \
  -p obscura-cli --bins --features render

if [[ "$TARGET" == "$HOST" ]]; then
  binary="$SOURCE_REPO/target/$PROFILE/obscura"
else
  binary="$SOURCE_REPO/target/$TARGET/$PROFILE/obscura"
fi
[[ -x "$binary" ]] || die "Cargo completed but binary is missing: $binary"
echo "Built $binary"

if [[ -n "$INSTALL_PATH" ]]; then
  if [[ "$INSTALL_PATH" == __DEFAULT__ ]]; then
    if [[ -n "${PREFIX:-}" ]]; then INSTALL_PATH="$PREFIX/bin"; else INSTALL_PATH="${HOME}/.local/bin"; fi
  fi
  mkdir -p "$INSTALL_PATH"
  install -m 0755 "$binary" "$INSTALL_PATH/obscura"
  echo "Installed $INSTALL_PATH/obscura"
fi
