using Test
using Suindara
using Suindara: @router, match_and_dispatch, resp
using JSON3

dummy_oa_handler(conn) = resp(conn, 200, "ok")

@testset "OpenAPI Module" begin
    OA = Suindara.OpenAPIModule

    @testset "route_to_openapi_path converte :id para {id}" begin
        @test OA.route_to_openapi_path("/users/:id") == "/users/{id}"
        @test OA.route_to_openapi_path("/api/v1/items/:item_id/reviews/:review_id") == "/api/v1/items/{item_id}/reviews/{review_id}"
        @test OA.route_to_openapi_path("/health") == "/health"
    end

    @testset "extract_path_params extrai parâmetros" begin
        params = OA.extract_path_params("/users/:id/posts/:post_id")
        @test length(params) == 2
        @test params[1] == "id"
        @test params[2] == "post_id"
    end

    @testset "extract_path_params sem parâmetros" begin
        params = OA.extract_path_params("/health")
        @test isempty(params)
    end

    @testset "generate_spec retorna Dict válido OpenAPI" begin
        @router OpenAPITestRouter begin
            get("/users", dummy_oa_handler)
            get("/users/:id", dummy_oa_handler)
            post("/users", dummy_oa_handler)
            delete("/users/:id", dummy_oa_handler)
        end

        spec = OA.generate_spec(OpenAPITestRouter, title="TestAPI", version="1.0.0")

        @test spec["openapi"] == "3.0.0"
        @test spec["info"]["title"] == "TestAPI"
        @test spec["info"]["version"] == "1.0.0"
        @test haskey(spec["paths"], "/users")
        @test haskey(spec["paths"], "/users/{id}")
        @test haskey(spec["paths"]["/users"], "get")
        @test haskey(spec["paths"]["/users"], "post")
        @test haskey(spec["paths"]["/users/{id}"], "get")
        @test haskey(spec["paths"]["/users/{id}"], "delete")
    end

    @testset "generate_spec path params incluídos" begin
        @router ParamAPIRouter begin
            get("/items/:id", dummy_oa_handler)
        end

        spec = OA.generate_spec(ParamAPIRouter)
        path_item = spec["paths"]["/items/{id}"]
        get_op = path_item["get"]
        @test haskey(get_op, "parameters")
        @test length(get_op["parameters"]) == 1
        @test get_op["parameters"][1]["name"] == "id"
        @test get_op["parameters"][1]["in"] == "path"
    end

    @testset "spec_to_json retorna JSON válido" begin
        @router JSONTestRouter begin
            get("/ping", dummy_oa_handler)
        end
        spec = OA.generate_spec(JSONTestRouter)
        json_str = OA.spec_to_json(spec)
        @test json_str isa String
        parsed = JSON3.read(json_str)
        @test parsed["openapi"] == "3.0.0"
    end

end
