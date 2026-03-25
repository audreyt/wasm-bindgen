# Contributing

See the ["Contributing" section of the `wasm-bindgen`
guide](https://wasm-bindgen.github.io/wasm-bindgen/contributing/index.html).

## Justfile

This project includes a [`justfile`](https://github.com/casey/just) as a convenient store of commonly used commands. The justfile is entirely optional - all tasks can still be run using their underlying commands directly. It simply provides shortcuts for script invocations you would otherwise need to remember or look up.

Available commands:

- `just ci-list` - List the checked-in local CI groups and checks
- `just ci ...` - Run selected local CI groups or checks
- `just ci-pr` - Run the pull request checks from the GitHub workflows locally
- `just ci-release` - Run the release-only build checks locally
- `just ci-full` - Run `ci-pr` plus the release-only build checks
- `just clippy` - Run clippy linting (accepts optional args)
- `just test` - Run all tests

Run individual tests (all accept test names as args):

- `just test-wasm-bindgen` - Run end to end Node.js tests (accepts optional args for test names)
- `just test-wasm-bindgen-futures` - Run end to end Node.js futures tests (accepts optional args for test names)
- `just test-cli` - Run CLI tests
- `just test-macro` - Run macro tests
- `just test-macro-support` - Run macro support tests
- `just test-ui` - Run UI tests for macros
- `just test-js-sys` - Run the JS Sys tests
- `just test-web-sys` - Run the Web Sys tests

To inspect failed generated tests for `just test-wasm-bindgen`, set `WASM_BINDGEN_KEEP_TEST_BUILD=1` to retain the temporary folder for test output.

## Local CI Runner

The checked-in script [`scripts/ci/run-local-checks.sh`](scripts/ci/run-local-checks.sh) wraps the same commands used by the GitHub workflows and groups them by check family. By default it runs the pull request check set:

- `./scripts/ci/run-local-checks.sh`
- `./scripts/ci/run-local-checks.sh pr`
- `./scripts/ci/run-local-checks.sh list`
- `./scripts/ci/run-local-checks.sh web-sys-unstable webidl-tests-next`
- `just ci rustfmt cli-reference-typescript`

The runner expects the external tools used by the corresponding GitHub jobs to already be installed, such as Firefox/geckodriver, Node/npm/pnpm, Deno, mdBook, Taplo, cargo-llvm-cov, Emscripten, and wasm-pack.

On OrbStack-backed Linux containers the runner automatically switches browser-heavy host builds to `clang` unless `WBG_CI_USE_CLANG_FOR_HOST=0` is set. This avoids a Rosetta/GCC failure in `ring` that does not happen on GitHub Actions. The `native` wrapper also applies the serialized `wasm-bindgen-cli` test-runner fallback that was needed locally to avoid an OrbStack artifact copy race.

Update fixtures:

- `just test-cli-overwrite` - Run CLI tests overwriting reference tests
- `just test-ui-overwrite` - Overwrite UI test outputs

## Release Process

The release process for Wasm Bindgen typically consists of the following steps:

* `./publish bump`
* Regenerate the reference tests (`just test-cli-overwrite`).
* Check if the schema version must be bumped in crates/shared/src/lib.rs, by verifying the history of crates/shared/src/schema_hash_approval.rs.
* Verify the schema tests pass via `cargo test -p wasm-bindgen-shared`.
* Bump the changelog.
* Commit and publish as a PR.
* Merge and wait for status checks to succeed.
* Push a new tag, which then triggers the automated release process.
