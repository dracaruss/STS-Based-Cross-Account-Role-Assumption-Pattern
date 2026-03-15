# ─────────────────────────────────────────────────────────────
# DATA: Get current account info
# ─────────────────────────────────────────────────────────────
data "aws_caller_identity" "current" {}


# ─────────────────────────────────────────────────────────────
# IAM ROLE: SecurityAuditRole
# This role can be assumed by users in the Security account.
# It grants READ-ONLY access for security auditing.
# ─────────────────────────────────────────────────────────────
resource "aws_iam_role" "security_audit_role" {
  name = "SecurityAuditRole"


  # TRUST POLICY: Who can assume this role?
  # Only the Security account, and only with MFA.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.security_account_id}:root"
        }
        Action = "sts:AssumeRole"
        Condition = {
          Bool = {
            "aws:MultiFactorAuthPresent" = "true"
          }
        }
      }
    ]
  })


  tags = {
    Project     = "cloud-security-portfolio"
    Environment = "lab"
    Purpose     = "cross-account-security-audit"
  }
}


# ─────────────────────────────────────────────────────────────
# ATTACH POLICY: SecurityAudit (AWS Managed - read only)
# This gives the role read access to security configurations
# but cannot modify anything.
# ─────────────────────────────────────────────────────────────
resource "aws_iam_role_policy_attachment" "security_audit" {
  role       = aws_iam_role.security_audit_role.name
  policy_arn = "arn:aws:iam::aws:policy/SecurityAudit"
}


# ─────────────────────────────────────────────────────────────
# IAM ROLE: IncidentResponderRole
# Higher privilege role for incident response.
# Can isolate EC2 instances and take forensic snapshots.
# ─────────────────────────────────────────────────────────────
resource "aws_iam_role" "incident_responder_role" {
  name = "IncidentResponderRole"


  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.security_account_id}:root"
        }
        Action = "sts:AssumeRole"
        Condition = {
          Bool = {
            "aws:MultiFactorAuthPresent" = "true"
          }
          NumericLessThan = {
            "aws:MultiFactorAuthAge" = "3600" # MFA must be < 1 hour old
          }
        }
      }
    ]
  })


  tags = {
    Project = "cloud-security-portfolio"
    Purpose = "incident-response"
  }
}


# Custom policy: Only the actions needed for incident containment
resource "aws_iam_role_policy" "incident_responder_policy" {
  name = "IncidentResponderPolicy"
  role = aws_iam_role.incident_responder_role.id


  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "IsolateEC2"
        Effect = "Allow"
        Action = [
          "ec2:ModifyInstanceAttribute",
          "ec2:CreateSecurityGroup",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:DescribeInstances",
          "ec2:DescribeSecurityGroups"
        ]
        Resource = "*"
      },
      {
        Sid    = "ForensicSnapshots"
        Effect = "Allow"
        Action = [
          "ec2:CreateSnapshot",
          "ec2:DescribeVolumes",
          "ec2:DescribeSnapshots",
          "ec2:CreateTags"
        ]
        Resource = "*"
      },
      {
        Sid    = "DisableCompromisedKeys"
        Effect = "Allow"
        Action = [
          "iam:UpdateAccessKey",
          "iam:ListAccessKeys"
        ]
        Resource = "*"
      }
    ]
  })
}
