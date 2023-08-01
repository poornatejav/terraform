provider "aws" {
  region                   = "us-east-1"
  shared_credentials_files = ["~/.aws/credentials"]
  profile                  = "Poorna"
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"

}

resource "aws_subnet" "private" {
  vpc_id                  = aws_vpc.main.id
  map_public_ip_on_launch = false
  cidr_block              = "10.0.2.0/24"

}

resource "aws_internet_gateway" "internet" {
  vpc_id     = aws_vpc.main.id

}

resource "aws_eip" "nat_eip" {
  vpc = true
}

resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public.id
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet.id
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway.id
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

resource "aws_security_group" "instance_sg" {
  name_prefix = "security rules"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "ec2" {
  ami                    = "ami-053b0d53c279acc90"
  instance_type          = "t2.micro"
  associate_public_ip_address = true
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.instance_sg.id]
  key_name               = aws_key_pair.web-app-auth.key_name
}

resource "aws_s3_bucket" "poorna-web-0730-23-assets" {
  bucket = "poorna-web-0730-23-assets"
  acl = "private"
}

resource "aws_s3_bucket_versioning" "bucket_versioning" {
  bucket = aws_s3_bucket.poorna-web-0730-23-assets.id
    versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_vpc_endpoint" "s3_endpoint" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.us-east-1.s3"
}

resource "aws_iam_role" "ec2_s3_role" {
  name = "EC2-S3-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2_s3_profile" {
  name  = "EC2-S3-Instance-Profile"
  role = aws_iam_role.ec2_s3_role.name
}

resource "aws_iam_role_policy_attachment" "s3_access" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
  role       = aws_iam_role.ec2_s3_role.name
}

resource "aws_key_pair" "web-app-auth" {
  key_name   = "web-app-key"
  public_key = file("~/.ssh/web-app-key.pub")

}

resource "aws_s3_object" "html" {
    bucket = aws_s3_bucket.poorna-web-0730-23-assets.bucket
    key = "index.html"
    source = "/Users/poornateja/Documents/Cloud Training/aws-web-app/webapp/webpage/index.html"
}

resource "aws_instance" "ec2_with_s3" {
  ami                    = "ami-053b0d53c279acc90"
  key_name               = aws_key_pair.web-app-auth.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.private.id
  iam_instance_profile   = aws_iam_instance_profile.ec2_s3_profile.name
  vpc_security_group_ids = [aws_security_group.instance_sg.id]
  user_data              = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install apache2 -y
              aws s3 cp s3://aws_s3_bucket.poorna-web-0730-23-assets.id/index.html 
              sudo systemctl start apache2
              sudo systemctl enable apache2
              EOF
}