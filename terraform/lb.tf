resource "yandex_lb_target_group" "my-target-group" {
  name      = "my-target-group"
  region_id = var.region

  dynamic "target" {
    for_each  = "${yandex_compute_instance.app.*.network_interface.0.ip_address}"
    content {  
      subnet_id = var.subnet_id
      address   = target.value
    }
  }
}

resource "yandex_lb_network_load_balancer" "my-external-lb" {
  name = "my-network-lb"

  listener {
    name = "my-listener"
    port = 80
    target_port = 9292
    external_address_spec {
      ip_version = "ipv4"
    }
  }

  attached_target_group {
    target_group_id = "${yandex_lb_target_group.my-target-group.id}"

    healthcheck {
      name = "http"
      http_options {
        port = 9292 
        path = "/"
      }
    }
  }
}
