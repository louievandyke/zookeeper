job "zoonavigator" {
  datacenters = ["dc1"]

  group "zoonavigator" {
    network {
      mode = "bridge"

      port "ui" {
        to = 9000
      }
    }

    service {
      connect {
        sidecar_service {
          disable_default_tcp_check = true

          proxy {
            upstreams {
              destination_name = "zookeeper-client-pool"
              local_bind_port  = 2181
            }
          }
        }
      }
    }


    task "zoonavigator" {
      driver = "docker"

      env {
        HTTP_PORT = 9000
        CONNECTION_LOCALZK_NAME = "Zookeeper Cluster"
        CONNECTION_LOCALZK_CONN = "${NOMAD_UPSTREAM_ADDR_zookeeper-client-pool}"
      }

      config {
        image = "elkozmon/zoonavigator:latest"
        ports = ["ui"]
      }

      resources {
        cpu    = 500
        memory = 256
      }
    }
  }
}