# Function to simulate typewriter effect
function Typewriter {
  param (
      [string]$message
  )
  $delay = 0.005
  foreach ($char in $message.ToCharArray()) {
      Write-Host -NoNewline $char
      Start-Sleep -Milliseconds ($delay * 1000)
  }
  Write-Host
}

# Print a message indicating the creation of a Docker network
Typewriter "Creating Docker network..."

# Remove the existing Docker network named 'mongodb-network' if it exists
docker network rm mongodb-network 

# Create a new Docker network named 'mongodb-network'
docker network create mongodb-network

# Confirm that the Docker network has been successfully created
Typewriter "Docker network was successfully created"
Write-Host

# Print a message indicating the start of MongoDB sharded cluster configuration
Typewriter "Configuring MongoDB Clusters with Replica Sets"
docker-compose up -d

# Checking connectivity with improved readability and error handling
Typewriter "Checking connectivity..."

function Check-Connectivity {
  param (
      [string]$container,
      [int]$port
  )
  $max_retries = 5
  $count = 0
  $base_sleep = 1  # Base sleep duration in seconds

  while ($count -lt $max_retries) {
      $output = docker exec $container mongosh --port $port --eval "db.runCommand({ ping: 1 })" --quiet
      
      if ($output -match 'ok') {
          Write-Host "$container is up and running."
          return
      } else {
          Write-Host "Attempt $($count + 1) to reach $container failed."
          $count++
          $sleep_time = $base_sleep * [math]::Pow(2, $count)
          Write-Host "Backing off for $sleep_time seconds..."
          Start-Sleep -Seconds $sleep_time
      }
  }

  Write-Host "$container is not reachable or not running after $max_retries attempts."
  exit 1
}

# Initialize the replica set for Shard 1
Typewriter "Initializing the Replica Sets..."
Typewriter "Replica Set 1 (mongo-shard1-rs)"

docker exec mongo-shard1-1 mongosh --eval @"
rs.initiate({
_id: "mongo-shard1-rs",
members: [
  {_id: 0, host: "mongo-shard1-1:27017"},
  {_id: 1, host: "mongo-shard1-2:27017"},
  {_id: 2, host: "mongo-shard1-3:27017"}
]
})
"@
Write-Host

# Initialize the replica set for Shard 2
Typewriter "Replica Set 2 (mongo-shard2-rs)"

docker exec mongo-shard2-1 mongosh --eval @"
rs.initiate({
_id: "mongo-shard2-rs",
members: [
  {_id: 0, host: "mongo-shard2-1:27017"},
  {_id: 1, host: "mongo-shard2-2:27017"},
  {_id: 2, host: "mongo-shard2-3:27017"}
]
})
"@
Write-Host

# Initialize the replica set
Typewriter "Initializing the Config Server Replica Set..."
docker exec -it mongo-config-server-1 mongosh --port 27017 --eval @"
rs.initiate({
_id: "mongo-config-server-rs",
members: [
  {_id: 0, host: "mongo-config-server-1"},
  {_id: 1, host: "mongo-config-server-2"},
  {_id: 2, host: "mongo-config-server-3"}
]
})
"@
Write-Host

Typewriter "Checking connectivity..."
# Check connectivity for Shard 1
Check-Connectivity -container "mongo-shard1-1" -port 27017
Check-Connectivity -container "mongo-shard1-2" -port 27017
Check-Connectivity -container "mongo-shard1-3" -port 27017

# Check connectivity for Shard 2
Check-Connectivity -container "mongo-shard2-1" -port 27017
Check-Connectivity -container "mongo-shard2-2" -port 27017
Check-Connectivity -container "mongo-shard2-3" -port 27017

# Check connectivity for Config Servers
Check-Connectivity -container "mongo-config-server-1" -port 27017
Check-Connectivity -container "mongo-config-server-2" -port 27017
Check-Connectivity -container "mongo-config-server-3" -port 27017

# Check connectivity for mongos router
Check-Connectivity -container "mongos-router-1" -port 27017
Check-Connectivity -container "mongos-router-2" -port 27017

Typewriter "All instances are reachable and running."
Write-Host

# Connect Shards with mongos
Typewriter "Connecting shards to mongos-router-1..."
docker exec -it mongos-router-1 mongosh "mongodb://localhost:27017" --eval "sh.addShard('mongo-shard1-rs/mongo-shard1-1:27017,mongo-shard1-2:27017,mongo-shard1-3:27017')"
docker exec -it mongos-router-1 mongosh "mongodb://localhost:27017" --eval "sh.addShard('mongo-shard2-rs/mongo-shard2-1:27017,mongo-shard2-2:27017,mongo-shard2-3:27017')"

Typewriter "Connecting shards to mongos-router-2..."
docker exec -it mongos-router-2 mongosh "mongodb://localhost:27017" --eval "sh.addShard('mongo-shard1-rs/mongo-shard1-1:27017,mongo-shard1-2:27017,mongo-shard1-3:27017')"
docker exec -it mongos-router-2 mongosh "mongodb://localhost:27017" --eval "sh.addShard('mongo-shard2-rs/mongo-shard2-1:27017,mongo-shard2-2:27017,mongo-shard2-3:27017')"
