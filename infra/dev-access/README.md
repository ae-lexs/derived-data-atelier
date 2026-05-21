# infra/dev-access

A **dev-only** Terraform root module that opens a path from your host to the
Aurora cluster in `infra/data-model/`. Aurora lives in private subnets and
is not reachable from outside the VPC; this module adds:

- An Internet Gateway and a public subnet (`10.42.10.0/24`).
- A `t4g.nano` Amazon Linux 2023 ARM64 EC2 bastion with the
  `AmazonSSMManagedInstanceCore` policy attached — no SSH key, no inbound
  port, all access via Systems Manager Session Manager.

You open an SSM-tunneled port forward from `localhost:5432` on your Mac
→ bastion → Aurora. The migrate / psql / api containers dial
`host.docker.internal` to reach it.

## Cost

≈ $3 / month while running (t4g.nano + 8 GB gp3 EBS, IGW is free).
Destroy when you don't need it.

## Prerequisite — Session Manager Plugin on the host

The Session Manager Plugin binds a local TCP port and forwards bytes through
an outbound websocket. It cannot reasonably be containerized on macOS (binds
`127.0.0.1` only, no host-network mode under Docker Desktop), so it's
installed alongside the AWS CLI on the host. One-time:

```sh
# macOS Apple Silicon
curl -sSL "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/mac_arm64/sessionmanager-bundle.zip" \
  -o /tmp/sessionmanager-bundle.zip
unzip -q /tmp/sessionmanager-bundle.zip -d /tmp
sudo /tmp/sessionmanager-bundle/install \
  -i /usr/local/sessionmanagerplugin \
  -b /usr/local/bin/session-manager-plugin
rm -rf /tmp/sessionmanager-bundle*
session-manager-plugin   # smoke — prints version
```

For other platforms: https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html

## Apply

```sh
docker compose run --rm terraform -chdir=infra/dev-access init
docker compose run --rm terraform -chdir=infra/dev-access apply -auto-approve
```

~30 seconds, plus a brief wait for SSM agent to register the new instance
(usually under 60 s after the instance reaches `running`).

## Open a port forward

```sh
# Read the ready-made command and run it (foreground — leave this terminal open).
$(docker compose run --rm terraform -chdir=infra/dev-access output -raw port_forward_command)
```

You'll see:

```
Starting session with SessionId: ...
Port 5432 opened for sessionId ...
Waiting for connections...
```

`localhost:5432` on your Mac is now Aurora's writer endpoint. Keep this
terminal tab open while you work.

## Run migrations through the tunnel

In a separate terminal, with the tunnel running:

```sh
export DBSECRET=$(aws secretsmanager get-secret-value \
  --profile derived-data-atelier \
  --secret-id dda/data-model/master \
  --query SecretString --output text)
export PGUSER=$(echo "$DBSECRET" | jq -r .username)
export PGPASSWORD=$(echo "$DBSECRET" | jq -r .password)
export PGHOST=host.docker.internal       # the SSM tunnel listener on the host
export PGDATABASE=tpch

docker compose --profile seed run --rm migrate
```

`host.docker.internal` is Docker Desktop's pre-configured DNS name that
resolves to the host's gateway address. The migrate container dials it on
port 5432, Docker forwards to the host's `localhost:5432`, and the Session
Manager Plugin relays through the bastion to Aurora.

The same flow works for ad-hoc psql, the `api/` smoke test in Module 02,
and any other module that needs direct DB access during development.

## Destroy

```sh
docker compose run --rm terraform -chdir=infra/dev-access destroy -auto-approve
```

`infra/data-model/` and the Aurora cluster are untouched — they live in a
separate Terraform state.

## Outputs

| Name | Description |
|---|---|
| `bastion_instance_id` | EC2 instance ID — pass as `--target` of `aws ssm start-session`. |
| `port_forward_command` | Pre-formatted, ready-to-execute `aws ssm start-session` command. |
