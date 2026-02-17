using Test
using Suindara

@testset "Repo Adapter Pattern" begin

    @testset "create_adapter(:sqlite) retorna SQLiteAdapter" begin
        adapter = Suindara.RepoAdapterModule.create_adapter(:sqlite)
        @test adapter isa Suindara.RepoAdapterModule.AbstractAdapter
    end

    @testset "create_adapter com adapter desconhecido dá erro claro" begin
        @test_throws ErrorException Suindara.RepoAdapterModule.create_adapter(:mysql)
    end

    @testset "convert_placeholders :question mantém ?" begin
        sql = "SELECT * FROM users WHERE id = ? AND name = ?"
        result = Suindara.RepoAdapterModule.convert_placeholders(sql, :question)
        @test result == sql
    end

    @testset "convert_placeholders :dollar converte ? para \$N" begin
        sql = "SELECT * FROM users WHERE id = ? AND name = ?"
        result = Suindara.RepoAdapterModule.convert_placeholders(sql, :dollar)
        @test result == "SELECT * FROM users WHERE id = \$1 AND name = \$2"
    end

    @testset "convert_placeholders :dollar com 5 params" begin
        sql = "INSERT INTO t (a,b,c,d,e) VALUES (?,?,?,?,?)"
        result = Suindara.RepoAdapterModule.convert_placeholders(sql, :dollar)
        @test result == "INSERT INTO t (a,b,c,d,e) VALUES (\$1,\$2,\$3,\$4,\$5)"
    end

    @testset "Repo.connect com default adapter (:sqlite) funciona" begin
        Repo.connect(":memory:")
        Repo.execute("CREATE TABLE adapter_test (id INTEGER PRIMARY KEY, val TEXT)")
        Repo.execute("INSERT INTO adapter_test (val) VALUES (?)", ["hello"])
        rows = Repo.query("SELECT * FROM adapter_test")
        @test length(rows) == 1
        @test first(rows).val == "hello"
    end

    @testset "Repo.connect com adapter=:sqlite explícito funciona" begin
        Repo.connect(":memory:", adapter=:sqlite)
        Repo.execute("CREATE TABLE adapter_test2 (id INTEGER PRIMARY KEY, name TEXT)")
        Repo.execute("INSERT INTO adapter_test2 (name) VALUES (?)", ["Julia"])
        row = Repo.get_one("adapter_test2", 1)
        @test row !== nothing
        @test row.name == "Julia"
    end

    @testset "Repo.connect com adapter=:postgres sem LibPQ dá erro" begin
        @test_throws ErrorException Repo.connect("host=localhost", adapter=:postgres)
    end

    @testset "CRUD via adapter funciona" begin
        Repo.connect(":memory:")
        Repo.execute("CREATE TABLE crud_adapter (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT)")

        ch = cast(Dict("name" => "Alice"), [:name])
        Repo.insert(ch, "crud_adapter")

        row = Repo.get_one("crud_adapter", 1)
        @test row.name == "Alice"

        ch2 = cast(Dict("name" => "Bob"), [:name])
        Repo.update(ch2, "crud_adapter", 1)
        @test Repo.get_one("crud_adapter", 1).name == "Bob"

        Repo.delete("crud_adapter", 1)
        @test Repo.get_one("crud_adapter", 1) === nothing
    end

    @testset "transaction via adapter funciona" begin
        Repo.connect(":memory:")
        Repo.execute("CREATE TABLE txn_adapter (id INTEGER PRIMARY KEY, val INTEGER)")
        Repo.execute("INSERT INTO txn_adapter (val) VALUES (?)", [0])

        Repo.transaction() do
            Repo.execute("UPDATE txn_adapter SET val = 42 WHERE id = 1")
        end
        @test first(Repo.query("SELECT val FROM txn_adapter")).val == 42

        # Rollback on error
        try
            Repo.transaction() do
                Repo.execute("UPDATE txn_adapter SET val = 999 WHERE id = 1")
                error("boom")
            end
        catch
        end
        @test first(Repo.query("SELECT val FROM txn_adapter")).val == 42
    end

end
