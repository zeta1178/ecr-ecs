# ===========================================================================
# Terraform conversion of ecs-internal-template-ec2.yml
#
# Faithful 1:1 conversion of the CDK-generated CloudFormation stack
# "is-aiworkspace-jupyterhub-d-us-east-1-stack" (EC2-backed ECS / JupyterHub).
#
# The source template hardcodes environment-specific values (VPC, subnets,
# ACM cert, account IDs, ARNs). Those are captured in locals below so this
# file is self-contained and does not disturb the existing variables.tf.
# ===========================================================================

# ---------------------------------------------------------------------------
# Pseudo parameters (AWS::Partition, etc.) and the ECS-optimized AMI lookup
# (CloudFormation Parameters block)
# ---------------------------------------------------------------------------

data "aws_partition" "ec2" {}

data "aws_ssm_parameter" "ecs_optimized_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id"
}

locals {
  # Networking / environment values from the source template
  vpc_id      = "vpc-0aa9799898d383e32"
  alb_subnets = ["subnet-041b16402eac0dce8", "subnet-0ca4bafe5f2cb36be"]
  efs_subnet_ids = [
    "subnet-041b16402eac0dce8",
    "subnet-095b95dae131c5050",
    "subnet-0597f2c1ab2fc49e9",
  ]
  certificate_arn = "arn:aws:acm:us-east-1:128211541887:certificate/2bee7b9c-c499-4f54-a8c7-42d8ad0a4cdd"

  cluster_name    = "is-aiworkspace-jupyterhub-d-cluster"
  service_name    = "is-aiworkspace-jupyterhub-d"
  container_name  = "is-aiworkspace-jupyterhub-d"
  container_image = "873043565046.dkr.ecr.us-east-1.${data.aws_partition.ec2.dns_suffix}/is-aiworkspace-jupyterhub:8b6deba6b5f"

  ecr_repository_arn         = "arn:aws:ecr:us-east-1:873043565046:repository/is-aiworkspace-jupyterhub"
  dynatrace_secret_glob      = "arn:aws:secretsmanager:us-east-1:128211541887:secret:/amtrak/project/io/entobsv/d/dynatrace/ecs-??????"
  dynatrace_tenant_token_arn = "arn:aws:secretsmanager:us-east-1:128211541887:secret:/amtrak/project/io/entobsv/d/dynatrace/ecs:DT_TENANTTOKEN::"

  # Common tag set applied across the stack
  common_tags = {
    ApplicationGroup = "PrivateAI"
    BackupTier       = "DEV"
    Department       = "is"
    ITDR             = "424844"
    Landscape        = "DEV"
    Project          = "aiworkspace"
  }
}

# ---------------------------------------------------------------------------
# Task Execution Role
# (taskexecutionroleisaiworkspacejupyterhubduseast1dev...)
# ---------------------------------------------------------------------------

resource "aws_iam_role" "task_execution" {
  name = "is-aiworkspace-jupyterhub-d-Task-Execution-Role"
  path = "/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = { Service = "ecs-tasks.amazonaws.com" }
      }
    ]
  })

  managed_policy_arns = [
    "arn:aws:iam::128211541887:policy/amtrak/project-api-management-fullaccess",
    "arn:aws:iam::128211541887:policy/amtrak/project-integration-fullaccess",
    "arn:aws:iam::128211541887:policy/amtrak/project-containers-fullaccess",
    "arn:aws:iam::128211541887:policy/amtrak/project-dynamodb-fullaccess",
    "arn:aws:iam::128211541887:policy/amtrak/project-lambda-fullaccess",
    "arn:aws:iam::128211541887:policy/amtrak/project-management-fullaccess",
    "arn:aws:iam::128211541887:policy/amtrak/project-s3-fullaccess",
    "arn:${data.aws_partition.ec2.partition}:iam::aws:policy/AWSXrayFullAccess",
    "arn:aws:iam::128211541887:policy/amtrak/project-eks-fullaccess",
    "arn:aws:iam::128211541887:policy/amtrak/project-efs-fullaccess",
    "arn:aws:iam::128211541887:policy/amtrak/project-kafka-fullaccess",
  ]

  tags = local.common_tags
}

resource "aws_iam_role_policy" "task_execution_default" {
  name = "taskexecutionroleisaiworkspacejupyterhubduseast1devDefaultPolicy98D88A4E"
  role = aws_iam_role.task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer",
        ]
        Resource = local.ecr_repository_arn
      },
      {
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ]
        Resource = aws_cloudwatch_log_group.ecs.arn
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:DescribeSecret",
          "secretsmanager:GetSecretValue",
        ]
        Resource = [
          local.dynatrace_secret_glob,
          aws_secretsmanager_secret.app.arn,
        ]
      },
    ]
  })
}

# ---------------------------------------------------------------------------
# Task Role (taskroleisaiworkspacejupyterhubd...)
# ---------------------------------------------------------------------------

resource "aws_iam_role" "task_role" {
  name = "is-aiworkspace-jupyterhub-d-Task-Role"
  path = "/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = { Service = "ecs-tasks.amazonaws.com" }
      }
    ]
  })

  managed_policy_arns = [
    "arn:aws:iam::128211541887:policy/amtrak/project-s3-fullaccess",
    "arn:aws:iam::128211541887:policy/amtrak/project-management-fullaccess",
    "arn:aws:iam::128211541887:policy/amtrak/project-containers-fullaccess",
    "arn:${data.aws_partition.ec2.partition}:iam::aws:policy/AWSXRayDaemonWriteAccess",
    "arn:${data.aws_partition.ec2.partition}:iam::aws:policy/CloudWatchFullAccess",
    "arn:${data.aws_partition.ec2.partition}:iam::aws:policy/AWSAppMeshEnvoyAccess",
    "arn:${data.aws_partition.ec2.partition}:iam::aws:policy/CloudWatchAgentServerPolicy",
    "arn:aws:iam::128211541887:policy/amtrak/project-dynamodb-fullaccess",
    "arn:aws:iam::128211541887:policy/amtrak/project-lambda-fullaccess",
    "arn:aws:iam::128211541887:policy/amtrak/project-efs-fullaccess",
  ]

  # Inline policy: AllowExecuteCommand
  inline_policy {
    name = "AllowExecuteCommand"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "ssmmessages:CreateControlChannel",
            "ssmmessages:CreateDataChannel",
            "ssmmessages:OpenControlChannel",
            "ssmmessages:OpenDataChannel",
          ]
          Resource = "*"
        }
      ]
    })
  }

  # Inline policy: CDKCustom
  inline_policy {
    name = "CDKCustom"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Sid    = "GuardDutytest"
          Effect = "Allow"
          Action = [
            "ecr:BatchCheckLayerAvailability",
            "ecr:BatchGetImage",
            "ecr:GetAuthorizationToken",
            "ecr:GetDownloadUrlForLayer",
            "guardduty:SendSecurityTelemetry",
          ]
          Resource = "*"
        },
        {
          Sid    = "S3KobieReadAccess"
          Effect = "Allow"
          Action = [
            "s3:GetBucketLocation",
            "s3:GetObject",
            "s3:GetObjectVersion",
            "s3:ListBucket",
          ]
          Resource = [
            "arn:aws:s3:::is-ecoupon-d-128211541887-us-east-1*",
            "arn:aws:s3:::is-ecoupon-d-128211541887-us-east-1/*",
          ]
        },
        {
          Sid    = "S3CustomKMSAccess"
          Effect = "Allow"
          Action = [
            "kms:Decrypt",
            "kms:DescribeKey",
          ]
          Resource = "arn:aws:kms:us-east-1:128211541887:key/40268282-b811-4a49-8d71-1708f736a086*"
        },
      ]
    })
  }

  # Inline policy: AllowCWAccess
  inline_policy {
    name = "AllowCWAccess"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect   = "Allow"
          Action   = "secretsmanager:GetSecretValue"
          Resource = "*"
        }
      ]
    })
  }

  tags = local.common_tags
}

resource "aws_iam_role_policy" "task_role_default" {
  name = "taskroleisaiworkspacejupyterhubdDefaultPolicy8BD3C6EE"
  role = aws_iam_role.task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:PutLogEvents",
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel",
        ]
        Resource = "*"
      }
    ]
  })
}

# ---------------------------------------------------------------------------
# ALB Security Group (isaiworkspacejupyterhubdALB...)
# ---------------------------------------------------------------------------

resource "aws_security_group" "alb" {
  description = "SecurityGroup for is-aiworkspace-jupyterhub-d ALB"
  vpc_id      = local.vpc_id

  ingress {
    description = "Open LB for incoming traffic"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }
  ingress {
    description = "Open LB for incoming traffic"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }
  ingress {
    description = "Open LB for VPN incoming traffic"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["172.16.0.0/12"]
  }
  ingress {
    description = "Open LB for VPN incoming traffic"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["172.16.0.0/12"]
  }

  egress {
    description = "Allow all outbound traffic by default"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# Application Load Balancer (LBisaiworkspacejupyterhubd...)
# ---------------------------------------------------------------------------

resource "aws_lb" "main" {
  name               = "is-aiworkspace-jupyterhub-d-alb"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = local.alb_subnets

  enable_deletion_protection = false
  enable_http2               = false
  idle_timeout               = 1000
  drop_invalid_header_fields = true
  desync_mitigation_mode     = "strictest"

  tags = local.common_tags
}

# Blue (production) target group used by the ECS service / PublicListener
resource "aws_lb_target_group" "blue" {
  name             = "is-aiworkspace-jupyterhub-d-blue"
  port             = 8000
  protocol         = "HTTP"
  protocol_version = "HTTP1"
  target_type      = "instance"
  vpc_id           = local.vpc_id

  health_check {
    interval            = 30
    path                = "/hub"
    port                = "traffic-port"
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 2
    matcher             = "200-302"
  }

  stickiness {
    enabled         = true
    type            = "lb_cookie"
    cookie_duration = 604800
  }

  tags = local.common_tags
}

# Green target group (blue/green deployments)
resource "aws_lb_target_group" "green" {
  name             = "is-aiworkspace-jupyterhub-d-green"
  port             = 8000
  protocol         = "HTTP"
  protocol_version = "HTTP1"
  target_type      = "instance"
  vpc_id           = local.vpc_id

  health_check {
    enabled             = true
    interval            = 30
    path                = "/hub"
    port                = "traffic-port"
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 2
    matcher             = "200-302"
  }

  stickiness {
    enabled         = true
    type            = "lb_cookie"
    cookie_duration = 604800
  }

  tags = local.common_tags
}

# Public (prod) listener on port 80 (HTTPS per source template)
resource "aws_lb_listener" "public" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-Res-2021-06"
  certificate_arn   = local.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.blue.arn
  }

  # CodeDeploy blue/green swaps the target group; ignore drift.
  lifecycle {
    ignore_changes = [default_action]
  }
}

# Green (test) listener on port 443
resource "aws_lb_listener" "green" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-Res-2021-06"
  certificate_arn   = local.certificate_arn

  default_action {
    type = "forward"
    forward {
      target_group {
        arn    = aws_lb_target_group.green.arn
        weight = 1
      }
      stickiness {
        enabled  = true
        duration = 604800
      }
    }
  }

  lifecycle {
    ignore_changes = [default_action]
  }
}

# ---------------------------------------------------------------------------
# SSM Parameters exposing the LB ARN and DNS name
# ---------------------------------------------------------------------------

resource "aws_ssm_parameter" "lb_arn" {
  name        = "/amtrak/is/aiworkspace/jupyterhub/lb-arn"
  description = "LB ARN for is-aiworkspace-jupyterhub-d in d"
  type        = "String"
  value       = aws_lb.main.arn
  tags        = local.common_tags
}

resource "aws_ssm_parameter" "lb_dns" {
  name        = "/amtrak/is/aiworkspace/jupyterhub/lb-dns-name"
  description = "LB DNS Name for is-aiworkspace-jupyterhub-d in d"
  type        = "String"
  value       = aws_lb.main.dns_name
  tags        = local.common_tags
}

# ---------------------------------------------------------------------------
# ECS Cluster + capacity provider association
# ---------------------------------------------------------------------------

resource "aws_ecs_cluster" "main" {
  name = local.cluster_name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = local.common_tags
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name       = aws_ecs_cluster.main.name
  capacity_providers = [aws_ecs_capacity_provider.main.name]
}

# ---------------------------------------------------------------------------
# EC2 AutoScaling security group + instance role/profile
# ---------------------------------------------------------------------------

resource "aws_security_group" "asg_ec2" {
  description = "Security group for ECS EC2 instances"
  vpc_id      = local.vpc_id

  ingress {
    description     = "from ALB:ALL TRAFFIC"
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "Allow all outbound traffic by default"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.common_tags
}

resource "aws_iam_role" "asg_instance" {
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = { Service = "ec2.amazonaws.com" }
      }
    ]
  })

  managed_policy_arns = [
    "arn:${data.aws_partition.ec2.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore",
    "arn:${data.aws_partition.ec2.partition}:iam::aws:policy/CloudWatchAgentServerPolicy",
    "arn:aws:iam::128211541887:policy/amtrak/project-efs-fullaccess",
  ]

  tags = merge(local.common_tags, {
    Name = "is-aiworkspace-jupyterhub-ecs-pipeline/dev/is-aiworkspace-jupyterhub-d-us-east-1-stack/is-aiworkspace-jupyterhub-dAutoScalingGroup"
  })
}

resource "aws_iam_role_policy" "asg_instance_default" {
  name = "isaiworkspacejupyterhubdAutoScalingGroupInstanceRoleDefaultPolicyB8578095"
  role = aws_iam_role.asg_instance.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecs:DeregisterContainerInstance",
          "ecs:RegisterContainerInstance",
          "ecs:Submit*",
        ]
        Resource = aws_ecs_cluster.main.arn
      },
      {
        Effect = "Allow"
        Action = [
          "ecs:Poll",
          "ecs:StartTelemetrySession",
        ]
        Resource = "*"
        Condition = {
          ArnEquals = {
            "ecs:cluster" = aws_ecs_cluster.main.arn
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecs:DiscoverPollEndpoint",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ]
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_instance_profile" "asg_instance" {
  role = aws_iam_role.asg_instance.name
}

# ---------------------------------------------------------------------------
# Launch configuration + AutoScaling group
# ---------------------------------------------------------------------------

resource "aws_launch_configuration" "ecs" {
  image_id             = data.aws_ssm_parameter.ecs_optimized_ami.value
  instance_type        = "m6a.8xlarge"
  iam_instance_profile = aws_iam_instance_profile.asg_instance.name
  security_groups      = [aws_security_group.asg_ec2.id]

  metadata_options {
    http_tokens = "required"
  }

  user_data = <<-EOT
    #!/bin/bash
    echo ECS_CLUSTER=${local.cluster_name} >> /etc/ecs/ecs.config
    sudo iptables --insert FORWARD 1 --in-interface docker+ --destination 169.254.169.254/32 --jump DROP
    sudo service iptables save
    echo ECS_AWSVPC_BLOCK_IMDS=true >> /etc/ecs/ecs.config
  EOT

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_iam_role_policy.asg_instance_default,
    aws_iam_role.asg_instance,
  ]
}

resource "aws_autoscaling_group" "ecs" {
  launch_configuration  = aws_launch_configuration.ecs.name
  min_size              = 1
  max_size              = 6
  desired_capacity      = 1
  protect_from_scale_in = true
  vpc_zone_identifier   = local.alb_subnets

  dynamic "tag" {
    for_each = merge(local.common_tags, {
      Name = "is-aiworkspace-jupyterhub-ecs-pipeline/dev/is-aiworkspace-jupyterhub-d-us-east-1-stack/is-aiworkspace-jupyterhub-dAutoScalingGroup"
    })
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  # UpdatePolicy: IgnoreUnmodifiedGroupSizeProperties
  lifecycle {
    ignore_changes = [desired_capacity]
  }
}

# ---------------------------------------------------------------------------
# ECS Capacity Provider backed by the ASG
# ---------------------------------------------------------------------------

resource "aws_ecs_capacity_provider" "main" {
  name = "is-aiworkspace-jupyterhub-d-cp"

  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.ecs.arn
    managed_termination_protection = "ENABLED"

    managed_scaling {
      status          = "ENABLED"
      target_capacity = 100
    }
  }

  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# Application secret (appSecret)
# ---------------------------------------------------------------------------

resource "aws_secretsmanager_secret" "app" {
  name = "/amtrak/project/is/aiworkspace/jupyterhub/d/app"
  tags = local.common_tags
}

resource "aws_secretsmanager_secret_version" "app" {
  secret_id = aws_secretsmanager_secret.app.id
  secret_string = jsonencode({
    DOMAIN                = "Set Me"
    AAD_TENANT_ID         = "Set Me"
    AAD_APP_CLIENT_ID     = "Set Me"
    AAD_APP_CLIENT_SECRET = "Set Me"
  })
}

# ---------------------------------------------------------------------------
# CloudWatch Log Group (ecsisaiworkspacejupyterhubdLogGroup)
# ---------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "ecs" {
  name              = "ecs/is-aiworkspace-jupyterhub-d"
  retention_in_days = 30
  tags              = local.common_tags

  # DeletionPolicy / UpdateReplacePolicy: Retain
  lifecycle {
    prevent_destroy = true
  }
}

# ---------------------------------------------------------------------------
# ECS Task Definition (isaiworkspacejupyterhubdTaskDefinition2)
# ---------------------------------------------------------------------------

resource "aws_ecs_task_definition" "main" {
  family                   = "is-aiworkspace-jupyterhub-d-TaskDefinition"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.task_role.arn

  container_definitions = jsonencode([
    {
      name       = local.container_name
      image      = local.container_image
      essential  = true
      memory     = 122880
      privileged = false

      entryPoint = ["/bin/sh", "-c"]
      command = [
        <<-EOT
        METADATA=$(curl -s "$${ECS_CONTAINER_METADATA_URI_V4}/task")

        SERVICE_NAME=$(echo "$METADATA" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('ServiceName', d['Family']))")
        TASK_ID=$(echo "$METADATA" | python3 -c "import sys,json; print(json.load(sys.stdin)['TaskARN'].split('/')[-1][:8])")

        export DT_HOST_ID="$${SERVICE_NAME}-$${TASK_ID}"
        echo "DT_HOST_ID=$DT_HOST_ID"

        exec /srv/jupyterhub/run.sh
        EOT
      ]

      environment = [
        { name = "USER_GROUP", value = "admin" },
        { name = "OAUTH_CALLBACK_URL", value = "https://jupyter-dev.amtrak.ad.nrpc/hub/oauth_callback" },
        { name = "JUPYTERHUB_CRYPT_KEY", value = "6ef9cf93112abaae673b2b49dd9a2d11b0959b5431f186af19b836ee6b434851" },
        { name = "DT_TENANT", value = "yef22672" },
        { name = "DT_NETWORK_ZONE", value = "aws.us-east-1.oneagent.dev" },
        { name = "DT_CONNECTION_POINT", value = "https://dynagagent31d.amtrak.ad.nrpc:9999/communication;https://10.224.12.153:9999/communication;https://yef22672.live.dynatrace.com:443" },
        { name = "DT_TAGS", value = "dynatrace=true servicemap=A3I application=A3I-JUPYTERHUB environment=DEV cluster=is-aiworkspace-jupyterhub-d-cluster aws_region=us-east-1" },
        { name = "DT_API_URL", value = "https://yef22672.live.dynatrace.com/api" },
        { name = "DT_TENANT_URL", value = "https://yef22672.live.dynatrace.com" },
      ]

      secrets = [
        { name = "DOMAIN", valueFrom = "${aws_secretsmanager_secret.app.arn}:DOMAIN::" },
        { name = "AAD_TENANT_ID", valueFrom = "${aws_secretsmanager_secret.app.arn}:AAD_TENANT_ID::" },
        { name = "AAD_APP_CLIENT_ID", valueFrom = "${aws_secretsmanager_secret.app.arn}:AAD_APP_CLIENT_ID::" },
        { name = "AAD_APP_CLIENT_SECRET", valueFrom = "${aws_secretsmanager_secret.app.arn}:AAD_APP_CLIENT_SECRET::" },
        { name = "DT_TENANTTOKEN", valueFrom = local.dynatrace_tenant_token_arn },
      ]

      linuxParameters = {
        initProcessEnabled = true
      }

      mountPoints = [
        {
          containerPath = "/notebooks"
          sourceVolume  = "EFSMount"
          readOnly      = false
        }
      ]

      portMappings = [
        {
          containerPort = 8000
          hostPort      = 0
          protocol      = "tcp"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
          "awslogs-stream-prefix" = "us-east-1"
          "awslogs-region"        = "us-east-1"
          mode                    = "non-blocking"
        }
      }
    }
  ])

  volume {
    name = "EFSMount"
    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.main.id
      root_directory     = "/"
      transit_encryption = "ENABLED"
    }
  }

  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# ECS Service security group + rules
# ---------------------------------------------------------------------------

resource "aws_security_group" "service" {
  description = "SecurityGroup for is-aiworkspace-jupyterhub-d Service"
  vpc_id      = local.vpc_id
  tags        = local.common_tags
}

resource "aws_security_group_rule" "service_egress_all" {
  type              = "egress"
  description       = "Allow all outbound traffic by default"
  security_group_id = aws_security_group.service.id
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "service_from_alb_ephemeral" {
  type                     = "ingress"
  description              = "Load balancer to target"
  security_group_id        = aws_security_group.service.id
  from_port                = 32768
  to_port                  = 65535
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
}

resource "aws_security_group_rule" "service_from_alb_8000" {
  type                     = "ingress"
  description              = "from ALB:8000"
  security_group_id        = aws_security_group.service.id
  from_port                = 8000
  to_port                  = 8000
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
}

# ---------------------------------------------------------------------------
# ECS Service (CODE_DEPLOY controller)
# ---------------------------------------------------------------------------

resource "aws_ecs_service" "main" {
  name                = local.service_name
  cluster             = aws_ecs_cluster.main.id
  task_definition     = aws_ecs_task_definition.main.arn
  launch_type         = "EC2"
  scheduling_strategy = "REPLICA"

  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 50

  health_check_grace_period_seconds = 60
  enable_ecs_managed_tags           = true
  enable_execute_command            = true
  propagate_tags                    = "SERVICE"

  deployment_controller {
    type = "CODE_DEPLOY"
  }

  load_balancer {
    container_name   = local.container_name
    container_port   = 8000
    target_group_arn = aws_lb_target_group.blue.arn
  }

  tags = local.common_tags

  # CodeDeploy manages task definition rollouts and target group swaps.
  lifecycle {
    ignore_changes = [task_definition, load_balancer, desired_count]
  }

  depends_on = [
    aws_lb_listener.public,
    aws_iam_role_policy.task_role_default,
  ]
}

# ---------------------------------------------------------------------------
# Application Auto Scaling for the ECS service task count
# ---------------------------------------------------------------------------

resource "aws_appautoscaling_target" "service" {
  max_capacity       = 6
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.main.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "cpu" {
  name               = "isaiworkspacejupyterhubdServiceTaskCountTargetCpuScaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.service.resource_id
  scalable_dimension = aws_appautoscaling_target.service.scalable_dimension
  service_namespace  = aws_appautoscaling_target.service.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value = 60
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}

resource "aws_appautoscaling_policy" "memory" {
  name               = "isaiworkspacejupyterhubdServiceTaskCountTargetMemoryScaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.service.resource_id
  scalable_dimension = aws_appautoscaling_target.service.scalable_dimension
  service_namespace  = aws_appautoscaling_target.service.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value = 60
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
  }
}

# ---------------------------------------------------------------------------
# EFS file system, security group and mount targets
# ---------------------------------------------------------------------------

resource "aws_security_group" "efs" {
  description = "EFS SecurityGroup"
  vpc_id      = local.vpc_id
  tags        = local.common_tags
}

resource "aws_security_group_rule" "efs_egress_all" {
  type              = "egress"
  description       = "Allow all outbound traffic by default"
  security_group_id = aws_security_group.efs.id
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "efs_from_service" {
  type                     = "ingress"
  description              = "from Service:2049"
  security_group_id        = aws_security_group.efs.id
  from_port                = 2049
  to_port                  = 2049
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.service.id
}

resource "aws_security_group_rule" "efs_from_asg_ec2" {
  type                     = "ingress"
  description              = "from AutoScalingEC2SecurityGroup:2049"
  security_group_id        = aws_security_group.efs.id
  from_port                = 2049
  to_port                  = 2049
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.asg_ec2.id
}

resource "aws_efs_file_system" "main" {
  encrypted        = true
  performance_mode = "generalPurpose"

  tags = merge(local.common_tags, {
    Name = "is-aiworkspace-jupyterhub-ecs-pipeline/dev/is-aiworkspace-jupyterhub-d-us-east-1-stack/EFSFS"
  })

  # DeletionPolicy / UpdateReplacePolicy: Retain
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_efs_file_system_policy" "main" {
  file_system_id = aws_efs_file_system.main.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Action    = "*"
        Principal = { AWS = "*" }
        Resource  = "*"
      }
    ]
  })
}

resource "aws_efs_mount_target" "main" {
  count           = length(local.efs_subnet_ids)
  file_system_id  = aws_efs_file_system.main.id
  subnet_id       = local.efs_subnet_ids[count.index]
  security_groups = [aws_security_group.efs.id]
}

# ---------------------------------------------------------------------------
# CodeDeploy application, service role and blue/green deployment group
# ---------------------------------------------------------------------------

resource "aws_codedeploy_app" "main" {
  name             = "is-aiworkspace-jupyterhub-d-Application"
  compute_platform = "ECS"

  tags = local.common_tags
}

resource "aws_iam_role" "codedeploy" {
  path = "/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = { Service = "codedeploy.amazonaws.com" }
      }
    ]
  })

  managed_policy_arns = [
    "arn:${data.aws_partition.ec2.partition}:iam::aws:policy/AWSCodeBuildDeveloperAccess",
    "arn:${data.aws_partition.ec2.partition}:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess",
    "arn:${data.aws_partition.ec2.partition}:iam::aws:policy/AmazonECS_FullAccess",
    "arn:${data.aws_partition.ec2.partition}:iam::aws:policy/CloudWatchLogsFullAccess",
    "arn:${data.aws_partition.ec2.partition}:iam::aws:policy/AWSCodeDeployRoleForECS",
    "arn:${data.aws_partition.ec2.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole",
  ]

  tags = local.common_tags
}

resource "aws_codedeploy_deployment_group" "main" {
  app_name               = aws_codedeploy_app.main.name
  deployment_group_name  = "is-aiworkspace-jupyterhub-d-DeployGroup"
  deployment_config_name = "CodeDeployDefault.ECSAllAtOnce"
  service_role_arn       = aws_iam_role.codedeploy.arn

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }

  blue_green_deployment_config {
    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"
    }
    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 0
    }
  }

  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "BLUE_GREEN"
  }

  ecs_service {
    cluster_name = aws_ecs_cluster.main.name
    service_name = aws_ecs_service.main.name
  }

  load_balancer_info {
    target_group_pair_info {
      prod_traffic_route {
        listener_arns = [aws_lb_listener.public.arn]
      }
      test_traffic_route {
        listener_arns = [aws_lb_listener.green.arn]
      }
      target_group {
        name = aws_lb_target_group.blue.name
      }
      target_group {
        name = aws_lb_target_group.green.name
      }
    }
  }

  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# SNS topic + subscription for autoscaling notifications
# ---------------------------------------------------------------------------

resource "aws_sns_topic" "autoscaling" {
  name         = "is-aiworkspace-jupyterhub-d-autoscaling-notifications"
  display_name = "ECS Auto-scaling notifications for is-aiworkspace-jupyterhub-d"
  tags         = local.common_tags
}

resource "aws_sns_topic_subscription" "autoscaling_email" {
  topic_arn = aws_sns_topic.autoscaling.arn
  protocol  = "email"
  endpoint  = "Emilio.Barcelos@amtrak.com"
}

# ---------------------------------------------------------------------------
# CloudWatch alarms driving scale in/out notifications
# ---------------------------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "is-aiworkspace-jupyterhub-d-cpu-high-alarm"
  alarm_description   = "is-aiworkspace-jupyterhub-d CPU utilization is high - triggering scale out"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 60
  alarm_actions       = [aws_sns_topic.autoscaling.arn]

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.main.name
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  alarm_name          = "is-aiworkspace-jupyterhub-d-cpu-low-alarm"
  alarm_description   = "is-aiworkspace-jupyterhub-d CPU utilization is low - triggering scale in"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 40
  alarm_actions       = [aws_sns_topic.autoscaling.arn]

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.main.name
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "memory_high" {
  alarm_name          = "is-aiworkspace-jupyterhub-d-memory-high-alarm"
  alarm_description   = "is-aiworkspace-jupyterhub-d Memory utilization is high - triggering scale out"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 60
  alarm_actions       = [aws_sns_topic.autoscaling.arn]

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.main.name
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "memory_low" {
  alarm_name          = "is-aiworkspace-jupyterhub-d-memory-low-alarm"
  alarm_description   = "is-aiworkspace-jupyterhub-d Memory utilization is low - triggering scale in"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 3
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 40
  alarm_actions       = [aws_sns_topic.autoscaling.arn]

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.main.name
  }

  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# Outputs (CloudFormation Outputs block)
# ---------------------------------------------------------------------------

output "load_balancer_dns" {
  description = "DNS name of the internal ALB"
  value       = aws_lb.main.dns_name
}

output "service_url" {
  description = "HTTPS URL of the service"
  value       = "https://${aws_lb.main.dns_name}"
}
