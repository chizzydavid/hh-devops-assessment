# 1. ECR Repository with lifecycle policy
module "ecr" {
  source          = "./modules/ecr"
  repository_name = var.service_name
}


# 2. S3 Remote State Bucket Storage, (with encryption, versioning, and lifecycle policy)
module "s3_bucket" {
  source            = "./modules/s3_bucket"
  versioning_status = "Enabled"
  bucket_name       = "hh-tf-state-${var.environment}-${var.service_name}"
}

# 3. IAM Role with OIDC Least-Privilege Policy for GitHub Actions
data "aws_iam_openid_connect_provider" "github" {
  arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
}

data "aws_caller_identity" "current" {}

resource "aws_iam_role" "github_ci" {
  name = "github-actions-ci-${var.service_name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = data.aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:*"
          }
        }
      }
    ]
  })
}

resource "aws_iam_policy" "github_ci_ecr" {
  name        = "github-actions-ecr-${var.service_name}"
  description = "Least-privilege permissions for GitHub Actions to push images to ECR"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = module.ecr.repository_arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "github_ci_attach" {
  role       = aws_iam_role.github_ci.name
  policy_arn = aws_iam_policy.github_ci_ecr.arn
}
