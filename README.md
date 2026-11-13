# IT3200 M9: Cloud Identity and Access Management

This project uses Terraform to deploy private Azure Blob Storage, an
application registration, a service principal, and a container-scoped
RBAC assignment.

The deployment and access tests were completed successfully. The live
resources were subsequently destroyed to limit costs.

## Architecture

Service principal → Microsoft Entra authentication → Azure RBAC →
private reports container

The personal user provisions the environment. The application uses its
own service principal identity for blob operations.

## Project Files

| File | Purpose |
|---|---|
| providers.tf | Provider versions, tenant selection, and authentication settings |
| variables.tf | Configurable inputs |
| main.tf | Resource group, storage account, and private container |
| identity.tf | Application registration, service principal, and temporary secret |
| rbac.tf | Container-scoped Storage Blob Data Contributor assignment |
| outputs.tf | Resource identifiers and a sensitive credential output |
| terraform.tfvars.example | Example configuration |
| screenshots/ | Deployment and test evidence |

## Prerequisites

- Terraform 1.5 or later, below version 2.0
- Azure CLI and Git
- An Azure subscription with resource creation permissions
- Permission to register Entra applications and create service principals
- Permission to create Azure RBAC role assignments

The tested providers are AzureRM 4.81.0 and AzureAD 3.10.0.

## Configure

Sign in with the user account that will provision the environment:

```powershell
az login
Copy-Item terraform.tfvars.example terraform.tfvars
```

Edit terraform.tfvars with your subscription ID, tenant ID, an allowed
region, and a globally unique storage account name.

The local terraform.tfvars file is excluded from Git.

## Deploy in Two Stages

First, temporarily exclude the RBAC configuration so the service
principal can be tested without blob permissions:

```powershell
Rename-Item rbac.tf rbac.tf.disabled
terraform init
terraform fmt
terraform validate
terraform plan
terraform apply
```

Record successful service principal authentication and denied blob
access before granting permissions.

Then restore and deploy the RBAC configuration:

```powershell
Rename-Item rbac.tf.disabled rbac.tf
terraform plan
terraform apply
```

The role assignment may require time to propagate.

## Authentication and Testing

Use a separate PowerShell window with a separate AZURE_CONFIG_DIR for
service principal testing. Keep the provisioning user's CLI session
available for Terraform.

Load the client ID, tenant ID, and client secret from Terraform outputs
into PowerShell variables. Do not print the secret.

Sign in using az login --service-principal with the client ID, secret,
tenant ID, and --allow-no-subscriptions.

Use --auth-mode login for all blob tests.

The completed tests demonstrated:

| Test | Actual Result |
|---|---|
| Authenticate as service principal | Success |
| List blobs before RBAC | Denied |
| Upload after RBAC | Success |
| List and download after RBAC | Success |
| Compare original and downloaded file hashes | Match |
| Read resource group through the management API | AuthorizationFailed |

The management denial was captured using Invoke-RestMethod with a
tenant-issued management token because Azure CLI subscription discovery
prevented the initial management commands from reaching the API.

## Security Decisions

- Anonymous blob access is disabled.
- The container is private.
- HTTPS and TLS 1.2 are required.
- Shared Key authentication is disabled.
- Terraform uses Entra authentication for supported storage data APIs.
- The application receives Storage Blob Data Contributor only on reports.
- The role also permits deletion; a custom role could further restrict
  operations if deletion were prohibited.
- The temporary client secret expires seven days after creation.
- State, backup state, credentials, and local variable files are excluded
  from Git.

Sensitive Terraform outputs hide normal terminal display but do not
encrypt or remove secrets from state. Protect local state and backups.

## Cleanup

After saving evidence, use the provisioning user's PowerShell window:

```powershell
terraform plan -destroy
terraform destroy
```

The completed lab cleanup removed seven managed resources.

## 11. GitHub Repository

Terraform configuration, deployment instructions, and screenshots:

https://github.com/jordannaegle/it3200-m9-cloud-identity