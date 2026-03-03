# Multi-Region Serverless Infrastructure with Terraform

[![Terraform](https://img.shields.io/badge/terraform-%235835CC.svg?style=for-the-badge&logo=terraform&logoColor=white)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-%23FF9900.svg?style=for-the-badge&logo=amazon-aws&logoColor=white)](https://aws.amazon.com/)

This repository provides a production-grade Infrastructure as Code (IaC) solution for deploying a multi-region serverless application on AWS. It demonstrates advanced Terraform techniques, including module composition and provider aliasing.

## 🏗️ Architecture Overview

The stack is designed for high availability and modularity:
- **Identity Layer:** Amazon Cognito (Centralized in US)
- **Compute Layer:** AWS Lambda (Regional)
- **Entry Point:** Amazon API Gateway (Regional)
- **Testing:** Automated Python-based integration suite

### Repository Structure
```text
.
├── main.tf                 # Module orchestration
├── providers.tf            # Multi-region provider aliases
├── versions.tf             # Terraform & Provider constraints
├── variables.tf            # Global input variables
├── outputs.tf              # Cross-region outputs for CI/CD
├── modules/
│   ├── cognito/            # Global Auth logic
│   │   ├── main.tf
│   │   └── outputs.tf
│   └── compute/            # Regional API logic
│       ├── main.tf
│       ├── lambda_greeter/    # Python source
│       └── lambda_dispatcher/ # Python source
└── test_apis.py            # Integration test suite
```

## 🛠️ Infrastructure Design

### 1. Global Identity Module (Cognito)
The `cognito` module is pinned to **us-east-1**. It provisions the User Pool and Client ID required for the authentication handshake.

### 2. Regional Compute Module
The `compute` module is instantiated twice using **Provider Aliases**. This creates two identical but independent stacks in **us-east-1** and **eu-west-1**, demonstrating a true multi-region failover architecture.

### Example of multi-region call in main.tf

```
module "compute_eu" {
  source    = "./modules/compute"
  providers = { 
    aws = aws.eu_west_1 
  }
```

## 🚀 Deployment Guide

### Prerequisites
* **Terraform:** `v1.14.6+`
* **AWS CLI:** Configured with appropriate IAM permissions.

### Sensitive Data Management
This project uses **zero hardcoded secrets**. Ensure the following variables are available via a `.tfvars` file or environment variables:
* `email`
* `repo_url`
* `cognito_user_password`
* `sns_topic_arn`

### Manual Steps
1. **Initialize**: `terraform init`
2. **Plan**: `terraform plan -out=tfplan`
3. **Apply**: `terraform apply tfplan`

---

## 🧪 Integration Testing
The `test_apis.py` script validates the end-to-end flow:

1. **Authenticates** against Cognito to retrieve a JWT ID Token.
2. **Dynamically discovers** regional endpoints.
3. **Executes and validates** responses from both US and EU regional APIs.



**Run tests locally:**

```bash
# Install dependencies
pip install boto3 httpx

# Set environment variables from Terraform outputs
export COGNITO_USER_POOL_ID=$(terraform output -raw cognito_user_pool_id)
export COGNITO_CLIENT_ID=$(terraform output -raw cognito_user_pool_client_id)
export API_ENDPOINT_EU=$(terraform output -raw api_endpoint_eu)
export API_ENDPOINT_US=$(terraform output -raw api_endpoint_us)

# Execute the test suite
python3 test_apis.py
```

## 🤖 CI/CD (GitHub Actions)

The included workflow automates the entire lifecycle.

### ⚠️ Important Note on GitHub Actions
If using `hashicorp/setup-terraform`, ensure the **wrapper is disabled** to prevent Terraform output pollution when capturing variables:

```yaml
- uses: hashicorp/setup-terraform@v3
  with:
    terraform_wrapper: false
```

Ensure the following are set in your GitHub Repository Secrets:

* `AWS_ACCESS_KEY_ID`
* `AWS_SECRET_ACCESS_KEY`
* `COGNITO_USER_PASSWORD`
* `SNS_TOPIC_ARN`
* `EMAIL`
* `REPO_URL`


## 🧹 Cleanup

To avoid unnecessary AWS costs, destroy the infrastructure when finished:

```bash
terraform destroy -auto-approve
