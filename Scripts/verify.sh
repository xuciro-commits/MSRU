#!/usr/bin/env bash
# Single verification entry point (see AGENTS.md → "Verify").
#   Scripts/verify.sh            gates + package tests + macOS unit tests + iOS Simulator build
#   Scripts/verify.sh gates      source guardrails only (seconds, no Xcode needed)
#   Scripts/verify.sh packages   gates + `swift test` for every local package
#   Scripts/verify.sh app        gates + app build/test via xcodebuild
#   Scripts/verify.sh contract   gates + kernel contract: schema lint, generated code in sync,
#                                Go and Swift implementations against the shared vectors
# Full logs: .build/verify/<step>.log (gitignored). Exit code is non-zero if any step fails.
set -uo pipefail
cd "$(dirname "$0")/.."
MODE="${1:-all}"
LOGS=.build/verify
DERIVED=.build/DerivedData
mkdir -p "$LOGS"
failed=()

step() {
  local name="$1"; shift
  printf '%-28s' "$name"
  if "$@" >"$LOGS/$name.log" 2>&1; then
    echo "ok"
  else
    echo "FAILED  ($LOGS/$name.log)"
    failed+=("$name")
  fi
}

step gate-architecture python3 Scripts/verify-architecture.py
step gate-previews     python3 Scripts/verify-previews.py

if [[ "$MODE" == all || "$MODE" == packages ]]; then
  for pkg in AppFoundation MusicDomain; do
    step "test-$pkg" swift test --package-path "Packages/$pkg"
  done
fi

if [[ "$MODE" == all || "$MODE" == contract ]]; then
  step contract-schema bash -c 'cd Contract/proto && export PATH="$(go env GOPATH)/bin:$PATH" && gen() { find ../go/gen -type f -exec shasum {} + | sort; } && before=$(gen) && buf lint && buf generate && { [ "$before" = "$(gen)" ] || { echo "generated code was stale; buf generate updated Contract/go/gen"; exit 1; }; }'
  step contract-go bash -c 'cd Contract/go && go vet ./... && go test -count=1 ./...'
  step contract-swift swift test --package-path Contract/swift
fi

if [[ "$MODE" == all || "$MODE" == app ]]; then
  step test-macos xcodebuild test -project MSRU.xcodeproj -scheme MSRU-UnitTests \
    -destination 'platform=macOS' -derivedDataPath "$DERIVED" CODE_SIGNING_ALLOWED=NO
  step build-ios-simulator xcodebuild build -project MSRU.xcodeproj -scheme MSRU \
    -destination 'generic/platform=iOS Simulator' -derivedDataPath "$DERIVED" CODE_SIGNING_ALLOWED=NO
fi

if ((${#failed[@]})); then
  echo "Failed: ${failed[*]}"
  exit 1
fi
echo "All requested checks passed."
