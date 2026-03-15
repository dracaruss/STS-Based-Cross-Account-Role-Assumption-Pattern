# IAM Cross-Account Role Assumption

In this project, I built the manual cross-account IAM architecture that AWS Identity Center automates under the hood. This was a learning exercise to using trust policies, STS AssumeRole, and least-privilege design. The important thing is that many organizations still use this method to control their organization, so understanding the structure from a granular point of view without Identity Center's ease is imnportant.

## What This Build Actually Does

I created two separate Terraform configurations to simulate a multi-account setup, where security engineers in one AWS account (the "Security" identity account) assume temporary roles into another account (the "Workload" account) to perform audits or respond to incidents.  

In a real enterprise, these would be two completely different AWS accounts. For this lab, I used a single account to host both sides, but the trust policy mechanics are identical to the real world situation.  

**The Workload account creates these roles:**
- `SecurityAuditRole`  
This role has read-only access using the AWS-managed `SecurityAudit` policy. It requires MFA.  
- `IncidentResponderRole`  
This more powerful role has 12 specific API actions for containment (isolate EC2, snapshot volumes, disable compromised keys). It also requires MFA to have been used within the last hour.
##
**The Security account creates these 2 groups:**
- `SecurityEngineers` group  
Members in this group can assume the audit role only.
- `IncidentResponders` group  
Members in this group can assume the IR role only.  
<br>
Both the Workload account and the Security account must agree for access to work. The Workload account trust policy says "I trust this account," and the Security account group policy says "these members can assume that role." Remove either side and the AssumeRole call fails. This is the two-way handshake that governs all cross-account access in AWS.  

## Why I Built This

I wanted to getter a deeper feel of the actual mechanism behind cross-account access, not just how to use Identity Center's portal. Every enterprise uses this pattern in one form or another, and if you only know the portal, you can't troubleshoot when something breaks, or if a particular situation uses another method.  

This also mirrors how security teams actually operate. They're the one department that needs visibility across every account in the org:  
- production
- HR systems  finance
- data platforms
- etc
Compliance frameworks like SOC 2, PCI-DSS, and HIPAA require independent audit capability; the security team doesn't need to ask permission to view and display the current status of an account. That independence is what auditors want to see.. The security team gets read-only trust policies everywhere by design, while HR can only see HR and finance can only see finance.  

## Architecture

```
┌─────────────────────────┐         ┌─────────────────────────┐
│   SECURITY ACCOUNT      │         │   WORKLOAD ACCOUNT      │
│   (Identity Hub)        │         │   (Where infra runs)    │
│                         │         │                         │
│  ┌───────────────────┐  │  STS    │  ┌───────────────────┐  │
│  │ SecurityEngineers │──┼────────>│  │ SecurityAuditRole │  │
│  │ (IAM Group)       │  │ Assume  │  │ (Read-only)       │  │
│  └───────────────────┘  │ Role    │  └───────────────────┘  │
│                         │ + MFA   │                         │
│  ┌───────────────────┐  │         │  ┌───────────────────┐  │
│  │ IncidentResponders│──┼────────>│  │ IncidentResponder │  │
│  │ (IAM Group)       │  │ Assume  │  │ Role (Containment)│  │
│  └───────────────────┘  │ Role    │  └───────────────────┘  │
│                         │ + MFA   │                         │
│                         │ < 1hr   │                         │
└─────────────────────────┘         └─────────────────────────┘
```

## Folder Structure

```
iam-cross-account-access/
├── README.md
├── security-account/
│   ├── main.tf          # Groups and assume-role policies
│   ├── variables.tf     # Workload account ID input
│   ├── outputs.tf       # Group names and account ID
│   └── providers.tf     # AWS provider config
└── workload-account/
    ├── main.tf          # Roles, trust policies, permissions
    ├── variables.tf     # Security account ID input
    ├── outputs.tf       # Role ARNs
    └── providers.tf     # AWS provider config
```

## Deploy

The Workload account needs to be deployed first.  
This is because the roles need to exist here first, before the security account can reference them.

```bash
# Authenticate
aws login

# Bridge credentials for Terraform (aws login stores creds where Terraform can't find them)
eval "$(aws configure export-credentials --format env)"

# Deploy workload account roles
cd workload-account
terraform init
terraform apply -var='security_account_id=YOUR_ACCOUNT_ID'

# Deploy security account groups
cd ../security-account
terraform init
terraform apply -var='workload_account_id=YOUR_ACCOUNT_ID'
```

## Grab the role ARN
Once the infrastructure is finished deploying, grab the ARN of the role:  
<img width="827" height="793" alt="Image" src="https://github.com/user-attachments/assets/d49576d6-72e5-48f6-b505-a62d8fabe302" />

## Next grab the MFA device info 
<img width="761" height="220" alt="Image" src="https://github.com/user-attachments/assets/7ed6b5a5-4dea-4217-b879-060ee77c4f58" />

## Validate
Input the ARN and MFA to get the new Access Keys for the new role.  
```bash
# Assume the audit role (replace with your actual MFA serial and live token code)
aws sts assume-role \
  --role-arn arn:aws:iam::YOUR_ACCOUNT_ID:role/SecurityAuditRole \
  --role-session-name test-session \
  --serial-number arn:aws:iam::YOUR_ACCOUNT_ID:mfa/YOUR_MFA_DEVICE \
  --token-code YOUR_6_DIGIT_CODE
```
<img width="925" height="463" alt="Image" src="https://github.com/user-attachments/assets/06f99452-7ee4-490a-9ca0-b54e1920e666" />

## Export the new Keys as ENV variables to be able to use them to become the new role
```bash
# Export the temporary credentials from the response
export AWS_ACCESS_KEY_ID=ASIA...
export AWS_SECRET_ACCESS_KEY=...
export AWS_SESSION_TOKEN=...
```
<img width="779" height="159" alt="Image" src="https://github.com/user-attachments/assets/f82a7bf0-60fe-4ac5-949a-12761630aa92" />

## Now to verify my new identity
```bash
# Verify you're now operating as the audit role
aws sts get-caller-identity
```
<img width="839" height="140" alt="Image" src="https://github.com/user-attachments/assets/7f65c296-f981-442c-8151-7ee73fe8434f" />

## Both roles are tested and working and can be assumed
<img width="967" height="459" alt="Image" src="https://github.com/user-attachments/assets/9595d6e6-7050-4eee-bf18-ea0b91b5ca8c" />

## Run Prowler to check the environment

I ran Prowler to check the environment as an extra 'hmm' test. It displayed a few failed areas, BUT many of there were CloudTrail and issues that weren't fitting for this lab situation. The one area I did pass which I found critical was the Access Analyzer check,which scans your account for resources that grant access to external entities (other accounts, public access).

## Cleanup after everything is finished

```bash
eval "$(aws configure export-credentials --format env)"
cd workload-account && terraform destroy -var='security_account_id=YOUR_ACCOUNT_ID' -auto-approve
cd ../security-account && terraform destroy -var='workload_account_id=YOUR_ACCOUNT_ID' -auto-approve
```

## Design Decisions and What I Learned

**Managed vs custom policies.**  
> The audit role uses the AWS-managed *SecurityAudit* policy because AWS maintains it as new services launch. The IR role uses a custom inline policy with exactly 12 API actions because there's no managed policy for "isolate a server and take a forensic snapshot." Most teams use a hybrid — managed policies for common patterns, custom policies scoped to specific workflows.

**MFA enforcement differences.**  
> Both roles require MFA, but the incident response role adds *aws:MultiFactorAuthAge < 3600*. In this case MFA must have been used within the last hour. Higher privilege gets tighter verification.

**The `aws login` credential problem.**  
> Terraform's AWS provider doesn't natively read credentials from *aws login*'s browser-based auth flow. The workaround is *eval "$(aws configure export-credentials --format env)"* before every Terraform command. The credentials are still temporary and session-based — nothing long-lived gets written to disk. This was frustrating to figure out but it's worth documenting because anyone using *aws login* with Terraform will hit the same wall.

**Why two directories instead of one.**  
> In production these target different AWS accounts with different credentials. Keeping them separate mirrors reality. The tradeoff is that the deployment order becomes a human responsibility — there's no *depends_on* across directories, which makes it more explicit in this case. In a mature setup you'd use Terragrunt or a CI/CD pipeline with staged jobs to enforce ordering, but for this small test example the 2 builds work well.

## What I'd Do Differently in Production

- Use Terragrunt or a single Terraform config with provider aliases to enforce deployment ordering
- Use GitHub Actions with staged jobs (*needs* keyword) to chain workload → security deployment
- Run Checkov in CI/CD pre-deploy (I did double check everything with IAM Access Analyzer post-deploy)
- Store Terraform state remotely in S3 with DynamoDB locking instead of local state files
- Pull account IDs from SSM Parameter Store or Terraform remote state instead of passing them as *-var* flags

## Tools

- Terraform >= 1.0
- AWS Provider ~> 5.0
- AWS CLI with `aws login` for browser-based auth
- Checkov for static IaC analysis (recommended pre-deploy)

##Mission Accomplished
