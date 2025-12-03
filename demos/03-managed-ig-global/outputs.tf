output "global_lb_ip" {
  description = "Global external L7 load balancer IP (HTTP on port 80)"
  value       = module.global_lb.global_lb_ip
}

output "region_a_backend_internal_lb_ip" {
  description = "Internal backend ILB IP for region A"
  value       = module.region_a_stack.backend_internal_lb_ip
}

output "region_b_backend_internal_lb_ip" {
  description = "Internal backend ILB IP for region B"
  value       = module.region_b_stack.backend_internal_lb_ip
}