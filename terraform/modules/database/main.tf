resource "aws_iam_instance_profile" "database_profile" {
  name = "database_profile"
  role = aws_iam_role.database_role.name
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "inline_policy" {
  statement {
    actions = ["ec2:*"]
    resources = ["*"]
  }
}

resource "aws_iam_role" "database_role" {
  name               = "database_role"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  inline_policy {
    name = "inline_policy"
    policy = data.aws_iam_policy_document.inline_policy.json
  }
}





resource "aws_default_vpc" "default" {
  tags = {
    Name = "Default VPC"
  }
}

resource "tls_private_key" "key_pair" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create the Key Pair
resource "aws_key_pair" "key_pair" {
  key_name   = "databasekey"  
  public_key = tls_private_key.key_pair.public_key_openssh
}

# Save file
resource "local_file" "ssh_key" {
  filename = "${aws_key_pair.key_pair.key_name}-pub.pem"
  content  = tls_private_key.key_pair.private_key_pem
}

resource "aws_security_group" "database_sg" {
  name        = "allow_ssh_mongo"
  description = "Allow ssh and mongo inbound traffic"
  vpc_id      = aws_default_vpc.default.id

  ingress {
    from_port   = 22 
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 27017
    to_port     = 27019
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
  tags = {
    Name = "database-sg"
  }
}

data "aws_subnets" "subnets" {
  filter {
    name   = "vpc-id"
    values = [aws_default_vpc.default.id]
  }
}
resource "aws_instance" "database" {
  ami           = "ami-0799d612b35d4bd43"
  instance_type = "t3.small"
  security_groups = [aws_security_group.database_sg.id]
  subnet_id = data.aws_subnets.subnets.ids[0]
  key_name = aws_key_pair.key_pair.key_name
  user_data = file("${path.module}/firstboot.sh")
  iam_instance_profile = aws_iam_instance_profile.database_profile.name
  tags = {
    Name = "database"
    }
  }