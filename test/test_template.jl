using Test
using Suindara
using HTTP

@testset "Template Engine" begin
    T = Suindara.TemplateModule

    @testset "render_string interpola variáveis" begin
        result = T.render_string("Hello, {{name}}!", Dict("name" => "Julia"))
        @test result == "Hello, Julia!"
    end

    @testset "render_string sem variáveis retorna original" begin
        result = T.render_string("Static text", Dict{String,String}())
        @test result == "Static text"
    end

    @testset "render_string escape HTML por padrão" begin
        result = T.render_string("{{content}}", Dict("content" => "<script>alert('xss')</script>"))
        @test !contains(result, "<script>")
        @test contains(result, "&lt;script&gt;")
    end

    @testset "render_string com {{{raw}}} não escapa" begin
        result = T.render_string("{{{content}}}", Dict("content" => "<b>bold</b>"))
        @test result == "<b>bold</b>"
    end

    @testset "render_string múltiplas variáveis" begin
        template = "{{greeting}}, {{name}}! Age: {{age}}"
        result = T.render_string(template, Dict("greeting" => "Hi", "name" => "Ana", "age" => "30"))
        @test result == "Hi, Ana! Age: 30"
    end

    @testset "escape_html escapa caracteres perigosos" begin
        @test T.escape_html("<b>test</b>") == "&lt;b&gt;test&lt;/b&gt;"
        @test T.escape_html("a & b") == "a &amp; b"
        @test T.escape_html("\"quotes\"") == "&quot;quotes&quot;"
    end

    @testset "render_file lê template de arquivo" begin
        tmpdir = mktempdir()
        write(joinpath(tmpdir, "hello.html"), "<h1>{{title}}</h1>")
        result = T.render_file(joinpath(tmpdir, "hello.html"), Dict("title" => "Welcome"))
        @test result == "<h1>Welcome</h1>"
        rm(tmpdir, recursive=true)
    end

    @testset "plug_render_html seta Content-Type e body" begin
        conn = Suindara.TestHelpersModule.build_conn("GET", "/")
        conn = T.plug_render_html(conn, "<h1>Hi</h1>")
        @test conn.resp_body == "<h1>Hi</h1>"
        @test any(h -> h == ("Content-Type" => "text/html; charset=utf-8"), conn.resp_headers)
    end

end
