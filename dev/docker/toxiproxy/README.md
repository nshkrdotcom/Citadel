# Citadel Toxiproxy Harness

This directory contains the repo-local Docker harness for fault-injection work in Citadel.

It gives you:

- a Toxiproxy server on `http://127.0.0.1:18474`
- a simple upstream Nginx service on `http://127.0.0.1:18080`
- a proxied upstream listener on `http://127.0.0.1:18081`
- a verification script that proves proxy creation and toxic injection both work

Verified image refs in this harness:

- `shopify/toxiproxy@sha256:a6b080af39986b863a1f7c5a3b9bacf2afeb48abab8f0eb7e243f8f7ad38c645`
- `nginx@sha256:65645c7bb6a0661892a8b03b89d0743208a18dd2f3f17a54ef4b76fb8e2f2a10`

## Layout

- `docker-compose.yml`
- `upstream/index.html`
- `run_fault_injection_suite.sh`
- `test_support.exs`
- `verify.sh`

## Start

```bash
docker compose -f dev/docker/toxiproxy/docker-compose.yml -p citadel-toxiproxy up -d
```

## Verify

```bash
dev/docker/toxiproxy/verify.sh
```

The verification script:

1. starts the harness if needed
2. creates the `citadel_nginx` proxy through the Toxiproxy API
3. proves the proxied response matches the upstream response
4. injects a downstream latency toxic
5. proves the response time rises materially
6. removes the toxic
7. proves the response time drops again

## Wave 12 Suite

Run the full infrastructure fault-injection proof from the workspace root:

```bash
mix hardening.infrastructure_faults
```

That runner:

1. verifies the canonical Docker harness with `dev/docker/toxiproxy/verify.sh`
2. runs the `invocation_bridge` hostile-infrastructure suite
3. runs the `projection_bridge` hostile-infrastructure suite
4. runs the `citadel_runtime` outbox and worker-saturation suite

The package tests are opt-in behind `CITADEL_REQUIRE_TOXIPROXY=1` so ordinary `mix test` runs stay independent of Docker, while Wave 12 remains a first-class scripted regression path.

## Covered Fault Classes

The Wave 12 suites currently prove these classes explicitly:

- `invocation_bridge`: real-socket latency injection through Toxiproxy, explicit connection drop via disabled proxy, repeated hostile failures that open the bridge circuit, and a faithful equivalent half-open socket server for hanging-response behavior
- `projection_bridge`: real-socket bandwidth starvation through Toxiproxy, explicit connection drop via disabled proxy, and circuit-open fast-fail after repeated transient downstream failure
- `citadel_runtime`: replay-safe outbox retry, deterministic backoff scheduling, payload preservation, explicit dead-letter or blocked state on exhaustion, and no invocation dispatch backlog once the shared bridge circuit is already open

The one deliberate substitution is half-open behavior. The pinned Toxiproxy image in this repo exposes latency, bandwidth, timeout, limit-data, and slow-close toxics, but it does not provide a stable half-open hang primitive for the bridge tests. `test_support.exs` therefore supplies a real local socket fixture that accepts the connection and never returns a response, which preserves the packet's required hanging-connection assertion strength without changing bridge architecture.

## Inspect

List the current proxy state:

```bash
curl -fsS http://127.0.0.1:18474/proxies | jq
```

Inspect the proxied upstream:

```bash
curl -fsS http://127.0.0.1:18081/
```

## Stop

```bash
docker compose -f dev/docker/toxiproxy/docker-compose.yml -p citadel-toxiproxy down -v
```

## Host Requirements

- Docker Engine
- the modern `docker compose` plugin
- `curl`
- `jq`
- `awk`

No host-installed `toxiproxy-cli` is required for this repo-local harness.
