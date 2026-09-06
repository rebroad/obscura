#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
object_path="${PREFIX:-/data/data/com.termux/files/usr}/tmp/obscura-android-tls-alignment.o"
if [[ ! -s "$object_path" || "$script_dir/android_tls_alignment.S" -nt "$object_path" ]]; then
  mkdir -p "$(dirname -- "$object_path")"
  "${ANDROID_CLANG:-${PREFIX:-/data/data/com.termux/files/usr}/bin/clang}" -c "$script_dir/android_tls_alignment.S" -o "$object_path"
fi
exec "${ANDROID_CLANG:-${PREFIX:-/data/data/com.termux/files/usr}/bin/clang}" "$@" "$object_path" -Wl,-u,obscura_android_tls_alignment -Wl,-u,__clear_cache "${PREFIX:-/data/data/com.termux/files/usr}/lib/clang/21/lib/linux/libclang_rt.builtins-aarch64-android.a"
