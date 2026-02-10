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
    
    # 5. Insert with Changeset (The 'Ecto' Dream)
    # We need a function `Repo.insert(changeset, table_name)`
    
    # Mock changeset
    params = Dict("name" => "Bob", "email" => "bob@example.com")
    ch = cast(params, [:name, :email])
    
    # This function doesn't exist yet, but we want it
    # Repo.insert(ch, "users") 
    
    # Let's verify Bob exists
    # bob_results = Repo.query("SELECT * FROM users WHERE name = 'Bob'")
    # @test !isempty(bob_results)
end
