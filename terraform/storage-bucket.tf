provider "yandex" {
  service_account_key_file = var.service_account_key_file
  cloud_id                 = var.cloud_id
  folder_id                = var.folder_id
  zone                     = var.zone
}
resource "yandex_storage_bucket" "dberezikov-otus-bucket" {
  access_key    = var.access_key
  secret_key    = var.secret_key
  bucket        = var.bucket
#  force_destroy = true 
}
