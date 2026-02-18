using Test
using Suindara
using HTTP

# Mock Controller
module TestUserController
    using Suindara
    index(conn) = text(conn, "index")
    new(conn) = text(conn, "new")
    create(conn) = text(conn, "create")
    show(conn) = text(conn, "show " * conn.params["id"])
    edit(conn) = text(conn, "edit " * conn.params["id"])
    update(conn) = text(conn, "update " * conn.params["id"])
    delete(conn) = text(conn, "delete " * conn.params["id"])
end

@testset "Resources Macro" begin
    @router ResourceRouter begin
        resources("/users", TestUserController)
    end

    # Test GET /users -> index
    req = HTTP.Request("GET", "/users")
    conn = match_and_dispatch(ResourceRouter, req)
    @test conn.status == 200
    @test conn.resp_body == "index"

    # Test GET /users/new -> new
    req = HTTP.Request("GET", "/users/new")
    conn = match_and_dispatch(ResourceRouter, req)
    @test conn.status == 200
    @test conn.resp_body == "new"

    # Test POST /users -> create
    req = HTTP.Request("POST", "/users")
    conn = match_and_dispatch(ResourceRouter, req)
    @test conn.status == 200
    @test conn.resp_body == "create"

    # Test GET /users/:id -> show
    req = HTTP.Request("GET", "/users/123")
    conn = match_and_dispatch(ResourceRouter, req)
    @test conn.status == 200
    @test conn.resp_body == "show 123"

    # Test GET /users/:id/edit -> edit
    req = HTTP.Request("GET", "/users/123/edit")
    conn = match_and_dispatch(ResourceRouter, req)
    @test conn.status == 200
    @test conn.resp_body == "edit 123"

    # Test PUT /users/:id -> update
    req = HTTP.Request("PUT", "/users/123")
    conn = match_and_dispatch(ResourceRouter, req)
    @test conn.status == 200
    @test conn.resp_body == "update 123"

    # Test PATCH /users/:id -> update
    req = HTTP.Request("PATCH", "/users/123")
    conn = match_and_dispatch(ResourceRouter, req)
    @test conn.status == 200
    @test conn.resp_body == "update 123"

    # Test DELETE /users/:id -> delete
    req = HTTP.Request("DELETE", "/users/123")
    conn = match_and_dispatch(ResourceRouter, req)
    @test conn.status == 200
    @test conn.resp_body == "delete 123"
end
