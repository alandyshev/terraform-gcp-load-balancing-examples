output "internal_lb_ip" {
  description = "Internal Load Balancer IP"
  value       = module.internal_lb.internal_lb_ip
}

output "external_lb_ip" {
  description = "External Load Balancer IP"
  value       = module.external_lb.external_lb_ip
}
