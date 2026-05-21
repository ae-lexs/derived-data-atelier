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
