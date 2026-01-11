module Exceptions

export ConfigError, ValidationError, TemplateError

"""
    ConfigError

Error en configuración de proyecto.
"""
struct ConfigError <: Exception
    field::Symbol
    message::String
end

"""
    ValidationError

Error de validación con múltiples mensajes.
"""
struct ValidationError <: Exception
    errors::Vector{String}
end

"""
    TemplateError

Error al procesar template Mustache.
"""
struct TemplateError <: Exception
    template::String
    message::String
end

# Pretty printing
Base.showerror(io::IO, e::ConfigError) =
    print(io, "❌ ConfigError - $(e.field): $(e.message)")

Base.showerror(io::IO, e::ValidationError) =
    print(io, "❌ ValidationError:\n  $(join(e.errors, "\n  "))")

Base.showerror(io::IO, e::TemplateError) =
    print(io, "❌ TemplateError - $(e.template): $(e.message)")

end # module
