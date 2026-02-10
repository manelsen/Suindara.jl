using Test
using Suindara
using Base.Threads

@testset "Repo Concurrency Tests" begin
    # Use a file-based DB for concurrency testing, as :memory: is unique per connection/thread usually
    # But since we use a single global connection protected by a lock, :memory: is fine shared.
    db_path = ":memory:"
    Repo.connect(db_path)
    
    Repo.execute("CREATE TABLE counter (id INTEGER PRIMARY KEY, value INTEGER)")
    Repo.execute("INSERT INTO counter (value) VALUES (0)")
    
    # Define a function to increment the counter concurrently
    function worker()
        for _ in 1:100
            Repo.transaction() do
                current = first(Repo.query("SELECT value FROM counter")).value
                Repo.execute("UPDATE counter SET value = ? WHERE id = 1", [current + 1])
            end
        end
    end
    
    # Run workers in parallel
    tasks = []
    n_threads = 4
    
    for _ in 1:n_threads
        push!(tasks, Threads.@spawn worker())
    end
    
    # Wait for all tasks
    for t in tasks
        wait(t)
    end
    
    final_value = first(Repo.query("SELECT value FROM counter")).value
    expected_value = n_threads * 100
    
    @test final_value == expected_value
end
