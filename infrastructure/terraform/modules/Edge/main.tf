terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      configuration_aliases = [aws.us_east_1]
    }
  }
}

resource "aws_acm_certificate" "cert" {
    provider = aws.us_east_1
    domain_name = var.doamin.name
    validation_method = "DNS"
}

resource "aws_route53_record" "cert_validation" {
    for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }
  allow_overwrite = true
  name =each.value.name
  records = [each.value.record]
  ttl = 60
  type = each.value.type
  zone_id = var.route53_zone_id

}

resource "aws_acm_certificate_validation" "cert" {
    provider = aws.us_east_1
    certificate_arn = aws_acm_certificate.cert.arn
    validation_record_fqdns = [ for record in aws_route53_record.cert_validation :record.fqdn]
}

resource "aws_cloudfront_distribution" "cdn" {
    enabled = true
    aliases = [var.domain_name]

    origin {
        domain_name = var.alb_dns_name
        origin_id = "ALB"
        custom_origin_config {
          http_port = 80
          https_port = 443
          origin_protocol_policy = "http-only"
          origin_ssl_protocols = ["TLSv1.2"]
        }
    }

    default_cache_behavior {
      allowed_methods = ["DELETE" , "GET", "HEAD", "OPTIONS", "PATCH","POST","PUT" ]
      cached_methods = ["GET" , "HEAD"]
      target_origin_id = "ALB"
      viewer_protocol_policy = "redirect-to-https"
      forwarded_values {
        query_string = true
        headers = ["Host" , "Authorization", "CloudFront-Forwarded-Proto"]
        cookies {
          forward = "all"
        }
      }
    }
    viewer_certificate {
        acm_certificate_arn = aws_acm_certificate_validation.cert.certificate_arn
        ssl_support_method = "sni-only"
        minimum_protocol_version = "TLSv1.2_2021"

    }
    
    restrictions {
      geo_restriction {
        restriction_type = "none"
      }
    }
}

## mapping domain to cdn

resource "aws_route53_record" "apex" {
    zone_id = var.route53_zone_id
    name = var.domain_name
    type = "A"
    alias {
        name = aws_cloudfront_distribution.cdn.domain_name
        zone_id = aws_cloudfront_distribution.cdn.hosted_zone_id
        evaluate_target_health = false
    }
}