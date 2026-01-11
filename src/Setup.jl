module Setup

export setup_identity, init_config

using TOML
using Dates

# === Setup Identity (refactorizado en funciones pequeñas) ===

function setup_identity()
    _print_setup_header()

    config_dir = _create_config_dir()
    env_path = joinpath(config_dir, ".env")

    _check_existing_env(env_path) || return

    identity_data = _prompt_identity_data()
    _validate_identity_data(identity_data)
    _create_project_dir_if_needed(identity_data.project_dir)
    _write_env_file(env_path, identity_data)

    _print_setup_footer(env_path)
end

_print_setup_header() = (
    println("🔧 Configuración de identidad para QuickTemplates.jl");
    println("=" ^ 60);
    println()
)

_create_config_dir() = (
    config_dir = joinpath(homedir(), ".config", "QuickTemplates");
    mkpath(config_dir);
    config_dir
)

function _check_existing_env(env_path::String)::Bool
    isfile(env_path) || return true

    print("⚠️  .env ya existe en $env_path\n")
    print("¿Sobrescribir? [y/N]: ")
    response = strip(readline())

    lowercase(response) == "y" || (println("✓ Configuración cancelada"); return false)
    return true
end

function _prompt_identity_data()
    print("Nombre completo: ")
    author_fullname = strip(readline())

    print("Usuario GitHub: ")
    github_user = strip(readline())

    print("Email GitHub (recomendado: privado de GitHub): ")
    github_email = strip(readline())

    print("Directorio base proyectos [$(homedir())/Projects/Julia]: ")
    project_dir_input = strip(readline())
    project_dir = isempty(project_dir_input) ? joinpath(homedir(), "Projects", "Julia") : project_dir_input

    return (
        author_fullname=author_fullname,
        github_user=github_user,
        github_email=github_email,
        project_dir=project_dir
    )
end

function _validate_identity_data(data)
    (isempty(data.author_fullname) || isempty(data.github_user) || isempty(data.github_email)) && error("❌ Todos los campos son obligatorios")
end

function _create_project_dir_if_needed(project_dir::String)
    expanded_dir = expanduser(project_dir)
    isdir(expanded_dir) && return

    print("📁 Directorio $expanded_dir no existe. ¿Crear? [Y/n]: ")
    response = strip(readline())
    lowercase(response) == "n" && return

    mkpath(expanded_dir)
    println("✓ Directorio creado")
end

function _write_env_file(env_path::String, data)
    env_content = _build_env_content(data)
    write(env_path, env_content)
end

function _build_env_content(data)::String
    return """
    # .env - Configuración global QuickTemplates.jl
    # Generado: $(Dates.format(Dates.now(), "yyyy-mm-dd HH:MM:SS"))

    # === IDENTIDAD (obligatorio) ===
    AUTHOR_FULLNAME="$(data.author_fullname)"
    GITHUB_USER="$(data.github_user)"
    GITHUB_EMAIL="$(data.github_email)"
    PROJECT_DIR="$(data.project_dir)"

    # === DVC (descomentar si usas) ===
    # DVC_REMOTE_URL=""
    # AWS_ACCESS_KEY_ID=""
    # AWS_SECRET_ACCESS_KEY=""
    # GOOGLE_APPLICATION_CREDENTIALS=""

    # === Database (descomentar si usas) ===
    # DB_HOST="localhost"
    # DB_PORT="5432"
    # DB_NAME=""
    # DB_USER=""
    # DB_PASSWORD=""

    # === Notebooks (descomentar si usas) ===
    # JUPYTER_PORT=8888
    # PLUTO_PORT=1234

    # === MLOps (descomentar si usas) ===
    # OPENAI_API_KEY=""
    # ANTHROPIC_API_KEY=""
    """
end

function _print_setup_footer(env_path::String)
    println()
    println("✅ Identidad configurada correctamente")
    println("📁 Archivo: $env_path")
    println()
    println("Siguiente paso:")
    println("  1. cd <directorio-trabajo>")
    println("  2. julia -e 'using QuickTemplates; init_config()'")
    println("  3. Editar config.toml (solo name + features)")
    println("  4. julia -e 'using QuickTemplates; generate()'")
end

# === Init Config ===

function init_config()
    template_path = joinpath(dirname(@__DIR__), "config", "config.toml.template")
    isfile(template_path) || error("❌ config.toml.template no encontrado en package")

    dest_path = "config.toml"

    _check_existing_config(dest_path) || return

    cp(template_path, dest_path; force=true)

    _print_init_footer()
end

function _check_existing_config(dest_path::String)::Bool
    isfile(dest_path) || return true

    print("⚠️  config.toml ya existe. ¿Sobrescribir? [y/N]: ")
    response = strip(readline())

    lowercase(response) == "y" || (println("✓ Operación cancelada"); return false)
    return true
end

function _print_init_footer()
    println("✅ config.toml creado")
    println("📝 Edita config.toml y cambia:")
    println("   - name = \"TuPaquete\"")
    println("   - Activa features que necesites (true/false)")
    println()
    println("Luego ejecuta: julia -e 'using QuickTemplates; generate()'")
end

end # module
