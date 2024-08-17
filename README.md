## Sharding in MongoDB using docker
An automated shell script for deploying a MongoDB sharded cluster using Docker (created as part of a Xero jog day). The primary aim was to enjoy and experiment with MongoDB clusters for local testing, learning, and adding a dash of fun to my database experience.

This will set up sharding in MongoDB by creating a cluster of Mongo instances with the following components:
1. Config servers
2. Shard servers
3. Mongo routers

These instances are set up using Docker containers. In this repository, we create one config replica set, two shard replica sets, and one Mongo router. Each replica set consists of three Mongo instances.

### Pre-requisites
1. Install docker based on your platform from https://docs.docker.com/engine/install/
2. Install mongosh from https://www.mongodb.com/docs/mongodb-shell/install/

### Deployment

To deploy, execute the following command: 

#### Bash

```shell
./deploy-cluster.sh
```

#### PowerShell

```shell
./deploy-cluster.ps1
```

### MongoDB Setup and Configuration

Connect to the cluster via mongosh command:

```shell
mongosh mongodb://localhost:27100,localhost:27200
```

Once connected to the cluster, follow these commands to create and configure a sharded collection and insert sample data:

```javascript
// Switch to the `payroll` database
use payroll;

// Create the `employees` collection
db.createCollection("employees");

// Enable sharding for the `payroll` database
sh.enableSharding("payroll");

// Create a unique index on the `employeeId` field
db.employees.createIndex({ "employeeId": 1 }, { name: "employeeId_index", unique: true });

// Shard the `employees` collection based on `employeeId` with a hashed sharding key
sh.shardCollection("payroll.employees", { employeeId: "hashed" });

// Insert 10 sample employees
for (let i = 1; i <= 10; i++) {
    db.employees.insertOne({
        employeeId: i,
        fullName: "Employee " + i
    });
}

// Verify the shard distribution
db.employees.getShardDistribution();

```

### Cleanup
For removing all containers and volumes run the following command:

```shell
docker rm -v -f $(docker ps -aq --filter "label=com.docker.compose.project=mongo-cluster")
```