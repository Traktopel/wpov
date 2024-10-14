resource "aws_default_vpc" "default" {
  tags = {
    Name = "Default VPC"
  }
}
resource "aws_default_subnet" "default_az1" {
  availability_zone = "eu-central-1a"
}


resource "aws_subnet" "priv1" {
  vpc_id     = aws_default_vpc.default.id
  cidr_block = "172.31.48.0/24"
  availability_zone_id = "euc1-az1"
  map_public_ip_on_launch = false # 
  tags = {
    Name = "subnet_priv1"
  }
}

resource "aws_subnet" "priv2" {
  vpc_id     = aws_default_vpc.default.id
  cidr_block = "172.31.49.0/24"
  availability_zone_id = "euc1-az2"
  map_public_ip_on_launch = false # 
  tags = {
    Name = "subnet_priv2"
  }
}
resource "aws_eip" "natgw_pubip" {
}

resource "aws_nat_gateway" "natgw" {
  allocation_id = aws_eip.natgw_pubip.id
  subnet_id = aws_default_subnet.default_az1.id
}


resource "aws_route_table" "private_route_table" {
  vpc_id = aws_default_vpc.default.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.natgw.id
  }
}

resource "aws_route_table_association" "private_rt_asso1" {
  subnet_id = aws_subnet.priv1.id
  route_table_id = aws_route_table.private_route_table.id
}

resource "aws_route_table_association" "private_rt_asso2" {
  subnet_id = aws_subnet.priv2.id
  route_table_id = aws_route_table.private_route_table.id
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.8.5"

  cluster_name    = "eks"

  cluster_endpoint_public_access           = true
  cluster_endpoint_private_access          = true
  enable_cluster_creator_admin_permissions = true

  cluster_addons = {
    eks-pod-identity-agent = {}
  }

  vpc_id     = aws_default_vpc.default.id
  subnet_ids = [aws_subnet.priv1.id,aws_subnet.priv2.id]

  eks_managed_node_group_defaults = {
    ami_type = "AL2_x86_64"

  }

  eks_managed_node_groups = {
    one = {
      name = "node-group-1"

      instance_types = ["t3.small"]

      min_size     = 1
      max_size     = 3
      desired_size = 2
    }
  }
}


data "aws_iam_policy" "ebs_csi_policy" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

module "irsa-ebs-csi" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version = "5.39.0"

  create_role                   = true
  role_name                     = "AmazonEKSTFEBSCSIRole-${module.eks.cluster_name}"
  provider_url                  = module.eks.oidc_provider
  role_policy_arns              = [data.aws_iam_policy.ebs_csi_policy.arn]
  oidc_fully_qualified_subjects = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
}

output "endpoint" {
  value = module.eks.eks_managed_node_groups.one.iam_role_arn
}

data "aws_iam_policy" "regrw" {
  arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess"
}
resource "aws_iam_role_policy_attachment" "write_ecr" {
  role       = split("/", module.eks.eks_managed_node_groups.one.iam_role_arn)[1]
  policy_arn = data.aws_iam_policy.regrw.arn
}


provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    command     = "aws"
  }
}


resource "aws_ecr_repository" "repo" {
  name                 = "repo"
  image_tag_mutability = "MUTABLE"
}

resource "aws_ecr_repository_policy" "repo_policy_attach" {
  repository = aws_ecr_repository.repo.name
  policy   = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid = "allowpublic"
        Effect = "Allow"
        Principal = "*"
        Action = [
          "ecr:*"
        ]
        
      }
    ]
  }) 
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }

    actions = ["sts:AssumeRole", "sts:TagSession"]
  }
}

data "aws_iam_policy_document" "inline_policy" {
  statement {
    actions = ["ecr:*"]
    resources = ["*"]
    effect = "Allow"
  }
}

resource "aws_iam_role" "tasky_role" {
  name               = "tasky_role"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  inline_policy {
    name = "inline_policy"
    policy = data.aws_iam_policy_document.inline_policy.json
  }
}

resource "aws_eks_pod_identity_association" "tasky_identity_association" {
  cluster_name    = module.eks.cluster_name
  namespace       = "default"
  service_account = "tasky"
  role_arn        = aws_iam_role.tasky_role.arn
}


provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}

resource "helm_release" "flux" {
  name       = "flux"
  repository = "https://fluxcd-community.github.io/helm-charts"
  chart      = "flux2"
}