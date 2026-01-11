module ConfigHelpers

export nested_get, merge_with_defaults, load_toml_section

using TOML

"""
    nested_get(dict, keys...; default=nothing)

Acceso seguro a diccionarios anidados sin repetición de get().

# Ejemplos
```julia
dict = Dict("a" => Dict("b" => Dict("c" => 42)))
nested_get(dict, "a", "b", "c")  # 42
nested_get(dict, "x", "y")       # nothing
nested_get(dict, "x", "y"; default=0)  # 0
```
"""
@inline function nested_get(dict::AbstractDict, keys...; default=nothing)
    result = dict
    for key in keys
        haskey(result, key) || return default
        result = result[key]
    end
    return result
end

"""
    merge_with_defaults(defaults::Dict, user::Dict, section::String, key::String; default=nothing)

Merge con precedencia user > defaults > fallback.
"""
@inline function merge_with_defaults(defaults::Dict, user::Dict, section::String, key::String; default=nothing)
    user_val = nested_get(user, section, key)
    !isnothing(user_val) && return user_val

    default_val = nested_get(defaults, section, key)
    !isnothing(default_val) && return default_val

    return default
end

"""
    load_toml_section(dict::Dict, section::String, defaults::T) where T

Carga sección TOML con merge de defaults.
"""
function load_toml_section(dict::Dict, section::String, defaults::T) where T
    section_data = get(dict, section, Dict())
    return merge(defaults, section_data)
end

end # module
