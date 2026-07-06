variable "stack_name" {
  type        = string
  description = "Name used to prefix resource names (equivalent to CloudFormation's AWS::StackName)."
  default     = "ecr-ecs"
}

variable "vpc_id" {
  type        = string
  description = "The VPC where your infrastructure is deployed."
  default     = "vpc-0cd345c357056ee7c"
}

variable "subnet_ids" {
  type        = list(string)
  description = "At least two public subnets for the Load Balancer and Fargate tasks."
  default     = ["subnet-0e03271be6a707285", "subnet-074b99143081c9174"]
}

variable "ecr_image_uri" {
  type        = string
  description = "The full URI of your ECR image."
  default     = "992690408789.dkr.ecr.us-east-1.amazonaws.com/ecr-ecs:latest"
}

variable "container_port" {
  type        = number
  description = "The port number the application inside the container listens on."
  default     = 8501
}

variable "bedrock_agent" {
  type        = string
  description = "The name of the secret in AWS Secrets Manager for the bedrock agent."
  default     = "bedrock-agent"
}

variable "TF_VAR_BEDROCK_AGENT_ID" {
  type        = string
  description = "The ID of the secret in AWS Secrets Manager for the bedrock agent."
}

variable "TF_VAR_BEDROCK_AGENT_ALIAS_ID" {
  type        = string
  description = "The ID of the agent alias. The default `TSTALIASID` will be used if it is not set."
}

variable "TF_VAR_AWS_DEFAULT_REGION" {
  type        = string
  description = "The default region for the agent. The default `us-east-1` will be used if it is not set."
}