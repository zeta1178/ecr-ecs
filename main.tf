# ---------------------------------------------------------------------------
# Data sources (replace CloudFormation pseudo parameters)
# ---------------------------------------------------------------------------

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

# ---------------------------------------------------------------------------
# Secret for Bedrock Agent ID, Alias ID, and Region
# ---------------------------------------------------------------------------

resource "aws_secretsmanager_secret" "bedrock_agent" {
  name = "/ecs/ecr-ecs/${var.bedrock_agent}"
}

# Create the secret version to hold the data
resource "aws_secretsmanager_secret_version" "bedrock_agent_value" {
  secret_id     = aws_secretsmanager_secret.bedrock_agent.id
  secret_string = jsonencode({
    BEDROCK_AGENT_ID = var.TF_VAR_BEDROCK_AGENT_ID
    BEDROCK_AGENT_ALIAS_ID = var.TF_VAR_BEDROCK_AGENT_ALIAS_ID
    AWS_DEFAULT_REGION = var.TF_VAR_AWS_DEFAULT_REGION
  })
}

# ---------------------------------------------------------------------------
# IAM Execution Role for Fargate to pull from ECR and log to CloudWatch
# ---------------------------------------------------------------------------

resource "aws_iam_role" "ecs_task_execution" {
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "ecs-tasks.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "ecs_task_execution_cloudwatch_logs" {
  name = "ExecutionRoleInlinePolicy"
  role = aws_iam_role.ecs_task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid: "AllowCloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups"
        ]
        Resource = "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/ecs/${var.stack_name}-fargate-app:*"
      },
      {
        Sid: "AllowSecretsManagerAccess"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",        ]
        Resource = "arn:${data.aws_partition.current.partition}:secretsmanager:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:secret:/ecs/ecr-ecs/${var.bedrock_agent}-*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ---------------------------------------------------------------------------
# IAM Task Role for ECS Tasks (Optional, if your container needs to access AWS services)
# ---------------------------------------------------------------------------

resource "aws_iam_role" "ecs_task_role" {
  # name = "ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "ecs_task_role_policy" {
  name = "ecs-task-role-policy"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ]
        Resource = "*"
      }
    ]
  })
}

# ---------------------------------------------------------------------------
# KMS Key for encrypting CloudWatch Logs (Optional)
# ---------------------------------------------------------------------------

resource "aws_kms_key" "cloudwatch" {
  description             = "KMS Key for encrypting CloudWatch Logs"
  is_enabled              = true
  key_usage               = "ENCRYPT_DECRYPT"
  customer_master_key_spec = "SYMMETRIC_DEFAULT"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "Enable IAM User Permissions"
        Effect    = "Allow"
        Principal = { AWS = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        Sid       = "Allow access for Key Administrators"
        Effect    = "Allow"
        Principal = { AWS = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:user/Mike.Cruz" }
        Action = [
          "kms:Create*",
          "kms:Describe*",
          "kms:Enable*",
          "kms:List*",
          "kms:Put*",
          "kms:Update*",
          "kms:Revoke*",
          "kms:Disable*",
          "kms:Get*",
          "kms:Delete*",
          "kms:TagResource",
          "kms:UntagResource",
          "kms:ScheduleKeyDeletion",
          "kms:CancelKeyDeletion",
          "kms:RotateKeyOnDemand"
        ]
        Resource = "*"
      },
      {
        Sid       = "Allow use of the key"
        Effect    = "Allow"
        Principal = { AWS = aws_iam_role.ecs_task_execution.arn }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      },
      {
        Sid       = "Allow service use of the key"
        Effect    = "Allow"
        Principal = { Service = "logs.us-east-1.amazonaws.com" }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/ecs/${var.stack_name}-fargate-app"
          }
        }
      }
    ]
  })
}

resource "aws_kms_alias" "cloudwatch" {
  name          = "alias/CloudWatchEncryptAlias"
  target_key_id = aws_kms_key.cloudwatch.key_id
}

# ---------------------------------------------------------------------------
# Log Group for Container Application Logs
# ---------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.stack_name}-fargate-app"
  retention_in_days = 7
  kms_key_id        = aws_kms_key.cloudwatch.arn
}

# ---------------------------------------------------------------------------
# Security Groups
# ---------------------------------------------------------------------------

# Security Group for the Application Load Balancer
resource "aws_security_group" "alb" {
  description = "Allow public HTTP traffic to the Load Balancer"
  vpc_id      = var.vpc_id

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Security Group for Fargate Tasks (Allows traffic ONLY from the ALB)
resource "aws_security_group" "fargate_task" {
  description = "Allow traffic from the ALB to Fargate tasks"
  vpc_id      = var.vpc_id

  ingress {
    protocol        = "tcp"
    from_port       = var.container_port
    to_port         = var.container_port
    security_groups = [aws_security_group.alb.id]
  }
  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ---------------------------------------------------------------------------
# Application Load Balancer
# ---------------------------------------------------------------------------

resource "aws_lb" "app" {
  name               = "${var.stack_name}-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = var.subnet_ids
  security_groups    = [aws_security_group.alb.id]

  drop_invalid_header_fields = true
}

# Target Group targeting Fargate Tasks using 'ip' target type
resource "aws_lb_target_group" "app" {
  name        = "${var.stack_name}-tg"
  port        = var.container_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  health_check {
    interval            = 30
    path                = "/"
    protocol            = "HTTP"
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# ALB Listener routing HTTP traffic to the Target Group
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# ---------------------------------------------------------------------------
# ECS Cluster, Task Definition, and Service
# ---------------------------------------------------------------------------

resource "aws_ecs_cluster" "main" {
  name = "${var.stack_name}-cluster"
}

resource "aws_ecs_task_definition" "app" {
  family                   = "${var.stack_name}-task"
  cpu                      = "256"
  memory                   = "512"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "${var.stack_name}-container"
      image     = var.ecr_image_uri
      secrets   = [
        {
          name = "BEDROCK_AGENT_ID",
          valueFrom = aws_secretsmanager_secret.bedrock_agent.arn
        },
        {
          name = "BEDROCK_AGENT_ALIAS_ID",
          valueFrom = aws_secretsmanager_secret.bedrock_agent.arn
        },
        {
          name = "AWS_DEFAULT_REGION",
          valueFrom = aws_secretsmanager_secret.bedrock_agent.arn
        }
      ]
      cpu       = 256
      memory    = 512
      portMappings = [
        {
          containerPort = var.container_port
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.app.name
          "awslogs-region"        = data.aws_region.current.region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

# ECS Fargate Service connecting Tasks to the ALB
resource "aws_ecs_service" "app" {
  name            = "${var.stack_name}-service"
  cluster         = aws_ecs_cluster.main.id
  launch_type     = "FARGATE"
  desired_count   = 2
  task_definition = aws_ecs_task_definition.app.arn

  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100

  # Enable ECS Exec
  enable_execute_command = true

  network_configuration {
    assign_public_ip = true
    security_groups  = [aws_security_group.fargate_task.id]
    subnets          = var.subnet_ids
  }

  load_balancer {
    container_name   = "${var.stack_name}-container"
    container_port   = var.container_port
    target_group_arn = aws_lb_target_group.app.arn
  }

  depends_on = [aws_lb_listener.http]
}

# ---------------------------------------------------------------------------
# Outputs
# ---------------------------------------------------------------------------

output "service_url" {
  description = "URL of the Application Load Balancer"
  value       = "http://${aws_lb.app.dns_name}"
}
