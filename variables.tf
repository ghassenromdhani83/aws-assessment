variable "email" {
  type = string
}

variable "repo_url" {
  type = string
}

variable "cognito_user_password" {
  description = "Permanent password for the Cognito user"
  type        = string
  sensitive   = true
}

variable "sns_topic_arn" {
  description = "The SNS topic used by Unleash live"
  type        = string
}
