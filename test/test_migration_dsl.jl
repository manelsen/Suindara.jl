using Test
using Suindara
using Suindara.MigrationModule
using Suindara.Repo

@testset "Migration DSL (SQLite)" begin
    DB_FILE = "test_migration_dsl.db"
    MIG_DIR = "test_migrations_dsl"

    # Cleanup
    rm(DB_FILE, force=true)
    rm(MIG_DIR, recursive=true, force=true)

    Repo.connect(DB_FILE)
    mkpath(MIG_DIR)

    # 1. Create Migration File using DSL
    timestamp = "20240101000000"
    filename = "$(timestamp)_create_users.jl"
    open(joinpath(MIG_DIR, filename), "w") do io
        write(io, """
        using Suindara.MigrationModule
        
        function up()
            create_table(:users) do
                add(:id, :integer; primary_key=true)
                add(:name, :string; null=false)
                add(:age, :integer; default=18)
                add(:is_active, :boolean; default=true)
                timestamps()
            end
            
            add_index(:users, :name)
        end
        
        function down()
            drop_table(:users)
        end
        """)
    end

    # 2. Run Migration
    migrate(MIG_DIR)

    # 3. Verify Table Schema via insert
    Repo.execute("INSERT INTO users (name, age) VALUES (?, ?)", ["Alice", 30])
    
    user = Repo.get_one("users", 1)
    @test user.name == "Alice"
    @test user.age == 30
    @test user.is_active == 1 # SQLite boolean is integer
    @test hasproperty(user, :inserted_at)
    @test hasproperty(user, :updated_at)
    
    # Verify default value
    Repo.execute("INSERT INTO users (name) VALUES (?)", ["Bob"])
    bob = Repo.get_one("users", 2)
    @test bob.age == 18

    # 4. Cleanup
    rm(DB_FILE, force=true)
    rm("$(DB_FILE)-shm", force=true)
    rm("$(DB_FILE)-wal", force=true)
    rm(MIG_DIR, recursive=true, force=true)
end
