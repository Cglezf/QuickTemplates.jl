module Result

export Result, Ok, Err, @unwrap, isok, iserr
export unwrap_or, map_err, and_then_err, transpose_results, collect_oks, collect_errs

"""
Railway-oriented programming para Julia.

# Ejemplos

```julia
# Crear resultados
ok_val = Ok(42)
err_val = Err("error message")

# Pattern matching
result = do_something()
if isok(result)
    println("Success: ", result.value)
else
    println("Error: ", result.error)
end

# Railway chaining con @unwrap
function process()
    val = @unwrap validate_input()
    result = @unwrap transform(val)
    Ok(result)
end

# Unwrap con fallback
value = unwrap_or(0, compute())

# Map sobre error
result = map_err(x -> "Error: " * x, dangerous_op())

# Transpose vector de Results
results = [Ok(1), Ok(2), Ok(3)]
all_ok = transpose_results(results)  # Ok([1, 2, 3])
```
"""
abstract type Result{T,E} end

struct Ok{T} <: Result{T,Nothing}
    value::T
end

struct Err{E} <: Result{Nothing,E}
    error::E
end

# === Predicados ===

isok(::Ok) = true
isok(::Err) = false

iserr(::Ok) = false
iserr(::Err) = true

# === Unwrap ===

"""
    @unwrap(expr)

Railway macro: early return si Err, desenvuelve Ok.

# Ejemplo

```julia
function process()
    val = @unwrap validate()  # Si Err, return; si Ok, val = result.value
    transformed = @unwrap transform(val)
    Ok(transformed)
end
```
"""
macro unwrap(expr)
    quote
        result = $(esc(expr))
        iserr(result) && return result
        result.value
    end
end

"""
    unwrap_or(default, r::Result)

Desenvuelve Result o retorna default si Err.

# Ejemplo

```julia
value = unwrap_or(0, parse_int(str))  # 0 si falla
name = unwrap_or("Unknown", fetch_name())
```
"""
unwrap_or(default, r::Ok) = r.value
unwrap_or(default, ::Err) = default

# === Functor map ===

Base.map(f::Function, r::Ok) = Ok(f(r.value))
Base.map(::Function, r::Err) = r

"""
    map_err(f::Function, r::Result)

Map sobre el error (transforma Err, mantiene Ok).

# Ejemplo

```julia
result = map_err(x -> "Failed: " * x, dangerous_op())
```
"""
map_err(::Function, r::Ok) = r
map_err(f::Function, r::Err) = Err(f(r.error))

# === Monad bind (and_then) ===

"""
    and_then(f::Function, r::Result)

Railway bind: aplica f si Ok, propaga Err.

Alias: `>>=` (bind operator)

# Ejemplo

```julia
result = Ok(5)
    |> and_then(x -> Ok(x * 2))
    |> and_then(x -> Ok(x + 1))  # Ok(11)
```
"""
and_then(f::Function, r::Ok) = f(r.value)
and_then(::Function, r::Err) = r

# Alias bind operator
Base.:>>(r::Result, f::Function) = and_then(f, r)

"""
    and_then_err(f::Function, r::Result)

Railway bind sobre error: aplica f si Err, mantiene Ok.

# Ejemplo

```julia
result = Err("network timeout")
    |> and_then_err(x -> Err("Retry failed: " * x))
```
"""
and_then_err(::Function, r::Ok) = r
and_then_err(f::Function, r::Err) = f(r.error)

# === Alternative (or_else) ===

"""
    or_else(f::Function, r::Result)

Ejecuta f si Err, mantiene Ok.

# Ejemplo

```julia
result = Err("failed")
    |> or_else(x -> Ok(default_value))  # Fallback
```
"""
or_else(::Function, r::Ok) = r
or_else(f::Function, r::Err) = f(r.error)

# === Transpose (Vector{Result} -> Result{Vector}) ===

"""
    transpose_results(results::Vector{Result{T,E}}) where {T,E}

Transpone Vector de Results: si todos Ok -> Ok(Vector), si alguno Err -> primer Err.

# Ejemplo

```julia
results = [Ok(1), Ok(2), Ok(3)]
transpose_results(results)  # Ok([1, 2, 3])

mixed = [Ok(1), Err("fail"), Ok(3)]
transpose_results(mixed)  # Err("fail")
```
"""
function transpose_results(results::Vector{<:Result{T,E}})::Result{Vector{T},E} where {T,E}
    values = Vector{T}(undef, length(results))

    for (i, result) in enumerate(results)
        iserr(result) && return result
        values[i] = result.value
    end

    return Ok(values)
end

# === Utilities ===

"""
    collect_oks(results::Vector{Result{T,E}}) where {T,E}

Colecta solo los valores Ok, ignora Err.

# Ejemplo

```julia
mixed = [Ok(1), Err("x"), Ok(3), Err("y")]
collect_oks(mixed)  # [1, 3]
```
"""
collect_oks(results::Vector{<:Result{T,E}}) where {T,E} = [r.value for r in results if isok(r)]

"""
    collect_errs(results::Vector{Result{T,E}}) where {T,E}

Colecta solo los errores Err, ignora Ok.

# Ejemplo

```julia
mixed = [Ok(1), Err("x"), Ok(3), Err("y")]
collect_errs(mixed)  # ["x", "y"]
```
"""
collect_errs(results::Vector{<:Result{T,E}}) where {T,E} = [r.error for r in results if iserr(r)]

# === Pretty printing ===

Base.show(io::IO, r::Ok) = print(io, "Ok(", r.value, ")")
Base.show(io::IO, r::Err) = print(io, "Err(", r.error, ")")

end # module
