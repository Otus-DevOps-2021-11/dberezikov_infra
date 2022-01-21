variable app_instance_name {
  description = "Name of APP instance"
  default     = "reddit-app"
}
variable public_key_path {
  description = "Path to the public key used for ssh access"
}
variable private_key_path {
  description = "Path to the private key used for ssh access"
}
variable subnet_id {
  description = "Subnets for modules"
}
variable app_disk_image {
  description = "Disk image for reddit app"
  default = "reddit-app-base"
}
