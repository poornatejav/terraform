output "s3_bucket" {
  value = aws_instance.ec2_with_s3.public_ip
}