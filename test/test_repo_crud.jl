using Test
using Suindara
using Suindara.Repo

@testset "Repo CRUD Operations" begin
    # Setup: in-memory DB with products table
    Repo.connect(":memory:")
    Repo.execute("CREATE TABLE products (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, category TEXT, price REAL)")

    @testset "insert — valid changeset" begin
        ch = cast(Dict("name" => "Laptop", "category" => "Electronics", "price" => 999.99), [:name, :category, :price])
        Repo.insert(ch, "products")

        row = Repo.get_one("products", 1)
        @test row !== nothing
        @test row.name == "Laptop"
        @test row.category == "Electronics"
    end

    @testset "insert — invalid changeset throws" begin
        ch = cast(Dict{String,Any}(), [:name])
        ch = validate_required(ch, [:name])
        @test !ch.valid
        @test_throws ErrorException Repo.insert(ch, "products")
    end

    @testset "get_one — existing row returns NamedTuple" begin
        row = Repo.get_one("products", 1)
        @test row !== nothing
        @test row isa NamedTuple
        @test row.name == "Laptop"
    end

    @testset "get_one — missing ID returns nothing" begin
        row = Repo.get_one("products", 9999)
        @test row === nothing
    end

    @testset "get_one — custom pk parameter" begin
        Repo.execute("CREATE TABLE keyed (code TEXT PRIMARY KEY, label TEXT)")
        Repo.execute("INSERT INTO keyed (code, label) VALUES (?, ?)", ["ABC", "Alpha"])

        row = Repo.get_one("keyed", "ABC", pk="code")
        @test row !== nothing
        @test row.label == "Alpha"

        missing_row = Repo.get_one("keyed", "XYZ", pk="code")
        @test missing_row === nothing
    end

    @testset "update — changes specific fields" begin
        ch = cast(Dict("name" => "Gaming Laptop", "price" => 1299.99), [:name, :price])
        Repo.update(ch, "products", 1)

        row = Repo.get_one("products", 1)
        @test row.name == "Gaming Laptop"
        @test row.price == 1299.99
        @test row.category == "Electronics"  # unchanged
    end

    @testset "update — empty changeset is no-op" begin
        ch = cast(Dict{String,Any}(), [:name])
        # No matching keys → empty changes
        result = Repo.update(ch, "products", 1)
        @test result isa Suindara.ChangesetModule.Changeset

        # Data unchanged
        row = Repo.get_one("products", 1)
        @test row.name == "Gaming Laptop"
    end

    @testset "update — invalid changeset throws" begin
        ch = cast(Dict{String,Any}(), [:name])
        ch = validate_required(ch, [:name])
        @test !ch.valid
        @test_throws ErrorException Repo.update(ch, "products", 1)
    end

    @testset "delete — removes record" begin
        # Insert disposable record
        ch = cast(Dict("name" => "Mouse", "category" => "Accessory", "price" => 25.0), [:name, :category, :price])
        Repo.insert(ch, "products")
        rows = Repo.query("SELECT id FROM products WHERE name = 'Mouse'")
        mouse_id = first(rows).id

        Repo.delete("products", mouse_id)
        @test Repo.get_one("products", mouse_id) === nothing
    end

    @testset "delete — non-existent ID doesn't error" begin
        # Should not throw
        Repo.delete("products", 99999)
    end

    @testset "validate_name — rejects SQL injection" begin
        @test_throws ErrorException Repo.insert(
            cast(Dict("name" => "x"), [:name]),
            "users; DROP TABLE users;"
        )
        @test_throws ErrorException Repo.delete("valid_table", 1, pk="id; DROP TABLE x;")
    end

    @testset "query — returns Vector of NamedTuples" begin
        results = Repo.query("SELECT * FROM products")
        @test results isa Vector
        @test !isempty(results)
        @test first(results) isa NamedTuple
    end

    @testset "transaction — commit on success" begin
        Repo.transaction() do
            Repo.execute("INSERT INTO products (name, category, price) VALUES (?, ?, ?)", ["Keyboard", "Accessory", 75.0])
        end
        rows = Repo.query("SELECT * FROM products WHERE name = 'Keyboard'")
        @test length(rows) == 1
    end

    @testset "transaction — rollback on error" begin
        count_before = length(Repo.query("SELECT * FROM products"))
        try
            Repo.transaction() do
                Repo.execute("INSERT INTO products (name, category, price) VALUES (?, ?, ?)", ["Ghost", "None", 0.0])
                error("Simulated failure")
            end
        catch
        end
        count_after = length(Repo.query("SELECT * FROM products"))
        @test count_after == count_before  # Ghost was rolled back
    end
end
