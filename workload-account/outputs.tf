output "security_audit_role_arn" {
  description = "ARN of the SecurityAuditRole — give this to security team"
  value       = aws_iam_role.security_audit_role.arn
}


output "incident_responder_role_arn" {
  description = "ARN of the IncidentResponderRole"
  value       = aws_iam_role.incident_responder_role.arn
}
