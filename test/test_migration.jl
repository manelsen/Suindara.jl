using Test
using Suindara
using Suindara.MigrationModule
using Suindara.Repo

@testset "Migration System Tests" begin
    # Setup isolated environment
    DB_FILE = "test_migration_suite.db"
    MIG_DIR = "test_migrations_suite"

    # Cleanup start
    rm(DB_FILE, force=true)
    rm(MIG_DIR, recursive=true, force=true)

    Repo.connect(DB_FILE)
    mkpath(MIG_DIR)

    # 1. Generate Migration File
    timestamp = "20990101000000" # Future date to ensure sorting order
    filename = "$(timestamp)_test_table.jl"
    open(joinpath(MIG_DIR, filename), "w") do io
        write(io, """
        using Suindara.MigrationModule
        
        function up()
            create_table("test_items", [
                "id INTEGER PRIMARY KEY",
                "name TEXT"
            ])
        end
        
        function down()
            drop_table("test_items")
        end
        """)
    end

    # 2. Migrate UP
    migrate(MIG_DIR)
    
    # Verify
    Repo.execute("INSERT INTO test_items (name) VALUES ('item1')")
    row = Repo.get_one("test_items", 1)
    @test row.name == "item1"
    
    applied = MigrationModule.get_applied_versions()
    @test timestamp in applied

    # 3. Migrate DOWN (Rollback)
    rollback(MIG_DIR)
    
    # Verify table gone
    try
        Repo.query("SELECT * FROM test_items")
        @test false # Should fail
    catch e
        @test true
    end
    
    applied_after = MigrationModule.get_applied_versions()
    @test !(timestamp in applied_after)

    # Cleanup end
    rm(DB_FILE, force=true)
    rm("$(DB_FILE)-shm", force=true)
    rm("$(DB_FILE)-wal", force=true)
    rm(MIG_DIR, recursive=true, force=true)
end
