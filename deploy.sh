#!/bin/bash

# Function to simulate typewriter effect
typewriter() {
  local message="$1"
  local delay=0.005
  for (( i=0; i<${#message}; i++ )); do
    printf "%s" "${message:i:1}"
    sleep $delay
  done
  echo
}

# Print a message indicating the creation of a Docker network
typewriter "Creating Docker network..."

# Remove the existing Docker network named 'mongodb-network' if it exists
docker network rm mongodb-network 

# Create a new Docker network named 'mongodb-network'
docker network create mongodb-network

# Confirm that the Docker network has been successfully created
typewriter "Docker network was successfully created"
echo

# Print a message indicating the start of MongoDB sharded cluster configuration
typewriter "Configuring MongoDB Clusters with Replica Sets"
docker compose up -d

# Checking connectivity with improved readability and error handling
typewriter "Checking connectivity..."

check_connectivity() {
  local container=$1
  local port=$2
  local max_retries=5
  local count=0
  local base_sleep=1  # Base sleep duration in seconds

  while [ $count -lt $max_retries ]; do
    local output=$(docker exec "$container" mongosh --port "$port" --eval "db.runCommand({ ping: 1 })" --quiet)
    
    if echo "$output" | grep -q 'ok'; then
      echo "$container is up and running."
      return 0
    else
      echo "Attempt $((count + 1)) to reach $container failed."
      count=$((count + 1))
      sleep_time=$((base_sleep * 2 ** count))
      echo "Backing off for $sleep_time seconds..."
      sleep "$sleep_time"
    fi
  done

  echo "$container is not reachable or not running after $max_retries attempts."
  exit 1
}

# Initialize the replica set for Shard 1
typewriter "Initializing the Replica Sets..."
typewriter "Replica Set 1 (mongo-shard1-rs)"

docker exec mongo-shard1-1 mongosh --eval "rs.initiate({
  _id: \"mongo-shard1-rs\",
  members: [
    {_id: 0, host: \"mongo-shard1-1:27017\"},
    {_id: 1, host: \"mongo-shard1-2:27017\"},
    {_id: 2, host: \"mongo-shard1-3:27017\"}
  ]
})"
echo

# Initialize the replica set for Shard 2
typewriter "Replica Set 2 (mongo-shard2-rs)"

docker exec mongo-shard2-1 mongosh --eval "rs.initiate({
  _id: \"mongo-shard2-rs\",
  members: [
    {_id: 0, host: \"mongo-shard2-1:27017\"},
    {_id: 1, host: \"mongo-shard2-2:27017\"},
    {_id: 2, host: \"mongo-shard2-3:27017\"}
  ]
})"
echo

# Initialize the replica set
typewriter "Initializing the Config Server Replica Set..."
docker exec -it mongo-config-server-1 mongosh --port 27017 --eval "rs.initiate({                                                                                                 
 _id: \"mongo-config-server-rs\",
 members: [
   {_id: 0, host: \"mongo-config-server-1\"},
   {_id: 1, host: \"mongo-config-server-2\"},
   {_id: 2, host: \"mongo-config-server-3\"}
 ]
})"
echo

typewriter "Checking connectivity..."
# Check connectivity for Shard 1
check_connectivity "mongo-shard1-1" 27017
check_connectivity "mongo-shard1-2" 27017
check_connectivity "mongo-shard1-3" 27017

# Check connectivity for Shard 2
check_connectivity "mongo-shard2-1" 27017
check_connectivity "mongo-shard2-2" 27017
check_connectivity "mongo-shard2-3" 27017

# Check connectivity for Config Servers
check_connectivity "mongo-config-server-1" 27017
check_connectivity "mongo-config-server-2" 27017
check_connectivity "mongo-config-server-3" 27017

# Check connectivity for mongos router
check_connectivity "mongos-router-1" 27017
check_connectivity "mongos-router-2" 27017

typewriter "All instances are reachable and running."
echo

# Connect Shards with mongos
typewriter "Connecting shards to mongos-router-1..."
docker exec -it mongos-router-1 mongosh "mongodb://localhost:27017" --eval "sh.addShard('mongo-shard1-rs/mongo-shard1-1:27017,mongo-shard1-2:27017,mongo-shard1-3:27017')"
docker exec -it mongos-router-1 mongosh "mongodb://localhost:27017" --eval "sh.addShard('mongo-shard2-rs/mongo-shard2-1:27017,mongo-shard2-2:27017,mongo-shard2-3:27017')"

typewriter "Connecting shards to mongos-router-2..."
docker exec -it mongos-router-2 mongosh "mongodb://localhost:27017" --eval "sh.addShard('mongo-shard1-rs/mongo-shard1-1:27017,mongo-shard1-2:27017,mongo-shard1-3:27017')"
docker exec -it mongos-router-2 mongosh "mongodb://localhost:27017" --eval "sh.addShard('mongo-shard2-rs/mongo-shard2-1:27017,mongo-shard2-2:27017,mongo-shard2-3:27017')"