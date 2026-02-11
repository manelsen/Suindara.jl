using Test
using Suindara
using Suindara.MigrationModule
using Suindara.Repo

@testset "Migration DDL Tests" begin
    DB_FILE = "test_migration_ddl.db"
    MIG_DIR = "test_migrations_ddl"

    # Cleanup start
    rm(DB_FILE, force=true)
    rm(MIG_DIR, recursive=true, force=true)

    Repo.connect(DB_FILE)
    mkpath(MIG_DIR)

    @testset "create_table — IF NOT EXISTS is idempotent" begin
        create_table("ddl_test", ["id INTEGER PRIMARY KEY", "name TEXT"])
        # Second call should not error
        create_table("ddl_test", ["id INTEGER PRIMARY KEY", "name TEXT"])

        Repo.execute("INSERT INTO ddl_test (name) VALUES (?)", ["works"])
        row = Repo.get_one("ddl_test", 1)
        @test row.name == "works"
    end

    @testset "drop_table — IF EXISTS is idempotent" begin
        drop_table("ddl_test")
        # Second call should not error
        drop_table("ddl_test")

        # Table should be gone
        @test_throws Exception Repo.query("SELECT * FROM ddl_test")
    end

    @testset "add_column — adds column to existing table" begin
        create_table("extendable", ["id INTEGER PRIMARY KEY", "name TEXT"])
        add_column("extendable", "age INTEGER DEFAULT 0")

        Repo.execute("INSERT INTO extendable (name, age) VALUES (?, ?)", ["Alice", 30])
        row = Repo.get_one("extendable", 1)
        @test row.name == "Alice"
        @test row.age == 30
    end

    @testset "Multiple migrations applied in order" begin
        # Create two migration files with ordered timestamps
        open(joinpath(MIG_DIR, "20990101000001_create_animals.jl"), "w") do io
            write(io, """
            using Suindara.MigrationModule
            function up()
                create_table("animals", ["id INTEGER PRIMARY KEY", "species TEXT"])
            end
            function down()
                drop_table("animals")
            end
            """)
        end

        open(joinpath(MIG_DIR, "20990101000002_create_habitats.jl"), "w") do io
            write(io, """
            using Suindara.MigrationModule
            function up()
                create_table("habitats", ["id INTEGER PRIMARY KEY", "biome TEXT"])
            end
            function down()
                drop_table("habitats")
            end
            """)
        end

        migrate(MIG_DIR)

        applied = MigrationModule.get_applied_versions()
        @test "20990101000001" in applied
        @test "20990101000002" in applied

        # Both tables should exist
        Repo.execute("INSERT INTO animals (species) VALUES (?)", ["Cat"])
        Repo.execute("INSERT INTO habitats (biome) VALUES (?)", ["Forest"])
        @test Repo.get_one("animals", 1).species == "Cat"
        @test Repo.get_one("habitats", 1).biome == "Forest"
    end

    @testset "migrate — already up-to-date is no-op" begin
        # Running migrate again should not error
        migrate(MIG_DIR)
        applied = MigrationModule.get_applied_versions()
        @test length(applied) == 2  # Still just the two
    end

    @testset "rollback — only rolls back the last migration" begin
        rollback(MIG_DIR)

        applied = MigrationModule.get_applied_versions()
        @test "20990101000001" in applied
        @test !("20990101000002" in applied)

        # habitats should be gone, animals should remain
        @test_throws Exception Repo.query("SELECT * FROM habitats")
        @test Repo.get_one("animals", 1).species == "Cat"
    end

    @testset "migrate — missing up() raises error" begin
        bad_dir = "test_migrations_bad"
        rm(bad_dir, recursive=true, force=true)
        mkpath(bad_dir)

        open(joinpath(bad_dir, "20990101000003_broken.jl"), "w") do io
            write(io, """
            using Suindara.MigrationModule
            # No up() defined!
            function down()
                drop_table("nothing")
            end
            """)
        end

        @test_throws Exception migrate(bad_dir)

        rm(bad_dir, recursive=true, force=true)
    end

    # Cleanup end
    rm(DB_FILE, force=true)
    rm("$(DB_FILE)-shm", force=true)
    rm("$(DB_FILE)-wal", force=true)
    rm(MIG_DIR, recursive=true, force=true)
end
