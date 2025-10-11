resource "aws_iam_role" "bastion_ssm" {
  name = "${var.app_name}-bastion-ssm-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "bastion_ssm" {
  role       = aws_iam_role.bastion_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_security_group" "bastion" {
  name        = "${var.app_name}-bastion-sg"
  description = "Security group for Bastion host"
  vpc_id      = aws_vpc.main.id

  # Allow SSH from your IP (optional, for emergencies)
  #ingress {
  #  from_port   = 22
  #  to_port     = 22
  #  protocol    = "tcp"
  #  cidr_blocks = ["YOUR_PUBLIC_IP/32"] # Replace with your IP or remove for SSM-only
  #}

  # Allow all outbound (for SSM and DB access)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.app_name}-bastion-sg"
    Environment = var.environment
  }
}

resource "aws_instance" "bastion" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro" # Minimal cost, eligible for free tier
  subnet_id     = aws_subnet.public_a.id
  vpc_security_group_ids = [aws_security_group.bastion.id]
  iam_instance_profile   = aws_iam_instance_profile.bastion_ssm.name

  tags = {
    Name        = "${var.app_name}-bastion"
    Environment = var.environment
  }
}

resource "aws_iam_instance_profile" "bastion_ssm" {
  name = "${var.app_name}-bastion-ssm-profile"
  role = aws_iam_role.bastion_ssm.name
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}