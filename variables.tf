variable "email" {
  type    = string
  default = "ghassen.cherni@gmail.com"
}

variable "repo_url" {
  type    = string
  default = "https://github.com/ghassenromdhani83/aws-assessment"
}

variable "cognito_user_password" {
  description = "Permanent password for the Cognito user"
  default     = "YourSecurePassword123!"
  type        = string
  sensitive   = true
}

variable "sns_topic_arn" {
  description = "The SNS topic used by Unleash live"
  default     = "arn:aws:sns:us-east-1:263274769945:sns-test"
  type        = string
}
