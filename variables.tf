
  
# Input variable definitions

variable "aws_region" {
  description = "AWS region for all resources."

  type    = string
}

variable "function_name" {}
variable "runtime" {}
variable "handler" {}
variable "schedule_name" {}
variable "schedule_expression" {}