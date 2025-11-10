variable "project_id" { 
  type = string 
}

variable "region" { 
  type    = string 
  default = "us-central1" 
}

variable "bq_location" { 
  type    = string 
  default = "US" 
}

variable "image_ref" { 
  type        = string 
  description = "Container image (Artifact Registry)" 
}
variable "source_url" { 
  type        = string 
  description = "Public CSV/JSON URL to ingest" 
}