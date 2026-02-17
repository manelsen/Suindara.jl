using Test
using Suindara
using HTTP

# Mock Plugs
module Plugs
    using Suindara.ConnModule: Conn, resp, halt!
    
    function set_header(conn::Conn)
        push!(conn.resp_headers, "X-Test" => "Scoped")
        return conn
    end

    function set_auth(conn::Conn)
        conn.assigns[:user] = "admin"
        return conn
    end

    function halt_plug(conn::Conn)
        return halt!(conn, 401, "Halted")
    end
end

# Mock Controller
module ScopeController
    using Suindara
    
    function index(conn::Conn)
        return resp(conn, 200, "Index")
    end

    function show(conn::Conn)
        id = conn.params["id"]
        return resp(conn, 200, "Show $id")
    end
    
    function admin_dash(conn::Conn)
        user = get(conn.assigns, :user, "guest")
        return resp(conn, 200, "Admin: $user")
    end
end

@testset "Router Scope & Pipelines" begin

    @router ScopeRouter begin
        # Use valid Julia syntax: pipeline(:name) do ... end
        pipeline(:browser) do
            Plugs.set_header
        end

        pipeline(:auth) do
            Plugs.set_auth
        end

        pipeline(:stopper) do
            Plugs.halt_plug
        end

        # Global scope
        get("/", ScopeController.index)

        scope("/api") do
            pipe_through(:browser)

            get("/users", ScopeController.index)
            
            scope("/v1") do
                # Inherits :browser
                get("/users/:id", ScopeController.show)
                
                # Double scope
                scope("/admin") do
                    pipe_through(:auth)
                    get("/dashboard", ScopeController.admin_dash)
                end
            end
        end

        scope("/protected") do
            pipe_through([:browser, :stopper])
            get("/secret", ScopeController.index)
        end
    end

    @testset "Global Route (No Pipeline)" begin
        req = HTTP.Request("GET", "/", [], "")
        conn = match_and_dispatch(ScopeRouter, req)
        @test conn.status == 200
        @test !haskey(Dict(conn.resp_headers), "X-Test")
    end

    @testset "Scoped Route with Pipeline" begin
        req = HTTP.Request("GET", "/api/users", [], "")
        conn = match_and_dispatch(ScopeRouter, req)
        @test conn.status == 200
        @test Dict(conn.resp_headers)["X-Test"] == "Scoped"
    end

    @testset "Nested Scope inheritance" begin
        req = HTTP.Request("GET", "/api/v1/users/42", [], "")
        conn = match_and_dispatch(ScopeRouter, req)
        @test conn.status == 200
        @test conn.resp_body == "Show 42"
        @test Dict(conn.resp_headers)["X-Test"] == "Scoped"
    end

    @testset "Deeply Nested Scope with multiple pipelines" begin
        req = HTTP.Request("GET", "/api/v1/admin/dashboard", [], "")
        conn = match_and_dispatch(ScopeRouter, req)
        @test conn.status == 200
        @test conn.resp_body == "Admin: admin"
        @test Dict(conn.resp_headers)["X-Test"] == "Scoped" # From :browser
        @test conn.assigns[:user] == "admin" # From :auth
    end

    @testset "Pipeline Halting" begin
        req = HTTP.Request("GET", "/protected/secret", [], "")
        conn = match_and_dispatch(ScopeRouter, req)
        @test conn.status == 401
        @test conn.resp_body == "Halted"
        @test conn.halted == true
    end
end
