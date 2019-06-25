variable "authorized_key_file" {
  
}

variable "instance_type" {
  default = "t2.micro"
}

variable "instance_count" {
  default = "1"
}

variable "region" {
  default = "eu-central-1"
}

variable "tags" {
  type = "map"
  default = {
      app = "lab2"
      env = "lab"
  }
}