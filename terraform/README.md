# Usage

- Fill in `variables.tf` file
- Add parameters to backend block in `main.tf`
- run `terraform init`

## What does this deploy?

- Adopts default VPC and subnets for Terraform to track
- 3 lambda functions
- API-Gateway with 3 endpoints
- DynamoDB table
- Some permissions and IAM roles to make it all work together

## notes

These files are probably not super useful as is, but can be used as stepping stone for your own Terraform configs.