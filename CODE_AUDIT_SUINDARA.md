# Auditoria Técnica: Suindara

**Data:** 2026-02-10
**Foco:** Fluxo de Pipeline, Tratamento de Erros HTTP e Robustez.

## 1. Fluxo da Pipeline (`Pipeline.jl`)

### 1.1. Mutabilidade da `Conn`
- **Problema:** O loop `for plug in plugs` assume que `conn = plug(conn)`. Como `Conn` é um `mutable struct`, os plugs podem modificar a conexão in-place.
- **Risco:** Inconsistência se um plug retornar uma nova instância de `Conn` enquanto outros modificam a antiga.
- **Recomendação:** Padronizar se os plugs devem modificar a instância e retornar a mesma ou se devem retornar uma cópia (abordagem funcional). Dada a performance em Julia, a mutação in-place é aceitável, mas o código deve ser explícito.

### 1.2. Falta de Exception Shielding na Pipeline
- **Problema:** Se um `plug` lançar uma exceção não tratada, o loop `run_pipeline` quebra e a exceção se propaga para o servidor HTTP, possivelmente derrubando a tarefa ou resultando em um erro 500 genérico sem contexto.
- **Risco:** Instabilidade do servidor.
- **Recomendação:** Envolver a execução do plug em um bloco `try-catch` dentro do `run_pipeline` para capturar erros e converter automaticamente em um `halt!` com status 500.

## 2. Tratamento de Erros HTTP (`Router.jl`, `Web.jl`)

### 2.1. Parsing de JSON Frágil
- **Problema:** Em `plug_json_parser`, o erro de parsing é silenciado: `catch e; # ignore ; end`.
- **Risco:** Se o cliente enviar um JSON malformado, o servidor continua o processamento com `conn.params` vazio em vez de avisar ao cliente que a requisição está inválida.
- **Recomendação:** O parser deve chamar `halt!(conn, 400, "Invalid JSON")` em caso de erro de parsing.

### 2.2. Error Handling no Dispatch
- **Problema:** Em `match_and_dispatch`, o `catch e` retorna `resp(conn, 500, "Internal Server Error: $(e)")`. 
- **Risco:** Vazamento de informações sensíveis (stack traces, caminhos de arquivos) para o cliente final através da interpolação de `$(e)`.
- **Recomendação:** Logar o erro internamente e retornar uma mensagem genérica para o cliente em produção.

## 3. Segurança e Performance

### 3.1. Regex Re-compilação
- **Problema:** A macro `@router` compila as rotas, mas o `compile_route` é chamado dentro de um bloco `quote`, o que sugere que a compilação do Regex ocorre em tempo de execução/instanciação do roteador. 
- **Risco:** Overhead desnecessário se o roteador for instanciado frequentemente.
- **Recomendação:** Garantir que o Regex seja compilado uma única vez (preferencialmente durante a expansão da macro ou em uma constante global).

### 3.2. Headers de Resposta Duplicados
- **Problema:** O método `resp` faz `push!(conn.resp_headers, "Content-Type" => content_type)`. Se `resp` for chamado múltiplas vezes, a lista de headers terá múltiplas entradas de "Content-Type".
- **Risco:** Comportamento indefinido em alguns clientes HTTP ou proxies.
- **Recomendação:** Usar um `Dict` para headers ou verificar se o header já existe antes de adicionar.

## 4. Violações de Padrões Idiomáticos (Julia)

- **Type Constraints em Plugs:** `Vector{T} where T <: Function`. Embora correto, em Julia é mais performático e flexível usar `Vector{Any}` ou um tipo abstrato para plugs se houver muitos tipos diferentes de funções, ou simplesmente aceitar um iterável de funções.
- **Uso de `Symbol` como chaves de Params:** O `plug_json_parser` tenta ler JSON como `Dict{Symbol, Any}`. Se as chaves do JSON forem muitas e dinâmicas, isso pode levar ao estouro da tabela de símbolos (interning) do Julia. 
    - **Recomendação:** Usar `Dict{String, Any}` para dados externos e converter para Symbol apenas campos conhecidos e validados.

## 5. Tratamento de Erros de Conexão (IO)

- O servidor parece não lidar com desconexões prematuras do cliente durante o streaming da resposta ou leitura do corpo. Se o `HTTP.jl` lançar um `IOError`, a `Conn` não possui um mecanismo de cleanup.
- **Recomendação:** Adicionar suporte a finalizadores ou um bloco `finally` no loop principal de requisição.
