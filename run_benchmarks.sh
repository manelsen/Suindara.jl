#!/bin/bash

RESULTS_FILE="benchmark_results.txt"
echo "Benchmark Results" > $RESULTS_FILE
echo "=================" >> $RESULTS_FILE

wait_for_port() {
  local port=$1
  local timeout=60
  local interval=1
  local elapsed=0

  while ! nc -z 127.0.0.1 $port; do
    sleep $interval
    elapsed=$((elapsed + interval))
    if [ $elapsed -ge $timeout ]; then
      echo "Timeout waiting for port $port"
      return 1
    fi
  done
  return 0
}

run_test() {
  local name=$1
  local command=$2
  local port=$3
  local url="http://127.0.0.1:$port/"

  echo "Benchmarking $name..."
  echo "Command: $command"
  
  # Run command in background
  $command > /dev/null 2>&1 &
  local pid=$!
  
  if wait_for_port $port; then
    # Warmup run
    echo "Warming up..."
    ./venv/bin/python3 benchmarks/bench.py $url 2 10 > /dev/null 2>&1
    
    # Real run
    echo "Running benchmark..."
    echo "--- $name ---" >> $RESULTS_FILE
    ./venv/bin/python3 benchmarks/bench.py $url 10 100 >> $RESULTS_FILE
  else
    echo "Failed to start $name" >> $RESULTS_FILE
  fi
  
  kill $pid
  wait $pid 2>/dev/null
  sleep 2 # Cooldown
}

# Suindara Master
git checkout master
run_test "Suindara (Master)" "julia --project=. benchmarks/run_suindara.jl" 8080

# Suindara Dev
git checkout dev
# We need to ensure dependencies are resolved if changed, usually Pkg.instantiate is safe
julia --project=. -e 'using Pkg; Pkg.instantiate()'
run_test "Suindara (Dev)" "julia --project=. benchmarks/run_suindara.jl" 8080
git checkout master

# FastAPI
# run_test "FastAPI" "./venv/bin/uvicorn benchmarks.fastapi_app:app --host 127.0.0.1 --port 8081 --log-level critical" 8081

# Flask
# run_test "Flask" "./venv/bin/python3 benchmarks/flask_app.py" 8082

# Express
# run_test "Express" "node benchmarks/express_app.js" 8083

# Fastify
# run_test "Fastify" "node benchmarks/fastify_app.js" 8084

# Django
# Need to use python to run the script directly as configured in single file
# run_test "Django" "./venv/bin/python3 benchmarks/django_app.py runserver 8087 --noreload" 8087

# Genie.jl
# run_test "Genie.jl" "julia --project=benchmarks benchmarks/run_genie.jl" 8085 # Genie defaults to 8000? No, specified 8085 in code? No, let's check code. Code said 8085? No, I wrote 8085. Let's check file content.

# Oxygen.jl
# run_test "Oxygen.jl" "julia --project=benchmarks benchmarks/run_oxygen.jl" 8086

cat $RESULTS_FILE
