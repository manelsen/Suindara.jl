using Test
using HTTP
using JSON3

# Start server in background? No, difficult to coordinate in script.
# We will just assume the user runs the server in one terminal 
# and this script in another?
# Better: We import the module and mock the server loop or run it async.

# Let's start the server in a separate thread for testing.
include("suintask_app.jl")

# Run Server in background task
server_task = @async SuinTaskApp.start(9999)
sleep(2) # Give it time to boot and migrate

if istaskfailed(server_task)
    println("SERVER FAILED TO START!")
    fetch(server_task) # Rethrow exception
end

const BASE_URL = "http://localhost:9999"

@testset "SuinTask Live Scenario" begin
    # 1. Access Protected Route (Should Fail)
    println("1. Testing Unauthorized Access...")
    try
        HTTP.get("$BASE_URL/tasks")
        @test false # Should have thrown 401
    catch e
        @test e.status == 401
    end

    # 2. Login
    println("2. Logging in...")
    resp = HTTP.post("$BASE_URL/login", ["Content-Type" => "application/json"], JSON3.write(Dict("email" => "admin@suintask.com")))
    @test resp.status == 200
    token = JSON3.read(resp.body).token
    println("   -> Got Token: $token")
    
    headers = ["Authorization" => token, "Content-Type" => "application/json"]

    # 3. Create Task
    println("3. Creating Task...")
    task_payload = Dict("title" => "Finish Suindara Tutorial", "status" => "doing")
    resp = HTTP.post("$BASE_URL/tasks", headers, JSON3.write(task_payload))
    @test resp.status == 201
    
    # 4. List Tasks
    println("4. Listing Tasks...")
    resp = HTTP.get("$BASE_URL/tasks", headers)
    tasks = JSON3.read(resp.body)
    @test length(tasks) >= 1
    @test tasks[1].title == "Finish Suindara Tutorial"

    # 5. Dashboard
    println("5. Checking Dashboard...")
    resp = HTTP.get("$BASE_URL/dashboard")
    stats = JSON3.read(resp.body)
    println("   -> Stats: $stats")
    @test stats.users >= 1
    @test stats.tasks >= 1
end

println("
✅ SuinTask Scenario Passed Successfully!")
exit(0)
