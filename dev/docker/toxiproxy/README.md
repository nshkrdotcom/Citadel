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
