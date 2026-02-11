using Test
using Suindara
using HTTP
using JSON3

@testset "Web Module Error Handling" begin
    # Test JSON Parsing Error
    req = HTTP.Request("POST", "/api", ["Content-Type" => "application/json"], "{invalid-json")
    conn = Conn(req)
    
    conn = plug_json_parser(conn)
    
    @test conn.halted == true
    @test conn.status == 400
    @test conn.resp_body == "Invalid JSON body"
    
    # Test Valid JSON
    req_valid = HTTP.Request("POST", "/api", ["Content-Type" => "application/json"], "{\"key\": \"value\"}")
    conn_valid = Conn(req_valid)
    
    conn_valid = plug_json_parser(conn_valid)
    
    @test conn_valid.halted == false
    @test conn_valid.params["key"] == "value"
end
