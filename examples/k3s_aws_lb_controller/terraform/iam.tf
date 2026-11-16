# k3s에는 IRSA(OIDC)가 없으므로, 컨트롤러들은 노드의 인스턴스 프로파일 권한을 사용합니다.
# AWS Load Balancer Controller Pod는 어느 노드에든 스케줄될 수 있어 모든 노드에 같은 Role을 연결합니다.
resource "aws_iam_instance_profile" "k3s_node" {
  name = "${local.cluster_name}-node"
  role = aws_iam_role.k3s_node.name
}

resource "aws_iam_role" "k3s_node" {
  name = "${local.cluster_name}-node"
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
}

# AWS Cloud Controller Manager용 정책
# 로드밸런서는 AWS Load Balancer Controller가 전담하므로 (CCM의 service, route 컨트롤러는 비활성화)
# 공식 Control Plane 정책에서 노드 초기화에 필요한 조회 권한만 남겼습니다.
# 참고자료: https://cloud-provider-aws.sigs.k8s.io/prerequisites/
resource "aws_iam_policy" "aws_cloud_controller_manager" {
  name = "${local.cluster_name}-cloud-controller-manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:DescribeTags",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceTopology",
          "ec2:DescribeRegions",
          "ec2:DescribeRouteTables",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeVolumes",
          "ec2:DescribeVpcs",
        ]
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "aws_cloud_controller_manager" {
  role       = aws_iam_role.k3s_node.name
  policy_arn = aws_iam_policy.aws_cloud_controller_manager.arn
}

# AWS Load Balancer Controller용 정책 (v3.6.3)
# 출처: https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v3.6.3/docs/install/iam_policy.json
# 컨트롤러 버전을 올릴 때는 이 파일도 같은 버전의 것으로 교체합니다.
resource "aws_iam_policy" "aws_load_balancer_controller" {
  name   = "${local.cluster_name}-load-balancer-controller"
  policy = file("${path.module}/policies/aws_load_balancer_controller.json")
}

resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller" {
  role       = aws_iam_role.k3s_node.name
  policy_arn = aws_iam_policy.aws_load_balancer_controller.arn
}
