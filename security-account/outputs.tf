output "security_account_id" {
  description = "The AWS Account ID of this Security account"
  value       = data.aws_caller_identity.current.account_id
}


output "security_engineers_group_name" {
  description = "Name of the SecurityEngineers IAM group"
  value       = aws_iam_group.security_engineers.name
}


output "incident_responders_group_name" {
  description = "Name of the IncidentResponders IAM group"
  value       = aws_iam_group.incident_responders.name
}
