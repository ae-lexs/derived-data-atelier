# Derived Data Atelier

Hands-on, hypothesis-driven codelab measuring the trade-off between OLTP
isolation, analytical freshness, and operational cost across three
architectures on AWS:

1. **Coupled** — Aurora writer serves both OLTP and OLAP queries.
2. **Replica** — OLAP routes to an Aurora reader endpoint.
3. **CDC** — OLAP hits Athena over Apache Iceberg, fed by AWS DMS CDC from Aurora.

Companion documentation lives in the *Derived Data Atelier* folder of the
[`constellational_atelier`](https://github.com/ae-lexs/constellational_atelier) repo.

## Prerequisites

- Docker and Docker Compose
- AWS CLI configured with SSO profile `derived-data-atelier`
- ~1.5 GB free disk (for the TPC-H scale-factor-1 dataset)

## Quickstart

```sh
aws sso login --profile derived-data-atelier

# Module 00 — Terraform state backend (one-time)
docker compose run --rm terraform -chdir=infra/bootstrap init
docker compose run --rm terraform -chdir=infra/bootstrap apply -auto-approve

# Module 01 — Data substrate
docker compose run --rm terraform -chdir=infra/data-model init
docker compose run --rm terraform -chdir=infra/data-model apply -auto-approve
```

See the atelier documentation for the full module sequence and methodology.

## Apply database migrations

Aurora lives in private subnets and is not reachable from the host directly. Bring up the `infra/dev-access/` SSM bastion, open a port forward, then run migrations through the tunnel.

```sh
# 1. Apply the dev-only bastion stack (≈ 30 s + brief SSM agent registration)
docker compose run --rm terraform -chdir=infra/dev-access init
docker compose run --rm terraform -chdir=infra/dev-access apply -auto-approve
```

Open the SSM port forward in its own terminal — `localhost:5432` will tunnel to the Aurora writer through the bastion. Keep this terminal open:

```sh
# 2. Open the tunnel (foreground — leave this terminal running)
$(docker compose run --rm terraform -chdir=infra/dev-access output -raw port_forward_command)
```

In a second terminal, export the master credentials from Secrets Manager and run `golang-migrate` against `host.docker.internal:5432`:

```sh
# 3. Apply pending migrations
export DBSECRET=$(aws secretsmanager get-secret-value \
  --profile derived-data-atelier \
  --secret-id dda/data-model/master \
  --query SecretString --output text)
export PGUSER=$(echo "$DBSECRET" | jq -r .username)
export PGPASSWORD=$(echo "$DBSECRET" | jq -r .password)
export PGHOST=host.docker.internal
export PGDATABASE=tpch

docker compose --profile seed run --rm migrate
```

Destroy the bastion when you no longer need DB access (≈ $3/mo while running):

```sh
docker compose run --rm terraform -chdir=infra/dev-access destroy -auto-approve
```

Session Manager Plugin must be installed on the host — see `infra/dev-access/README.md` for the one-time setup.

## Repository structure

| Path | Purpose |
|---|---|
| `docker-compose.yml` | Toolchain (terraform, migrate, seed, api, k6) per ADR-DDA-013 — nothing on host except Docker |
| `infra/bootstrap/` | Terraform state backend (S3 + DynamoDB lock) |
| `infra/data-model/` | VPC + Aurora PostgreSQL Serverless v2 + Secrets Manager (system of record) |
| `infra/dev-access/` | **Dev-only.** IGW + public subnet + EC2 bastion with SSM. Opens an `aws ssm start-session` port forward from your host to Aurora. Apply before migrations / psql / smoke tests; destroy when idle. See `infra/dev-access/README.md`. |
| `migrations/` | `golang-migrate` schema migrations (TPC-H DDL) |

## Development

All toolchain runs inside Docker per ADR-DDA-013 — nothing on host except
Docker itself. Lint and format checks are run via the `terraform` compose
service:

```sh
# Format the whole tree (writes changes in place)
docker compose run --rm terraform fmt -recursive .

# Validate each root module
docker compose run --rm terraform -chdir=infra/bootstrap  validate
docker compose run --rm terraform -chdir=infra/data-model validate
```

TFLint is invoked from Module 07's CI pipeline (`.github/workflows/ci.yml`)
against the `.tflint.hcl` config at the repo root; the same checks run as
PR-gating CI steps. Local commits are not auto-gated by design — see ADR-DDA-013
and the Docker-non-negotiable stance.

## License

TBD
