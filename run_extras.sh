#!/bin/bash
RESULTS_FILE="benchmark_results_extra.txt"
echo "Extra Results" > $RESULTS_FILE

wait_for_port() {
  local port=$1
  local timeout=10
  while ! nc -z 127.0.0.1 $port; do
    sleep 0.5
  done
}

run_test() {
  local name=$1
  local command=$2
  local port=$3
  local url="http://127.0.0.1:$port/"

  echo "Benchmarking $name..."
  $command > /dev/null 2>&1 &
  local pid=$!
  
  if wait_for_port $port; then
    ./venv/bin/python3 benchmarks/bench.py $url 2 10 > /dev/null 2>&1
    echo "--- $name ---" >> $RESULTS_FILE
    ./venv/bin/python3 benchmarks/bench.py $url 10 100 >> $RESULTS_FILE
  fi
  
  kill $pid
  wait $pid 2>/dev/null
}

run_test "Aiohttp" "./venv/bin/python3 benchmarks/aiohttp_app.py" 8088
run_test "Starlette" "./venv/bin/uvicorn benchmarks.starlette_app:app --host 127.0.0.1 --port 8089 --log-level critical" 8089

cat $RESULTS_FILE
