using Test
using Suindara

@testset "Error Handler" begin
    EH = Suindara.ErrorHandlerModule

    @testset "is_dev_mode detecta ambiente" begin
        @test EH.is_dev_mode() isa Bool
    end

    @testset "format_error_dev inclui detalhes" begin
        try
            error("test boom")
        catch e
            bt = catch_backtrace()
            body = EH.format_error_dev(e, bt)
            @test contains(body, "test boom")
            @test contains(body, "ErrorException")
        end
    end

    @testset "format_error_prod é genérico" begin
        try
            error("secret")
        catch e
            bt = catch_backtrace()
            body = EH.format_error_prod(e, bt)
            @test contains(body, "Internal Server Error")
            @test !contains(body, "secret")
        end
    end

    @testset "format_error despacha por modo" begin
        try
            error("dispatch test")
        catch e
            bt = catch_backtrace()
            body = EH.format_error(e, bt)
            @test body isa String
            @test length(body) > 0
        end
    end

end
