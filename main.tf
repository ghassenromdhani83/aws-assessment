########################################################
# COGNITO MODULE (Centralized Authentication)
########################################################

module "cognito" {
  source = "./modules/cognito"

  providers = {
    aws = aws.us_east_1
  }

  cognito_user          = var.email
  cognito_user_password = var.cognito_user_password
}

########################################################
# COMPUTE STACK - US EAST 1
########################################################

module "compute_us" {
  source = "./modules/compute"

  providers = {
    aws = aws.us_east_1
  }

  region            = "us-east-1"
  cognito_pool_id   = module.cognito.user_pool_id
  cognito_client_id = module.cognito.user_pool_client_id
  email             = var.email
  repo_url          = var.repo_url
  sns_topic_arn     = var.sns_topic_arn
}

########################################################
# COMPUTE STACK - EU WEST 1
########################################################

module "compute_eu" {
  source = "./modules/compute"

  providers = {
    aws = aws.eu_west_1
  }

  region            = "eu-west-1"
  cognito_pool_id   = module.cognito.user_pool_id
  cognito_client_id = module.cognito.user_pool_client_id
  email             = var.email
  repo_url          = var.repo_url
  sns_topic_arn     = var.sns_topic_arn
}
