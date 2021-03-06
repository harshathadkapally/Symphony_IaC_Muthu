provider "aws" {
 # access_key = var.aws_access_key_id
 # secret_key = var.aws_secret_access_key
  region = var.region_name
}
#
#
#locals {
#  ecs_name = "${var.heading_name}-${terraform.workspace}-${var.app_name}"
#}

resource "aws_alb" "aws_ecs_alb" {
  name     = "${var.ecs_name}-ELB"
  internal = true
  subnets  = ["${var.subnet_name_az1}", "${var.subnet_name_az2}"]
  security_groups = ["${var.sg_name}"]
  idle_timeout    = 600
}

output "alb_output" {
  value = "${aws_alb.aws_ecs_alb.dns_name}"
}

resource "aws_alb_listener" "front_end" {
  load_balancer_arn = "${aws_alb.aws_ecs_alb.id}"
  port              = "${var.alb_list_port}"
  protocol          = "${var.aws_alb_protocol}"
  certificate_arn = "arn:aws:acm:us-east-1:945116902499:certificate/6a9617d6-4b80-4ead-b2c6-bd397db760f2"
 # certificate_arn   = "${aws_iam_server_certificate.url1_valouille_fr.arn}"

  default_action {
    target_group_arn = "${aws_alb_target_group.ecs-group[var.container_default_task].id}"
    type             = "forward"
  }
}

resource "aws_alb_listener_rule" "listener_rule" {
  count      = "${length(var.container_def) - 1}"
  listener_arn = "${aws_alb_listener.front_end.arn}"
  
   action {
    type             = "forward"
    target_group_arn = "${aws_alb_target_group.ecs-group[count.index].id}"
  }

  condition {
    path_pattern {
      values = ["${lookup(var.container_def[count.index], "listener_rule")}"]
    }
  }
}


resource "aws_alb_target_group" "ecs-group" {
  count      = "${length(var.container_def)}"
  name       = "${var.ecs_name}-${lookup(var.container_def[count.index], "name")}"
  port       = "${var.alb_target_port}"
  protocol   = "${var.aws_alb_protocol}"
  vpc_id     = "${var.vpc_name}"
  depends_on = [aws_alb.aws_ecs_alb]

  health_check {
    path                = "${lookup(var.container_def[count.index], "searchpath")}"
    protocol            = "${var.aws_alb_protocol}"
    healthy_threshold   = 5
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    matcher             = "${lookup(var.container_def[count.index], "successcode")}"
  }
}

# User data for first ASG instances
data "template_file" "ecs-cluster" {
  template = "${file("${var.user_data_file}")}"

  vars = {
    ecs_cluster = "${aws_ecs_cluster.ecs_cluster.name}"
  }
}

# User data for second ASG instances
data "template_file" "ecs-cluster-2" {
  template = "${file("${var.user_data_file_2}")}"

  vars = {
    ecs_cluster = "${aws_ecs_cluster.ecs_cluster.name}"
  }
}

resource "aws_ecs_cluster" "ecs_cluster" {
  name = "${var.ecs_name}"
}

resource "aws_autoscaling_group" "ecs-cluster" {
  name                      = "${var.ecs_name}_ASG_${var.running-os}"
  vpc_zone_identifier       = ["${var.subnet_name_az1}", "${var.subnet_name_az2}"]
  min_size                  = "${var.min_instance_size}"
  max_size                  = "${var.max_instance_size}"
  desired_capacity          = "${var.desired_capacity}"
  launch_configuration      = "${aws_launch_configuration.ecs-cluster-lc.name}"
  health_check_grace_period = 120
  default_cooldown          = 30
  termination_policies      = ["OldestInstance"]

  #tag {
  #  key                 = "Name"
  #  value               = "${var.ecs_name}_asg_${var.running-os}"
  #  propagate_at_launch = true
  #}
  tags = [
      {
      # 1
      key                 = "Name"
      value               = "${var.ecs_name}_ASG_${var.running-os}"
      propagate_at_launch = true
       },
      {
      # 2
      key                 = "Client"
      value               = "${var.client_name}"
      propagate_at_launch = true
      },
      {
      # 3
      key                 = "Project"
      value               = "${var.project_name}"
      propagate_at_launch = true
      },
      {
      # 4
      key                 = "Service_Name"
      value               = "${var.service_name}"
      propagate_at_launch = true
      },
      {
      # 5
      key                 = "Service_Role"
      value               = "${var.service_role}"
      propagate_at_launch = true
      },
      {
      # 6
      key                 = "Environment"
      value               = "${var.environment_name}"
      propagate_at_launch = true
      },
      {
      # 7
      key                 = "Security_Zone"
      value               = "${var.security_zone}"
      propagate_at_launch = true
      },
      {
      # 8
      key                 = "Billing_Type"
      value               = "${var.billing_type}"
      propagate_at_launch = true
      },
      {
      # 9
      key                 = "OS_Type"
      value               = "Linux"
      propagate_at_launch = true
      },
      {
      # 10
      key                 = "OS_Name"
      value               = "Amazon Linux 2"
      propagate_at_launch = true
      },
      {
      # 11
      key                 = "App_Version"
      value               = "${var.app_version}"
      propagate_at_launch = true
      },
      {
      # 12
      key                 = "Backup_Frequency"
      value               = "${var.backup_frequency}"
      propagate_at_launch = true
      },
      {
      # 13
      key                 = "Backup_Vault"
      value               = "${var.backup_vault}"
      propagate_at_launch = true
      }
  ]
}

resource "aws_autoscaling_group" "ecs-cluster-2" {
  count                     = "${var.second_asg ? 1 : 0}"
  name                      = "${var.ecs_name}_ASG_${var.running-os_2}"
  vpc_zone_identifier       = ["${var.subnet_name_az1}", "${var.subnet_name_az2}"]
  min_size                  = "${var.min_instance_size}"
  max_size                  = "${var.max_instance_size}"
  desired_capacity          = "${var.desired_capacity}"
  launch_configuration      = "${aws_launch_configuration.ecs-cluster-lc-2[count.index].name}"
  health_check_grace_period = 120
  default_cooldown          = 30
  termination_policies      = ["OldestInstance"]

  #tag {
  #  key                 = "Name"
  #  value               = "${var.ecs_name}_asg_${var.running-os_2}"
  #  propagate_at_launch = true
  #}
    tags = [
      {
      # 1
      key                 = "Name"
      value               = "${var.ecs_name}_ASG_${var.running-os_2}"
      propagate_at_launch = true
       },
      {
      # 2
      key                 = "Client"
      value               = "${var.client_name}"
      propagate_at_launch = true
      },
      {
      # 3
      key                 = "Project"
      value               = "${var.project_name}"
      propagate_at_launch = true
      },
      {
      # 4
      key                 = "Service_Name"
      value               = "${var.service_name}"
      propagate_at_launch = true
      },
      {
      # 5
      key                 = "Service_Role"
      value               = "${var.service_role}"
      propagate_at_launch = true
      },
      {
      # 6
      key                 = "Environment"
      value               = "${var.environment_name}"
      propagate_at_launch = true
      },
      {
      # 7
      key                 = "Security_Zone"
      value               = "${var.security_zone}"
      propagate_at_launch = true
      },
      {
      # 8
      key                 = "Billing_Type"
      value               = "${var.billing_type}"
      propagate_at_launch = true
      },
      {
      # 9
      key                 = "OS_Type"
      value               = "Windows"
      propagate_at_launch = true
      },
      {
      # 10
      key                 = "OS_Name"
      value               = "Windows 2019"
      propagate_at_launch = true
      },
      {
      # 11
      key                 = "App_Version"
      value               = "${var.app_version}"
      propagate_at_launch = true
      },
      {
      # 12
      key                 = "Backup_Frequency"
      value               = "${var.backup_frequency}"
      propagate_at_launch = true
      },
      {
      # 13
      key                 = "Backup_Vault"
      value               = "${var.backup_vault}"
      propagate_at_launch = true
      }
  ]
}

resource "aws_autoscaling_policy" "ecs-cluster" {
  name                      = "${var.ecs_name}_autoscaling_${var.running-os}"
  policy_type               = "TargetTrackingScaling"
  estimated_instance_warmup = "90"
  adjustment_type           = "ChangeInCapacity"
  autoscaling_group_name    = "${aws_autoscaling_group.ecs-cluster.name}"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = 70.0
  }
}

resource "aws_autoscaling_policy" "ecs-cluster-2" {
  count                     = "${var.second_asg ? 1 : 0}"
  name                      = "${var.ecs_name}_autoscaling_${var.running-os_2}"
  policy_type               = "TargetTrackingScaling"
  estimated_instance_warmup = "90"
  adjustment_type           = "ChangeInCapacity"
  autoscaling_group_name    = "${aws_autoscaling_group.ecs-cluster-2[count.index].name}"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = 70.0
  }
}


resource "aws_launch_configuration" "ecs-cluster-lc" {
  name_prefix     = "${var.ecs_name}-lc-${var.running-os}"
  security_groups = ["${var.sg_name}"]

  key_name                    = "${var.keypair_name}"
  image_id                    = "${var.ami_id}"
  instance_type               = "${var.instance_type}"
  iam_instance_profile        = "${aws_iam_instance_profile.ecs-ec2-role.id}"
  user_data                   = "${data.template_file.ecs-cluster.rendered}"
  associate_public_ip_address = false

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_launch_configuration" "ecs-cluster-lc-2" {
  count           = "${var.second_asg ? 1 : 0}"
  name_prefix     = "${var.ecs_name}-lc-${var.running-os_2}"
  security_groups = ["${var.sg_name}"]

  key_name                    = "${var.keypair_name}"
  image_id                    = "${var.ami_id_2}"
  instance_type               = "${var.instance_type}"
  iam_instance_profile        = "${aws_iam_instance_profile.ecs-ec2-role.id}"
  user_data                   = "${data.template_file.ecs-cluster-2.rendered}"
  associate_public_ip_address = false

  lifecycle {
    create_before_destroy = true
  }
}


resource "aws_iam_instance_profile" "ecs-ec2-role" {
  name = "${var.ecs_name}-iam-instance-profile"
  role = "${var.aws_iam_ecs_ec2_role}"
}

resource "aws_ecs_service" "ecs_service" {
  count           = "${length(var.container_def)}"
  name            = "${var.ecs_name}-${lookup(var.container_def[count.index], "name")}"
  cluster         = "${aws_ecs_cluster.ecs_cluster.id}"
  task_definition = "${aws_ecs_task_definition.ecs_service[count.index].arn}"
  desired_count   = "${var.container_desired_count}"
  iam_role        = "${var.aws_iam_ecs_service_role}"
  depends_on      = [aws_iam_role_policy_attachment.ecs-service-attach, aws_alb_listener.front_end, aws_alb_listener_rule.listener_rule]

  load_balancer {
    target_group_arn = "${aws_alb_target_group.ecs-group[count.index].id}"
    container_name   = "${var.ecs_name}-${lookup(var.container_def[count.index], "name")}"
    container_port   = "${var.container_port}"
  }

  placement_constraints {
    type       = "memberOf"
    expression = "attribute:ecs.os-type==${lookup(var.container_def[count.index], "os_type")}"
  }
}

#resource "aws_ecs_service" "ecs_service_noalb" {
#  count           = "${length(var.container_noALB_def)}"
#  name            = "${var.ecs_name}-${lookup(var.container_noALB_def[count.index], "name")}"
#  cluster         = "${aws_ecs_cluster.ecs_cluster.id}"
#  task_definition = "${aws_ecs_task_definition.ecs_service_noalb[count.index].arn}"
#  desired_count   = "${var.container_desired_count}"
#  iam_role        = "${var.aws_iam_ecs_service_role}"
#
#  placement_constraints {
#    type       = "memberOf"
#    expression = "attribute:ecs.os-type==${lookup(var.container_noALB_def[count.index], "os_type")}"
#  }
#}


resource "aws_ecs_task_definition" "ecs_service" {
  count           = "${length(var.container_def)}"
  family = "${var.ecs_name}-${lookup(var.container_def[count.index], "name")}"
  cpu = "${lookup(var.container_def[count.index], "cpu")}"
  memory = "${lookup(var.container_def[count.index], "memory")}"
  task_role_arn = "arn:aws:iam::945116902499:role/ecsTaskExecutionRole"
  execution_role_arn = "arn:aws:iam::945116902499:role/ecsTaskExecutionRole"
  container_definitions = "${data.template_file.ecs-tasks[count.index].rendered}"

  placement_constraints {
    type       = "memberOf"
    expression = "attribute:ecs.os-type==${lookup(var.container_def[count.index], "os_type")}"
  }

}

resource "aws_ecs_task_definition" "ecs_service_noalb" {
  count           = "${length(var.container_noALB_def)}"
  family = "${var.ecs_name}-${lookup(var.container_noALB_def[count.index], "name")}"
  cpu = "${lookup(var.container_noALB_def[count.index], "cpu")}"
  memory = "${lookup(var.container_noALB_def[count.index], "memory")}"
  task_role_arn = "arn:aws:iam::945116902499:role/ecsTaskExecutionRole"
  execution_role_arn = "arn:aws:iam::945116902499:role/ecsTaskExecutionRole"
  container_definitions = "${data.template_file.ecs-tasks-noalb[count.index].rendered}"

  placement_constraints {
    type       = "memberOf"
    expression = "attribute:ecs.os-type==${lookup(var.container_noALB_def[count.index], "os_type")}"
  }

}


data "template_file" "ecs-tasks" {
  count    = "${length(var.container_def)}"
  template = "${file("task-definitions/${lookup(var.container_def[count.index], "name")}.json")}"

  vars = {
    container_name  = "${var.ecs_name}-${lookup(var.container_def[count.index], "name")}"
    Ecs_name = "${var.ecs_name}"
    myregion = "${var.region_name}"
  }
}

data "template_file" "ecs-tasks-noalb" {
  count    = "${length(var.container_noALB_def)}"
  template = "${file("task-definitions/${lookup(var.container_noALB_def[count.index], "name")}.json")}"

  vars = {
    container_name  = "${var.ecs_name}-${lookup(var.container_noALB_def[count.index], "name")}"
    Ecs_name = "${var.ecs_name}"
    myregion = "${var.region_name}"
  }
}


resource "aws_cloudwatch_log_group" "ecs_service" {
  name = "/${var.ecs_name}/${var.ecs_name}_logs"
}

resource "aws_iam_role_policy_attachment" "ecs-service-attach" {
  role       = "${var.aws_iam_ecs_service_role}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceRole"
}

