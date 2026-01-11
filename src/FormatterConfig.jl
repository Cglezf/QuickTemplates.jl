module FormatterConfig

export FormatterConfig, from_config, to_dict

"""
    FormatterConfig

Configuración para JuliaFormatter.jl con defaults idiomáticos.

# Campos
- `style`: Estilo de formato ("blue", "yas", "sciml")
- `indent`: Espacios de indentación
- `margin`: Ancho máximo de línea
- `always_for_in`: Usar `for x in iter` en lugar de `for x = iter`
- `whitespace_typedefs`: Espacios en definiciones de tipo
- `whitespace_ops_in_indices`: Espacios en operadores de índices
- `import_to_using`: Convertir `import` a `using`
- `pipe_to_function_call`: Convertir pipe `|>` a llamadas de función
- `short_to_long_function_def`: Convertir definiciones cortas a largas
- `always_use_return`: Forzar `return` explícito
- `conditional_to_if`: Convertir ternarios a `if`
- `normalize_line_endings`: Normalizar finales de línea ("unix", "windows", "auto")
- `format_docstrings`: Formatear docstrings
- `align_struct_field`: Alinear campos de struct
- `align_conditional`: Alinear condicionales
- `align_assignment`: Alinear asignaciones
- `align_pair_arrow`: Alinear `=>`

# Ejemplo
```julia
formatter = FormatterConfig(
    style = "blue",
    margin = 92
)
```
"""
Base.@kwdef struct FormatterConfig
    style::String = "blue"
    indent::Int = 4
    margin::Int = 92
    always_for_in::Bool = true
    whitespace_typedefs::Bool = true
    whitespace_ops_in_indices::Bool = true
    import_to_using::Bool = false
    pipe_to_function_call::Bool = false
    short_to_long_function_def::Bool = false
    always_use_return::Bool = false
    conditional_to_if::Bool = false
    normalize_line_endings::String = "unix"
    format_docstrings::Bool = true
    align_struct_field::Bool = false
    align_conditional::Bool = false
    align_assignment::Bool = false
    align_pair_arrow::Bool = false
end

"""
    to_dict(fc::FormatterConfig) -> Dict{String, Any}

Convierte FormatterConfig a Dict para Mustache templates.
"""
function to_dict(fc::FormatterConfig)::Dict{String,Any}
    return Dict{String,Any}(
        "formatter_style" => fc.style,
        "formatter_indent" => fc.indent,
        "formatter_margin" => fc.margin,
        "formatter_always_for_in" => fc.always_for_in,
        "formatter_whitespace_typedefs" => fc.whitespace_typedefs,
        "formatter_whitespace_ops_in_indices" => fc.whitespace_ops_in_indices,
        "formatter_import_to_using" => fc.import_to_using,
        "formatter_pipe_to_function_call" => fc.pipe_to_function_call,
        "formatter_short_to_long_function_def" => fc.short_to_long_function_def,
        "formatter_always_use_return" => fc.always_use_return,
        "formatter_conditional_to_if" => fc.conditional_to_if,
        "formatter_normalize_line_endings" => fc.normalize_line_endings,
        "formatter_format_docstrings" => fc.format_docstrings,
        "formatter_align_struct_field" => fc.align_struct_field,
        "formatter_align_conditional" => fc.align_conditional,
        "formatter_align_assignment" => fc.align_assignment,
        "formatter_align_pair_arrow" => fc.align_pair_arrow
    )
end

"""
    from_config(cfg) -> FormatterConfig

Crea FormatterConfig desde config TOML.
NOTA: Esta función NO debe usarse - FormatterPrefs se construye en Config.jl usando defaults.toml.
Mantenida por compatibilidad API.
"""
function from_config(cfg)::FormatterConfig
    # Usar defaults del struct @kwdef en lugar de hardcodear aquí
    defaults = FormatterConfig()

    return FormatterConfig(;
        style=haskey(cfg, :formatter_style) ? cfg.formatter_style : defaults.style,
        indent=haskey(cfg, :formatter_indent) ? cfg.formatter_indent : defaults.indent,
        margin=haskey(cfg, :formatter_margin) ? cfg.formatter_margin : defaults.margin,
        always_for_in=haskey(cfg, :formatter_always_for_in) ? cfg.formatter_always_for_in : defaults.always_for_in,
        whitespace_typedefs=haskey(cfg, :formatter_whitespace_typedefs) ? cfg.formatter_whitespace_typedefs : defaults.whitespace_typedefs,
        whitespace_ops_in_indices=haskey(cfg, :formatter_whitespace_ops_in_indices) ? cfg.formatter_whitespace_ops_in_indices : defaults.whitespace_ops_in_indices,
        import_to_using=haskey(cfg, :formatter_import_to_using) ? cfg.formatter_import_to_using : defaults.import_to_using,
        pipe_to_function_call=haskey(cfg, :formatter_pipe_to_function_call) ? cfg.formatter_pipe_to_function_call : defaults.pipe_to_function_call,
        short_to_long_function_def=haskey(cfg, :formatter_short_to_long_function_def) ? cfg.formatter_short_to_long_function_def : defaults.short_to_long_function_def,
        always_use_return=haskey(cfg, :formatter_always_use_return) ? cfg.formatter_always_use_return : defaults.always_use_return,
        conditional_to_if=haskey(cfg, :formatter_conditional_to_if) ? cfg.formatter_conditional_to_if : defaults.conditional_to_if,
        normalize_line_endings=haskey(cfg, :formatter_normalize_line_endings) ? cfg.formatter_normalize_line_endings : defaults.normalize_line_endings,
        format_docstrings=haskey(cfg, :formatter_format_docstrings) ? cfg.formatter_format_docstrings : defaults.format_docstrings,
        align_struct_field=haskey(cfg, :formatter_align_struct_field) ? cfg.formatter_align_struct_field : defaults.align_struct_field,
        align_conditional=haskey(cfg, :formatter_align_conditional) ? cfg.formatter_align_conditional : defaults.align_conditional,
        align_assignment=haskey(cfg, :formatter_align_assignment) ? cfg.formatter_align_assignment : defaults.align_assignment,
        align_pair_arrow=haskey(cfg, :formatter_align_pair_arrow) ? cfg.formatter_align_pair_arrow : defaults.align_pair_arrow
    )
end

end # module
