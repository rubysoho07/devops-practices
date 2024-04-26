resource "aws_iam_instance_profile" "control_node" {
  name = "control_node"
  role = aws_iam_role.control_node.name
}

resource "aws_iam_role" "control_node" {
  name = "control_node"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEC2FullAccess",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    aws_iam_policy.ssm_connection_temp.arn
  ]
}

resource "aws_iam_instance_profile" "managed_nodes" {
  name = "managed_nodes"
  role = aws_iam_role.managed_nodes.name
}

resource "aws_iam_role" "managed_nodes" {
  name = "managed_nodes"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  ]
}

resource "aws_iam_policy" "ssm_connection_temp" {
  name = "ansible-ssm-connection-temp"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
          "s3:DeleteObject",
          "s3:GetBucketLocation",
        ]
        Effect = "Allow"
        Resource = [
          aws_s3_bucket.ssm_connection_temp.arn,
          "${aws_s3_bucket.ssm_connection_temp.arn}/*",
        ]
        }, {
        Effect = "Allow",
        Action = [
          "ssm:ResumeSession",
          "ssm:TerminateSession",
          "ssm:StartSession"
        ],
        Resource = [
          "arn:aws:ssm:*:${data.aws_caller_identity.current.account_id}:document/*",
          "arn:aws:ssm:*:${data.aws_caller_identity.current.account_id}:session/*",
          "arn:aws:ssm:*:${data.aws_caller_identity.current.account_id}:managed-instance/*",
          "arn:aws:ecs:*:${data.aws_caller_identity.current.account_id}:task/*",
          "arn:aws:ec2:*:${data.aws_caller_identity.current.account_id}:instance/*"
        ]
      },
      {
        Effect   = "Allow",
        Action   = "ssm:DescribeSessions",
        Resource = "*"
      }
    ]
  })
}