variable db_instance_name {
  description = "Name of DB instance"
  default     = "reddit-db"
}
variable public_key_path {
  description = "Path to the public key used for ssh access"
}
variable subnet_id {
  description = "Subnets for modules"
}
variable db_disk_image {
  description = "Disk image for reddit db"
  default = "reddit-db-base"
}
