using Test
using Suindara
using Suindara.ResourceModule
using HTTP
using JSON3

# --- Test Entity Definition ---
struct Item
    id::Int
    title::String
    price::Float64
end

# Override interface methods for Item
Suindara.ResourceModule.schema(::Type{Item}) = [:title, :price]
Suindara.ResourceModule.table_name(::Type{Item}) = "items"

# Helper: create a Conn with params and optional JSON body
function make_conn(; method="GET", path="/", params=Dict{String,Any}(), json_body=nothing)
    headers = Pair{SubString{String}, SubString{String}}[]
    body = UInt8[]
    if json_body !== nothing
        push!(headers, "Content-Type" => "application/json")
        body = Vector{UInt8}(JSON3.write(json_body))
    end
    req = HTTP.Request(method, path, headers, body)
    conn = Conn(req)
    merge!(conn.params, params)
    if json_body !== nothing
        conn = plug_json_parser(conn)
    end
    return conn
end

@testset "ResourceController Tests" begin
    # Setup: in-memory DB with items table
    Repo.connect(":memory:")
    Repo.execute("CREATE TABLE items (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL, price REAL NOT NULL)")

    @testset "primary_key default" begin
        @test ResourceModule.primary_key(Item) == :id
    end

    @testset "create — happy path" begin
        conn = make_conn(method="POST", json_body=Dict("title" => "Widget", "price" => 9.99))
        result = ResourceController.create(conn, Item)

        @test result.status == 201
        data = JSON3.read(result.resp_body)
        @test data[:title] == "Widget"
        @test data[:price] == 9.99
    end

    @testset "create — missing required field" begin
        conn = make_conn(method="POST", json_body=Dict("title" => "Incomplete"))
        result = ResourceController.create(conn, Item)

        @test result.status == 422
        errors = JSON3.read(result.resp_body)
        @test haskey(errors, :price)
    end

    @testset "index — returns inserted records" begin
        conn = make_conn()
        result = ResourceController.index(conn, Item)

        @test result.status == 200
        data = JSON3.read(result.resp_body)
        @test length(data) >= 1
        @test data[1][:title] == "Widget"
    end

    @testset "index — pagination with limit/offset" begin
        # Insert a second record
        Repo.execute("INSERT INTO items (title, price) VALUES (?, ?)", ["Gadget", 19.99])

        conn = make_conn(params=Dict{String,Any}("limit" => "1", "offset" => "0"))
        result = ResourceController.index(conn, Item)
        data = JSON3.read(result.resp_body)
        @test length(data) == 1

        conn2 = make_conn(params=Dict{String,Any}("limit" => "1", "offset" => "1"))
        result2 = ResourceController.index(conn2, Item)
        data2 = JSON3.read(result2.resp_body)
        @test length(data2) == 1
        @test data2[1][:title] == "Gadget"
    end

    @testset "index — limit clamped to MAX_LIMIT" begin
        conn = make_conn(params=Dict{String,Any}("limit" => "9999"))
        result = ResourceController.index(conn, Item)
        # Should not error; limit internally clamped to 100
        @test result.status == 200
    end

    @testset "index — invalid limit/offset defaults gracefully" begin
        conn = make_conn(params=Dict{String,Any}("limit" => "abc", "offset" => "xyz"))
        result = ResourceController.index(conn, Item)
        @test result.status == 200
    end

    @testset "show — existing record" begin
        conn = make_conn(params=Dict{String,Any}("id" => "1"))
        result = ResourceController.show(conn, Item)

        @test result.status == 200
        data = JSON3.read(result.resp_body)
        @test data[:title] == "Widget"
    end

    @testset "show — non-existent record" begin
        conn = make_conn(params=Dict{String,Any}("id" => "9999"))
        result = ResourceController.show(conn, Item)

        @test result.status == 404
        @test result.halted
    end

    @testset "update — happy path" begin
        conn = make_conn(method="PUT", params=Dict{String,Any}("id" => "1"), json_body=Dict("title" => "Updated Widget", "price" => 12.99))
        result = ResourceController.update(conn, Item)

        @test result.status == 200
        data = JSON3.read(result.resp_body)
        @test data[:title] == "Updated Widget"
        @test data[:price] == 12.99

        # Verify in DB
        row = Repo.get_one("items", 1)
        @test row.title == "Updated Widget"
    end

    @testset "update — non-existent record" begin
        conn = make_conn(method="PUT", params=Dict{String,Any}("id" => "9999"), json_body=Dict("title" => "Ghost"))
        result = ResourceController.update(conn, Item)

        @test result.status == 404
        @test result.halted
    end

    @testset "delete — happy path" begin
        # Insert a disposable record
        Repo.execute("INSERT INTO items (title, price) VALUES (?, ?)", ["ToDelete", 0.01])
        rows = Repo.query("SELECT id FROM items WHERE title = 'ToDelete'")
        del_id = string(first(rows).id)

        conn = make_conn(method="DELETE", params=Dict{String,Any}("id" => del_id))
        result = ResourceController.delete(conn, Item)

        @test result.status == 204
        @test Repo.get_one("items", parse(Int, del_id)) === nothing
    end

    @testset "delete — non-existent record" begin
        conn = make_conn(method="DELETE", params=Dict{String,Any}("id" => "9999"))
        result = ResourceController.delete(conn, Item)

        @test result.status == 404
        @test result.halted
    end

    @testset "index — empty table" begin
        # Clear all records
        Repo.execute("DELETE FROM items")

        conn = make_conn()
        result = ResourceController.index(conn, Item)
        @test result.status == 200
        data = JSON3.read(result.resp_body)
        @test data == []
    end
end
