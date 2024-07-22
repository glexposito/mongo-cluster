## Sharding in MongoDB using docker (WIP)
An automated shell script for deploying a MongoDB sharded cluster using Docker (created as part of a Xero jog day). The primary aim was to enjoy and experiment with MongoDB clusters for local testing, learning, and adding a dash of fun to my database experience.

This will set up sharding in MongoDB by creating a cluster of Mongo instances with the following components:
1. Config servers
2. Shard servers
3. Mongo routers

These instances are set up using Docker containers. In this repository, we create one config replica set, two shard replica sets, and one Mongo router. Each replica set consists of three Mongo instances.


### Pre-requisites
1. Install docker based on your platform from https://docs.docker.com/engine/install/
2. Install mongosh from https://www.mongodb.com/docs/mongodb-shell/install/

### Deployment (WIP)

To deploy, execute the following command: 

#### Bash

```shell
./deploy-cluster.sh
```

#### PowerShell

```shell
./deploy-cluster.ps1
```