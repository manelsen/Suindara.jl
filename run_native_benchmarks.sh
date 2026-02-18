#!/bin/bash
# Re-export paths just in case
export PATH=$PWD/benchmarks/go_dist/bin:$PWD/benchmarks/cargo/bin:$PATH

RESULTS_FILE="benchmark_results_native.txt"
echo "Native Results" > $RESULTS_FILE

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

run_test "Go (Fiber)" "./benchmarks/go_fiber_app/app" 8090
run_test "Rust (Axum)" "./benchmarks/rust_axum_app/target/release/rust_axum_app" 8091

cat $RESULTS_FILE
