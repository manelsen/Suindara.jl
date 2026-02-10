using Suindara
using Suindara.MigrationModule
using Suindara.Repo
using Test

# Setup Environment
const DB_FILE = "migration_test.db"
const MIG_DIR = "test_migrations"

# Cleanup previous runs
rm(DB_FILE, force=true)
rm(MIG_DIR, recursive=true, force=true)

# 1. Connect DB
Repo.connect(DB_FILE)

# 2. Generate Migration File
println("Generating migration...")
mkpath(MIG_DIR)
timestamp = "20260101000000"
filename = "$(timestamp)_create_users.jl"
open(joinpath(MIG_DIR, filename), "w") do io
    write(io, """
    using Suindara.MigrationModule
    
    function up()
        create_table("users", [
            "id INTEGER PRIMARY KEY",
            "username TEXT NOT NULL"
        ])
    end
    
    function down()
        drop_table("users")
    end
    """)
end

# 3. Migrate UP
println("Running Migrate UP...")
migrate(MIG_DIR)

# Verify table exists
@testset "Migration Up" begin
    # Check if table exists by trying to insert
    Repo.execute("INSERT INTO users (username) VALUES ('admin')")
    row = Repo.get_one("users", 1)
    @test row.username == "admin"
    
    # Check version control
    versions = MigrationModule.get_applied_versions()
    @test timestamp in versions
end

# 4. Migrate DOWN (Rollback)
println("Running Migrate DOWN (Rollback)...")
rollback(MIG_DIR)

@testset "Migration Down" begin
    # Table should be gone
    try
        Repo.query("SELECT * FROM users")
        @test false # Should fail if table exists
    catch e
        @test true # Expected error (no such table)
    end
    
    # Version should be gone
    versions = MigrationModule.get_applied_versions()
    @test !(timestamp in versions)
end

println("Migration System Verified Successfully!")

# Cleanup
rm(DB_FILE, force=true)
rm(MIG_DIR, recursive=true, force=true)
