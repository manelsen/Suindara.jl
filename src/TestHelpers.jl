"""
    module TestHelpersModule

Helpers para facilitar testes de integração em aplicações Suindara.
Inspirado no Phoenix.ConnTest.
"""
module TestHelpersModule

using ..ConnModule
using ..Repo
using HTTP
using JSON3

export build_conn, assert_status, assert_body_contains, setup_test_db

"""
    build_conn(method, path; json=nothing) :: Conn

Cria um Conn de teste com HTTP.Request configurado.
"""
function build_conn(method::String, path::String; json=nothing)::Conn
    headers = Pair{String,String}[]
    body = ""

    if json !== nothing
        body = JSON3.write(json)
        push!(headers, "Content-Type" => "application/json")
    end

    req = HTTP.Request(method, path, headers, body)
    return Conn(req)
end

"""
    assert_status(conn::Conn, expected::Int) :: Bool

Retorna true se conn.status == expected.
"""
function assert_status(conn::Conn, expected::Int)::Bool
    return conn.status == expected
end

"""
    assert_body_contains(conn::Conn, substring::String) :: Bool

Retorna true se conn.resp_body contém a substring.
"""
function assert_body_contains(conn::Conn, substring::String)::Bool
    return contains(conn.resp_body, substring)
end

"""
    setup_test_db()

Conecta a um banco SQLite in-memory para testes isolados.
"""
function setup_test_db()
    Repo.connect(":memory:")
end

end # module
