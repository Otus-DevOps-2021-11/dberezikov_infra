terraform {
  backend "s3" {
    endpoint   = "storage.yandexcloud.net"
    bucket     = "dberezikov-bucket"
    key        = "prod/terraform.tfstate"
    region     = "ru-central1"
    access_key = "pOqcvy1Aj-iHHLN459oL"
    secret_key = "gvz-QkXPoPiNNfLbhaF0_OKpSYRUJgMBfBqA5rDq"

    skip_region_validation      = true
    skip_credentials_validation = true
  }
}
