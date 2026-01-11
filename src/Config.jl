module Config

export load_defaults, load_user, load_env, merge_configs, validate
export ProjectConfig, ProjectMetadata, CIConfig, GitHubConfig, TestingConfig, FormatterPrefs, DevWorkspace

using TOML

# === Const memoization para defaults.toml (performance optimization) ===
# Inicialización en tiempo de carga del módulo - ZERO allocations, O(1) constante

const DEFAULTS_DICT::Dict{String,Any} = let
    defaults_path = joinpath(dirname(@__DIR__), "config", "defaults.toml")
    TOML.parsefile(defaults_path)
end

# === Sub-structs por feature (composable, testeable) ===

struct ProjectMetadata
    name::String
    author_fullname::String
    github_user::String
    github_email::String
    project_dir::String
    license::String
    julia_version::String
    initial_version::String
    default_branch::String
end

struct CIConfig
    julia_versions::Vector{String}
    os::Vector{String}
    docs_julia_version::String
    codecov::Bool
end

struct GitHubConfig
    create_repo::Bool
    private::Bool
    auto_push::Bool
end

struct TestingConfig
    use_aqua::Bool
    rtol::Float64
    atol::Float64
    ml_rtol::Float64
    ml_atol::Float64
end

struct FormatterPrefs
    style::String
    indent::Int
    margin::Int
    always_for_in::Bool
    whitespace_typedefs::Bool
    whitespace_ops_in_indices::Bool
    import_to_using::Bool
    pipe_to_function_call::Bool
    short_to_long_function_def::Bool
    always_use_return::Bool
    conditional_to_if::Bool
    normalize_line_endings::String
    format_docstrings::Bool
    align_struct_field::Bool
    align_conditional::Bool
    align_assignment::Bool
    align_pair_arrow::Bool
end

struct DevWorkspace
    auto_setup::Bool
    packages::Vector{String}
end

struct ProjectConfig
    metadata::ProjectMetadata
    ci::CIConfig
    github::GitHubConfig
    testing::TestingConfig
    formatter::FormatterPrefs
    dev::DevWorkspace
    features::Dict{String,Bool}
    logging_min_level::String
    env_vars::Dict{String,String}
end

# === Loaders ===

load_defaults()::Dict{String,Any} = DEFAULTS_DICT

load_user(config_path::String="config.toml")::Dict{String,Any} = _load_toml_file(config_path, "config.toml", "Ejecuta: using QuickTemplates; init_config()")

function load_env()::Dict{String,String}
    env_dict = Dict{String,String}()
    env_paths = [
        joinpath(homedir(), ".config", "QuickTemplates", ".env"),
        ".env"
    ]

    for env_path in env_paths
        isfile(env_path) && _parse_env_file!(env_dict, env_path)
    end

    return env_dict
end

# === Helpers ===

function _load_toml_file(path::String, name::String, hint::String="")::Dict{String,Any}
    isfile(path) || error("❌ $name no encontrado en: $path\n   $(hint)")
    return TOML.parsefile(path)
end

function _parse_env_file!(env_dict::Dict{String,String}, env_path::String)
    for line in readlines(env_path)
        line = strip(line)
        (isempty(line) || startswith(line, "#")) && continue

        m = match(r"^([A-Z_]+)=(.*)$", line)
        isnothing(m) && continue

        key, value = m.captures
        value = strip(value, ['"', '\''])
        value = replace(value, r"\$\{([^}]+)\}" => s -> get(ENV, s[3:end-1], ""))
        value = replace(value, r"\$([A-Z_]+)" => s -> get(ENV, s[2:end], ""))
        env_dict[key] = value
    end
end

# === Merge configs ===

function merge_configs(defaults::Dict, user::Dict, env::Dict{String,String})::ProjectConfig
    metadata = _build_metadata(defaults, user, env)
    ci = _build_ci_config(defaults, user)
    github = _build_github_config(defaults, user)
    testing = _build_testing_config(defaults, user)
    formatter = _build_formatter_prefs(defaults, user)
    dev = _build_dev_workspace(defaults, user)
    features = _build_features(defaults, user)
    logging_min_level = _get_from_defaults(defaults, user, "logging", "min_level")
    env_vars = _extract_env_vars(env)

    return ProjectConfig(metadata, ci, github, testing, formatter, dev, features, logging_min_level, env_vars)
end

# === Builders (ZERO_FALLBACKS - solo defaults.toml) ===

# Helper: Extrae valor de env sin fallback hardcodeado (validation maneja campos vacíos)
@inline _get_env_value(env::Dict{String,String}, key::String)::String = get(env, key, "")

# Helper: Extrae valor de sección user sin fallback hardcodeado
@inline _get_user_value(user::Dict, section::String, key::String)::String =
    haskey(user, section) && haskey(user[section], key) ? user[section][key] : ""

function _build_metadata(defaults::Dict, user::Dict, env::Dict{String,String})::ProjectMetadata
    return ProjectMetadata(
        _get_user_value(user, "project", "name"),
        _get_env_value(env, "AUTHOR_FULLNAME"),
        _get_env_value(env, "GITHUB_USER"),
        _get_env_value(env, "GITHUB_EMAIL"),
        _get_env_value(env, "PROJECT_DIR"),
        _get_from_defaults(defaults, user, "project", "license"),
        _get_from_defaults(defaults, user, "project", "julia_version"),
        _get_from_defaults(defaults, user, "project", "initial_version"),
        _get_from_defaults(defaults, user, "project", "default_branch")
    )
end

# Helper DRY: Merge user override con defaults para una sección específica
@inline function _get_config_value(defaults_section::Dict, user_section::Dict, key::String)
    haskey(user_section, key) ? user_section[key] : defaults_section[key]
end

function _build_ci_config(defaults::Dict, user::Dict)::CIConfig
    ci_defaults = get(defaults, "ci", Dict())
    ci_user = get(user, "ci", Dict())

    return CIConfig(
        _get_config_value(ci_defaults, ci_user, "julia_versions"),
        _get_config_value(ci_defaults, ci_user, "os"),
        _get_config_value(ci_defaults, ci_user, "docs_julia_version"),
        _get_config_value(ci_defaults, ci_user, "codecov")
    )
end

function _build_github_config(defaults::Dict, user::Dict)::GitHubConfig
    github_defaults = get(defaults, "github", Dict())
    github_user = get(user, "github", Dict())

    return GitHubConfig(
        _get_config_value(github_defaults, github_user, "create_repo"),
        _get_config_value(github_defaults, github_user, "private"),
        _get_config_value(github_defaults, github_user, "auto_push")
    )
end

function _build_testing_config(defaults::Dict, user::Dict)::TestingConfig
    testing_defaults = get(defaults, "testing", Dict())
    testing_user = get(user, "testing", Dict())

    return TestingConfig(
        _get_config_value(testing_defaults, testing_user, "use_aqua"),
        _get_config_value(testing_defaults, testing_user, "rtol"),
        _get_config_value(testing_defaults, testing_user, "atol"),
        _get_config_value(testing_defaults, testing_user, "ml_rtol"),
        _get_config_value(testing_defaults, testing_user, "ml_atol")
    )
end

function _build_formatter_prefs(defaults::Dict, user::Dict)::FormatterPrefs
    formatter_defaults = get(defaults, "formatter", Dict())
    formatter_user = get(user, "formatter", Dict())
    features_user = get(user, "features", Dict())

    # Precedencia: features.formatter_* > formatter.* > defaults.formatter.*
    values = []

    for field in fieldnames(FormatterPrefs)
        key_str = string(field)

        # Check features.formatter_style override (dot notation support)
        feature_key = "formatter_$key_str"
        if haskey(features_user, feature_key)
            push!(values, features_user[feature_key])
            continue
        end

        # Check formatter section
        if haskey(formatter_user, key_str)
            push!(values, formatter_user[key_str])
            continue
        end

        # Fallback to defaults (guaranteed by ZERO_FALLBACKS)
        push!(values, formatter_defaults[key_str])
    end

    return FormatterPrefs(values...)
end

function _build_dev_workspace(defaults::Dict, user::Dict)::DevWorkspace
    dev_defaults = get(defaults, "dev", Dict())
    dev_user = get(user, "dev", Dict())

    return DevWorkspace(
        _get_config_value(dev_defaults, dev_user, "auto_setup"),
        _get_config_value(dev_defaults, dev_user, "packages")
    )
end

_build_features(defaults::Dict, user::Dict)::Dict{String,Bool} = merge(get(defaults, "features", Dict()), get(user, "features", Dict()))

_extract_env_vars(env::Dict{String,String})::Dict{String,String} = Dict(k => v for (k, v) in env if !in(k, ["AUTHOR_FULLNAME", "GITHUB_USER", "GITHUB_EMAIL", "PROJECT_DIR"]))

# Helper: user > defaults (ZERO_FALLBACKS - defaults.toml garantiza valores)
function _get_from_defaults(defaults::Dict, user::Dict, section::String, key::String)::Any
    user_section = get(user, section, Dict())
    haskey(user_section, key) && return user_section[key]

    defaults_section = defaults[section]  # Garantizado por defaults.toml
    return defaults_section[key]  # Garantizado por defaults.toml
end

# === Validation ===

function validate(config::ProjectConfig)::Bool
    errors = String[]

    # Metadata validation
    _validate_metadata!(errors, config.metadata)
    _validate_paths!(errors, config.metadata)
    _validate_julia_version!(errors, config.metadata.julia_version)
    _validate_logging_level!(errors, config.logging_min_level)
    _validate_github_cli!(errors, config.github.create_repo)

    isempty(errors) || error(join(errors, "\n"))
    return true
end

function _validate_project_name!(errors::Vector{String}, name::String)
    isempty(name) && return  # Ya validado en _validate_metadata!

    # Path traversal prevention
    contains(name, "/") && push!(errors, "❌ project.name no puede contener '/' (path separator)")
    contains(name, "\\") && push!(errors, "❌ project.name no puede contener '\\' (path separator)")
    contains(name, "..") && push!(errors, "❌ project.name no puede contener '..' (path traversal)")
    startswith(name, ".") && push!(errors, "❌ project.name no puede empezar con '.' (hidden file)")

    # Julia package naming conventions
    occursin(r"^[A-Z][a-zA-Z0-9]*$", name) || push!(errors, "❌ project.name debe empezar con mayúscula y contener solo letras/números")
end

function _validate_github_user!(errors::Vector{String}, github_user::String)
    isempty(github_user) && return  # Ya validado en _validate_metadata!

    # GitHub username: 1-39 chars, alphanumeric + hyphens, cannot start/end with hyphen
    occursin(r"^[a-zA-Z0-9]([a-zA-Z0-9-]{0,37}[a-zA-Z0-9])?$", github_user) ||
        push!(errors, "❌ GITHUB_USER formato inválido (debe ser alphanumeric + guiones, 1-39 caracteres)")
end

function _validate_email!(errors::Vector{String}, email::String)
    isempty(email) && return  # Ya validado en _validate_metadata!

    # RFC 5322 simplified validation
    occursin(r"^[^@\s]+@[^@\s]+\.[^@\s]+$", email) ||
        push!(errors, "❌ GITHUB_EMAIL formato inválido (debe ser email válido)")
end

function _validate_metadata!(errors::Vector{String}, metadata::ProjectMetadata)
    isempty(metadata.name) && push!(errors, "❌ project.name OBLIGATORIO en config.toml")
    isempty(metadata.author_fullname) && push!(errors, "❌ AUTHOR_FULLNAME OBLIGATORIO en ~/.config/QuickTemplates/.env")
    isempty(metadata.github_user) && push!(errors, "❌ GITHUB_USER OBLIGATORIO en ~/.config/QuickTemplates/.env")
    isempty(metadata.github_email) && push!(errors, "❌ GITHUB_EMAIL OBLIGATORIO en ~/.config/QuickTemplates/.env")
    isempty(metadata.project_dir) && push!(errors, "❌ PROJECT_DIR OBLIGATORIO en ~/.config/QuickTemplates/.env")

    # Security validations
    _validate_project_name!(errors, metadata.name)
    _validate_github_user!(errors, metadata.github_user)
    _validate_email!(errors, metadata.github_email)
end

function _validate_paths!(errors::Vector{String}, metadata::ProjectMetadata)
    isempty(metadata.project_dir) && return

    expanded_dir = expanduser(metadata.project_dir)
    if !isdir(expanded_dir)
        push!(errors, "❌ PROJECT_DIR no existe: $(metadata.project_dir)")
        return
    end

    # Resolve symlinks para prevenir ataques
    try
        resolved_dir = realpath(expanded_dir)
        project_path = joinpath(resolved_dir, metadata.name)

        # Normalize path para comparar (resolve .. and . components)
        # Si project_path no existe, usamos abspath para normalizar
        normalized_project = isdir(project_path) ? realpath(project_path) : abspath(project_path)

        # Security: Verificar que normalized_project NO escape de resolved_dir
        if !startswith(normalized_project, resolved_dir)
            push!(errors, "❌ project.name escapa del directorio base (path traversal detectado)")
            return
        end

        # Idempotencia: Warn pero NO error (archivos protegidos por skip-if-exists)
        if isdir(project_path)
            @warn "⚠️  Proyecto ya existe en $project_path\n   Archivos existentes NO serán sobrescritos (modo incremental seguro)"
        end
    catch e
        if isa(e, Base.IOError)
            push!(errors, "❌ Error accediendo a PROJECT_DIR: $(metadata.project_dir)")
        else
            rethrow(e)
        end
    end
end

function _validate_julia_version!(errors::Vector{String}, julia_version::String)
    # ZERO_FALLBACKS: min_julia_version DEBE estar en defaults.toml
    project_defaults = DEFAULTS_DICT["project"]  # Garantizado por const initialization
    min_version_str = project_defaults["min_julia_version"]  # Garantizado por defaults.toml
    min_version = parse(VersionNumber, min_version_str)

    parsed_version = parse(VersionNumber, julia_version)
    parsed_version < min_version && push!(errors, "❌ julia_version debe ser >= $min_version_str (actual: $julia_version)")
end

_validate_logging_level!(errors::Vector{String}, level::String) =
    level in ["Debug", "Info", "Warn", "Error"] || push!(errors, "❌ logging_min_level debe ser uno de: Debug, Info, Warn, Error")

function _validate_github_cli!(errors::Vector{String}, create_repo::Bool)
    create_repo || return
    success(pipeline(`which gh`, devnull)) && return
    @warn "gh CLI no instalado. create_repo no funcionará.\n   Instalar: https://cli.github.com"
end

end # module
