# One DynamoDB table per app (single-table design).
#   pk = "C#<collection>"   sk = <time-sortable item id>
# Add GSIs here when a spec needs a new access pattern.

resource "aws_dynamodb_table" "main" {
  name         = "${local.name}-data"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "pk"
  range_key    = "sk"

  attribute {
    name = "pk"
    type = "S"
  }

  attribute {
    name = "sk"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  # Guardrail: the table cannot be deleted by Terraform or the console until
  # this is set to false in a reviewed change.
  deletion_protection_enabled = true
}
