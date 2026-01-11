module QuickTemplates

# Core modules
include("ConfigHelpers.jl")
include("Result.jl")
include("Exceptions.jl")
include("FormatterConfig.jl")
include("Config.jl")
include("Setup.jl")
include("Generator.jl")

using .ConfigHelpers
using .Result
using .Exceptions
using .FormatterConfig
using .Config
using .Setup
using .Generator
using UUIDs
using TOML

export setup_identity, init_config, generate

# Re-export desde Config
export ProjectConfig, ProjectMetadata, CIConfig, GitHubConfig, TestingConfig, FormatterPrefs, DevWorkspace
export load_defaults, load_user, load_env, merge_configs, validate

"""
    generate(config_path::String="config.toml")

Genera un nuevo proyecto Julia basado en config.toml.
"""
function generate(config_path::String="config.toml")
    config = load_and_validate_config(config_path)
    config_with_uuid = add_uuid(config)
    Generator.generate_project(config_with_uuid)
end

# Helper: Load and validate configuration
function load_and_validate_config(config_path::String)::Config.ProjectConfig
    defaults = load_defaults()
    user = load_user(config_path)
    env = load_env()
    config = merge_configs(defaults, user, env)
    validate(config)
    return config
end

# Helper: Add UUID to config (IDEMPOTENTE - preserva UUID existente)
function add_uuid(config::Config.ProjectConfig)
    project_path = joinpath(expanduser(config.metadata.project_dir), config.metadata.name)
    existing_uuid = _read_existing_uuid(project_path)

    return (
        metadata=config.metadata,
        ci=config.ci,
        github=config.github,
        testing=config.testing,
        formatter=config.formatter,
        dev=config.dev,
        features=config.features,
        logging_min_level=config.logging_min_level,
        env_vars=config.env_vars,
        uuid=isnothing(existing_uuid) ? string(uuid4()) : existing_uuid
    )
end

# Helper: Lee UUID de Project.toml existente (si existe)
function _read_existing_uuid(project_path::String)::Union{String,Nothing}
    project_toml = joinpath(project_path, "Project.toml")
    isfile(project_toml) || return nothing

    try
        toml_data = TOML.parsefile(project_toml)
        return haskey(toml_data, "uuid") ? toml_data["uuid"] : nothing
    catch
        return nothing
    end
end

"""
    QuickTemplates

Generador moderno de paquetes Julia 1.12+ con MLOps integrado.

# Uso

## Primera vez (configurar identidad global)
```julia
using QuickTemplates
setup_identity()  # Crea ~/.config/QuickTemplates/.env
```

## Crear nuevo proyecto
```julia
cd("mi-directorio-trabajo")
init_config()     # Crea config.toml template
# Editar config.toml: name + features
generate()        # Genera proyecto
```

## Agregar features a proyecto existente
```julia
cd("mi-proyecto")
# Editar config.toml: activar nuevas features
update()          # Agrega features sin eliminar existentes
```
"""
QuickTemplates

end # module
