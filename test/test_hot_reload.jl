using Test
using Suindara

@testset "HotReload Module" begin

    @testset "revise_available() retorna Bool" begin
        result = Suindara.HotReloadModule.revise_available()
        @test result isa Bool
    end

    @testset "start_watching() não explode quando Revise ausente" begin
        result = Suindara.HotReloadModule.start_watching()
        @test result == :no_revise
    end

    @testset "watched_paths() retorna vetor vazio sem Revise" begin
        paths = Suindara.HotReloadModule.watched_paths()
        @test paths isa Vector{String}
        @test isempty(paths)
    end

end
