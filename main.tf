provider "aws" {
  region = "${var.region}"
}

data "aws_ami" "ami" {
    most_recent = true

    filter {
        name   = "name"
        values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
    }

    filter {
        name   = "virtualization-type"
        values = ["hvm"]
    }

    owners = ["099720109477"]
}


resource "aws_vpc" "lab2vpc" {
  cidr_block = "10.0.0.0/16"
  instance_tenancy = "dedicated"
  tags = "${var.tags}"
}

resource "aws_subnet" "subnet_a" {
  cidr_block = "10.0.0.0/24"
  availability_zone = "${var.region}a"
  vpc_id = "${aws_vpc.lab2vpc.id}"
  tags = "${var.tags}"
}
resource "aws_subnet" "subnet_b" {
  cidr_block = "10.0.1.0/24"
  availability_zone = "${var.region}b"
  vpc_id = "${aws_vpc.lab2vpc.id}"
  tags = "${var.tags}"
}

resource "aws_internet_gateway" "default_gateway" {
    vpc_id = "${aws_vpc.lab2vpc.id}"
    tags = "${var.tags}"
}

resource "aws_route_table" "route_a" {
  vpc_id = "${aws_vpc.lab2vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.default_gateway.id}"
  }
}

resource "aws_route_table_association" "rt_association_a" {
  subnet_id = "${aws_subnet.subnet_a.id}"
  route_table_id = "${aws_route_table.route_a.id}"
}

resource "aws_route_table_association" "rt_association_b" {
  subnet_id = "${aws_subnet.subnet_b.id}"
  route_table_id = "${aws_route_table.route_a.id}"
}

resource "aws_security_group" "security_group" {
  vpc_id = "${aws_vpc.lab2vpc.id}"
  egress {
      cidr_blocks = ["0.0.0.0/0"]
      from_port = "0"
      to_port = "0"
      protocol = "-1"
  }
  ingress {
      cidr_blocks = ["0.0.0.0/0"]
      from_port = "22"
      to_port = "443"
      protocol = "TCP"
  }
}

resource "aws_key_pair" "key" {
  key_name = "mylab2key"
  public_key = "${file(var.authorized_key_file)}"
}


resource "aws_instance" "vms" {
  count = "${var.instance_count}"
  ami = "${data.aws_ami.ami.id}"
  key_name = "${aws_key_pair.key.key_name}"
  subnet_id = "${count.index % 2 == 0 ? aws_subnet.subnet_a.id : aws_subnet.subnet_b.id}"
  vpc_security_group_ids = ["${aws_security_group.security_group.id}"]
  associate_public_ip_address = "true"
  instance_type = "t2.micro"
}

resource "aws_elb" "elb" {
  name            = "terraform-demo-elb"
  instances       = "${aws_instance.vms.*.id}"
  security_groups = ["${aws_security_group.security_group.id}"]
  subnets         = ["${aws_subnet.subnet_a.id}", "${aws_subnet.subnet_b.id}"]

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:80/"
    interval            = 30
  }

  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400
}
