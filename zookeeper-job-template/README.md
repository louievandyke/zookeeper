# Zookeeper Job Template

This is a levant template for generating a Zookeeper job for Nomad. It was based
around some example Learn guides we have surrounding using Levant to abstract job
specs. Referencing them may prove useful if you intend to modify the template:

- [DRY Nomad Job Specs with Levant](https://learn.hashicorp.com/tutorials/nomad/dry-jobs-levants)
- [Make Abstract Job Specs with Levant](https://learn.hashicorp.com/tutorials/nomad/levant-abstract-jobs)


To run this locally, you will need to have a few things.

- Three clients

  - Each client needs to have a host volume configured named `zk1`, `zk2`,
    and `zk3` respectively. Add additional clients/volumes as required
    if you intend to run a Zookeeper cluster larger than 3.

- [levant](https://releases.hashicorp.com/levant/0.3.0/)

## Consul Connect

The job this generates is intended for deployments where the user desires Zookeeper
to communicate between Zookeeper nodes over Consul Connect service mesh. Consul
doesn't currently support multi-port services, so this requires defining a separate
service for every port Zookeeper exposes. As such, there will be 4 services in
Consul for every Zookeeper node you have running.

### Intentions

You'll need to setup `allow` intentions for the `zookeeper-*-{client,leader,leader-election}`
services so Zookeeper will be able to communicate amongst its various nodes. This
should be scriptable using the [Consul CLI](https://www.consul.io/commands/intention/create)
or the [Consul HTTP API](https://www.consul.io/api-docs/connect/intentions).

To allow other services to access Zookeeper, use the `zookeeper-client-pool` service.
This is a service that routes to the Zookeeper client port on each Zookeeper node
and pools them all together. It also simplifies the required intentions by only
presenting Zookeeper as a single service to outside services.

## `defaults.json` file

This file contains a JSON hash with default values the template references. The
notable settings that will make a difference are:

- `zookeeper.job_name` - The name of the job.
- `zookeeper.image` - The docker image that's used. This was only tested
  using 3.6.3, but should work on newer versions barring major config changes.
- `zookeeper.node_count` - How many Zookeeper nodes are created.
- `zookeeper.resources` - CPU and memory resources allocated per ZK node.
- `zookeeper.datacenters` - Array of datacenters used in the job. Uses `dc1` by
  default.

## `zookeeper.tmpl.nomad` file

This is the levant template file. To render it run:

```
levant render zookeeper.tmpl.nomad > zoo.nomad
```
The resulting `zoo.nomad` job file can be used to to spin up the job wherever
it's required.

## `zoonavigator.job.nomad` file

You can use this to test the deployment out quickly. It should work out-of-the-box
if the deployment worked properly. Just browse to the exposed dynamic port of the
service and connect using the pre-populated option in the bottom dropdown. If things
aren't working, you'll get an error saying it can't connect on `127.0.0.1:2181`.
If things are working, you should be able to create nodes and so on.