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
typewriter "Configuring MongoDB Sharded Clusters with Replica Sets"

# Configure Shard 1 using the Docker Compose file for shard1
typewriter "Starting Shard 1 (mongo-shard1)..."
docker compose -f shard1/docker-compose.yaml up -d

# Configure Shard 2 using the Docker Compose file for shard2
typewriter "Starting Shard 2 (mongo-shard2)..."
docker compose -f shard2/docker-compose.yaml up -d
echo

# Checking connectivity with improved readability and error handling
typewriter "Checking connectivity..."

check_connectivity() {
  local container=$1
  local port=$2
  local max_retries=3
  local count=0

  while [ $count -lt $max_retries ]; do
    local output=$(docker exec "$container" mongosh --port "$port" --eval "db.runCommand({ ping: 1 })" --quiet)
    
    if echo "$output" | grep -q 'ok: 1'; then
      echo "$container is up and running."
      return 0
    else
      echo "Attempt $((count + 1)) to reach $container failed."
      count=$((count + 1))
      sleep 1
    fi
  done

  echo "$container is not reachable or not running after $max_retries attempts."
  exit 1
}

# Check connectivity for Shard 1
check_connectivity "mongo-shard1-1" 27017
check_connectivity "mongo-shard1-2" 27017
check_connectivity "mongo-shard1-3" 27017

# Check connectivity for Shard 2
check_connectivity "mongo-shard2-1" 27017
check_connectivity "mongo-shard2-2" 27017
check_connectivity "mongo-shard2-3" 27017

typewriter "All MongoDB instances are reachable and running."
echo

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

# Set up the Config server replica set
typewriter "Setting up Config Server Replica Set..."
docker compose -f config/docker-compose.yaml up -d
echo

# Check connectivity for Config Servers
typewriter "Checking connectivity..."
check_connectivity "mongo-config-server-1" 27017
check_connectivity "mongo-config-server-2" 27017
check_connectivity "mongo-config-server-3" 27017

typewriter "All MongoDB instances are reachable and running."
echo

# Initialize the replica set for Shard 1
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