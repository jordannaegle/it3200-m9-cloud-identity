# M9: Identity Management and Service Principal Accounts

**Student:** Jordan Naegle  
**Course:** IT3200  
**Testing date:** November 13, 2026

## 1. Architecture

```text
Terraform, run by the provisioning user
    |
    +-- Creates Azure storage resources
    +-- Creates Entra application and service principal
    +-- Assigns container-scoped Azure RBAC role

Application / Azure CLI test client
    |
    | Client ID + temporary client secret + tenant ID
    v
Microsoft Entra ID
    |
    | Authenticates the service principal and issues an access token
    v
Azure Blob Storage
    |
    | Evaluates Azure RBAC permissions for the requested operation
    v
Private reports container
```

The provisioning user and application identity have different purposes.
My personal user deployed the environment. The service principal
authenticated independently and performed the application’s blob tests.

## 2. Infrastructure

Terraform created the following resources:

| Resource | Purpose |
|---|---|
| Resource group | Organizes the lab resources |
| Standard StorageV2 account with LRS | Stores application data |
| Private reports container | Holds the sample report |
| Entra application registration | Defines the application |
| Service principal | Represents the application in the tenant |
| Application password | Provides a temporary authentication credential |
| Azure RBAC assignment | Grants blob access at the container scope |

The storage account was named stit3200jnaeglev2 and deployed in westus3.

Anonymous blob access and Shared Key authentication were disabled.
HTTPS was required, with TLS 1.2 as the minimum version. Terraform used
storage_use_azuread = true for supported storage data APIs.

Variables made the subscription, tenant, location, resource naming, and
container configurable. Outputs exposed resource identifiers; the client
secret output was marked sensitive.

## 3. Identity and Authentication

The application registration describes the application. Its associated
service principal is the identity to which Azure RBAC permissions are
assigned in the tenant.

The application client ID was:
79a44717-8b23-47bf-86ab-dd9d754907bd

The service principal object ID was:
97dcc0d4-f833-4137-90f1-eff8f66aa0f5

The client ID identifies the application during authentication. The
service principal object ID identifies the principal receiving the
Azure RBAC assignment.

For this educational lab, Terraform generated a temporary client secret
with a seven-day expiration. I loaded it into a PowerShell variable
without displaying it and used it with az login --service-principal.

A separate AZURE_CONFIG_DIR isolated the service principal session from
the provisioning user’s session. Identity verification returned
user.type = servicePrincipal.

Authentication proves identity. It does not automatically authorize
access to storage resources.

## 4. Authorization and Least Privilege

I assigned Storage Blob Data Contributor to the service principal at:

/subscriptions/8ea0e696-6adb-42ea-ad51-49187c07d50f/resourceGroups/rg-uvu-it3200-jordan/providers/Microsoft.Storage/storageAccounts/stit3200jnaeglev2/blobServices/default/containers/reports

This role supports listing, uploading, and downloading blobs. It also
permits deletion, so it provides more operations than an upload/download
only custom role would provide.

Container scope limits the assignment to the application’s required
container. The service principal received no subscription-wide Owner or
Contributor assignment.

Reader provides management-plane visibility rather than blob data read
access. Storage Blob Data Reader supports reading and listing but not
uploading. Storage Blob Data Owner provides additional privileges,
including POSIX access control management, that this application did
not require.

Storage Blob Data Contributor was the suitable built-in role among the
roles investigated. For a production application prohibited from deleting
data, I would evaluate a custom role that excludes deletion.

## 5. Authentication and Authorization Testing

Before assigning permissions, I queried the service principal’s RBAC
assignments at the container scope, including inherited assignments.
The result was an empty list: [].

I then authenticated as the service principal and confirmed that its
client ID appeared with identity type servicePrincipal.

All blob commands used --auth-mode login to use Microsoft Entra
credentials rather than storage account keys.

| Test | Expected | Actual Result |
|---|---|---|
| Authenticate as service principal | Success | Successful login; identity type was servicePrincipal |
| List blobs before RBAC assignment | Denied | Storage returned an insufficient-permissions message |
| Upload blob after RBAC assignment | Success | sample-report.txt uploaded successfully |
| List blobs after RBAC assignment | Success | sample-report.txt appeared with a size of 53 bytes |
| Download blob after RBAC assignment | Success | File downloaded as downloaded-report.txt |
| Verify downloaded contents | Match | Original message was present; SHA-256 hash comparison returned True |
| Read resource group details | Denied | Management API returned AuthorizationFailed |

The test file contained:

IT3200 M9: uploaded using the service principal.

The successful login followed by denied blob access before RBAC
demonstrated that authentication and authorization are separate checks.

After the container-scoped role assignment, upload, list, and download
operations succeeded. The matching file hashes verified that the
downloaded file was identical to the uploaded file.

For the negative test after RBAC, I attempted to read resource group
details, which is outside the assigned container-level permissions.

The initial az group show and az rest attempts stopped at Azure CLI
subscription lookup errors. Those messages alone did not demonstrate an
authorization decision by the management API.

To obtain direct evidence, I acquired a management access token for the
service principal’s tenant and sent a read-only request using
Invoke-RestMethod. Azure returned AuthorizationFailed for:

Microsoft.Resources/subscriptions/resourcegroups/read

The response identified the tested application client ID and service
principal object ID. This confirmed that the application could perform
its required blob operations while the unrelated management operation
remained restricted.

Screenshots in the screenshots directory document deployment, identity,
RBAC scope, denied access, successful blob operations, file verification,
and cleanup.

## 6. Troubleshooting and Security Investigation

### Scenario A: Authentication Works, Storage Access Fails

**Possible causes:** The service principal may lack a blob data role,
have the wrong role, or have an assignment at the wrong scope. Other
possibilities include role propagation delay, the wrong active identity,
storage network restrictions, or using key authentication when Shared
Key access is disabled.

**Investigation:** First, confirm the active identity:

```powershell
az account show --query "{Identity:user.name,Type:user.type,Tenant:tenantId}" --output table
```

Then use the provisioning account to inspect the service principal’s
role assignments at the target container, including inherited roles:

```powershell
az role assignment list --assignee-object-id <SP_OBJECT_ID> --scope <CONTAINER_RESOURCE_ID> --include-inherited --fill-principal-name false --output json
```

Check that the principal ID matches the intended service principal,
the role includes the required blob data operations, and the scope
contains the target container. Confirm the storage command uses
--auth-mode login.

Record the storage error code and request ID. If necessary, review
storage diagnostic logs when enabled and available. Check network
restrictions separately from RBAC.

**Root cause identification:** A successful sign-in establishes that
authentication worked. An absent or incorrect data role explains a
subsequent authorization denial. If the role was just assigned, allow
for propagation and refresh the test login before concluding that the
role is wrong.

**Resolution:** Correct the role or scope through Terraform. In this
lab, assigning Storage Blob Data Contributor on reports resolved the
blob access denial. Do not grant subscription Owner merely to make
the test pass.

**Prevention:** Keep RBAC in version control, review Terraform plans,
and test both required operations and an operation outside the scope.

### Scenario D: Access Stops Because a Client Secret Expired

This scenario is an investigation plan rather than an observed lab
failure.

**Possible causes:** The secret may have expired, been deleted, or been
rotated without updating the application. A wrong secret value, client
ID, or tenant ID can also prevent authentication.

**Investigation:** Capture the sign-in error code, timestamp, and
correlation ID without recording credentials. Review service principal
sign-in logs if available and permitted.

Using an appropriately authorized provisioning account, inspect
credential metadata:

```powershell
az ad app credential list --id <APPLICATION_CLIENT_ID> --query "[].{Name:displayName,Expires:endDateTime}" --output table
```

Compare the relevant expiration time with the failure time in UTC.
Confirm that the application uses the secret value, not its credential
identifier, and the expected client and tenant IDs.

**Root cause identification:** AADSTS7000222 specifically indicates
expired client secret keys. An unexpired credential in the list does
not prove that the application is using that credential; check the
application’s configured credential version.

**Resolution:** Create a replacement credential through the managed
deployment process and securely update the application. Verify a fresh
login and successful blob operations, then remove the obsolete
credential after the replacement is confirmed.

In this lab configuration, expiration is fixed at creation and later
end_date changes are ignored. Routine terraform apply does not renew
the secret; rotation requires an intentional replacement.

**Prevention:** Track credential ownership and expiration, rotate before
expiry, and test rotation. For suitable production workloads, use
managed identity or workload identity federation to reduce reliance on
stored client secrets.

### References for These Investigations

- [Blob authorization with Entra ID](https://learn.microsoft.com/en-us/azure/storage/blobs/authorize-access-azure-active-directory)
- [Azure CLI credential metadata commands](https://learn.microsoft.com/en-us/cli/azure/ad/app/credential)
- [Microsoft Entra error codes, including AADSTS7000222](https://learn.microsoft.com/en-us/entra/identity-platform/reference-error-codes)

## 7. Security and Production Improvements

The application used its own identity rather than my personal account.
Its RBAC assignment was limited to the reports container. Shared Key
authentication and anonymous blob access were disabled.

The temporary secret was hidden in normal Terraform output and loaded
into a PowerShell variable without printing it. However, sensitive
outputs do not prevent credentials from being stored in Terraform state.
State files, backups, and local variable files were excluded from Git.

For production, I would evaluate managed identity for an Azure-hosted
application or workload identity federation for a suitable external
workload. I would also protect remote Terraform state with appropriate
access controls, establish identity ownership and monitoring, and
automate permission tests.

Because Storage Blob Data Contributor includes deletion, a custom role
could further restrict permissions if the application must only upload,
list, and download.

For an organization with 500 applications, I would use separate
identities where appropriate, reusable Terraform modules, narrowly
scoped role assignments, ownership records, and regular access reviews.
Automated tests would verify both permitted and denied operations.
Credential rotation and application retirement would be managed as
part of each identity’s lifecycle.

## 8. Cleanup and Cost Control

After completing the tests and saving screenshots, I ran
terraform plan -destroy and reviewed the seven planned deletions.

Terraform destroy completed with:

Destroy complete! Resources: 7 destroyed.

This removed the personal lab’s storage resources, application identity,
temporary secret, and RBAC assignment. Local source files and evidence
were retained.

I configured a $2.50 spending alert on the personal subscription.
A budget alert is a notification rather than an automatic spending cap.

## 9. AI Assistance and Verification

I used ChatGPT for step-by-step guidance on Terraform syntax, Entra
identity concepts, RBAC scope, credential handling, testing, and
troubleshooting.


- “Can you explain service principle account rules to me and why this
  is happening?”


Recommendations included separating the provisioning user from the
application identity, using container-scoped RBAC, testing access before
and after assignment, and excluding sensitive Terraform files from Git.

I checked the guidance against Terraform validation and plans, provider
warnings, Azure deployment output, identity verification, role assignment
inspection, blob operation results, and a denied management request.
Deprecated arguments suggested during the process were corrected.

## 10. Personal Reflection

I learned about application identity in this assignment. By setting up a service principal I learned about authentication vs authorization. Authentication determines who someone is and authorization determines what that person is allowed to do. Having roles and scopes to permissions allows things to be very specific per user/application. These are important in the real world because as an administrator you want to decrease the likelihood of an application or user changing something it shouldn't. The change could be malicious or even just accidental but having scoped permissions reduces the chances that something bad even can happen in the first place. At first I tried to use my UVU account but that did not allow me to setup the service principal so I had to create a personal Azure account. It also took a few tried even with the help of AI to figure out how to troubleshoot CLI subscription errors. 