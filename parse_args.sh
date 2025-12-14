#!/bin/bash
# parse_args.sh - Argument parser and help menu for benchmark script

set -euo pipefail

# Colors for headers only
BOLD='\033[1m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RESET='\033[0m'

show_help() {
  echo -e "${BOLD}${CYAN}FastAPI Benchmark Tool${RESET}"
  echo ""
  echo -e "${BOLD}${YELLOW}USAGE:${RESET}"
  echo "  $0 <script.py> [OPTIONS]"
  echo ""
  echo -e "${BOLD}${YELLOW}REQUIRED:${RESET}"
  echo "  script.py              Python script to benchmark"
  echo ""
  echo -e "${BOLD}${YELLOW}OPTIONS:${RESET}"
  echo "  -h, --host HOST        Server host (default: localhost:8000)"
  echo "  -p, --port PORT        Server port"
  echo "  -e, --endpoint PATH    API endpoint to test (default: /)"
  echo "  -n, --requests NUM     Total number of requests (default: 200)"
  echo "  -c, --concurrency NUM  Number of concurrent requests (default: 50)"
  echo "  --help                 Show this help message"
  echo ""
  echo -e "${BOLD}${YELLOW}EXAMPLES:${RESET}"
  echo "  $0 script.py localhost:8000"
  echo "  $0 script.py example.com"
  echo "  $0 script.py example.com -p 8000"
  echo "  $0 script.py localhost:8000 -n 1000"
  echo "  $0 script.py https://localhost:8000"
  echo ""
}

# Check for help as first argument
if [[ "${1:-}" == "help" ]] || [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" && $# -eq 1 ]]; then
  show_help
  exit 0
fi

# Default values
SCRIPT_FILE=""
HOST=""
PORT=""
ENDPOINT="/"
REQUESTS="200"
CONCURRENCY="50"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--host)
      HOST="$2"
      shift 2
      ;;
    -p|--port)
      PORT="$2"
      shift 2
      ;;
    -e|--endpoint)
      ENDPOINT="$2"
      shift 2
      ;;
    -n|--requests)
      REQUESTS="$2"
      shift 2
      ;;
    -c|--concurrency)
      CONCURRENCY="$2"
      shift 2
      ;;
    -*)
      echo "Error: Unknown option: $1" >&2
      echo "Use --help for usage information" >&2
      exit 1
      ;;
    *)
      if [[ -z "$SCRIPT_FILE" ]]; then
        SCRIPT_FILE="$1"
      else
        echo "Error: Unexpected argument: $1" >&2
        echo "Use --help for usage information" >&2
        exit 1
      fi
      shift
      ;;
  esac
done

# Validate required arguments
if [[ -z "$SCRIPT_FILE" ]]; then
  echo "Error: Script file is required" >&2
  echo "" >&2
  show_help
  exit 1
fi

if [[ ! -f "$SCRIPT_FILE" ]]; then
  echo "Error: Script file not found: $SCRIPT_FILE" >&2
  exit 1
fi

# Parse host and port
FINAL_HOST=""
FINAL_PORT=""

if [[ -n "$HOST" ]]; then
  # Check if port is embedded in host (e.g., localhost:8000)
  if [[ "$HOST" =~ ^(.+):([0-9]+)$ ]]; then
    HOST_PART="${BASH_REMATCH[1]}"
    EMBEDDED_PORT="${BASH_REMATCH[2]}"
    
    # Use embedded port if -p not provided
    if [[ -z "$PORT" ]]; then
      PORT="$EMBEDDED_PORT"
    fi
    HOST="$HOST_PART"
  fi
  
  # Normalize localhost variants
  if [[ "$HOST" == "localhost" || "$HOST" == "127.0.0.1" ]]; then
    # Check if we have a port
    if [[ -z "$PORT" ]]; then
      echo "Error: Port is required for localhost/127.0.0.1" >&2
      echo "Provide port with -p option or in host string (e.g., localhost:8000)" >&2
      exit 1
    fi
    
    # Ensure http:// scheme for localhost
    if [[ ! "$HOST" =~ ^https?:// ]]; then
      FINAL_HOST="http://localhost"
    else
      FINAL_HOST="$HOST"
    fi
    FINAL_PORT="$PORT"
  else
    # Remote host
    # Add https:// if no scheme provided
    if [[ ! "$HOST" =~ ^https?:// ]]; then
      FINAL_HOST="https://$HOST"
    else
      FINAL_HOST="$HOST"
    fi
    
    # Port is optional for remote hosts
    if [[ -n "$PORT" ]]; then
      FINAL_PORT="$PORT"
    fi
  fi
else
  # No host provided, default to localhost
  if [[ -z "$PORT" ]]; then
    PORT="8000"
  fi
  FINAL_HOST="http://localhost"
  FINAL_PORT="$PORT"
fi

# Normalize endpoint (ensure leading /)
if [[ ! "$ENDPOINT" =~ ^/ ]]; then
  ENDPOINT="/$ENDPOINT"
fi

# Build HOST (without endpoint)
if [[ -n "$FINAL_PORT" ]]; then
  HOST="${FINAL_HOST}:${FINAL_PORT}"
else
  HOST="${FINAL_HOST}"
fi

# Export variables for use by benchmark script
export BENCH_SCRIPT_FILE="$SCRIPT_FILE"
export BENCH_HOST="$HOST"
export BENCH_ENDPOINT="$ENDPOINT"
export BENCH_REQUESTS="$REQUESTS"
export BENCH_CONCURRENCY="$CONCURRENCY"

# Output parsed values (for debugging)
# Uncomment for troubleshooting:
# echo "Parsed arguments:"
# echo "  Script: $BENCH_SCRIPT_FILE"
# echo "  Host: $BENCH_HOST"
# echo "  Endpoint: $BENCH_ENDPOINT"
# echo "  Requests: $BENCH_REQUESTS"
# echo "  Concurrency: $BENCH_CONCURRENCY"
