using Test
using Suindara
using HTTP

# Mock Controller defined at top level
module UserTestController
    using Suindara
    function show(conn::Conn)
        id = conn.params[:id]
        return resp(conn, 200, "User ID: $id")
    end
    
    function post_comment(conn::Conn)
        user_id = conn.params[:user_id]
        post_id = conn.params[:post_id]
        return resp(conn, 200, "User: $user_id, Post: $post_id")
    end
end

@testset "Dynamic Routing Tests" begin

    # Define Router with params
    @router DynamicRouter begin
        get("/users/:id", UserTestController.show)
        get("/users/:user_id/posts/:post_id", UserTestController.post_comment)
    end

    @testset "Match Single Parameter" begin
        req = HTTP.Request("GET", "/users/42", [], "")
        conn = match_and_dispatch(DynamicRouter, req)
        
        @test conn.status == 200
        @test conn.resp_body == "User ID: 42"
        @test conn.params[:id] == "42"
    end

    @testset "Match Multiple Parameters" begin
        req = HTTP.Request("GET", "/users/alice/posts/101", [], "")
        conn = match_and_dispatch(DynamicRouter, req)
        
        @test conn.status == 200
        @test conn.resp_body == "User: alice, Post: 101"
        @test conn.params[:user_id] == "alice"
        @test conn.params[:post_id] == "101"
    end
    
    @testset "No Match still 404" begin
        req = HTTP.Request("GET", "/users/42/invalid", [], "")
        conn = match_and_dispatch(DynamicRouter, req)
        @test conn.status == 404
    end
end