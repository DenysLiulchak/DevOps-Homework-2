provider "aws" {
  region = "us-west-2"
}

resource "aws_vpc" "custom_vpc" {
  cidr_block = "192.168.0.0/16"
  tags = {
    Name = "custom_vpc"
  }
}

resource "aws_internet_gateway" "custom_igw" {
  vpc_id = aws_vpc.custom_vpc.id
  tags = {
    Name = "custom_igw"
  }
}

resource "aws_subnet" "custom_public_subnet_1" {
  vpc_id            = aws_vpc.custom_vpc.id
  cidr_block        = "192.168.1.0/24"
  availability_zone = "us-west-2a"
  tags = {
    Name = "custom_public_subnet_1"
  }
}

resource "aws_subnet" "custom_public_subnet_2" {
  vpc_id            = aws_vpc.custom_vpc.id
  cidr_block        = "192.168.2.0/24"
  availability_zone = "us-west-2b"
  tags = {
    Name = "custom_public_subnet_2"
  }
}

resource "aws_route_table" "custom_public_rt" {
  vpc_id = aws_vpc.custom_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.custom_igw.id
  }
  tags = {
    Name = "custom_public_rt"
  }
}

resource "aws_route_table_association" "custom_public_rta_1" {
  subnet_id        = aws_subnet.custom_public_subnet_1.id
  route_table_id   = aws_route_table.custom_public_rt.id
}

resource "aws_route_table_association" "custom_public_rta_2" {
  subnet_id        = aws_subnet.custom_public_subnet_2.id
  route_table_id   = aws_route_table.custom_public_rt.id
}

resource "aws_security_group" "custom_sg" {
  name        = "custom_security_group"
  description = "Allow SSH and HTTP traffic"
  vpc_id      = aws_vpc.custom_vpc.id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "custom_ec2_instance_1" {
  ami                          = "customAMI"
  instance_type                = "t2.nano"
  key_name                     = "custom_key_pair"
  vpc_security_group_ids       = [aws_security_group.custom_sg.id]
  subnet_id                    = aws_subnet.custom_public_subnet_1.id
  associate_public_ip_address  = true
  user_data = <<-EOF
              #!/bin/bash
              
              sudo apt-get update
              sudo apt-get -y install apt-transport-https ca-certificates curl gnupg-agent software-properties-common
              curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
              sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
              sudo apt-get update
              sudo apt-get -y install docker-ce docker-ce-cli containerd.io docker-compose

              git clone https://github.com/custom-user/prometheus.git /home/ubuntu/custom-prometheus
              cd /home/ubuntu/custom-prometheus

              docker network create custom-prometheus

              docker-compose -f examples/metrics/docker-compose.yml up -d

              docker run -d --name custom-prometheus --network custom-prometheus -p 9090:9090 -v /home/ubuntu/custom-prometheus:/etc/prometheus custom/prometheus

            EOF
  tags = {
    Name = "custom_ec2_instance_1"
  }
}

resource "null_resource" "custom_install_prometheus" {
  depends_on = [aws_instance.custom_ec2_instance_1]

  provisioner "remote-exec" {
    inline = [
      "sleep 75",
      "curl localhost:9090",
      "curl localhost:9100/metrics",
      "curl localhost:8080/metrics",
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      host        = aws_instance.custom_ec2_instance_1.public_ip
      private_key = file("custom_key_pair.pem")
    }
  }
}

resource "aws_instance" "custom_ec2_instance_2" {
  ami                          = "customAMI"
  instance_type                = "t2.nano"
  key_name                     = "custom_key_pair"
  vpc_security_group_ids       = [aws_security_group.custom_sg.id]
  subnet_id                    = aws_subnet.custom_public_subnet_2.id
  associate_public_ip_address  = true
  user_data = <<-EOF
              #!/bin/bash
              
              sudo apt-get update
              sudo apt-get -y install apt-transport-https ca-certificates curl gnupg-agent software-properties-common
              curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
              sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
              sudo apt-get update
              sudo apt-get -y install docker-ce docker-ce-cli containerd.io docker-compose

              git clone https://github.com/custom-user/node_exporter.git /home/ubuntu/custom-node-exporter
              cd /home/ubuntu/custom-node-exporter

              docker run -d --name custom-node-exporter -p 9100:9100 -v "/proc:/host/proc" -v "/sys:/host/sys" -v "/:/rootfs" --net="host" custom/node-exporter

              git clone https://github.com/custom-user/cadvisor.git /home/ubuntu/custom-cadvisor
              cd /home/ubuntu/custom-cadvisor

              docker-compose up -d

              echo "IP-адрес: $(curl http://169.254.169.254/latest/meta-data/public-ipv4)"

            EOF
  tags = {
    Name = "custom_ec2_instance_2"
  }
}

output "custom_instance_ips" {
  value = [
    aws_instance.custom_ec2_instance_1.public_ip,
    aws_instance.custom_ec2_instance_2.public_ip
  ]
}
