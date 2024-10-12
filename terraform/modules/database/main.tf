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
  name        = "allow_http"
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
  ami           = "ami-0592c673f0b1e7665"
  instance_type = "t2.micro"
  security_groups = [aws_security_group.database_sg.id]
  subnet_id = data.aws_subnets.subnets.ids[0]
  key_name = aws_key_pair.key_pair.key_name
  tags = {
    Name = database
    }
  }