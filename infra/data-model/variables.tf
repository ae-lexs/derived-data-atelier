variable "min_capacity" {
  type        = number
  description = "Aurora Serverless v2 minimum ACU. Set to 0 for auto-pause; raise to 1.0 before a measurement run (see Module 03–05 run protocols)."
  default     = 0

  validation {
    condition     = contains([0, 0.5, 1.0], var.min_capacity)
    error_message = "min_capacity must be 0, 0.5, or 1.0 for this codelab."
  }
}
