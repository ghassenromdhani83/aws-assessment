output "cognito_user_pool_id" {
  value = module.cognito.user_pool_id
}

output "cognito_user_pool_client_id" {
  value = module.cognito.user_pool_client_id
}

output "api_endpoint_eu" {
  value = module.compute_eu.api_endpoint
}

output "api_endpoint_us" {
  value = module.compute_us.api_endpoint
}
