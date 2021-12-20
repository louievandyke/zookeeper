[[- /* The order of the protocols in this list is important. Don't change it!

Ports used are as follows (per node):

- 9010 (admin)
- 9011 (leader)
- 9012 (leader-election)
- 9013 (client)
- 9014 (client pool)

which uses the following pattern:

90${ID}${ProtocolIndex}

*/ -]]
[[- $Protocols := list  "admin" "leader" "leader-election" "client" -]]

[[- /* Template defaults as json */ -]]
[[- $Defaults := (fileContents "defaults.json" | parseJSON ) -]]

[[- /* Load variables over the defaults. */ -]]
[[- $Values := mergeOverwrite $Defaults . -]]

job "[[ $Values.zookeeper.job_name ]]" {
    datacenters = [[ $Values.zookeeper.datacenters | toJson ]]
    type = "service"

    update {
        max_parallel = 1
    }

[[- /* Build Group per ZK Node

This is the primmary loop that's generating the task group for each ZK node.

*/ -]]
[[- range $ID := loop 1 ( int $Values.zookeeper.node_count | add 1) ]]

    group "zk[[ $ID ]]" {
        volume "zk" {
          type      = "host"
          read_only = false
          source    = "zk[[ $ID ]]"
        }
        count = 1

        restart {
            attempts = 10
            interval = "5m"
            delay = "25s"
            mode = "delay"
        }

        network {
            mode = "bridge"
        }

    [[- /* Build Service Blocks

    These contain upstreams for neighboring ZK nodes so they can communicate with
    each other over the service mesh. We skip the node number if it matches the
    one we're currently on (no need to have a Connect upstream to talk to itself!).
    The $i index is pulled from the Protocol's list index.

    */ -]]
    [[- range $i, $Protocol := $Protocols -]]
        [[- $Tags := list $Protocol ( printf "zk%v" $ID ) -]]
        [[- println "" ]]
        service {
            tags = [[ $Tags | toJson ]]
            name = "zookeeper-[[$ID]]-[[$Protocol]]"
            port = 90[[ ( printf "%v%v" $ID $i ) ]]
            [[- println "" ]]
            meta {
                ZK_ID = "[[ $ID ]]"
                ALLOC_ID = "${NOMAD_ALLOC_ID}"
            }
            [[ if eq $Protocol "client" ]]
            check {
                task     = "zookeeper"
                type     = "script"
                name     = "Zookeeper Client Check"
                command  = "bash"
                args     = ["-c", "status=$(echo ruok | nc localhost 90[[$ID]]3); echo $status; if [ \"$status\" != \"imok\" ]; then exit 2; fi"]
                interval = "10s"
                timeout  = "1s"
            }
            [[ end ]]
            connect {
                sidecar_service {
                    disable_default_tcp_check = true
                    [[- println "" ]]
        [[- /* The admin port doesn't need to communicate between nodes, so skip it. */ -]]
        [[- if ne $Protocol "admin" ]]
                    proxy {

            [[- /* Build Connect Proxy Upstream Blocks

            These contain upstreams for neighboring ZK nodes so they can communicate with
            each other over the service mesh. We skip the node number if it matches the
            one we're currently on (no need to have a Connect upstream to talk to itself!).
            The $i index is pulled from the Protocol's list index.

            */ -]]
            [[- range $neighborID := loop 1 ( int $Values.zookeeper.node_count | add 1) ]]
                [[- if ne $neighborID $ID -]]
                    [[- $destName := printf "%v-%v-%v" $Values.zookeeper.service.name $neighborID $Protocol ]]
                        upstreams {
                            destination_name = "[[$destName]]"
                            local_bind_port  = 90[[$neighborID]][[$i]]
                        }
                [[- end -]]
            [[- end ]]
                    }
        [[- end ]]
                }
            }
        }
        [[- end ]]
        [[- /* 
            The client pool service is the one that should be used to allow other
            services to communicate with Zookeeper.
        */ -]]
        [[- println "" ]]
        service {
            tags = ["client","pool"]
            name = "zookeeper-client-pool"
            port = 90[[ $ID ]]4

            meta {
                ZK_ID = "[[ $ID ]]"
                ALLOC_ID = "${NOMAD_ALLOC_ID}"
            }

            connect {
                sidecar_service{
                    disable_default_tcp_check = true

                    proxy {
                        # this needs to proxy to the client port
                        local_service_port = 90[[ $ID ]]3
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
admin.serverPort=90[[ $ID ]]0
admin.serverAddress=127.0.0.1
4lw.commands.whitelist=ruok
EOF
            }

            template {
                destination = "config/zoo.cfg.dynamic"
                data = <<EOF
{{- /*
    In this context the index ($i) correlates with the ZK_ID. We use it to
    derrive the correct port to server ID mappings.
*/ -}}
{{- range $i := loop 1 [[add ( int $Values.zookeeper.node_count ) 1]] -}}
server.{{$i}} = 127.0.0.1:90{{$i}}1:90{{$i}}2;127.0.0.1:90{{$i}}3
{{ end -}}
EOF
                change_mode = "noop"
            }

            env {
                ZOO_MY_ID = [[ $ID ]]
            }

            volume_mount {
                volume      = "zk"
                destination = "/data"
                read_only   = false
            }

            config {
                image = "[[ $Values.zookeeper.image ]]"

                volumes = [
                    "config:/config",
                    "config/zoo.cfg:/conf/zoo.cfg"
                    ]
            }

            resources {
                cpu = [[ $Values.zookeeper.resources.cpu ]]
                memory = [[ $Values.zookeeper.resources.memory ]]
            }
        }
    }
[[- end ]]
}
