# infra/bootstrap

Terraform root module that creates the **state backend** every other DDA
module depends on:

- S3 bucket `dda-tfstate-<account-id>` (versioning enabled) for remote state.
- DynamoDB table `dda-tfstate-lock` (PAY_PER_REQUEST) for state locking.

## State

**Local state only.** This module bootstraps the backend, so it cannot use it.
The local `terraform.tfstate` lives next to `main.tf` after apply and is
gitignored. **Do not delete it** or you will lose the ability to manage the
bucket and lock table from Terraform.

## Apply

```sh
docker compose run --rm terraform -chdir=infra/bootstrap init
docker compose run --rm terraform -chdir=infra/bootstrap apply -auto-approve
```

## Outputs

| Name | Type | Description |
|---|---|---|
| `state_bucket_name` | string | Bucket every sibling module uses as its backend bucket. |
| `state_lock_table_name` | string | Locking table name (default `dda-tfstate-lock`). |
| `account_id` | string | AWS account ID (handy when constructing backend bucket names). |
