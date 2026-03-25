#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

STYLE_CHECKS=(
  rustfmt
  taplo
)

LINT_CHECKS=(
  clippy-native
  clippy-wasm
  clippy-wasm-no-std
  clippy-wasm-no-std-atomics
)

WASM_CHECKS=(
  wasm-default
  wasm-serde-serialize
  wasm-enable-interning
  wasm-mvp
  wasm-atomics
  wasm-unwind-legacy-eh
  wasm-unwind-exnref-eh
  wasm-emscripten
)

BROWSER_CHECKS=(
  web-sys
  web-sys-all-features
  web-sys-unstable
  web-sys-next
  js-sys
  js-sys-unstable
  js-sys-next
  wasm-bindgen-webidl
  webidl-tests
  webidl-tests-unstable
  webidl-tests-next
  typescript-tests
)

CORE_CHECKS=(
  cli-reference-typescript
  native
  ui
  build-webidl
)

EXAMPLE_AND_BENCH_CHECKS=(
  build-examples
  test-examples
  build-benchmarks
)

MSRV_CHECKS=(
  msrv-resolver
  msrv-lib
  msrv-cli
)

AUX_CHECKS=(
  coverage
  codspeed
)

BRANCH_CHECKS=(
  wasm64
)

PR_CHECKS=(
  "${STYLE_CHECKS[@]}"
  "${LINT_CHECKS[@]}"
  "${WASM_CHECKS[@]}"
  "${CORE_CHECKS[@]}"
  "${BROWSER_CHECKS[@]}"
  "${EXAMPLE_AND_BENCH_CHECKS[@]}"
  "${MSRV_CHECKS[@]}"
  "${AUX_CHECKS[@]}"
)

RELEASE_CHECKS=(
  doc-book
  doc-api
  dist-linux-x86_64-musl
  dist-linux-aarch64-gnu
  dist-linux-aarch64-musl
  dist-macos-x86_64
  dist-macos-aarch64
  dist-windows
)

FULL_CHECKS=(
  "${PR_CHECKS[@]}"
  "${RELEASE_CHECKS[@]}"
)

QUEUE=()

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

append_unique() {
  local check="$1"
  local existing
  if [[ ${#QUEUE[@]} -gt 0 ]]; then
    for existing in "${QUEUE[@]}"; do
      if [[ "$existing" == "$check" ]]; then
        return 0
      fi
    done
  fi
  QUEUE+=("$check")
}

is_orbstack_kernel() {
  uname -r 2>/dev/null | grep -qi orbstack
}

should_use_host_clang() {
  case "${WBG_CI_USE_CLANG_FOR_HOST:-auto}" in
    1|true|yes)
      return 0
      ;;
    0|false|no)
      return 1
      ;;
    *)
      is_orbstack_kernel && command -v clang >/dev/null 2>&1
      ;;
  esac
}

setup_host_build_env() {
  need_cmd node
  need_cmd npm
  if should_use_host_clang; then
    export CC="${CC:-clang}"
    export CXX="${CXX:-clang++}"
  fi
}

setup_browser_env() {
  setup_host_build_env
  need_cmd firefox
  need_cmd geckodriver
}

setup_examples_env() {
  need_cmd node
  need_cmd npm
  need_cmd pnpm
  need_cmd wasm-pack
  need_cmd cargo
}

check_rustfmt() {
  cargo fmt --all -- --check
}

check_taplo() {
  need_cmd taplo
  mapfile -t toml_files < <(git ls-files '*.toml')
  if [[ ${#toml_files[@]} -eq 0 ]]; then
    return 0
  fi
  taplo fmt --check "${toml_files[@]}"
}

check_clippy_native() {
  cargo clippy --no-deps --all --all-features -- -D warnings
}

check_clippy_wasm() {
  cargo clippy --no-deps --all --all-features \
    --target wasm32-unknown-unknown \
    --exclude 'wasm-bindgen-cli*' \
    --exclude 'wasm-bindgen-*macro*' \
    --exclude wasm-bindgen-webidl \
    -- -D warnings
}

check_clippy_wasm_no_std() {
  cargo clippy --no-deps --no-default-features --target wasm32-unknown-unknown \
    -p wasm-bindgen \
    -p js-sys \
    -p web-sys \
    -p wasm-bindgen-futures \
    -p wasm-bindgen-test \
    -- -D warnings
}

check_clippy_wasm_no_std_atomics() {
  cargo clippy --no-deps --no-default-features --target wasm32-unknown-unknown \
    -p wasm-bindgen \
    -p js-sys \
    -p web-sys \
    -p wasm-bindgen-futures \
    -p wasm-bindgen-test \
    --config "target.wasm32-unknown-unknown.rustflags='-Ctarget-feature=+atomics'" \
    -- -D warnings
}

check_wasm_default() {
  need_cmd node
  export WASM_BINDGEN_SPLIT_LINKED_MODULES=1
  cargo test --target wasm32-unknown-unknown
  cargo test --target wasm32-unknown-unknown -p wasm-bindgen-futures
}

check_wasm_serde_serialize() {
  need_cmd node
  export WASM_BINDGEN_SPLIT_LINKED_MODULES=1
  cargo test --target wasm32-unknown-unknown --features serde-serialize
}

check_wasm_enable_interning() {
  need_cmd node
  export WASM_BINDGEN_SPLIT_LINKED_MODULES=1
  cargo test --target wasm32-unknown-unknown --features enable-interning
}

check_wasm_mvp() {
  need_cmd node
  export WASM_BINDGEN_SPLIT_LINKED_MODULES=1
  CARGO_TARGET_WASM32_UNKNOWN_UNKNOWN_RUSTFLAGS="-Ctarget-cpu=mvp" \
    cargo +nightly test --target wasm32-unknown-unknown -Zbuild-std=std,panic_abort
}

check_wasm_atomics() {
  need_cmd node
  export WASM_BINDGEN_SPLIT_LINKED_MODULES=1
  CARGO_TARGET_WASM32_UNKNOWN_UNKNOWN_RUSTFLAGS="-Ctarget-feature=+atomics -Clink-args=--shared-memory -Clink-args=--max-memory=1073741824 -Clink-args=--import-memory -Clink-args=--export=__wasm_init_tls -Clink-args=--export=__tls_size -Clink-args=--export=__tls_align -Clink-args=--export=__tls_base" \
    cargo +nightly test --target wasm32-unknown-unknown -Zbuild-std=std,panic_abort
}

check_wasm_unwind_legacy_eh() {
  need_cmd node
  export WASM_BINDGEN_SPLIT_LINKED_MODULES=1
  export RUSTFLAGS="-Cpanic=unwind"
  cargo +nightly test --target wasm32-unknown-unknown -Zbuild-std --lib --bins --tests
  cargo +nightly test --target wasm32-unknown-unknown -Zbuild-std --test wasm --features std,wasm-bindgen-futures/std
}

check_wasm_unwind_exnref_eh() {
  need_cmd node
  export WASM_BINDGEN_SPLIT_LINKED_MODULES=1
  export RUSTFLAGS="-Cpanic=unwind -Cllvm-args=-wasm-use-legacy-eh=false"
  cargo +nightly test --target wasm32-unknown-unknown -Zbuild-std --lib --bins --tests
  cargo +nightly test --target wasm32-unknown-unknown -Zbuild-std --test wasm --features std,wasm-bindgen-futures/std
}

check_wasm_emscripten() {
  need_cmd node
  need_cmd emcc
  cargo test --test wasm32-emscripten --target wasm32-unknown-emscripten
}

check_cli_reference_typescript() {
  need_cmd node
  need_cmd npm
  local tmp_dir
  tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/wbg-cli-ref-ts.XXXXXX")"
  (
    cd "$tmp_dir"
    npm init -y >/dev/null 2>&1
    npm install --silent typescript @types/node @types/deno >/dev/null
    npx tsc --noEmit --skipLibCheck --lib esnext,dom "$ROOT_DIR"/crates/cli/tests/reference/*.d.ts
    npx tsc --noEmit --skipLibCheck --lib esnext,dom --module esnext --allowJs $(find "$ROOT_DIR"/crates/cli/tests/reference -maxdepth 1 -name '*.js' ! -name '*target-module*.js')
  )
  rm -rf "$tmp_dir"
}

check_native() {
  need_cmd node
  need_cmd firefox
  need_cmd geckodriver
  cargo test
  cargo test -p wasm-bindgen-cli-support
  if is_orbstack_kernel; then
    cargo test -p wasm-bindgen-cli --test wasm-bindgen
    CARGO_INCREMENTAL=0 cargo test -p wasm-bindgen-cli --test wasm-bindgen-test-runner -- --test-threads=1
  else
    cargo test -p wasm-bindgen-cli
  fi
  cargo test -p wasm-bindgen-macro-support
  cargo test -p wasm-bindgen-futures
  cargo test -p wasm-bindgen-shared
  cargo test -p wasm-bindgen-test-shared
}

check_web_sys() {
  (
    setup_browser_env
    cargo build --manifest-path crates/web-sys/Cargo.toml --target wasm32-unknown-unknown
    cargo build --manifest-path crates/web-sys/Cargo.toml --target wasm32-unknown-unknown --features Node
    cargo build --manifest-path crates/web-sys/Cargo.toml --target wasm32-unknown-unknown --features Element
    cargo build --manifest-path crates/web-sys/Cargo.toml --target wasm32-unknown-unknown --features Window
  )
}

check_web_sys_all_features() {
  (
    setup_browser_env
    cargo test --manifest-path crates/web-sys/Cargo.toml --target wasm32-unknown-unknown --all-features
  )
}

check_web_sys_unstable() {
  (
    setup_browser_env
    export RUSTFLAGS="--cfg=web_sys_unstable_apis"
    cargo test --manifest-path crates/web-sys/Cargo.toml --target wasm32-unknown-unknown --all-features
  )
}

check_web_sys_next() {
  (
    setup_browser_env
    export RUSTFLAGS="--cfg=web_sys_unstable_apis --cfg=wbg_next_unstable"
    cargo test --manifest-path crates/web-sys/Cargo.toml --target wasm32-unknown-unknown --all-features
  )
}

check_js_sys() {
  (
    setup_browser_env
    cargo test -p js-sys --features=unsafe-eval --target wasm32-unknown-unknown
  )
}

check_js_sys_unstable() {
  (
    setup_browser_env
    export RUSTFLAGS="--cfg=js_sys_unstable_apis"
    cargo test -p js-sys --features=unsafe-eval --target wasm32-unknown-unknown
  )
}

check_js_sys_next() {
  (
    setup_browser_env
    export RUSTFLAGS="--cfg=js_sys_unstable_apis --cfg=wbg_next_unstable"
    cargo test -p js-sys --features=unsafe-eval --target wasm32-unknown-unknown
  )
}

check_wasm_bindgen_webidl() {
  cargo test -p wasm-bindgen-webidl
}

check_webidl_tests() {
  (
    setup_browser_env
    export WBINDGEN_I_PROMISE_JS_SYNTAX_WORKS_IN_NODE=1
    cargo test -p webidl-tests --target wasm32-unknown-unknown
  )
}

check_webidl_tests_unstable() {
  (
    setup_browser_env
    export RUSTFLAGS="--cfg=web_sys_unstable_apis"
    cargo test -p webidl-tests --target wasm32-unknown-unknown
  )
}

check_webidl_tests_next() {
  (
    setup_browser_env
    export RUSTFLAGS="--cfg=web_sys_unstable_apis --cfg=wbg_next_unstable"
    export WBG_NEXT_UNSTABLE=1
    cargo test -p webidl-tests --target wasm32-unknown-unknown
  )
}

check_typescript_tests() {
  (
    setup_host_build_env
    cd crates/typescript-tests
    ./run.sh
  )
}

check_ui() {
  cargo +1.88 test -p wasm-bindgen-macro
  cargo +1.88 test -p wasm-bindgen-test-macro
}

check_build_webidl() {
  (
    cd crates/web-sys
    cargo run --release --package wasm-bindgen-webidl -- webidls src/features ./Cargo.toml
  )
  git diff --exit-code
}

check_build_examples() {
  setup_examples_env
  cargo build -p wasm-bindgen-cli --bins
  (
    export PATH="$ROOT_DIR/target/debug:$PATH"
    cd examples
    pnpm install
    pnpm run -r build
  )
}

check_test_examples() {
  setup_examples_env
  need_cmd deno
  if [[ ! -d "$ROOT_DIR/examples/dist" ]]; then
    check_build_examples
  fi
  (
    cd examples
    pnpm install
    PREBUILT_EXAMPLES=1 npm test --ignore-scripts
  )
}

check_build_benchmarks() {
  cargo build --manifest-path benchmarks/Cargo.toml --release --target wasm32-unknown-unknown
  cargo run -p wasm-bindgen-cli -- target/wasm32-unknown-unknown/release/wasm_bindgen_benchmark.wasm --out-dir benchmarks/pkg --target web
}

check_doc_book() {
  need_cmd mdbook
  (
    cd guide
    mdbook build
  )
}

check_doc_api() {
  cargo +nightly doc --no-deps --features serde-serialize
  cargo +nightly doc --no-deps --manifest-path crates/js-sys/Cargo.toml
  RUSTDOCFLAGS="--cfg=web_sys_unstable_apis" cargo +nightly doc --no-deps --manifest-path crates/web-sys/Cargo.toml --all-features
  RUSTDOCFLAGS="--cfg=docsrs" cargo +nightly doc --no-deps --manifest-path crates/futures/Cargo.toml --all-features
}

check_msrv_resolver() {
  (
    cd crates/msrv/resolver
    cargo +1.71 build --target x86_64-unknown-linux-gnu --no-default-features
    cargo +1.71 build --target x86_64-unknown-linux-gnu
    cargo +1.71 build --target wasm32-unknown-unknown --no-default-features
    cargo +1.71 build --target wasm32-unknown-unknown
    cargo +stable build --target x86_64-unknown-linux-gnu --no-default-features
    cargo +stable build --target x86_64-unknown-linux-gnu
    cargo +stable build --target wasm32-unknown-unknown --no-default-features
    cargo +stable build --target wasm32-unknown-unknown
  )
}

check_msrv_lib() {
  (
    cd crates/msrv/lib
    cargo +1.71 build --target x86_64-unknown-linux-gnu --no-default-features
    cargo +1.71 build --target x86_64-unknown-linux-gnu
    cargo +1.71 build --target wasm32-unknown-unknown --no-default-features
    cargo +1.71 build --target wasm32-unknown-unknown
    cargo +1.82 build --target x86_64-unknown-linux-gnu --no-default-features
    cargo +1.82 build --target x86_64-unknown-linux-gnu
    cargo +1.82 build --target wasm32-unknown-unknown --no-default-features
    cargo +1.82 build --target wasm32-unknown-unknown
  )
}

check_msrv_cli() {
  (
    cd crates/msrv/cli
    cargo +1.82 build
  )
}

check_coverage() {
  need_cmd cargo-llvm-cov
  CARGO_TARGET_WASM32_UNKNOWN_UNKNOWN_RUSTFLAGS="-Cinstrument-coverage -Zno-profiler-runtime -Clink-args=--no-gc-sections --cfg=wasm_bindgen_unstable_test_coverage" \
    WASM_BINDGEN_SPLIT_LINKED_MODULES=1 \
    cargo +nightly llvm-cov test \
      --coverage-target-only \
      -p js-sys \
      -p wasm-bindgen \
      -p wasm-bindgen-futures \
      -p wasm-bindgen-test \
      --all-features \
      --target wasm32-unknown-unknown \
      --lcov \
      --output-path lcov.info
}

check_codspeed() {
  export WASM_BINDGEN_BENCH_RESULT="${WASM_BINDGEN_BENCH_RESULT:-/tmp/wbg_benchmark.json}"
  export CODSPEED_PERF_ENABLED="${CODSPEED_PERF_ENABLED:-false}"
  export WASM_BINDGEN_TEST_TIMEOUT="${WASM_BINDGEN_TEST_TIMEOUT:-500}"
  cargo bench --target wasm32-unknown-unknown
  cargo bench --target wasm32-unknown-unknown -p js-sys
  cargo bench --target wasm32-unknown-unknown -p wasm-bindgen-futures
  cargo bench --target wasm32-unknown-unknown -p wasm-bindgen-test
  cargo run -p wcodspeed "$WASM_BINDGEN_BENCH_RESULT"
}

check_dist_linux_x86_64_musl() {
  cargo build --manifest-path crates/cli/Cargo.toml --target x86_64-unknown-linux-musl --features vendored-openssl --release
  strip -g target/x86_64-unknown-linux-musl/release/wasm-bindgen
  strip -g target/x86_64-unknown-linux-musl/release/wasm-bindgen-test-runner
  strip -g target/x86_64-unknown-linux-musl/release/wasm2es6js
}

check_dist_linux_aarch64_gnu() {
  CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_LINKER="${CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_LINKER:-aarch64-linux-gnu-gcc}" \
    cargo build --manifest-path crates/cli/Cargo.toml --target aarch64-unknown-linux-gnu --features vendored-openssl --release
}

check_dist_linux_aarch64_musl() {
  cargo build --manifest-path crates/cli/Cargo.toml --target aarch64-unknown-linux-musl --features vendored-openssl --release
}

check_dist_macos_x86_64() {
  MACOSX_DEPLOYMENT_TARGET=10.7 cargo build --manifest-path crates/cli/Cargo.toml --target x86_64-apple-darwin --release
}

check_dist_macos_aarch64() {
  MACOSX_DEPLOYMENT_TARGET=10.7 cargo build --manifest-path crates/cli/Cargo.toml --target aarch64-apple-darwin --release
}

check_dist_windows() {
  RUSTFLAGS="-Ctarget-feature=+crt-static" cargo build --manifest-path crates/cli/Cargo.toml --target x86_64-pc-windows-msvc --release
}

check_wasm64() {
  (
    setup_host_build_env
    export WASM_BINDGEN_SPLIT_LINKED_MODULES=1
    export WASM_BINDGEN_TEST_ONLY_NODE=1
    export NODE_ARGS="${NODE_ARGS:+$NODE_ARGS }--experimental-wasm-memory64"
    export CARGO_TARGET_WASM64_UNKNOWN_UNKNOWN_RUNNER="cargo run -p wasm-bindgen-cli --bin wasm-bindgen-test-runner --"
    cargo +nightly test --target wasm64-unknown-unknown -Zbuild-std=std,panic_abort -p wasm-bindgen --lib --no-default-features
  )
}

show_help() {
  cat <<'EOF'
Run checked-in wrappers for the GitHub CI jobs.

Usage:
  scripts/ci/run-local-checks.sh list
  scripts/ci/run-local-checks.sh pr
  scripts/ci/run-local-checks.sh full
  scripts/ci/run-local-checks.sh <group-or-check>...

Groups:
  style
  lint
  wasm
  browser
  core
  examples
  msrv
  aux
  branch
  pr
  release
  full

Notes:
  - `pr` mirrors the pull_request checks from the checked-in GitHub workflows.
  - `release` adds the release-only build jobs from `main.yml`.
  - `branch` contains local branch-specific checks, currently `wasm64`.
  - `deploy` is intentionally not runnable locally because it publishes artifacts.
  - On OrbStack kernels this runner automatically uses `clang` for browser-heavy
    host builds unless `WBG_CI_USE_CLANG_FOR_HOST=0` is set.
EOF
}

list_checks() {
  cat <<'EOF'
Groups:
  style: rustfmt taplo
  lint: clippy-native clippy-wasm clippy-wasm-no-std clippy-wasm-no-std-atomics
  wasm: wasm-default wasm-serde-serialize wasm-enable-interning wasm-mvp wasm-atomics wasm-unwind-legacy-eh wasm-unwind-exnref-eh wasm-emscripten
  browser: web-sys web-sys-all-features web-sys-unstable web-sys-next js-sys js-sys-unstable js-sys-next wasm-bindgen-webidl webidl-tests webidl-tests-unstable webidl-tests-next typescript-tests
  core: cli-reference-typescript native ui build-webidl
  examples: build-examples test-examples build-benchmarks
  msrv: msrv-resolver msrv-lib msrv-cli
  aux: coverage codspeed
  branch: wasm64
  pr: all pull_request workflow checks
  release: doc-book doc-api dist-linux-x86_64-musl dist-linux-aarch64-gnu dist-linux-aarch64-musl dist-macos-x86_64 dist-macos-aarch64 dist-windows
  full: pr + release
EOF
}

expand_item() {
  case "$1" in
    style)
      local item
      for item in "${STYLE_CHECKS[@]}"; do append_unique "$item"; done
      ;;
    lint)
      local item
      for item in "${LINT_CHECKS[@]}"; do append_unique "$item"; done
      ;;
    wasm)
      local item
      for item in "${WASM_CHECKS[@]}"; do append_unique "$item"; done
      ;;
    browser)
      local item
      for item in "${BROWSER_CHECKS[@]}"; do append_unique "$item"; done
      ;;
    core)
      local item
      for item in "${CORE_CHECKS[@]}"; do append_unique "$item"; done
      ;;
    examples)
      local item
      for item in "${EXAMPLE_AND_BENCH_CHECKS[@]}"; do append_unique "$item"; done
      ;;
    msrv)
      local item
      for item in "${MSRV_CHECKS[@]}"; do append_unique "$item"; done
      ;;
    aux)
      local item
      for item in "${AUX_CHECKS[@]}"; do append_unique "$item"; done
      ;;
    branch)
      local item
      for item in "${BRANCH_CHECKS[@]}"; do append_unique "$item"; done
      ;;
    pr)
      local item
      for item in "${PR_CHECKS[@]}"; do append_unique "$item"; done
      ;;
    release)
      local item
      for item in "${RELEASE_CHECKS[@]}"; do append_unique "$item"; done
      ;;
    full)
      local item
      for item in "${FULL_CHECKS[@]}"; do append_unique "$item"; done
      ;;
    rustfmt|taplo|clippy-native|clippy-wasm|clippy-wasm-no-std|clippy-wasm-no-std-atomics|wasm-default|wasm-serde-serialize|wasm-enable-interning|wasm-mvp|wasm-atomics|wasm-unwind-legacy-eh|wasm-unwind-exnref-eh|wasm-emscripten|cli-reference-typescript|native|web-sys|web-sys-all-features|web-sys-unstable|web-sys-next|js-sys|js-sys-unstable|js-sys-next|wasm-bindgen-webidl|webidl-tests|webidl-tests-unstable|webidl-tests-next|typescript-tests|ui|build-webidl|build-examples|test-examples|build-benchmarks|doc-book|doc-api|msrv-resolver|msrv-lib|msrv-cli|coverage|codspeed|dist-linux-x86_64-musl|dist-linux-aarch64-gnu|dist-linux-aarch64-musl|dist-macos-x86_64|dist-macos-aarch64|dist-windows|wasm64)
      append_unique "$1"
      ;;
    *)
      die "unknown group or check: $1"
      ;;
  esac
}

run_check() {
  local check="$1"
  printf '\n==> %s\n' "$check"
  (
    "check_${check//-/_}"
  )
}

main() {
  if [[ $# -eq 0 ]]; then
    set -- pr
  fi

  case "$1" in
    -h|--help|help)
      show_help
      exit 0
      ;;
    list)
      list_checks
      exit 0
      ;;
  esac

  local item
  for item in "$@"; do
    expand_item "$item"
  done

  for item in "${QUEUE[@]}"; do
    run_check "$item"
  done
}

main "$@"
