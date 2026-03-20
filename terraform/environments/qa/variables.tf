variable "environment" {
  description = "Ambiente de deployment"
  type        = string
  default     = "qa"
}

variable "vpc_cidr" {
  description = "CIDR block para a VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "instance_type" {
  description = "Tipo da instancia EC2 (Downgrade path: t3.large -> t3.medium -> t3.small)"
  type        = string
  default     = "t3.large"
}

variable "bucket_bronze_name" {
  description = "Nome do bucket da camada Bronze (Raw)"
  type        = string
  default     = "solarize-datalake-bronze"
}

variable "bucket_silver_name" {
  description = "Nome do bucket da camada Silver (Trusted)"
  type        = string
  default     = "solarize-datalake-silver"
}

variable "bucket_gold_name" {
  description = "Nome do bucket da camada Gold (Refined/Platinum)"
  type        = string
  default     = "solarize-datalake-gold"
}
