# # ---------------------------------------------------------------------------------------------------------------------#
# Get the name of the region where the Terraform deployment is running
# # ---------------------------------------------------------------------------------------------------------------------#
data "aws_region" "current" {}

# # ---------------------------------------------------------------------------------------------------------------------#
# Get the effective Account ID, User ID, and ARN in which Terraform is authorized.
# # ---------------------------------------------------------------------------------------------------------------------#
data "aws_caller_identity" "current" {}

# # ---------------------------------------------------------------------------------------------------------------------#
# Get the Account ID of the AWS ELB Service Account for the purpose of permitting in S3 bucket policy.
# # ---------------------------------------------------------------------------------------------------------------------#
data "aws_elb_service_account" "current" {}

# # ---------------------------------------------------------------------------------------------------------------------#
# Get AWS Inspector rules available in this region
# # ---------------------------------------------------------------------------------------------------------------------#
data "aws_inspector_rules_packages" "available" {}

# # ---------------------------------------------------------------------------------------------------------------------#
# Get the list of AWS Availability Zones available in this region
# # ---------------------------------------------------------------------------------------------------------------------#
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_availability_zone" "all" {
  for_each = toset(data.aws_availability_zones.available.names)
  name = each.key
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Get the ID of default VPC
# # ---------------------------------------------------------------------------------------------------------------------#
data "aws_vpc" "default" {
  default = true
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Get default subnets from AZ in this region/vpc
# # ---------------------------------------------------------------------------------------------------------------------#
data "aws_subnet_ids" "default" {
   vpc_id = data.aws_vpc.default.id

  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Get all available VPC in this region
# # ---------------------------------------------------------------------------------------------------------------------#
data "aws_vpcs" "available" {}

data "aws_vpc" "all" {
  for_each = data.aws_vpcs.available.ids
  id = each.key
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Get the ID of default Security Group
# # ---------------------------------------------------------------------------------------------------------------------#
data "aws_security_group" "default" {
  vpc_id = data.aws_vpc.default.id

  filter {
    name   = "group-name"
    values = ["default"]
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Get the ID of CloudFront origin request policy
# # ---------------------------------------------------------------------------------------------------------------------#
data "aws_cloudfront_origin_request_policy" "this" {
  name = "Managed-CORS-S3Origin"
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Get the ID of CloudFront cache policy.
# # ---------------------------------------------------------------------------------------------------------------------#
data "aws_cloudfront_cache_policy" "this" {
  name = "Managed-CachingOptimized"
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Get get the latest ID of a registered AMI linux distro by owner and version
# # ---------------------------------------------------------------------------------------------------------------------#
data "aws_ami" "distro" {
  most_recent = true
  #owners      = ["099720109477"] # ubuntu
  owners      = ["136693071363"] # debian

  filter {
    name   = "name"
    #values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-arm64-server-*"] # ubuntu
    values = ["debian-11-arm64*"] # debian
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Variables for user_data templates generation
# # ---------------------------------------------------------------------------------------------------------------------#
data "template_file" "user_data" {
for_each = var.ec2
template = file("./user_data/${each.key}")

vars = {
  
INSTANCE_NAME = "${each.key}"
CIDR = "${aws_vpc.this.cidr_block}"
RESOLVER = "${cidrhost(aws_vpc.this.cidr_block, 2)}"
AWS_DEFAULT_REGION = "${data.aws_region.current.name}"

ALB_DNS_NAME = "${aws_lb.this["inner"].dns_name}"
EFS_DNS_TARGET = "${values(aws_efs_mount_target.this).0.dns_name}"
  
CODECOMMIT_APP_REPO = "codecommit::${data.aws_region.current.name}://${aws_codecommit_repository.app.repository_name}"
CODECOMMIT_SERVICES_REPO = "codecommit::${data.aws_region.current.name}://${aws_codecommit_repository.services.repository_name}"
  
EXTRA_PACKAGES_DEB = "curl jq nfs-common gnupg2 apt-transport-https apt-show-versions ca-certificates lsb-release unzip vim wget git patch python3-pip acl attr imagemagick snmp"
PHP_PACKAGES_DEB = "cli fpm json common mysql zip gd mbstring curl xml bcmath intl soap oauth lz4"

PHP_VERSION = "${var.app["php_version"]}"
PHP_INI = "/etc/php/${var.app["php_version"]}/fpm/php.ini"
PHP_FPM_POOL = "/etc/php/${var.app["php_version"]}/fpm/pool.d/www.conf"
PHP_OPCACHE_INI = "/etc/php/${var.app["php_version"]}/fpm/conf.d/10-opcache.ini"

VERSION = "2"
DOMAIN = "${var.app["domain"]}"
STAGING_DOMAIN = "${var.app["staging_domain"]}"
BRAND = "${var.app["brand"]}"
PHP_USER = "php-${var.app["brand"]}"
ADMIN_EMAIL = "${var.app["admin_email"]}"
WEB_ROOT_PATH = "/home/${var.app["brand"]}/public_html"
TIMEZONE = "${var.app["timezone"]}"
MAGENX_HEADER = "${random_uuid.this.result}"
MYSQL_PATH = "mysql_${random_string.this["mysql_path"].result}"
PROFILER = "${random_string.this["profiler"].result}"
BLOWFISH = "${random_password.this["blowfish"].result}"

 }
}
