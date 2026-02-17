using Test
using Suindara
using HTTP

@testset "Form Parser Module" begin

    @testset "parse_urlencoded: chave=valor simples" begin
        result = Suindara.FormParserModule.parse_urlencoded("name=Julia&version=1.10")
        @test result["name"] == "Julia"
        @test result["version"] == "1.10"
    end

    @testset "parse_urlencoded: decodifica %20 e +" begin
        result = Suindara.FormParserModule.parse_urlencoded("msg=hello+world&path=%2Ffoo")
        @test result["msg"] == "hello world"
        @test result["path"] == "/foo"
    end

    @testset "parse_urlencoded: string vazia retorna Dict vazio" begin
        result = Suindara.FormParserModule.parse_urlencoded("")
        @test isempty(result)
    end

    @testset "plug_form_parser: parseia application/x-www-form-urlencoded" begin
        body = "username=ana&age=30"
        req = HTTP.Request("POST", "/", ["Content-Type" => "application/x-www-form-urlencoded"], body)
        conn = Conn(req)
        conn = Suindara.FormParserModule.plug_form_parser(conn)
        @test conn.params["username"] == "ana"
        @test conn.params["age"] == "30"
    end

    @testset "plug_form_parser: ignora Content-Type diferente" begin
        req = HTTP.Request("POST", "/", ["Content-Type" => "text/plain"], "data=123")
        conn = Conn(req)
        conn = Suindara.FormParserModule.plug_form_parser(conn)
        @test !haskey(conn.params, "data")
    end

    @testset "plug_form_parser: não explode com body vazio" begin
        req = HTTP.Request("POST", "/", ["Content-Type" => "application/x-www-form-urlencoded"], "")
        conn = Conn(req)
        conn = Suindara.FormParserModule.plug_form_parser(conn)
        @test conn.halted == false
    end

end
