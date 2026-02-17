using Test
using Suindara
using HTTP

@testset "Static File Serving" begin

    # Setup: criar diretório temporário com arquivo de teste
    test_dir = mktempdir()
    write(joinpath(test_dir, "style.css"), "body { color: red; }")
    write(joinpath(test_dir, "app.js"), "console.log('hi');")
    mkdir(joinpath(test_dir, "img"))
    write(joinpath(test_dir, "img", "logo.png"), "FAKE_PNG_DATA")

    @testset "guess_mime_type retorna tipo correto" begin
        @test Suindara.StaticFileModule.guess_mime_type("style.css") == "text/css"
        @test Suindara.StaticFileModule.guess_mime_type("app.js") == "application/javascript"
        @test Suindara.StaticFileModule.guess_mime_type("logo.png") == "image/png"
        @test Suindara.StaticFileModule.guess_mime_type("photo.jpg") == "image/jpeg"
        @test Suindara.StaticFileModule.guess_mime_type("data.json") == "application/json"
        @test Suindara.StaticFileModule.guess_mime_type("unknown.xyz") == "application/octet-stream"
    end

    @testset "sanitize_path rejeita path traversal" begin
        @test Suindara.StaticFileModule.sanitize_path("../etc/passwd") === nothing
        @test Suindara.StaticFileModule.sanitize_path("style.css") == "style.css"
        @test Suindara.StaticFileModule.sanitize_path("img/logo.png") == "img/logo.png"
    end

    @testset "make_static_plug serve arquivo existente" begin
        plug = Suindara.StaticFileModule.make_static_plug(test_dir, "/static")

        req = HTTP.Request("GET", "/static/style.css", [], "")
        conn = Conn(req)
        conn = plug(conn)

        @test conn.status == 200
        @test conn.resp_body == "body { color: red; }"
        @test any(h -> h == ("Content-Type" => "text/css"), conn.resp_headers)
        @test conn.halted == true
    end

    @testset "make_static_plug serve arquivo em subdiretório" begin
        plug = Suindara.StaticFileModule.make_static_plug(test_dir, "/static")

        req = HTTP.Request("GET", "/static/img/logo.png", [], "")
        conn = Conn(req)
        conn = plug(conn)

        @test conn.status == 200
        @test conn.resp_body == "FAKE_PNG_DATA"
    end

    @testset "make_static_plug ignora rotas que não começam com prefix" begin
        plug = Suindara.StaticFileModule.make_static_plug(test_dir, "/static")

        req = HTTP.Request("GET", "/api/users", [], "")
        conn = Conn(req)
        conn = plug(conn)

        @test conn.halted == false
        @test conn.status == 200
    end

    @testset "make_static_plug retorna 404 para arquivo inexistente" begin
        plug = Suindara.StaticFileModule.make_static_plug(test_dir, "/static")

        req = HTTP.Request("GET", "/static/nope.txt", [], "")
        conn = Conn(req)
        conn = plug(conn)

        @test conn.status == 404
        @test conn.halted == true
    end

    @testset "make_static_plug bloqueia path traversal" begin
        plug = Suindara.StaticFileModule.make_static_plug(test_dir, "/static")

        req = HTTP.Request("GET", "/static/../../../etc/passwd", [], "")
        conn = Conn(req)
        conn = plug(conn)

        @test conn.status == 400
        @test conn.halted == true
    end

    # Cleanup
    rm(test_dir, recursive=true)

end
