echo "Creating docker network..."

docker network rm mongodb-network 
docker network create mongodb-network

echo "Docker network was succesfully created"
echo

echo "Configuring MongoDB Sharded Clusters with Replica Sets"
echo "Shard 1 (mongo-shard1)"

docker run -d -p 27101:27017 --name mongo-shard1-1 --network mongodb-network mongo:5 mongod --shardsvr --replSet mongo-shard1-rs --port 27017 --bind_ip localhost,mongo-shard1-1
docker run -d -p 27102:27017 --name mongo-shard1-2 --network mongodb-network mongo:5 mongod --shardsvr --replSet mongo-shard1-rs --port 27017 --bind_ip localhost,mongo-shard1-2
docker run -d -p 27103:27017 --name mongo-shard1-3 --network mongodb-network mongo:5 mongod --shardsvr --replSet mongo-shard1-rs --port 27017 --bind_ip localhost,mongo-shard1-3

echo

echo "Shard 2 (mongo-shard2)"
docker run -d -p 27201:27017 --name mongo-shard2-1 --network mongodb-network mongo:5 mongod --shardsvr --replSet mongo-shard2-rs --port 27017 --bind_ip localhost,mongo-shard2-1
docker run -d -p 27202:27017 --name mongo-shard2-2 --network mongodb-network mongo:5 mongod --shardsvr --replSet mongo-shard2-rs --port 27017 --bind_ip localhost,mongo-shard2-2
docker run -d -p 27203:27017 --name mongo-shard2-3 --network mongodb-network mongo:5 mongod --shardsvr --replSet mongo-shard2-rs --port 27017 --bind_ip localhost,mongo-shard2-3


echo "Checking connectivity"
docker exec -it mongo-shard1-1 mongosh --port 27017 --eval "db.runCommand({ ping: 1 })" | grep ok
docker exec -it mongo-shard1-2 mongosh --port 27017 --eval "db.runCommand({ ping: 1 })" | grep ok
docker exec -it mongo-shard1-3 mongosh --port 27017 --eval "db.runCommand({ ping: 1 })" | grep ok

docker exec -it mongo-shard2-1 mongosh --port 27017 --eval "db.runCommand({ ping: 1 })" | grep ok
docker exec -it mongo-shard2-2 mongosh --port 27017 --eval "db.runCommand({ ping: 1 })" | grep ok
docker exec -it mongo-shard2-3 mongosh --port 27017 --eval "db.runCommand({ ping: 1 })" | grep ok

echo

echo "Initialize the Replica Sets"
docker exec -it mongo-shard1-1 mongosh --eval "rs.initiate({
 _id: \"mongo-shard1-rs\",
 members: [
   {_id: 0, host: \"mongo-shard1-1\"},
   {_id: 1, host: \"mongo-shard1-2\"},
   {_id: 2, host: \"mongo-shard1-3\"}
 ]
})"

docker exec -it mongo-shard2-1 mongosh --eval "rs.initiate({
 _id: \"mongo-shard2-rs\",
 members: [
   {_id: 0, host: \"mongo-shard2-1\"},
   {_id: 1, host: \"mongo-shard2-2\"},
   {_id: 2, host: \"mongo-shard2-3\"}
 ]
})"

docker exec -it mongo-shard1-1 mongosh --eval "rs.status()"
docker exec -it mongo-shard2-1 mongosh --eval "rs.status()"

echo "Setup Config server Replica Set"
docker run -dit --name mongo-config-server-1 --net mongodb-network -p 27001:27017 mongo:5 --configsvr --replSet mongo-config-server-rs --port 27017 --bind_ip localhost,mongo-config-server-1
docker run -dit --name mongo-config-server-2 --net mongodb-network -p 27002:27017 mongo:5 --configsvr --replSet mongo-config-server-rs --port 27017 --bind_ip localhost,mongo-config-server-2
docker run -dit --name mongo-config-server-3 --net mongodb-network -p 27003:27017 mongo:5 --configsvr --replSet mongo-config-server-rs --port 27017 --bind_ip localhost,mongo-config-server-3

echo

echo "Initialize the Replica Sets"
echo "Replica Set 1 (mongo-shard1-rs)"

docker exec -it mongo-shard1-1 mongosh --eval "rs.initiate({
 _id: \"mongo-shard1-rs\",
 members: [
   {_id: 0, host: \"mongo-shard1-1\"},
   {_id: 1, host: \"mongo-shard1-2\"},
   {_id: 2, host: \"mongo-shard1-3\"}
 ]
})"

echo "Replica Set 2 (mongo-shard2-rs)"

docker exec -it mongo-shard1-1 mongosh --eval "rs.initiate({
 _id: \"mongo-shard1-rs\",
 members: [
   {_id: 0, host: \"mongo-shard2-1\"},
   {_id: 1, host: \"mongo-shard2-2\"},
   {_id: 2, host: \"mongo-shard2-3\"}
 ]
})"

