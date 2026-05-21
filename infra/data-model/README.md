# infra/data-model

The DDA **system-of-record substrate**: VPC, Aurora PostgreSQL Serverless v2,
Secrets Manager master credentials, and the VPC endpoints needed to run
schema migrations without a NAT Gateway.

This module is **frozen at Module 01 sign-off** — Modules 03, 04, and 05
share its outputs byte-for-byte for the workload-constancy invariant
(see the *Derived Data Atelier Execution Plan* § II.3).

## Resources

- VPC `10.42.0.0/16` (single-AZ writer in `us-east-1a`; secondary subnet in
  `us-east-1b` required by the DB subnet group)
- Aurora PostgreSQL Serverless v2 cluster `dda-aurora` with `min_capacity = 0`
  and auto-pause after 5 minutes idle
- Aurora writer instance `dda-aurora-writer` (`db.serverless`)
- Secrets Manager secret `dda/data-model/master`
- Security group restricting Aurora ingress to the VPC CIDR
- VPC interface endpoints for Secrets Manager and CloudWatch Logs

## Apply

```sh
docker compose run --rm terraform -chdir=infra/data-model init
docker compose run --rm terraform -chdir=infra/data-model apply -auto-approve
```

## Inputs

| Variable | Type | Default | Purpose |
|---|---|---|---|
| `min_capacity` | `number` | `0` | Aurora Serverless v2 minimum ACU. `0` enables auto-pause; raise to `1.0` before experiment runs to eliminate scale dynamics. |

## Outputs

| Name | Type | Description |
|---|---|---|
| `cluster_endpoint` | string | Aurora writer endpoint hostname. |
| `secret_arn` | string | Secrets Manager ARN for master credentials. |
| `vpc_id` | string | VPC ID for sibling modules. |
| `private_subnet_ids` | list(string) | Both private subnet IDs. |
