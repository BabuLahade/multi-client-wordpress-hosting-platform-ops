terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      configuration_aliases = [aws.global] 
    }
  }
}


resource "aws_wafv2_web_acl" "waf" {
    provider = aws.global
    name = "${var.project_name}-edge-bouncer"
    description = "Block DDoS and brute-force attacks at the edge"
    scope = "CLOUDFRONT"

    default_action{
        allow{}
    }

    rule{
        name = "Block-spam-IPs"
        priority =1

        action{
            block{}
        }

        statement {
            rate_based_statement{
                limit = 600
                aggregate_key_type="IP"
            }
        }
        visibility_config {
            cloudwatch_metrics_enabled = true
            metric_name= "WAFRateLimitRule"
            sampled_requests_enabled = true
        }
    }
    visibility_config {
        cloudwatch_metrics_enabled=true
        metric_name= "WAFGlobalMetrics"
        sampled_requests_enabled = true
    }

}