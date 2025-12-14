#!/bin/bash
# benchmark.sh - Main benchmark orchestrator using hey and uv

set -euo pipefail

SCRIPT_FILE="${1:-}"
ENDPOINT="${2:-/words}"
HEY_REQUESTS="${3:-200}"
HEY_CONCURRENCY="${4:-50}"

if [[ -z "$SCRIPT_FILE" ]]; then
  echo "Usage: $0 <script.py> [endpoint] [requests] [concurrency]"
  echo "Example: $0 non-async.py /words 200 50"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORMATTER="$SCRIPT_DIR/format.sh"

if [[ ! -f "$FORMATTER" ]]; then
  echo "Error: format.sh not found in $SCRIPT_DIR" >&2
  exit 1
fi

# Start server
"$FORMATTER" status "Starting server: uv run $SCRIPT_FILE"
SERVER_LOG=$(mktemp)
set +e
uv run "$SCRIPT_FILE" > "$SERVER_LOG" 2>&1 &
SERVER_PROC=$!
set -e

# Extract PID from log
"$FORMATTER" status "Waiting for server to start..."
PID=""
for _ in {1..50}; do
  if grep -q "Started server process" "$SERVER_LOG"; then
    PID=$(grep "Started server process" "$SERVER_LOG" | tail -n1 | sed -E 's/.*\[(^[]]*)\].*/\1/' | grep -oE '[0-9]+')
    break
  fi
  sleep 0.1
done

if [[ -z "$PID" ]]; then
  # fallback parse with grep -oP if available
  if command -v grep >/dev/null 2>&1; then
    PID=$(grep "Started server process" "$SERVER_LOG" | tail -n1 | grep -oE '\[[0-9]+\]' | tr -d '[]' || true)
  fi
fi

if [[ -z "$PID" ]]; then
  "$FORMATTER" error "Failed to extract PID from server logs"
  kill "$SERVER_PROC" 2>/dev/null || true
  rm -f "$SERVER_LOG"
  exit 1
fi

"$FORMATTER" status "Server started with PID: $PID"

# Wait until endpoint ready
"$FORMATTER" status "Waiting for server to be ready at http://localhost:8000$ENDPOINT"
for _ in {1..100}; do
  if curl -sSf "http://localhost:8000$ENDPOINT" >/dev/null 2>&1; then
    break
  fi
  sleep 0.1
done
sleep 0.3
"$FORMATTER" status "Server ready"

# Thread monitor
THREAD_LOG=$(mktemp)
{
  while kill -0 "$SERVER_PROC" 2>/dev/null; do
    if [[ -d "/proc/$PID/task" ]]; then
      # Count threads via /proc (fast)
      wc -l < "/proc/$PID/task" >> "$THREAD_LOG" 2>/dev/null || true
    else
      # Fallback ps
      ps -p "$PID" -L 2>/dev/null | tail -n +2 | wc -l >> "$THREAD_LOG" 2>/dev/null || true
    fi
    sleep 0.5
  done
} &
MONITOR_PID=$!

# Run hey with live spinner
"$FORMATTER" status "Running benchmark: hey -n $HEY_REQUESTS -c $HEY_CONCURRENCY"
"$FORMATTER" progress_start
HEY_OUTPUT=$(mktemp)
set +e
hey -n "$HEY_REQUESTS" -c "$HEY_CONCURRENCY" "http://localhost:8000$ENDPOINT" >"$HEY_OUTPUT" 2>&1
HEY_EXIT=$?
set -e
"$FORMATTER" progress_end

if [[ $HEY_EXIT -ne 0 ]]; then
  "$FORMATTER" error "hey failed. Output:"
  cat "$HEY_OUTPUT" >&2
  # Cleanup
  kill "$SERVER_PROC" 2>/dev/null || true
  kill "$MONITOR_PID" 2>/dev/null || true
  wait "$SERVER_PROC" 2>/dev/null || true
  wait "$MONITOR_PID" 2>/dev/null || true
  rm -f "$SERVER_LOG" "$HEY_OUTPUT" "$THREAD_LOG"
  exit 1
fi

# Parse hey output (only the requested parts)
Total=$(grep -E "^  Total:" "$HEY_OUTPUT" | sed -E 's/^  Total:[[:space:]]+//' || echo "N/A")
Slowest=$(grep -E "^  Slowest:" "$HEY_OUTPUT" | sed -E 's/^  Slowest:[[:space:]]+//' || echo "N/A")
Fastest=$(grep -E "^  Fastest:" "$HEY_OUTPUT" | sed -E 's/^  Fastest:[[:space:]]+//' || echo "N/A")
Average=$(grep -E "^  Average:" "$HEY_OUTPUT" | sed -E 's/^  Average:[[:space:]]+//' || echo "N/A")
RPS=$(grep -E "^  Requests/sec:" "$HEY_OUTPUT" | awk '{print $2}' || echo "N/A")

TotalData=$(grep -E "^  Total data:" "$HEY_OUTPUT" | sed -E 's/^  Total data:[[:space:]]+//' || echo "0 bytes")
SizeReq=$(grep -E "^  Size/request:" "$HEY_OUTPUT" | sed -E 's/^  Size\/request:[[:space:]]+//' || echo "0 bytes")

DNS_dialup=$(grep -E "^  DNS\+dialup:" "$HEY_OUTPUT" | sed -E 's/^  DNS\+dialup:[[:space:]]+//' || echo "N/A")
DNS_lookup=$(grep -E "^  DNS-lookup:" "$HEY_OUTPUT" | sed -E 's/^  DNS-lookup:[[:space:]]+//' || echo "N/A")
Req_write=$(grep -E "^  req write:" "$HEY_OUTPUT" | sed -E 's/^  req write:[[:space:]]+//' || echo "N/A")
Resp_wait=$(grep -E "^  resp wait:" "$HEY_OUTPUT" | sed -E 's/^  resp wait:[[:space:]]+//' || echo "N/A")
Resp_read=$(grep -E "^  resp read:" "$HEY_OUTPUT" | sed -E 's/^  resp read:[[:space:]]+//' || echo "N/A")

# Thread stats
if [[ -s "$THREAD_LOG" ]]; then
  AVG_THREADS=$(awk '{s+=$1;n++} END{if(n>0) printf "%.2f", s/n; else print "0"}' "$THREAD_LOG")
  MAX_THREADS=$(sort -n "$THREAD_LOG" | tail -1)
  MIN_THREADS=$(sort -n "$THREAD_LOG" | head -1)
else
  AVG_THREADS="N/A"
  MAX_THREADS="N/A"
  MIN_THREADS="N/A"
fi

# Cleanup server and monitor
"$FORMATTER" status "Shutting down server"
kill "$SERVER_PROC" 2>/dev/null || true
kill "$MONITOR_PID" 2>/dev/null || true
wait "$SERVER_PROC" 2>/dev/null || true
wait "$MONITOR_PID" 2>/dev/null || true

rm -f "$SERVER_LOG" "$HEY_OUTPUT" "$THREAD_LOG"

# Print summary
"$FORMATTER" summary \
  "$SCRIPT_FILE" \
  "$ENDPOINT" \
  "$HEY_REQUESTS" \
  "$HEY_CONCURRENCY" \
  "$Total" \
  "$Slowest" \
  "$Fastest" \
  "$Average" \
  "$RPS" \
  "$TotalData" \
  "$SizeReq" \
  "$DNS_dialup" \
  "$DNS_lookup" \
  "$Req_write" \
  "$Resp_wait" \
  "$Resp_read" \
  "$AVG_THREADS" \
  "$MAX_THREADS" \
  "$MIN_THREADS"