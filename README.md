# HeliumHealth DevOps Assessment

A containerized Node.js API deployed to Kubernetes, with GitHub Actions for continuous integration, Amazon ECR for container image storage, and Terraform for infrastructure management.

This repository contains the application, continous delivery pipeline, Kubernetes manifests, and Terraform modules used to support the deployment.

---

## Table of Contents

1. [Overview](https://www.google.com/search?q=%23overview)
2. [Architecture](https://www.google.com/search?q=%23architecture)
3. [Repository Structure](https://www.google.com/search?q=%23repository-structure)
4. [Prerequisites](https://www.google.com/search?q=%23prerequisites)
5. [Configuration and Secrets](https://www.google.com/search?q=%23configuration-and-secrets)
6. [GitHub Actions CI/CD Pipeline](https://www.google.com/search?q=%23github-actions-cicd-pipeline)
7. [AWS OIDC Authentication](https://www.google.com/search?q=%23aws-oidc-authentication)
8. [Container Image Management](https://www.google.com/search?q=%23container-image-management)
9. [Deploying to Kubernetes](https://www.google.com/search?q=%23deploying-to-kubernetes)
10. [Network Policy and Security](https://www.google.com/search?q=%23network-policy-and-security)
11. [Terraform Infrastructure](https://www.google.com/search?q=%23terraform-infrastructure)
12. [Migrating Existing Resources into Terraform State](https://www.google.com/search?q=%23migrating-existing-resources-into-terraform-state)

---

## Overview

The project demonstrates a delivery workflow for a Node.js API with automated quality checks, container vulnerability scanning, and deployment-ready Kubernetes resources.

### Main Components

* **Node.js**: API application running on port `8001`.
* **Docker**: Packages the application into a container image.
* **GitHub Actions**: Automates linting, testing, building, and vulnerability scanning.
* **AWS IAM OIDC federation**: Allows GitHub Actions to obtain temporary AWS credentials without storing long-lived AWS access keys in GitHub Secrets.
* **Amazon ECR**: Stores versioned container images.
* **Kubernetes**: Runs the application with two replicas, health probes, resource constraints, and network restrictions.
* **Terraform**: Organizes infrastructure provisioning into reusable modules, including ECR and S3 bucket resources.

The CI workflow publishes container images to ECR after a successful push to the `main` branch. Kubernetes deployment is a separate operational step in the current workflow.

---

## Architecture

```text
Developer
    |
    | Push / Pull Request
    v
GitHub Repository
    |
    v
GitHub Actions
    |
    +--> Install dependencies
    +--> Lint and test
    +--> Authenticate to AWS using OIDC
    +--> Build Docker image
    +--> Scan image with Trivy
    |
    +--> Push to Amazon ECR (push to main only)
              |
              v
       Amazon ECR
              |
              | Image pull
              v
       Kubernetes Cluster
              |
              v
       HH Demo API Pods (2 replicas, port 8001)
              |
              v
       Kubernetes Service
              |
              v
       Ingress Controller
              |
              v
       api.heliumhealth.com

```

*Note: The diagram represents the intended traffic flow. The actual public routing depends on the installed ingress controller and its associated load balancer configuration.*

---

## Repository Structure

```text
.
├── .github/
│   └── workflows/
│       └── ci.yml
├── app/
│   └── index.js
├── kubernetes/
│   ├── configmap.yaml
│   ├── deployment.yaml
│   ├── ingress.yaml
│   ├── namespace.yaml
│   ├── networkpolicy.yaml
│   ├── secrets.yaml
│   ├── service.yaml
│   └── serviceaccount.yaml
├── terraform/
│   ├── main.tf
│   ├── providers.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── modules/
│       ├── ecr/
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       └── s3_bucket/
│           ├── main.tf
│           ├── variables.tf
│           └── outputs.tf
├── Dockerfile
├── package.json
└── README.md

```

---

## Prerequisites

Before running the pipeline or deploying the application, ensure the following are available:

* A GitHub repository with Actions enabled.
* Node.js 22 and npm for local development.
* Docker for building the container image locally.
* An AWS account with an ECR repository and an IAM role configured for GitHub OIDC.
* A Kubernetes cluster with a working `kubectl` context.
* An ingress controller compatible with the chosen Ingress configuration.
* Terraform installed if you intend to manage infrastructure through Terraform.
* Appropriate permissions to manage the relevant AWS and Kubernetes resources.

The AWS region, AWS account ID, role ARN, and container image reference must be configured for the target environment.

---

## Configuration and Secrets

### GitHub Actions Repository Configuration

Configure the following repository-level variables and secrets under **Settings** → **Secrets and variables** → **Actions**.

| Name | Type | Purpose |
| --- | --- | --- |
| `AWS_REGION` | Variable | AWS region containing the ECR repository. |
| `AWS_ROLE_ARN` | Secret | ARN of the IAM role assumed by GitHub Actions. |
| `AWS_ACCOUNT_ID` | Secret | AWS account ID used to construct the ECR registry hostname. |

The workflow constructs the registry hostname using this format:

```text
<ACCOUNT_ID>.dkr.ecr.<REGION>.amazonaws.com

```

The workflow uses GitHub's OIDC identity to authenticate to AWS. It does not require static `AWS_ACCESS_KEY_ID` or `AWS_SECRET_ACCESS_KEY` credentials.

### Application Configuration

The ConfigMap supplies non-sensitive configuration to the application:

| Variable | Example Purpose |
| --- | --- |
| `NODE_ENV` | `production` — Application runtime environment. |
| `PORT` | `8001` — Application listening port. |
| `LOG_LEVEL` | `info` — Logging verbosity. |

Sensitive values are referenced through the `hh-demo-api-secret` Kubernetes Secret.

---

## GitHub Actions CI/CD Pipeline

The workflow is triggered by pull requests targeting `main` and pushes to `main`.

### Pipeline Triggers

| Event | Lint and Test | Build and Scan | Push to ECR |
| --- | --- | --- | --- |
| **Pull request to main** | Yes | Yes, if lint and test succeed | No |
| **Push to main** | Yes | Yes, if lint and test succeed | Yes, if scanning succeeds |

*The workflow does not currently deploy Kubernetes manifests automatically.*

### Stage 1: Lint and test

The `lint-and-test` job runs on `ubuntu-latest`. It performs the following steps:

1. Checks out the repository.
2. Sets up Node.js 22.
3. Configures npm caching.
4. Installs dependencies using `npm ci`.
5. Runs the linter using `npm run lint`.
6. Runs tests using `npm test --if-present`.

The `build-scan-push` job depends on this job through `needs: lint-and-test`, so it will not run if linting or testing fails.

### Stage 2: AWS authentication and ECR login

The workflow authenticates to AWS through GitHub OIDC and then logs in to Amazon ECR.

### Stage 3: Build the container image

Docker Buildx builds the image from the repository root:

* **Context**: `.`
* **Load**: `true`
* **Tags**: `<ECR_REGISTRY>/hh-demo-api:<GIT_COMMIT_SHA>`

The image is tagged with `${{ github.sha }}`, providing a unique identifier associated with the triggering commit. GitHub Actions caching is used to reduce build times on subsequent runs.

### Stage 4: Scan the image with Trivy

Trivy scans the built image for operating system and application-library vulnerabilities.

* **Vulnerability types**: `os,library`
* **Severity levels**: `CRITICAL,HIGH`
* **Unfixed vulnerabilities**: ignored
* **Exit code**: `1` when a matching vulnerability is detected

A scan failure stops the job and prevents the subsequent image push.

### Stage 5: Push the image to ECR

The image is pushed only when the following condition is satisfied:

```yaml
if: github.event_name == 'push' && github.ref == 'refs/heads/main'

```

Two tags are published:

* `<ECR_REGISTRY>/hh-demo-api:<GIT_COMMIT_SHA>`
* `<ECR_REGISTRY>/hh-demo-api:latest`

### How to Trigger the CI Pipeline

* **Option 1: Open a pull request** — Create a feature branch, make changes, push to GitHub, and open a PR targeting `main`.
* **Option 2: Push directly to main** — Run standard git workflow commands (`git push origin main`).
* **Option 3: Rerun an existing workflow** — Use the GitHub Actions tab UI to re-run jobs.

---

## AWS OIDC Authentication

### Why use OIDC?

GitHub Actions needs AWS permissions to authenticate to ECR, obtain an authorization token, and push container images. Instead of storing permanent AWS access keys in GitHub Secrets, the workflow uses OpenID Connect (OIDC) federation to obtain temporary AWS credentials.

### Authentication Flow Diagram

```text
GitHub Actions Job
       |
       | Request GitHub OIDC token
       v
GitHub OIDC Provider
       |
       | Exchange token
       v
AWS STS
       |
       | Validate IAM trust policy
       v
Assumed IAM Role
       |
       | Temporary AWS credentials
       v
Amazon ECR
       |
       | Push approved image
       v
hh-demo-api:<commit-sha>

```

### AWS Configuration Requirements

Before the workflow can authenticate successfully, configure the following in AWS:

* An IAM OIDC identity provider for `token.actions.githubusercontent.com`.
* An IAM role with a trust policy that allows the intended GitHub repository and branch or environment.
* A trust policy with appropriate audience and subject restrictions, typically using `sts.amazonaws.com` as the audience.
* An IAM permissions policy granting only the ECR actions required by the workflow.
* An existing ECR repository named `hh-demo-api`.

---

## Container Image Management

The Kubernetes Deployment currently references:

```yaml
image: <ACCOUNT_ID>.dkr.ecr.<REGION>.amazonaws.com/hh-demo-api:latest

```

Replace the placeholders with the actual AWS account ID and region. For a more controlled release process, consider deploying the immutable commit tag generated by CI:

```yaml
image: <ACCOUNT_ID>.dkr.ecr.<REGION>.amazonaws.com/hh-demo-api:<GIT_COMMIT_SHA>

```

---

## Deploying to Kubernetes

### 1. Confirm cluster access

```bash
kubectl config current-context
kubectl cluster-info

```

### 2. Configure the image reference

Update `kubernetes/deployment.yaml` to reference the correct ECR registry and image tag.

### 3. Configure application secrets

Review `kubernetes/secrets.yaml` before applying the manifests. Do not apply example credentials or placeholder values to a production environment.

### 4. Apply the manifests

First, create the namespace:

```bash
kubectl apply -f kubernetes/namespace.yaml

```

Then apply the remaining resources:

```bash
kubectl apply -f kubernetes/

```

### 5. Verify the rollout

```bash
kubectl -n hh-demo-api get deployments
kubectl -n hh-demo-api rollout status deployment/hh-demo-api
kubectl -n hh-demo-api get pods -o wide
kubectl -n hh-demo-api get services
kubectl -n hh-demo-api get ingress

```

### 6. Test application connectivity

```bash
kubectl -n hh-demo-api port-forward service/hh-demo-api-service 8080:80

```

In another terminal:

```bash
curl -i http://localhost:8080/health

```

---

## Network Policy and Security

The `hh-demo-api-network-policy` NetworkPolicy selects pods labeled `app: hh-demo-api` in its own namespace.

### Intended Access Rules

* **Ingress**: Permit TCP port `8001` from pods in the `ingress-nginx` namespace and from pods in the same namespace.
* **DNS egress**: Permit UDP and TCP port `53`.
* **HTTPS egress**: Permit TCP port `443` to IPv4 destinations in `0.0.0.0/0`.
* **Other traffic**: Deny traffic in an isolated direction unless permitted.

---

## Terraform Infrastructure

Terraform is organized around a root module and reusable child modules.

### Directory Responsibilities

| Path | Responsibility |
| --- | --- |
| `terraform/main.tf` | Composes infrastructure modules and root-level resources. |
| `terraform/providers.tf` | Configures Terraform providers and AWS access. |
| `terraform/variables.tf` | Declares configurable infrastructure inputs. |
| `terraform/outputs.tf` | Exposes useful resource attributes. |
| `terraform/modules/ecr/` | Defines ECR resources and inputs/outputs. |
| `terraform/modules/s3_bucket/` | Defines S3 bucket resources and inputs/outputs. |

### Initialize and Validate Terraform

```bash
cd terraform
terraform init
terraform fmt -check -recursive
terraform validate
terraform plan -out=tfplan
terraform show tfplan
terraform apply tfplan

```

---

## Migrating Existing Resources into Terraform State

When an AWS resource already exists because it was created manually, you can bring it under Terraform management by importing it rather than recreating it:

1. **Identify the existing resource**: Confirm its AWS account, region, resource identifier, configuration, and dependencies.
2. **Back up the Terraform state**: Take a secure backup before making changes.
3. **Write the corresponding Terraform configuration**: Match the existing resource's settings as closely as possible.
4. **Import the existing resource**: Use an import block or CLI command.

Example CLI import:

```bash
terraform import \
  'module.s3_bucket.aws_s3_bucket.this' \
  'existing-bucket-name'

```
