resource "aws_default_vpc" "default" {
  tags = {
    Name = "Default VPC"
  }
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
  subnet_id = aws_subnet.priv1.id
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

resource "aws_eks_cluster" "example" {
  name     = "example"
  role_arn = aws_iam_role.example.arn

  vpc_config {
    subnet_ids = [aws_subnet.priv1.id, aws_subnet.priv2.id]
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Cluster handling.
  # Otherwise, EKS will not be able to properly delete EKS managed EC2 infrastructure such as Security Groups.
  depends_on = [
    aws_iam_role_policy_attachment.example-AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.example-AmazonEKSVPCResourceController,
  ]
}

output "endpoint" {
  value = aws_eks_cluster.example.endpoint
}

output "kubeconfig-certificate-authority-data" {
  value = aws_eks_cluster.example.certificate_authority[0].data
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "example" {
  name               = "eks-cluster-example"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy_attachment" "example-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.example.name
}

# Optionally, enable Security Groups for Pods
# Reference: https://docs.aws.amazon.com/eks/latest/userguide/security-groups-for-pods.html
resource "aws_iam_role_policy_attachment" "example-AmazonEKSVPCResourceController" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.example.name
}