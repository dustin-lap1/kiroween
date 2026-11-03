# Apply-App.ps1 saves these to .local/apps/<name>.json; Publish-App.ps1 reads them.

output "site_url" {
  value = "https://${aws_cloudfront_distribution.site.domain_name}"
}

output "site_bucket" {
  value = aws_s3_bucket.site.id
}

output "distribution_id" {
  value = aws_cloudfront_distribution.site.id
}

output "api_endpoint" {
  value = aws_apigatewayv2_api.api.api_endpoint
}

output "table_name" {
  value = aws_dynamodb_table.main.name
}

output "alerts_topic_arn" {
  value = aws_sns_topic.alerts.arn
}
