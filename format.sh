#!/bin/bash
# format.sh - Pretty output formatter (colors only for labels/values, not emojis)

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# Emojis (printed plain, not color-wrapped)
ROCKET="🚀"
GEAR="⚙️"
CHART="📊"
CLOCK="⏱️"
FIRE="🔥"
THREAD="🧵"
CHECK="✓"
CROSS="✗"
HOURGLASS="⏳"

SPINNER_PID_FILE="${TMPDIR:-/tmp}/.bench_spinner_pid"

status() {
  # simple status line, emoji not colored, text label colored
  echo -e "${GEAR} ${BLUE}$1${RESET}"
}

error() {
  echo -e "${CROSS} ${RED}Error:${RESET} $1" >&2
}

progress_start() {
  # Start a background spinner that dots every 0.2s
  # Print a one-time header line
  echo -ne "${HOURGLASS} ${YELLOW}Benchmarking${RESET}"
  (
    while true; do
      echo -n "."
      sleep 0.2
    done
  ) &
  echo $! > "$SPINNER_PID_FILE"
}

progress_end() {
  # Stop spinner and print check mark on a new line
  if [[ -f "$SPINNER_PID_FILE" ]]; then
    pid=$(cat "$SPINNER_PID_FILE" || true)
    if [[ -n "${pid:-}" ]] && kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
    fi
    rm -f "$SPINNER_PID_FILE"
  fi
  echo -e " ${GREEN}${CHECK}${RESET}"
}

summary() {
  local script="$1"
  local host="$2"
  local endpoint="$3"
  local requests="$4"
  local concurrency="$5"
  local total="$6"
  local slowest="$7"
  local fastest="$8"
  local average="$9"
  local rps="${10}"
  local total_data="${11}"
  local size_req="${12}"
  local dns_dialup="${13}"
  local dns_lookup="${14}"
  local req_write="${15}"
  local resp_wait="${16}"
  local resp_read="${17}"
  local avg_threads="${18}"
  local max_threads="${19}"
  local min_threads="${20}"

  echo ""
  echo -e "${BOLD}${CYAN}╔═══════════════════════════════════════════════════════════════╗${RESET}"
  echo -e "${BOLD}${CYAN}║${RESET}  ${ROCKET}  ${BOLD}${CYAN}BENCHMARK RESULTS${RESET}                                     ${BOLD}${CYAN}║${RESET}"
  echo -e "${BOLD}${CYAN}╚═══════════════════════════════════════════════════════════════╝${RESET}"
  echo ""

  echo -e "${BOLD}${MAGENTA}Test Configuration${RESET}"
  echo -e "  ${BOLD}${BLUE}Script:${RESET}       ${BOLD}$script${RESET}"
  echo -e "  ${BOLD}${BLUE}URL:${RESET}          ${BOLD}${host}${endpoint}${RESET}"
  echo -e "  ${BOLD}${BLUE}Requests:${RESET}     ${BOLD}$requests${RESET}"
  echo -e "  ${BOLD}${BLUE}Concurrency:${RESET}  ${BOLD}$concurrency${RESET}"
  echo ""

  echo -e "${FIRE} ${BOLD}${GREEN}Performance Metrics${RESET}"
  echo -e "  ${BOLD}${BLUE}Total time:${RESET}      ${BOLD}$total${RESET}"
  echo -e "  ${BOLD}${BLUE}Requests/sec:${RESET}    ${BOLD}${GREEN}$rps${RESET}"
  echo -e "  ${BOLD}${BLUE}Average latency:${RESET} ${BOLD}$average${RESET}"
  echo -e "  ${BOLD}${BLUE}Fastest:${RESET}         ${BOLD}${GREEN}$fastest${RESET}"
  echo -e "  ${BOLD}${BLUE}Slowest:${RESET}         ${BOLD}${RED}$slowest${RESET}"
  echo ""

  echo -e "${CHART} ${BOLD}${BLUE}Request Summary${RESET}"
  echo -e "  ${BOLD}${BLUE}Total data:${RESET}      ${BOLD}$total_data${RESET}"
  echo -e "  ${BOLD}${BLUE}Size/request:${RESET}    ${BOLD}$size_req${RESET}"
  echo ""

  echo -e "${CLOCK} ${BOLD}${YELLOW}Details (average, fastest, slowest)${RESET}"
  echo -e "  ${BOLD}${BLUE}DNS+dialup:${RESET}  ${BOLD}$dns_dialup${RESET}"
  echo -e "  ${BOLD}${BLUE}DNS lookup:${RESET}  ${BOLD}$dns_lookup${RESET}"
  echo -e "  ${BOLD}${BLUE}Request:${RESET}     ${BOLD}$req_write${RESET}"
  echo -e "  ${BOLD}${BLUE}Wait:${RESET}        ${BOLD}$resp_wait${RESET}"
  echo -e "  ${BOLD}${BLUE}Response:${RESET}    ${BOLD}$resp_read${RESET}"
  echo ""

  echo -e "${THREAD} ${BOLD}${MAGENTA}Thread Usage${RESET}"
  if [[ "$avg_threads" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    printf "  ${BOLD}${BLUE}Average:${RESET}     ${BOLD}%.1f${RESET}\n" "$avg_threads"
  else
    echo -e "  ${BOLD}${BLUE}Average:${RESET}     ${BOLD}$avg_threads${RESET}"
  fi
  echo -e "  ${BOLD}${BLUE}Min:${RESET}         ${BOLD}$min_threads${RESET}"
  echo -e "  ${BOLD}${BLUE}Max:${RESET}         ${BOLD}$max_threads${RESET}"
  echo ""
  echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════${RESET}"
  echo ""
}

# Command dispatcher
CMD="${1:-}"
shift || true
case "$CMD" in
  status) status "$@";;
  error) error "$@";;
  progress_start) progress_start ;;
  progress_end) progress_end ;;
  summary) summary "$@";;
  *) echo "Unknown command: $CMD" >&2; exit 1;;
esac