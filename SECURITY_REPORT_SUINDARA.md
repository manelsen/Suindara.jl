# Security Audit Report: Suindara

| Risk | Location | Impact | Recommendation |
| :--- | :--- | :--- | :--- |
| **High: SQL Injection** | `src/Repo.jl:48` | Table and Field names are interpolated directly into SQL strings. | Whitelist allowed table/field names or use a metadata-driven approach. Never interpolate parameters directly. |
| **Medium: Information Leak** | `src/Router.jl:36` | `500` errors return the full exception message to the client. | Use generic error messages for the client and log the detailed error internally. |
| **Medium: Denial of Service (DoS)** | `src/Web.jl:16` | `plug_json_parser` reads and parses JSON bodies without size limits. | Implement a `Content-Length` check and a maximum body size limit before parsing. |
| **Medium: Cross-Site Scripting (XSS)** | `src/Conn.jl:46` | No automatic HTML escaping; `resp` allows any content-type. | Provide an HTML escaping utility and use `text/html` cautiously. |

## Detailed Analysis

### 1. Route Parameter Validation
The router extracts parameters using Regex (`(?P<name>[^/]+)`). While effective for extraction, there is no built-in validation for types (e.g., ensuring `:id` is numeric). This places the burden of validation entirely on the controller.

### 2. JSON Parsing
The `plug_json_parser` merges parsed JSON into `conn.params` using `JSON3.read`. 
- **Risk:** Large payloads can consume excessive memory.
- **Risk:** Malformed JSON results in a silent failure, which may lead to `KeyError` in controllers if they assume data exists.

### 3. Database Security (SQL Injection)
The `Repo.insert` function:
```julia
sql = "INSERT INTO $table ($field_names) VALUES ($placeholders)"
```
While values are parameterized using `?`, the `$table` and `$field_names` are not. If a developer uses a `Changeset` with unvalidated allowed fields, an attacker could potentially inject SQL into the schema part of the query.

### 4. Input Validation
The `Changeset` module provides a good foundation for input validation (`cast`, `validate_required`). However, its use is optional and depends on developer discipline.

---
**Auditor:** OpenClaw Sub-Agent
**Date:** 2026-02-10
