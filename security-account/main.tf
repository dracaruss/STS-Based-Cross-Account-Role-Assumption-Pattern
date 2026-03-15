data "aws_caller_identity" "current" {}


# ─────────────────────────────────────────────────────────────
# IAM GROUP: SecurityEngineers
# Members of this group can assume the audit role in workload accounts
# ─────────────────────────────────────────────────────────────
resource "aws_iam_group" "security_engineers" {
  name = "SecurityEngineers"
}


resource "aws_iam_group_policy" "assume_audit_role" {
  name  = "AssumeSecurityAuditRole"
  group = aws_iam_group.security_engineers.name


  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowAssumeAuditRole"
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Resource = [
          "arn:aws:iam::${var.workload_account_id}:role/SecurityAuditRole"
        ]
        Condition = {
          Bool = {
            "aws:MultiFactorAuthPresent" = "true"
          }
        }
      }
    ]
  })
}


# ─────────────────────────────────────────────────────────────
# IAM GROUP: IncidentResponders
# Separate group with higher privilege assumption rights
# ─────────────────────────────────────────────────────────────
resource "aws_iam_group" "incident_responders" {
  name = "IncidentResponders"
}


resource "aws_iam_group_policy" "assume_ir_role" {
  name  = "AssumeIncidentResponderRole"
  group = aws_iam_group.incident_responders.name


  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowAssumeIRRole"
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Resource = [
          "arn:aws:iam::${var.workload_account_id}:role/IncidentResponderRole"
        ]
      }
    ]
  })
}
