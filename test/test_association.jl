using Test
using Suindara

@testset "Associations" begin
    # Setup: banco com duas tabelas relacionadas
    Suindara.Repo.connect(":memory:")
    Suindara.Repo.execute("CREATE TABLE authors (id INTEGER PRIMARY KEY, name TEXT)")
    Suindara.Repo.execute("CREATE TABLE books (id INTEGER PRIMARY KEY, title TEXT, author_id INTEGER)")
    Suindara.Repo.execute("INSERT INTO authors (id, name) VALUES (1, 'Machado')")
    Suindara.Repo.execute("INSERT INTO authors (id, name) VALUES (2, 'Clarice')")
    Suindara.Repo.execute("INSERT INTO books (title, author_id) VALUES ('Dom Casmurro', 1)")
    Suindara.Repo.execute("INSERT INTO books (title, author_id) VALUES ('Quincas Borba', 1)")
    Suindara.Repo.execute("INSERT INTO books (title, author_id) VALUES ('A Hora da Estrela', 2)")

    Assoc = Suindara.AssociationModule

    @testset "preload_has_many carrega filhos" begin
        authors = Suindara.Repo.query("SELECT * FROM authors ORDER BY id")
        result = Assoc.preload_has_many(authors, :books, "books", "author_id")

        @test length(result[1][:books]) == 2
        @test length(result[2][:books]) == 1
    end

    @testset "preload_belongs_to carrega pai" begin
        books = Suindara.Repo.query("SELECT * FROM books ORDER BY id")
        result = Assoc.preload_belongs_to(books, :author, "authors", "author_id")

        @test result[1][:author].name == "Machado"
        @test result[3][:author].name == "Clarice"
    end

    @testset "preload_has_many com lista vazia" begin
        result = Assoc.preload_has_many([], :books, "books", "author_id")
        @test isempty(result)
    end

end
