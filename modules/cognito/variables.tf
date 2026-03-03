variable "cognito_user" {
  description = "Cognito username/email to create"
  type        = string
}

variable "cognito_user_password" {
  description = "Permanent password for the Cognito user"
  type        = string
  sensitive   = true
}
