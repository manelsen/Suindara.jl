import asyncio
import aiohttp
import time
import sys
import statistics
import os

async def fetch(session, url, results):
    start = time.perf_counter()
    try:
        async with session.get(url) as response:
            await response.read()
            end = time.perf_counter()
            results.append(end - start)
            return True
    except Exception as e:
        return False

async def worker(url, duration, results):
    async with aiohttp.ClientSession() as session:
        end_time = time.time() + duration
        while time.time() < end_time:
            await fetch(session, url, results)

async def main():
    if len(sys.argv) < 4:
        print("Usage: python bench.py <url> <duration> <concurrency>")
        sys.exit(1)

    url = sys.argv[1]
    duration = int(sys.argv[2])
    concurrency = int(sys.argv[3])
    
    results = [] # Shared list, thread-safe for appends in CPython (GIL) anyway, but we are async
    
    print(f"Benchmarking {url} for {duration}s with concurrency {concurrency}...")
    
    tasks = []
    start_global = time.perf_counter()
    
    # Simple concurrency with asyncio.gather
    # Each worker loops for `duration` seconds independently
    for _ in range(concurrency):
        tasks.append(worker(url, duration, results))
        
    await asyncio.gather(*tasks)
    
    end_global = time.perf_counter()
    total_time = end_global - start_global
    
    count = len(results)
    rps = count / total_time if total_time > 0 else 0
    
    if count > 0:
        avg_latency = statistics.mean(results) * 1000
        p95_latency = statistics.quantiles(results, n=20)[18] * 1000 if count >= 20 else avg_latency
        p99_latency = statistics.quantiles(results, n=100)[98] * 1000 if count >= 100 else p95_latency
    else:
        avg_latency = 0
        p95_latency = 0
        p99_latency = 0
    
    print(f"--- Results for {url} ---")
    print(f"Total Requests: {count}")
    print(f"RPS: {rps:.2f}")
    print(f"Avg Latency: {avg_latency:.2f} ms")
    print(f"P95 Latency: {p95_latency:.2f} ms")
    print(f"P99 Latency: {p99_latency:.2f} ms")

if __name__ == "__main__":
    asyncio.run(main())
