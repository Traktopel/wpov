

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
    actions = ["ec2:*","s3:*"]
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
    cidr_blocks = [aws_default_vpc.default.cidr_block]
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
  subnet_id = data.aws_subnets.subnets.ids[1]
  key_name = aws_key_pair.key_pair.key_name
  user_data = templatefile("${path.module}/firstboot.sh",{bucket =  "${aws_s3_bucket.mongo_bucket.id}", noderole = "${var.eks_node_role}"})
  iam_instance_profile = aws_iam_instance_profile.database_profile.name
  tags = {
    Name = "database"
    }
  }
output "asd" {
  value = var.eks_node_role
}

output "database_ip" {
  value = aws_instance.database.private_ip
}


resource "aws_s3_bucket" "mongo_bucket" {
  bucket_prefix = "mongobucket"

}


resource "aws_s3_bucket_ownership_controls" "mongo_bucket" {
  bucket = aws_s3_bucket.mongo_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "mongo_bucket" {
  bucket = aws_s3_bucket.mongo_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_acl" "mongo_bucket" {
  depends_on = [
    aws_s3_bucket_ownership_controls.mongo_bucket,
    aws_s3_bucket_public_access_block.mongo_bucket,
  ]

  bucket = aws_s3_bucket.mongo_bucket.id
    acl    = "public-read"
}


resource "aws_s3_bucket_policy" "allow_access_public" {
  bucket = aws_s3_bucket.mongo_bucket.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid = "allowpublic"
        Effect = "Allow"
        Principal = "*"
        Action = [
          "s3:GetObject"
        ]
        Resource = [
          "${aws_s3_bucket.mongo_bucket.arn}/*"
        ]
      },
      {
        Sid = "allowmongorole"
        Effect = "Allow"
        Principal = {
          AWS = "${aws_iam_role.database_role.arn}"
        }
        Action = [
          "s3:*"
        ]
        Resource = [
          "${aws_s3_bucket.mongo_bucket.arn}/*"
        ]
      }
    ]
  }) 
}

