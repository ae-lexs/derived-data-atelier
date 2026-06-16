variable "image_tag" {
  type        = string
  description = "ECR image tag for the api/ container (the SHA you pushed in § V.1.5). The full image URI is <ecr_repo_url>:<image_tag>."
}

variable "desired_count" {
  type        = number
  description = "Fixed ECS service task count. Pinned at 1 for experiment reproducibility — autoscaling would confound the OLTP p99 signal we measure."
  default     = 1
}

variable "task_cpu" {
  type        = string
  description = "Fargate vCPU units (string per AWS API; 512 = 0.5 vCPU). 512 is the smallest size that comfortably hosts api/ + ADOT sidecar."
  default     = "512"
}

variable "task_memory" {
  type        = string
  description = "Fargate memory in MiB (string per AWS API). 1024 MiB matches the doc V.4.2 ADOT fragment's 512 MiB request plus a small ceiling for api/."
  default     = "1024"
}
