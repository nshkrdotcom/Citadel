#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="$SCRIPT_DIR/docker-compose.yml"
COMPOSE_PROJECT="citadel-toxiproxy"
TOXIPROXY_API="http://127.0.0.1:18474"
UPSTREAM_URL="http://127.0.0.1:18080/"
PROXY_URL="http://127.0.0.1:18081/"
PROXY_NAME="citadel_nginx"
TOXIC_NAME="downstream_latency"
EXPECTED_TEXT="citadel toxiproxy upstream ok"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "missing required command: $1" >&2
    exit 1
  fi
}

compose() {
  docker compose -f "$COMPOSE_FILE" -p "$COMPOSE_PROJECT" "$@"
}

wait_for_http() {
  local url="$1"
  local label="$2"
  local attempts=30
  local i

  for i in $(seq 1 "$attempts"); do
    if curl -fsS "$url" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done

  echo "timed out waiting for $label at $url" >&2
  return 1
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local label="$3"

  if [[ "$haystack" != *"$needle"* ]]; then
    echo "$label did not contain expected text: $needle" >&2
    exit 1
  fi
}

assert_float_gt() {
  local left="$1"
  local right="$2"
  local label="$3"

  awk "BEGIN { exit !($left > $right) }" || {
    echo "$label expected $left > $right" >&2
    exit 1
  }
}

assert_float_lt() {
  local left="$1"
  local right="$2"
  local label="$3"

  awk "BEGIN { exit !($left < $right) }" || {
    echo "$label expected $left < $right" >&2
    exit 1
  }
}

require_cmd docker
require_cmd curl
require_cmd jq
require_cmd awk

echo "Starting Citadel Toxiproxy harness..."
compose up -d

wait_for_http "$UPSTREAM_URL" "upstream container"
wait_for_http "$TOXIPROXY_API/version" "toxiproxy api"

echo "Resetting proxy state..."
curl -fsS -X DELETE "$TOXIPROXY_API/proxies/$PROXY_NAME" >/dev/null 2>&1 || true

curl -fsS \
  -H "Content-Type: application/json" \
  -X POST \
  "$TOXIPROXY_API/proxies" \
  -d "{\"name\":\"$PROXY_NAME\",\"listen\":\"0.0.0.0:18081\",\"upstream\":\"toxiproxy-upstream:80\",\"enabled\":true}" \
  >/dev/null

curl -fsS "$TOXIPROXY_API/proxies/$PROXY_NAME" | jq -e '.name == "'"$PROXY_NAME"'"' >/dev/null

direct_body="$(curl -fsS "$UPSTREAM_URL")"
proxy_body="$(curl -fsS "$PROXY_URL")"

assert_contains "$direct_body" "$EXPECTED_TEXT" "direct upstream response"
assert_contains "$proxy_body" "$EXPECTED_TEXT" "proxied response"

baseline_time="$(curl -o /dev/null -sS -w "%{time_total}" "$PROXY_URL")"

echo "Adding downstream latency toxic..."
curl -fsS \
  -H "Content-Type: application/json" \
  -X POST \
  "$TOXIPROXY_API/proxies/$PROXY_NAME/toxics" \
  -d "{\"name\":\"$TOXIC_NAME\",\"type\":\"latency\",\"stream\":\"downstream\",\"toxicity\":1.0,\"attributes\":{\"latency\":1200,\"jitter\":0}}" \
  >/dev/null

delayed_time="$(curl -o /dev/null -sS -w "%{time_total}" "$PROXY_URL")"
assert_float_gt "$delayed_time" "$(awk "BEGIN { print $baseline_time + 0.8 }")" "latency toxic verification"

echo "Removing latency toxic..."
curl -fsS -X DELETE "$TOXIPROXY_API/proxies/$PROXY_NAME/toxics/$TOXIC_NAME" >/dev/null

restored_time="$(curl -o /dev/null -sS -w "%{time_total}" "$PROXY_URL")"
assert_float_lt "$restored_time" "$(awk "BEGIN { print $delayed_time - 0.5 }")" "latency toxic removal verification"

echo
echo "Citadel Toxiproxy harness verified successfully."
echo "Direct upstream:  $UPSTREAM_URL"
echo "Toxiproxy API:    $TOXIPROXY_API"
echo "Proxied upstream: $PROXY_URL"
echo "Baseline time:    ${baseline_time}s"
echo "Delayed time:     ${delayed_time}s"
echo "Restored time:    ${restored_time}s"
