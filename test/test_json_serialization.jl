using Test
using Suindara.ConnModule
using HTTP
using JSON3

# Mock struct for testing
struct UserJSON
    id::Int
    name::String
    email::String
end

@testset "JSON Serialization" begin
    # 1. Test Dict Serialization
    req = HTTP.Request("GET", "/", [], "")
    conn = Conn(req)
    
    data = Dict("status" => "ok", "count" => 10)
    conn = json(conn, data)
    
    @test conn.status == 200
    headers = Dict(conn.resp_headers)
    @test haskey(headers, "Content-Type")
    @test headers["Content-Type"] == "application/json"
    
    body_json = JSON3.read(conn.resp_body)
    @test body_json.status == "ok"
    @test body_json.count == 10

    # 2. Test Struct Serialization (UserJSON)
    # JSON3 serializes structs automatically if fields match or are public
    conn = Conn(req)
    user = UserJSON(1, "Alice", "alice@example.com")
    conn = json(conn, 201, user)
    
    @test conn.status == 201
    headers = Dict(conn.resp_headers)
    @test headers["Content-Type"] == "application/json"
    
    body_json = JSON3.read(conn.resp_body)
    @test body_json.id == 1
    @test body_json.name == "Alice"
    @test body_json.email == "alice@example.com"

    # 3. Test NamedTuple Serialization
    conn = Conn(req)
    data_nt = (key="value", code=123)
    conn = json(conn, data_nt)
    
    @test conn.status == 200
    body_json = JSON3.read(conn.resp_body)
    @test body_json.key == "value"
    @test body_json.code == 123
end

@testset "Text & HTML Serialization" begin
    req = HTTP.Request("GET", "/", [], "")
    
    # Text
    conn = Conn(req)
    conn = text(conn, "Hello World")
    @test conn.status == 200
    headers = Dict(conn.resp_headers)
    @test headers["Content-Type"] == "text/plain"
    @test conn.resp_body == "Hello World"
    
    # HTML
    conn = Conn(req)
    conn = html(conn, 404, "<h1>Not Found</h1>")
    @test conn.status == 404
    headers = Dict(conn.resp_headers)
    @test headers["Content-Type"] == "text/html"
    @test conn.resp_body == "<h1>Not Found</h1>"
end
