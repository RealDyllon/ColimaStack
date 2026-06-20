#!/bin/sh
# Run ColimaStack tests inside a Tart macOS VM so the host is not hijacked.
#
# XCUITests drive the real app via Accessibility and take over whichever GUI
# session runs them. This script runs them inside a headless macOS guest, so
# your host stays fully usable while the tests click around inside the VM.
# Docker isolation is free: the guest runs its own environment, separate from
# your host's Colima/Docker.
#
# Requirements (auto-detected; install commands printed if missing):
#   brew install cirruslabs/cli/tart
#   brew install cirruslabs/cli/sshpass
#
# First run downloads a ~25 GB image and boots the VM (a few minutes).
# Subsequent runs reuse the kept VM and are much faster.
#
# Usage (from the repo root):
#   ./scripts/verify-vm.sh                       # all tests incl. UI tests
#   INCLUDE_UI_TESTS=0 ./scripts/verify-vm.sh    # unit tests only
#   VM_GRAPHICS=1 ./scripts/verify-vm.sh         # show guest window (debugging)
#
# Environment variables (defaults shown):
#   VM_IMAGE          ghcr.io/cirruslabs/macos-sequoia-xcode:latest
#   VM_NAME           colima-stack-sequoia
#   VM_CPU            4
#   VM_MEM_GB         8        (guest RAM in GB)
#   VM_DISPLAY        1920x1080
#   VM_GRAPHICS       0        (1 = show guest window; 0 = headless)
#   VM_NESTED         0        (1 = enable nested virt; needed to run real
#                              Colima inside the guest, not for --mock-data)
#   VM_DELETE         0        (1 = delete VM after run instead of keeping it)
#   INCLUDE_UI_TESTS  1        (0 = -skip-testing:ColimaStackUITests)
#   SSH_TIMEOUT       180      (seconds to wait for the VM to become SSH-able)
#
# Notes:
#   * The default image is Sequoia + Xcode 16.x, matching this host (macOS 15)
#     and the macos-15 GitHub-hosted runner. Apple Silicon cannot virtualize a
#     macOS guest newer than the host, so a Tahoe/26 guest is NOT an option on
#     Sequoia. Your CI's macos-26 builds use Xcode 26; the project's
#     objectVersion 77 is Xcode-16-compatible and your CI already builds it on
#     macos-15 with Xcode 16.4, so this VM matches that path.
#   * On the first UI-test run the guest may prompt for Accessibility/TCC
#     permission for the test runner. If UI tests fail with a permission error,
#     re-run with VM_GRAPHICS=1 and click Allow in the guest window once; the
#     grant persists in the kept VM and headless runs work afterwards.
set -eu

PROJECT="ColimaStack.xcodeproj"
SCHEME="ColimaStack"
REMOTE_DIR="colima-stack"
REMOTE_DERIVED="/tmp/ColimaStackVM-DerivedData"

VM_IMAGE="${VM_IMAGE:-ghcr.io/cirruslabs/macos-sequoia-xcode:latest}"
VM_NAME="${VM_NAME:-colima-stack-sequoia}"
VM_CPU="${VM_CPU:-4}"
VM_MEM_GB="${VM_MEM_GB:-8}"
VM_DISPLAY="${VM_DISPLAY:-1920x1080}"
VM_GRAPHICS="${VM_GRAPHICS:-0}"
VM_NESTED="${VM_NESTED:-0}"
VM_DELETE="${VM_DELETE:-0}"
INCLUDE_UI_TESTS="${INCLUDE_UI_TESTS:-1}"
SSH_TIMEOUT="${SSH_TIMEOUT:-180}"

VM_MEM_MB=$(( VM_MEM_GB * 1024 ))
VM_LOG=""
TART_RUN_PID=""

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "error: '$1' not found. $2" >&2
    exit 1
  }
}

cleanup() {
  rc=$?
  if [ -n "$TART_RUN_PID" ]; then
    tart stop "$VM_NAME" >/dev/null 2>&1 || true
    i=0
    while [ "$i" -lt 15 ]; do
      kill -0 "$TART_RUN_PID" >/dev/null 2>&1 || break
      i=$(( i + 1 ))
      sleep 1
    done
    kill "$TART_RUN_PID" >/dev/null 2>&1 || true
    wait "$TART_RUN_PID" >/dev/null 2>&1 || true
  fi
  if [ "$VM_DELETE" = "1" ]; then
    tart delete "$VM_NAME" >/dev/null 2>&1 || true
  fi
  if [ -n "$VM_LOG" ] && [ -f "$VM_LOG" ]; then
    echo "==> VM boot log: $VM_LOG" >&2
  fi
  # shell exit code is preserved through the EXIT trap
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

need tart "Install with: brew install cirruslabs/cli/tart"
need sshpass "Install with: brew install cirruslabs/cli/sshpass"
need rsync "rsync ships with macOS (or: brew install rsync)"

[ -f "$PROJECT" ] || { echo "error: $PROJECT not found; run from the repo root." >&2; exit 1; }

VM_IP=""
vm_ssh() {
  sshpass -p admin ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    -o ConnectTimeout=10 "admin@$VM_IP" "$@"
}

# 1. Ensure the local VM exists; clone + configure on first run.
if ! tart list 2>/dev/null | grep -wq "$VM_NAME"; then
  echo "==> Cloning $VM_IMAGE as $VM_NAME (first run downloads ~25 GB)..."
  tart clone "$VM_IMAGE" "$VM_NAME"
  tart set "$VM_NAME" --cpu "$VM_CPU" --memory "$VM_MEM_MB" --display "$VM_DISPLAY"
  echo "==> Configured $VM_NAME: ${VM_CPU} CPU, ${VM_MEM_GB} GB RAM, ${VM_DISPLAY}"
fi

# 2. Start the VM (headless by default) in the background.
VM_LOG="$(mktemp -t colima-stack-vm)"
RUN_ARGS=""
[ "$VM_GRAPHICS" = "1" ] || RUN_ARGS="$RUN_ARGS --no-graphics"
[ "$VM_NESTED" = "1" ] && RUN_ARGS="$RUN_ARGS --nested"
echo "==> Starting VM $VM_NAME (headless=$([ "$VM_GRAPHICS" = "1" ] && echo no || echo yes), nested=$VM_NESTED)..."
tart run $RUN_ARGS "$VM_NAME" >"$VM_LOG" 2>&1 &
TART_RUN_PID=$!

# 3. Wait for SSH to come up.
echo "==> Waiting for VM to become SSH-able (up to ${SSH_TIMEOUT}s)..."
deadline=$(( $(date +%s) + SSH_TIMEOUT ))
ready=0
while [ "$(date +%s)" -lt "$deadline" ]; do
  if ! kill -0 "$TART_RUN_PID" >/dev/null 2>&1; then
    echo "error: tart run exited before the VM became reachable." >&2
    break
  fi
  VM_IP="$(tart ip "$VM_NAME" 2>/dev/null || true)"
  if [ -n "$VM_IP" ] && \
     sshpass -p admin ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
       -o ConnectTimeout=5 "admin@$VM_IP" true >/dev/null 2>&1; then
    ready=1
    break
  fi
  sleep 3
done

if [ "$ready" != "1" ]; then
  echo "error: VM did not become SSH-able within ${SSH_TIMEOUT}s." >&2
  echo "----- last 40 lines of VM log -----" >&2
  tail -n 40 "$VM_LOG" >&2 2>/dev/null || true
  if grep -q "SecKeyCreateRandomKey\|Failed to generate keypair\|Interaction is not allowed" "$VM_LOG" 2>/dev/null; then
    echo "hint: headless Sequoia guests need an unlocked login keychain." >&2
    echo "      Re-run with VM_GRAPHICS=1 to log in via the guest window once;" >&2
    echo "      subsequent headless boots will work. See https://tart.run/faq/#headless-machines" >&2
  fi
  exit 1
fi
echo "==> VM reachable at $VM_IP"

# 4. Sync the repo into the VM (writable copy; build artifacts stay in guest).
echo "==> Syncing repo to VM..."
RSYNC_E="sshpass -p admin ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
RSYNC_EXCLUDES="--exclude=.git --exclude=DerivedData --exclude=build --exclude=dist --exclude=assets/screenshots --exclude=.DS_Store --exclude=*.log --exclude=.tart --exclude=node_modules"
vm_ssh "mkdir -p '$REMOTE_DIR'"
rsync -a --delete $RSYNC_EXCLUDES -e "$RSYNC_E" ./ "admin@$VM_IP:$REMOTE_DIR/"

# 5. Run the tests inside the VM.
if [ "$INCLUDE_UI_TESTS" = "1" ]; then
  SKIP_UI_FLAG=""
  echo "==> Running ALL tests including UI tests inside the VM (host stays free)."
else
  SKIP_UI_FLAG="-skip-testing:ColimaStackUITests"
  echo "==> Running unit tests only inside the VM (set INCLUDE_UI_TESTS=1 for UI tests)."
fi

REMOTE_CMD="cd $REMOTE_DIR && xcodebuild test -project $PROJECT -scheme $SCHEME -destination 'platform=macOS' -derivedDataPath $REMOTE_DERIVED $SKIP_UI_FLAG CODE_SIGNING_ALLOWED=NO"

set +e
vm_ssh "$REMOTE_CMD"
TEST_EXIT=$?
set -e
echo "==> Remote xcodebuild exited with $TEST_EXIT"

# 6. Pull generated screenshots back to the host (handy for marketing tests).
if [ "$INCLUDE_UI_TESTS" = "1" ]; then
  echo "==> Pulling generated screenshots back to host..."
  rsync -a -e "$RSYNC_E" "admin@$VM_IP:$REMOTE_DIR/assets/screenshots/" "assets/screenshots/" 2>/dev/null || true
fi

exit "$TEST_EXIT"
