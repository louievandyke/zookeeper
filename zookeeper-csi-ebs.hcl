job "zookeeper" {
    datacenters = ["dc1"]
    type = "service"

    constraint {
        operator = "distinct_hosts"
        value = true
    }

    update {
      max_parallel = 1
      #health_check = "checks"
      #min_healthy_time = "10s"
      #healthy_deadline = "5m"
      #progress_deadline = "10m"
      #auto_revert = false
    }

    #reschedule {
    #  attempts = 1
    #  interval = "24h"
    #  unlimited = false
    #  delay     = "5s"
    #  delay_function = "constant"
    #}

    group "zk1" {
        volume "zk" {
          type      = "csi"
          read_only = false
          source    = "zk1"
          attachment_mode = "file-system"
          access_mode  = "single-node-writer"
          per_alloc  = true

          mount_options {
            fs_type = "ext4"
            mount_flags = ["noatime"]
          }
        }

        #shutdown_delay = "20s"

        count = 1

        restart {
            attempts = 3
            interval = "2m"
            delay = "30s"
            mode = "delay"
        }

        network {
            mode = "bridge"
        }

        service {
            tags = ["admin","zk1"]
            name = "zookeeper-1-admin"
            port = 9010

            meta {
                ZK_ID = "1"
                ALLOC_ID = "${NOMAD_ALLOC_ID}"
            }

            connect {
                sidecar_service {
                    disable_default_tcp_check = true

                }
            }
        }

        service {
            tags = ["leader","zk1"]
            name = "zookeeper-1-leader"
            port = 9011

            meta {
                ZK_ID = "1"
                ALLOC_ID = "${NOMAD_ALLOC_ID}"
            }

            connect {
                sidecar_service {
                    disable_default_tcp_check = true

                    proxy {
                        upstreams {
                            destination_name = "zookeeper-2-leader"
                            local_bind_port  = 9021
                        }
                        upstreams {
                            destination_name = "zookeeper-3-leader"
                            local_bind_port  = 9031
                        }
                    }
                }
            }
        }

        service {
            tags = ["leader-election","zk1"]
            name = "zookeeper-1-leader-election"
            port = 9012

            meta {
                ZK_ID = "1"
                ALLOC_ID = "${NOMAD_ALLOC_ID}"
            }

            connect {
                sidecar_service {
                    disable_default_tcp_check = true

                    proxy {
                        upstreams {
                            destination_name = "zookeeper-2-leader-election"
                            local_bind_port  = 9022
                        }
                        upstreams {
                            destination_name = "zookeeper-3-leader-election"
                            local_bind_port  = 9032
                        }
                    }
                }
            }
        }

        service {
            tags = ["client","zk1"]
            name = "zookeeper-1-client"
            port = 9013

            meta {
                ZK_ID = "1"
                ALLOC_ID = "${NOMAD_ALLOC_ID}"
            }

            check {
                task     = "zookeeper"
                type     = "script"
                name     = "Zookeeper Client Check"
                command  = "bash"
                args     = ["-c", "status=$(echo ruok | nc localhost 9013); echo $status; if [ \"$status\" != \"imok\" ]; then exit 2; fi"]
                interval = "10s"
                timeout  = "1s"
            }

            connect {
                sidecar_service {
                    disable_default_tcp_check = true

                    proxy {
                        upstreams {
                            destination_name = "zookeeper-2-client"
                            local_bind_port  = 9023
                        }
                        upstreams {
                            destination_name = "zookeeper-3-client"
                            local_bind_port  = 9033
                        }
                    }
                }
            }
        }

        service {
            tags = ["client","pool"]
            name = "zookeeper-client-pool"
            port = 9014

            meta {
                ZK_ID = "1"
                ALLOC_ID = "${NOMAD_ALLOC_ID}"
            }

            connect {
                sidecar_service{
                    disable_default_tcp_check = true

                    proxy {
                        # this needs to proxy to the client port
                        local_service_port = 9013
                    }
                }
            }
        }

        task "zookeeper" {
            driver = "docker"

            template {
                destination = "config/zoo.cfg"
                data = <<EOF
tickTime=2000
initLimit=30
syncLimit=2
maxClientCnxns=0
reconfigEnabled=true
dynamicConfigFile=/config/zoo.cfg.dynamic
dataDir=/data
standaloneEnabled=false
quorumListenOnAllIPs=false
admin.serverPort=9010
admin.serverAddress=127.0.0.1
4lw.commands.whitelist=*
EOF
            }

            template {
                destination = "config/zoo.cfg.dynamic"
                data = <<EOF
{{- /*
    In this context the index ($i) correlates with the ZK_ID. We use it to
    derrive the correct port to server ID mappings.
*/ -}}
{{- range $i := loop 1 4 -}}
server.{{$i}} = 127.0.0.1:90{{$i}}1:90{{$i}}2;127.0.0.1:90{{$i}}3
{{ end -}}
EOF
                change_mode = "noop"
            }

            env {
                ZOO_MY_ID = 1
            }

            volume_mount {
                volume      = "zk"
                destination = "/data"
                read_only   = false
            }

            config {
                image = "zookeeper:3.7"

                volumes = [
                    "config:/config",
                    "config/zoo.cfg:/conf/zoo.cfg"
                    ]
            }

            resources {
                cpu = 300
                memory = 256
            }
        }
    }

    group "zk2" {
        volume "zk" {
          type      = "csi"
          read_only = false
          source    = "zk2"
          attachment_mode = "file-system"
          access_mode  = "single-node-writer"
          per_alloc  = true

          mount_options {
            fs_type = "ext4"
            mount_flags = ["noatime"]
          }
        }

        #shutdown_delay = "20s"

        count = 1

        restart {
            attempts = 3
            interval = "10m"
            delay = "10s"
            mode = "delay"
        }

        network {
            mode = "bridge"
        }

        service {
            tags = ["admin","zk2"]
            name = "zookeeper-2-admin"
            port = 9020

            meta {
                ZK_ID = "2"
                ALLOC_ID = "${NOMAD_ALLOC_ID}"
            }

            connect {
                sidecar_service {
                    disable_default_tcp_check = true

                }
            }
        }

        service {
            tags = ["leader","zk2"]
            name = "zookeeper-2-leader"
            port = 9021

            meta {
                ZK_ID = "2"
                ALLOC_ID = "${NOMAD_ALLOC_ID}"
            }

            connect {
                sidecar_service {
                    disable_default_tcp_check = true

                    proxy {
                        upstreams {
                            destination_name = "zookeeper-1-leader"
                            local_bind_port  = 9011
                        }
                        upstreams {
                            destination_name = "zookeeper-3-leader"
                            local_bind_port  = 9031
                        }
                    }
                }
            }
        }

        service {
            tags = ["leader-election","zk2"]
            name = "zookeeper-2-leader-election"
            port = 9022

            meta {
                ZK_ID = "2"
                ALLOC_ID = "${NOMAD_ALLOC_ID}"
            }

            connect {
                sidecar_service {
                    disable_default_tcp_check = true

                    proxy {
                        upstreams {
                            destination_name = "zookeeper-1-leader-election"
                            local_bind_port  = 9012
                        }
                        upstreams {
                            destination_name = "zookeeper-3-leader-election"
                            local_bind_port  = 9032
                        }
                    }
                }
            }
        }

        service {
            tags = ["client","zk2"]
            name = "zookeeper-2-client"
            port = 9023

            meta {
                ZK_ID = "2"
                ALLOC_ID = "${NOMAD_ALLOC_ID}"
            }

            check {
                task     = "zookeeper"
                type     = "script"
                name     = "Zookeeper Client Check"
                command  = "bash"
                args     = ["-c", "status=$(echo ruok | nc localhost 9023); echo $status; if [ \"$status\" != \"imok\" ]; then exit 2; fi"]
                interval = "10s"
                timeout  = "1s"
            }

            connect {
                sidecar_service {
                    disable_default_tcp_check = true

                    proxy {
                        upstreams {
                            destination_name = "zookeeper-1-client"
                            local_bind_port  = 9013
                        }
                        upstreams {
                            destination_name = "zookeeper-3-client"
                            local_bind_port  = 9033
                        }
                    }
                }
            }
        }

        service {
            tags = ["client","pool"]
            name = "zookeeper-client-pool"
            port = 9024

            meta {
                ZK_ID = "2"
                ALLOC_ID = "${NOMAD_ALLOC_ID}"
            }

            connect {
                sidecar_service{
                    disable_default_tcp_check = true

                    proxy {
                        # this needs to proxy to the client port
                        local_service_port = 9023
                    }
                }
            }
        }

        task "zookeeper" {
            driver = "docker"

            template {
                destination = "config/zoo.cfg"
                data = <<EOF
tickTime=2000
initLimit=30
syncLimit=2
maxClientCnxns=0
reconfigEnabled=true
dynamicConfigFile=/config/zoo.cfg.dynamic
dataDir=/data
standaloneEnabled=false
quorumListenOnAllIPs=false
admin.serverPort=9020
admin.serverAddress=127.0.0.1
4lw.commands.whitelist=*
EOF
            }

            template {
                destination = "config/zoo.cfg.dynamic"
                data = <<EOF
{{- /*
    In this context the index ($i) correlates with the ZK_ID. We use it to
    derrive the correct port to server ID mappings.
*/ -}}
{{- range $i := loop 1 4 -}}
server.{{$i}} = 127.0.0.1:90{{$i}}1:90{{$i}}2;127.0.0.1:90{{$i}}3
{{ end -}}
EOF
                change_mode = "noop"
            }

            env {
                ZOO_MY_ID = 2
            }

            volume_mount {
                volume      = "zk"
                destination = "/data"
                read_only   = false
            }

            config {
                image = "zookeeper:3.7"

                volumes = [
                    "config:/config",
                    "config/zoo.cfg:/conf/zoo.cfg"
                    ]
            }

            resources {
                cpu = 300
                memory = 256
            }
        }
    }

    group "zk3" {
        volume "zk" {
          type      = "csi"
          read_only = false
          source    = "zk3"
          attachment_mode = "file-system"
          access_mode  = "single-node-writer"
          per_alloc  = true

          mount_options {
            fs_type = "ext4"
            mount_flags = ["noatime"]
          }
        }

        #shutdown_delay = "20s"

        count = 1

        restart {
            attempts = 3
            interval = "10m"
            delay = "10s"
            mode = "delay"
        }

        network {
            mode = "bridge"
        }

        service {
            tags = ["admin","zk3"]
            name = "zookeeper-3-admin"
            port = 9030

            meta {
                ZK_ID = "3"
                ALLOC_ID = "${NOMAD_ALLOC_ID}"
            }

            connect {
                sidecar_service {
                    disable_default_tcp_check = true

                }
            }
        }

        service {
            tags = ["leader","zk3"]
            name = "zookeeper-3-leader"
            port = 9031

            meta {
                ZK_ID = "3"
                ALLOC_ID = "${NOMAD_ALLOC_ID}"
            }

            connect {
                sidecar_service {
                    disable_default_tcp_check = true

                    proxy {
                        upstreams {
                            destination_name = "zookeeper-1-leader"
                            local_bind_port  = 9011
                        }
                        upstreams {
                            destination_name = "zookeeper-2-leader"
                            local_bind_port  = 9021
                        }
                    }
                }
            }
        }

        service {
            tags = ["leader-election","zk3"]
            name = "zookeeper-3-leader-election"
            port = 9032

            meta {
                ZK_ID = "3"
                ALLOC_ID = "${NOMAD_ALLOC_ID}"
            }

            connect {
                sidecar_service {
                    disable_default_tcp_check = true

                    proxy {
                        upstreams {
                            destination_name = "zookeeper-1-leader-election"
                            local_bind_port  = 9012
                        }
                        upstreams {
                            destination_name = "zookeeper-2-leader-election"
                            local_bind_port  = 9022
                        }
                    }
                }
            }
        }

        service {
            tags = ["client","zk3"]
            name = "zookeeper-3-client"
            port = 9033

            meta {
                ZK_ID = "3"
                ALLOC_ID = "${NOMAD_ALLOC_ID}"
            }

            check {
                task     = "zookeeper"
                type     = "script"
                name     = "Zookeeper Client Check"
                command  = "bash"
                args     = ["-c", "status=$(echo ruok | nc localhost 9033); echo $status; if [ \"$status\" != \"imok\" ]; then exit 2; fi"]
                interval = "10s"
                timeout  = "1s"
            }

            connect {
                sidecar_service {
                    disable_default_tcp_check = true

                    proxy {
                        upstreams {
                            destination_name = "zookeeper-1-client"
                            local_bind_port  = 9013
                        }
                        upstreams {
                            destination_name = "zookeeper-2-client"
                            local_bind_port  = 9023
                        }
                    }
                }
            }
        }

        service {
            tags = ["client","pool"]
            name = "zookeeper-client-pool"
            port = 9034

            meta {
                ZK_ID = "3"
                ALLOC_ID = "${NOMAD_ALLOC_ID}"
            }

            connect {
                sidecar_service{
                    disable_default_tcp_check = true

                    proxy {
                        # this needs to proxy to the client port
                        local_service_port = 9033
                    }
                }
            }
        }

        task "zookeeper" {
            driver = "docker"

            template {
                destination = "config/zoo.cfg"
                data = <<EOF
tickTime=2000
initLimit=30
syncLimit=2
maxClientCnxns=0
reconfigEnabled=true
dynamicConfigFile=/config/zoo.cfg.dynamic
dataDir=/data
standaloneEnabled=false
quorumListenOnAllIPs=false
admin.serverPort=9030
admin.serverAddress=127.0.0.1
4lw.commands.whitelist=*
EOF
            }

            template {
                destination = "config/zoo.cfg.dynamic"
                data = <<EOF
{{- /*
    In this context the index ($i) correlates with the ZK_ID. We use it to
    derrive the correct port to server ID mappings.
*/ -}}
{{- range $i := loop 1 4 -}}
server.{{$i}} = 127.0.0.1:90{{$i}}1:90{{$i}}2;127.0.0.1:90{{$i}}3
{{ end -}}
EOF
                change_mode = "noop"
            }

            env {
                ZOO_MY_ID = 3
            }

            volume_mount {
                volume      = "zk"
                destination = "/data"
                read_only   = false
            }

            config {
                image = "zookeeper:3.7"

                volumes = [
                    "config:/config",
                    "config/zoo.cfg:/conf/zoo.cfg"
                    ]
            }

            resources {
                cpu = 300
                memory = 256
            }
        }
    }
}
