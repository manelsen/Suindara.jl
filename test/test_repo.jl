using Test
using Suindara
using SQLite

@testset "Repo Module Tests" begin
    # Use in-memory DB for testing
    db_path = ":memory:"
    
    # 1. Connect
    Repo.connect(db_path)
    
    # 2. Execute (Migration-ish)
    Repo.execute("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT, email TEXT)")
    
    # 3. Insert
    Repo.execute("INSERT INTO users (name, email) VALUES (?, ?)", ["Alice", "alice@example.com"])
    
    # 4. Query
    results = Repo.query("SELECT * FROM users")
    
    # SQLite returns a DataFrame-like object (Tables.jl compatible)
    # We can iterate over it
    row = first(results)
    @test row.name == "Alice"
    @test row.email == "alice@example.com"
    
    # 5. Insert with Changeset
    params = Dict("name" => "Bob", "email" => "bob@example.com")
    ch = cast(params, [:name, :email])
    
    Repo.insert(ch, "users")
    
    bob_results = Repo.query("SELECT * FROM users WHERE name = 'Bob'")
    @test !isempty(bob_results)
    @test first(bob_results).email == "bob@example.com"

    # 6. Security: SQL Injection Protection
    bad_table_name = "users; DROP TABLE users;"
    @test_throws ErrorException Repo.insert(ch, bad_table_name)
end
