# ECS PgBouncer Deployment

This folder contains a production-style PgBouncer container and ECS templates for placing PgBouncer between EC2 web applications and an RDS PostgreSQL database.

## Target Architecture

```text
EC2 web app instances
        |
        | TCP 6432
        v
Internal Network Load Balancer
        |
        v
ECS service: PgBouncer tasks in private subnets
        |
        | TCP 5432
        v
RDS PostgreSQL
```

## Files

- `Dockerfile` builds the PgBouncer image for ECS.
- `entrypoint.sh` renders `pgbouncer.ini` and `userlist.txt` from ECS environment variables and secrets.
- `healthcheck.sh` checks PgBouncer locally inside the task.
- `task-definition.json` is an ECS Fargate task definition template.
- `service.json` is an ECS service template for an internal NLB target group.

## Required AWS Resources

Create these before deploying:

- ECR repository, for example `pgbouncer`.
- ECS cluster.
- Private subnets for the PgBouncer tasks.
- Internal NLB with a TCP listener on `6432`.
- Target group using target type `ip`, protocol `TCP`, port `6432`.
- CloudWatch log group `/ecs/pgbouncer`.
- ECS task execution role with ECR, CloudWatch Logs, and Secrets Manager read access.
- Security group for PgBouncer tasks.
- Secrets Manager values for database usernames and passwords.

## Security Groups

Recommended rules:

```text
sg-web-app egress:
  allow TCP 6432 to sg-pgbouncer

sg-pgbouncer ingress:
  allow TCP 6432 from sg-web-app

sg-pgbouncer egress:
  allow TCP 5432 to sg-rds

sg-rds ingress:
  allow TCP 5432 from sg-pgbouncer
```

Keep direct EC2-to-RDS access during migration, then remove it after the application is stable through PgBouncer.

## Important Pool Sizing

Each ECS task has its own independent PgBouncer pool. Total possible RDS connections are roughly:

```text
desired_task_count * PGBOUNCER_MAX_DB_CONNECTIONS
```

If `desiredCount = 2` and `PGBOUNCER_MAX_DB_CONNECTIONS = 80`, PgBouncer can open up to about `160` RDS backend connections. Keep that comfortably below the RDS `max_connections` value and leave room for migrations, monitoring, and admin sessions.

## ECS Secrets

The task template expects these secret-backed environment variables:

```text
RDS_USER
RDS_PASSWORD
APP_DB_USER
APP_DB_PASSWORD
```

`RDS_USER` / `RDS_PASSWORD` are used by PgBouncer when it connects to RDS.

`APP_DB_USER` / `APP_DB_PASSWORD` are used by client applications when they connect to PgBouncer. If these are the same as the RDS credentials, you can point both secret values at the same underlying secret.

## Deploy Manually

Build and push the image:

```bash
aws ecr get-login-password --region <AWS_REGION> \
  | docker login --username AWS --password-stdin <AWS_ACCOUNT_ID>.dkr.ecr.<AWS_REGION>.amazonaws.com

docker build -f ecs/Dockerfile -t <ECR_REPOSITORY>:local ecs
docker tag <ECR_REPOSITORY>:local <AWS_ACCOUNT_ID>.dkr.ecr.<AWS_REGION>.amazonaws.com/<ECR_REPOSITORY>:local
docker push <AWS_ACCOUNT_ID>.dkr.ecr.<AWS_REGION>.amazonaws.com/<ECR_REPOSITORY>:local
```

Register the task definition after replacing placeholders:

```bash
aws ecs register-task-definition --cli-input-json file://ecs/task-definition.rendered.json
```

Create or update the ECS service after replacing placeholders:

```bash
aws ecs create-service --cli-input-json file://ecs/service.rendered.json
```

For existing services:

```bash
aws ecs update-service \
  --cluster <ECS_CLUSTER_NAME> \
  --service pgbouncer \
  --task-definition pgbouncer \
  --force-new-deployment
```

## Deploy with Azure Pipelines

The repository root contains `azure-pipelines.yml`.

Before running it, update these values:

```text
awsRegion
awsAccountId
ecrRepository
ecsClusterName
ecsServiceName
rdsEndpoint
databaseName
appDbUser
```

Also create an Azure DevOps AWS service connection named:

```text
aws-service-connection
```

The pipeline validates the Docker build on pull requests. On `main`, it pushes the image to ECR, registers a new ECS task definition, updates the ECS service, and waits for the service to become stable.

## Application Change

Change the EC2 web application database host from RDS to the internal NLB DNS name:

```text
DB_HOST=<internal-nlb-dns-name>
DB_PORT=6432
DB_NAME=<DATABASE_NAME>
DB_USER=<APP_DB_USER>
DB_PASSWORD=<APP_DB_PASSWORD>
```

## PgBouncer Admin Commands

From a network location that can reach the internal NLB:

```bash
psql -h <internal-nlb-dns-name> -p 6432 -U <APP_DB_USER> -d pgbouncer
```

Then run:

```sql
SHOW POOLS;
SHOW STATS;
SHOW CLIENTS;
SHOW SERVERS;
```
