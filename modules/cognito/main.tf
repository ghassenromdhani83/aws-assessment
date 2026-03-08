########################################
# COGNITO USER POOL
########################################
resource "aws_cognito_user_pool" "user_pool" {
  name = "test-user-pool"

  auto_verified_attributes = ["email"]

  password_policy {
    minimum_length                   = 8
    require_lowercase                = true
    require_numbers                  = true
    require_symbols                  = false
    require_uppercase                = true
    temporary_password_validity_days = 7
  }

  username_attributes = ["email"]

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  admin_create_user_config {
    allow_admin_create_user_only = false
  }
}

########################################
# COGNITO USER POOL CLIENT
########################################
resource "aws_cognito_user_pool_client" "user_pool_client" {
  name            = "test-user-pool-client"
  user_pool_id    = aws_cognito_user_pool.user_pool.id
  generate_secret = false

  explicit_auth_flows = [
    "ALLOW_ADMIN_USER_PASSWORD_AUTH", // required for admin initiate auth
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_SRP_AUTH"
  ]

  prevent_user_existence_errors = "ENABLED"
}

/* 
  The configuration below automates Cognito user creation for the assessment.
  - Creates a user programmatically (no manual intervention required)
  - Suppresses the welcome email
  - Sets a permanent password via AWS CLI to allow immediate authentication
*/
########################################
# COGNITO USER
########################################
resource "aws_cognito_user" "user" {
  username       = var.cognito_user
  user_pool_id   = aws_cognito_user_pool.user_pool.id
  message_action = "SUPPRESS" # suppress sending welcome email

  attributes = {
    email = var.cognito_user
  }
}

########################################
# SET PERMANENT PASSWORD VIA CLI
########################################
data "aws_region" "current" {}

resource "null_resource" "set_user_password" {
  depends_on = [aws_cognito_user.user]

  provisioner "local-exec" {
    command = <<EOT
      aws cognito-idp admin-set-user-password \
        --user-pool-id ${aws_cognito_user_pool.user_pool.id} \
        --username ${var.cognito_user} \
        --password "${var.cognito_user_password}" \
        --permanent \
        --region ${data.aws_region.current.id}
    EOT
  }
}
