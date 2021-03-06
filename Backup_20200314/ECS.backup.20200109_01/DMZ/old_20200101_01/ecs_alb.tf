#
#
#variable "aws_access_key_id" {}
#variable "aws_secret_access_key" {}
variable "region_name" {}
variable "vpc_name" {}
variable "ecs_name" {}
variable "subnet_name_az1" {}
variable "subnet_name_az2" {}
variable "sg_name" {}
variable "keypair_name" {}
variable "instance_type" {}
variable "no_of_instance" {}
variable "max_instance_size" {}
variable "min_instance_size" {}
variable "desired_capacity" {}
variable "ami_id" {}
variable "user_data_file" {}
variable "running-os" {}
variable "second_asg" {}
variable "ami_id_2" {}
variable "user_data_file_2" {}
variable "running-os_2" {}
variable "container_task_file" {}
variable "container_desired_count" {}
variable "aws_alb_protocol" {}
variable "alb_list_port" {}
variable "alb_target_port" {}
variable "aws_iam_ecs_service_role" {}
variable "aws_iam_ecs_ec2_role" {}
variable "aws_iam_role_policy" {}
#
#
provider "aws" {
  #access_key = var.aws_access_key_id
  #secret_key = var.aws_secret_access_key
  region = var.region_name
}
#
#
resource "aws_alb" "aws_ecs_alb" {
  name     = "${var.ecs_name}-ALB"
  internal = true
  subnets  = ["${var.subnet_name_az1}", "${var.subnet_name_az2}"]
  security_groups = ["${var.sg_name}"]
  enable_http2    = "true"
  idle_timeout    = 600
}

output "alb_output" {
  value = "${aws_alb.aws_ecs_alb.dns_name}"
}

resource "aws_alb_listener" "front_end" {
  load_balancer_arn = "${aws_alb.aws_ecs_alb.id}"
  port              = "${var.alb_list_port}"
  protocol          = "${var.aws_alb_protocol}"

  default_action {
    target_group_arn = "${aws_alb_target_group.ecs-group.id}"
    type             = "forward"
  }
}

resource "aws_alb_target_group" "ecs-group" {
  name       = "${var.ecs_name}-TG"
  port       = "${var.alb_target_port}"
  protocol   = "${var.aws_alb_protocol}"
  vpc_id     = "${var.vpc_name}"
  depends_on = [aws_alb.aws_ecs_alb]

  stickiness {
    type            = "lb_cookie"
    cookie_duration = 300
  }

  health_check {
    path                = "/"
    healthy_threshold   = 5
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    matcher             = "200,301,302"
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

  tag {
    key                 = "Name"
    value               = "${var.ecs_name}_ASG_${var.running-os}"
    propagate_at_launch = true
  }
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

  tag {
    key                 = "Name"
    value               = "${var.ecs_name}_ASG_${var.running-os_2}"
    propagate_at_launch = true
  }
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
  name_prefix     = "${var.ecs_name}-LC-${var.running-os}"
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
  name_prefix     = "${var.ecs_name}-LC-${var.running-os_2}"
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
  name            = "${var.ecs_name}-service"
  cluster         = "${aws_ecs_cluster.ecs_cluster.id}"
  task_definition = "${aws_ecs_task_definition.ecs_service.arn}"
  desired_count   = "${var.container_desired_count}"
  #iam_role        = "${var.aws_iam_ecs_service_role}"
  depends_on      = [aws_iam_role_policy_attachment.ecs-service-attach]

}

# Json file for ECS tasks
data "template_file" "ecs-tasks" {
  template = "${file("${var.container_task_file}")}"

  vars = {
    ecs_cluster  = "${aws_ecs_cluster.ecs_cluster.name}"
    which_region = "${var.region_name}"
  }
}

resource "aws_ecs_task_definition" "ecs_service" {
  family = "${var.ecs_name}-service"
  container_definitions = "${data.template_file.ecs-tasks.rendered}"

}

resource "aws_cloudwatch_log_group" "ecs_service" {
  name = "/${var.ecs_name}/${var.ecs_name}_logs"
}

resource "aws_iam_role_policy_attachment" "ecs-service-attach" {
  role       = "${var.aws_iam_ecs_service_role}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceRole"
}

