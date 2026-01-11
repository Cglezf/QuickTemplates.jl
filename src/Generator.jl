module Generator

export generate_project, generate_local_env

using Dates
using UUIDs
using Mustache
using ..FormatterConfig: from_config, to_dict
using ..Config: ProjectConfig, FormatterPrefs

# === Constants ===

const TEMPLATES_DIR = joinpath(dirname(@__DIR__), "templates")

# === Template Data Preparation (composable functions) ===

prepare_template_data(config::NamedTuple) = _build_template_dict(config)
prepare_template_data(config) = _build_template_dict(config)

function _build_template_dict(cfg)::Dict{String,Any}
    base_data = _build_base_data(cfg)

    # Use FormatterConfig.to_dict for formatter data (SSOT)
    formatter_data = _get_formatter_dict(cfg)
    merge!(base_data, formatter_data)

    _merge_env_vars!(base_data, cfg)
    return base_data
end

function _build_base_data(cfg)::Dict{String,Any}
    return Dict{String,Any}(
        "project_name" => _get_metadata_field(cfg, :name),
        "author_fullname" => _get_metadata_field(cfg, :author_fullname),
        "github_user" => _get_metadata_field(cfg, :github_user),
        "github_email" => _get_metadata_field(cfg, :github_email),
        "license" => _get_metadata_field(cfg, :license),
        "julia_version" => _get_metadata_field(cfg, :julia_version),
        "initial_version" => _get_metadata_field(cfg, :initial_version),
        "default_branch" => _get_metadata_field(cfg, :default_branch),
        "uuid" => haskey(cfg, :uuid) ? cfg.uuid : "",
        "year" => string(Dates.year(Dates.now())),
        "open" => "\${{",
        "close" => "}}",
        "features" => haskey(cfg, :features) ? cfg.features : Dict{String,Bool}(),
        "ci" => _build_ci_data(cfg),
        "github" => _build_github_data(cfg),
        "logging_min_level" => haskey(cfg, :logging_min_level) ? cfg.logging_min_level : "Info",
        "testing_rtol" => _get_testing_field(cfg, :rtol),
        "testing_atol" => _get_testing_field(cfg, :atol),
        "testing_ml_rtol" => _get_testing_field(cfg, :ml_rtol),
        "testing_ml_atol" => _get_testing_field(cfg, :ml_atol),
        "dev_packages" => _get_dev_field(cfg, :packages)
    )
end

# Type-stable getters usando multiple dispatch
@inline _get_metadata_field(cfg::ProjectConfig, field::Symbol)::String = getfield(cfg.metadata, field)

@inline function _get_metadata_field(cfg, field::Symbol)::String
    haskey(cfg, :metadata) ? getfield(cfg.metadata, field) : (haskey(cfg, field) ? cfg[field] : "")
end

@inline _get_testing_field(cfg::ProjectConfig, field::Symbol)::Float64 = getfield(cfg.testing, field)

@inline function _get_testing_field(cfg, field::Symbol)::Float64
    haskey(cfg, :testing) ? getfield(cfg.testing, field) : (haskey(cfg, Symbol("testing_$field")) ? cfg[Symbol("testing_$field")] : 0.0)
end

@inline _get_dev_field(cfg::ProjectConfig, field::Symbol)::Vector{String} = getfield(cfg.dev, field)

@inline function _get_dev_field(cfg, field::Symbol)::Vector{String}
    haskey(cfg, :dev) ? getfield(cfg.dev, field) : (haskey(cfg, Symbol("dev_$field")) ? cfg[Symbol("dev_$field")] : String[])
end

# Formatter field con type-stable dispatch y sin silent catch
@inline function _get_formatter_field(cfg::ProjectConfig, field::Symbol, default)
    field in fieldnames(FormatterPrefs) ? getfield(cfg.formatter, field) : default
end

@inline function _get_formatter_field(cfg, field::Symbol, default)
    if haskey(cfg, :formatter)
        f = cfg.formatter
        # Type-safe: check if field exists antes de acceder
        if isa(f, FormatterPrefs) && field in fieldnames(FormatterPrefs)
            return getfield(f, field)
        elseif haskey(f, field)
            return f[field]
        end
    end
    haskey(cfg, Symbol("formatter_$field")) && return cfg[Symbol("formatter_$field")]
    return default
end

function _build_ci_data(cfg)::Dict
    haskey(cfg, :ci) && return Dict(
        "julia_versions" => cfg.ci.julia_versions,
        "os" => cfg.ci.os,
        "docs_julia_version" => cfg.ci.docs_julia_version,
        "codecov" => cfg.ci.codecov
    )

    # Fallback para NamedTuple (debe tener valores por construcción)
    return Dict(
        "julia_versions" => haskey(cfg, :ci_julia_versions) ? cfg.ci_julia_versions : ["1.12"],
        "os" => haskey(cfg, :ci_os) ? cfg.ci_os : ["ubuntu-latest"],
        "docs_julia_version" => haskey(cfg, :ci_docs_julia_version) ? cfg.ci_docs_julia_version : "1.12",
        "codecov" => haskey(cfg, :codecov) ? cfg.codecov : true
    )
end

function _build_github_data(cfg)::Dict
    haskey(cfg, :github) && return Dict(
        "create_repo" => cfg.github.create_repo,
        "private" => cfg.github.private,
        "auto_push" => cfg.github.auto_push
    )

    # Fallback para NamedTuple (debe tener valores por construcción)
    return Dict(
        "create_repo" => haskey(cfg, :github_create_repo) ? cfg.github_create_repo : false,
        "private" => haskey(cfg, :github_private) ? cfg.github_private : true,
        "auto_push" => haskey(cfg, :github_auto_push) ? cfg.github_auto_push : false
    )
end

# Helper: Convert FormatterPrefs to Dict for templates (always use fallback path for compatibility)
function _get_formatter_dict(cfg)::Dict{String,Any}
    return Dict{String,Any}(
        "formatter_style" => _get_formatter_field(cfg, :style, "blue"),
        "formatter_indent" => _get_formatter_field(cfg, :indent, 4),
        "formatter_margin" => _get_formatter_field(cfg, :margin, 92),
        "formatter_always_for_in" => _get_formatter_field(cfg, :always_for_in, true),
        "formatter_whitespace_typedefs" => _get_formatter_field(cfg, :whitespace_typedefs, true),
        "formatter_whitespace_ops_in_indices" => _get_formatter_field(cfg, :whitespace_ops_in_indices, true),
        "formatter_import_to_using" => _get_formatter_field(cfg, :import_to_using, false),
        "formatter_pipe_to_function_call" => _get_formatter_field(cfg, :pipe_to_function_call, false),
        "formatter_short_to_long_function_def" => _get_formatter_field(cfg, :short_to_long_function_def, false),
        "formatter_always_use_return" => _get_formatter_field(cfg, :always_use_return, false),
        "formatter_conditional_to_if" => _get_formatter_field(cfg, :conditional_to_if, false),
        "formatter_normalize_line_endings" => _get_formatter_field(cfg, :normalize_line_endings, "unix"),
        "formatter_format_docstrings" => _get_formatter_field(cfg, :format_docstrings, true),
        "formatter_align_struct_field" => _get_formatter_field(cfg, :align_struct_field, false),
        "formatter_align_conditional" => _get_formatter_field(cfg, :align_conditional, false),
        "formatter_align_assignment" => _get_formatter_field(cfg, :align_assignment, false),
        "formatter_align_pair_arrow" => _get_formatter_field(cfg, :align_pair_arrow, false)
    )
end

function _merge_env_vars!(data::Dict, cfg)
    haskey(cfg, :env_vars) && merge!(data, cfg.env_vars)
end

# === Template Rendering ===

function render_template_to_file(template_path::String, output_path::String, data::Dict; force::Bool=false)
    isfile(template_path) || return

    # Idempotencia: Skip si archivo existe Y no force
    # Archivos core (src/, test/, README, Project.toml) protegidos por defecto
    if isfile(output_path) && !force
        @debug "Skipping $output_path (already exists)"
        return
    end

    template_content = read(template_path, String)
    rendered = Mustache.render(template_content, data)

    output_dir = dirname(output_path)
    !isdir(output_dir) && mkpath(output_dir)

    write(output_path, rendered)
end

# === Feature Generation (Multiple Dispatch) ===

"""
    generate_feature(::Val{Feature}, path, config)

Extension point vía multiple dispatch para generar features.
"""
function generate_feature end

# === Base Structure ===

function generate_base_structure(project_path::String, config)
    _create_base_dirs(project_path)
    _render_base_templates(project_path, config)
    _render_claude_rules(project_path, config)
end

_create_base_dirs(project_path::String) = (
    mkpath(joinpath(project_path, "src"));
    mkpath(joinpath(project_path, "test"));
    mkpath(joinpath(project_path, ".claude", "rules"))
)

function _render_base_templates(project_path::String, config)
    data = prepare_template_data(config)
    project_name = _get_metadata_field(config, :name)

    base_templates = [
        ("root/Project.toml.mustache", "Project.toml"),
        ("root/README.md.mustache", "README.md"),
        ("root/LICENSE.mustache", "LICENSE"),
        ("root/.gitignore.mustache", ".gitignore"),
        ("src/Module.jl.mustache", "src/$project_name.jl"),
        ("test/Project.toml.mustache", "test/Project.toml"),
        ("test/runtests.jl.mustache", "test/runtests.jl")
    ]

    for (template_name, output_name) in base_templates
        template_path = joinpath(TEMPLATES_DIR, template_name)
        output_path = joinpath(project_path, output_name)
        render_template_to_file(template_path, output_path, data)
    end
end

function _render_claude_rules(project_path::String, config)
    data = prepare_template_data(config)
    render_template_to_file(
        joinpath(TEMPLATES_DIR, ".claude/rules/workflow.md.mustache"),
        joinpath(project_path, ".claude/rules/workflow.md"),
        data
    )
end

# === Feature Implementations ===

function generate_feature(::Val{:docs}, project_path, config)
    mkpath(joinpath(project_path, "docs", "src"))
    data = prepare_template_data(config)

    docs_templates = [
        ("docs/Project.toml.mustache", "docs/Project.toml"),
        ("docs/make.jl.mustache", "docs/make.jl"),
        ("docs/src/index.md.mustache", "docs/src/index.md")
    ]

    for (template_name, output_name) in docs_templates
        render_template_to_file(
            joinpath(TEMPLATES_DIR, template_name),
            joinpath(project_path, output_name),
            data
        )
    end
end

function generate_feature(::Val{:ci}, project_path, config)
    mkpath(joinpath(project_path, ".github", "workflows"))
    data = prepare_template_data(config)

    render_template_to_file(
        joinpath(TEMPLATES_DIR, ".github/workflows/CI.yml.mustache"),
        joinpath(project_path, ".github/workflows/CI.yml"),
        data
    )

    # Auto-include TagBot y Dependabot (opt-out)
    features = haskey(config, :features) ? config.features : Dict()
    _get_feature_flag(features, "tagbot", true) && generate_feature(Val(:tagbot), project_path, config)
    _get_feature_flag(features, "dependabot", true) && generate_feature(Val(:dependabot), project_path, config)
end

function generate_feature(::Val{:drwatson}, project_path, config)
    drwatson_dirs = ["scripts", "data", "plots", "notebooks", "papers"]
    foreach(dir -> mkpath(joinpath(project_path, dir)), drwatson_dirs)

    data = prepare_template_data(config)
    render_template_to_file(
        joinpath(TEMPLATES_DIR, "scripts/example.jl.mustache"),
        joinpath(project_path, "scripts/01_example.jl"),
        data
    )

    # Generate notebook (DrWatson implies notebooks)
    render_template_to_file(
        joinpath(TEMPLATES_DIR, "notebooks/analysis.ipynb.mustache"),
        joinpath(project_path, "notebooks/01_analysis.ipynb"),
        data
    )

    _append_drwatson_gitignore(project_path)
end

function _append_drwatson_gitignore(project_path::String)
    gitignore_path = joinpath(project_path, ".gitignore")
    current_content = isfile(gitignore_path) ? read(gitignore_path, String) : ""

    drwatson_gitignore = read(joinpath(TEMPLATES_DIR, "drwatson/.gitignore.mustache"), String)

    # Idempotencia: Skip si ya contiene el contenido DrWatson
    contains(current_content, "# DrWatson .gitignore additions") && return

    open(gitignore_path, "a") do io
        write(io, "\n" * drwatson_gitignore)
    end
end

function generate_feature(::Val{:dev_mode}, project_path, config)
    mkpath(joinpath(project_path, "dev"))
    data = prepare_template_data(config)

    render_template_to_file(
        joinpath(TEMPLATES_DIR, "dev/Project.toml.mustache"),
        joinpath(project_path, "dev/Project.toml"),
        data
    )
end

function generate_feature(::Val{:benchmarks}, project_path, config)
    mkpath(joinpath(project_path, "benchmarks"))
    data = prepare_template_data(config)

    benchmarks_templates = [
        ("benchmarks/Project.toml.mustache", "benchmarks/Project.toml"),
        ("benchmarks/runbenchmarks.jl.mustache", "benchmarks/runbenchmarks.jl")
    ]

    for (template_name, output_name) in benchmarks_templates
        render_template_to_file(
            joinpath(TEMPLATES_DIR, template_name),
            joinpath(project_path, output_name),
            data
        )
    end
end

function generate_feature(::Val{:logging}, project_path, config)
    data = prepare_template_data(config)
    render_template_to_file(
        joinpath(TEMPLATES_DIR, "src/logging.jl.mustache"),
        joinpath(project_path, "src/logging.jl"),
        data
    )
end

function generate_feature(::Val{:tests}, project_path, config)
    data = prepare_template_data(config)

    tests_templates = [
        ("test/tolerances.jl.mustache", "test/tolerances.jl"),
        ("test/aqua_tests.jl.mustache", "test/aqua_tests.jl")
    ]

    for (template_name, output_name) in tests_templates
        render_template_to_file(
            joinpath(TEMPLATES_DIR, template_name),
            joinpath(project_path, output_name),
            data
        )
    end
end

function generate_feature(::Val{:formatter}, project_path, config)
    data = prepare_template_data(config)
    render_template_to_file(
        joinpath(TEMPLATES_DIR, "root/.JuliaFormatter.toml.mustache"),
        joinpath(project_path, ".JuliaFormatter.toml"),
        data
    )
end

function generate_feature(::Val{:tagbot}, project_path, config)
    data = prepare_template_data(config)
    github_workflows_dir = joinpath(project_path, ".github", "workflows")
    mkpath(github_workflows_dir)

    render_template_to_file(
        joinpath(TEMPLATES_DIR, ".github/workflows/TagBot.yml.mustache"),
        joinpath(github_workflows_dir, "TagBot.yml"),
        data
    )
end

function generate_feature(::Val{:dependabot}, project_path, config)
    data = prepare_template_data(config)
    github_dir = joinpath(project_path, ".github")
    mkpath(github_dir)

    render_template_to_file(
        joinpath(TEMPLATES_DIR, ".github/dependabot.yml.mustache"),
        joinpath(github_dir, "dependabot.yml"),
        data
    )
end

function generate_feature(::Val{:result_types}, project_path, config)
    data = prepare_template_data(config)
    render_template_to_file(
        joinpath(TEMPLATES_DIR, "src/Result.jl.mustache"),
        joinpath(project_path, "src/Result.jl"),
        data
    )
end

function generate_feature(::Val{:notebooks}, project_path, config)
    mkpath(joinpath(project_path, "notebooks"))
    mkpath(joinpath(project_path, ".vscode"))

    data = prepare_template_data(config)

    # Generate notebook
    render_template_to_file(
        joinpath(TEMPLATES_DIR, "notebooks/analysis.ipynb.mustache"),
        joinpath(project_path, "notebooks/01_analysis.ipynb"),
        data
    )

    # Generate .vscode/settings.json
    render_template_to_file(
        joinpath(TEMPLATES_DIR, ".vscode/settings.json.mustache"),
        joinpath(project_path, ".vscode/settings.json"),
        data
    )

    _append_notebooks_gitignore(project_path)
end

function _append_notebooks_gitignore(project_path::String)
    gitignore_path = joinpath(project_path, ".gitignore")
    current_content = isfile(gitignore_path) ? read(gitignore_path, String) : ""

    notebooks_gitignore = read(joinpath(TEMPLATES_DIR, "notebooks/.gitignore.mustache"), String)

    # Idempotencia: Skip si ya contiene el contenido notebooks
    contains(current_content, "# Jupyter/Notebooks .gitignore additions") && return

    open(gitignore_path, "a") do io
        write(io, "\n" * notebooks_gitignore)
    end
end

# === Project Generation ===

function generate_project(config)
    metadata = _get_project_metadata(config)
    project_path = joinpath(expanduser(metadata.project_dir), metadata.name)

    _print_generation_header(metadata.name, project_path)

    generate_base_structure(project_path, config)
    _generate_enabled_features(project_path, config)
    generate_local_env(config, project_path)
    run_postgen(project_path, config)

    _print_generation_footer(metadata.name, project_path)
end

_get_project_metadata(config) = haskey(config, :metadata) ? config.metadata : config

function _print_generation_header(name::String, path::String)
    println("🚀 Generando proyecto $name")
    println("📁 Ubicación: $path")
    println()
end

function _print_generation_footer(name::String, path::String)
    println()
    println("✅ Proyecto $name generado correctamente")
    println("📁 Ruta: $path")
    println()
    println("Siguiente paso:")
    println("  cd $path")
    println("  julia --project")
end

function _generate_enabled_features(project_path::String, config)
    features = haskey(config, :features) ? config.features : Dict{String,Bool}()

    for (feature, enabled) in features
        enabled || continue

        try
            generate_feature(Val(Symbol(feature)), project_path, config)
        catch ex
            if isa(ex, MethodError)
                @warn "Feature '$feature' no implementado, omitiendo"
            else
                rethrow(ex)
            end
        end
    end
end

# === Local .env Generation ===

function generate_local_env(config, project_path::String)
    project_name = _get_metadata_field(config, :name)
    features = haskey(config, :features) ? config.features : Dict{String,Bool}()

    lines = _build_env_header(project_name, features)
    _get_feature_flag(features, "drwatson") && _add_drwatson_env!(lines)
    _add_data_storage_env!(lines)
    _add_database_env!(lines)

    write(joinpath(project_path, ".env"), join(lines, "\n"))
end

# Helper: Safe feature flag access (Dict or NamedTuple)
@inline function _get_feature_flag(features, key::String)::Bool
    isa(features, Dict) ? (haskey(features, key) ? features[key] : false) : (haskey(features, Symbol(key)) ? getfield(features, Symbol(key)) : false)
end

# Helper: Safe feature flag with default (para opt-out features como tagbot/dependabot)
@inline function _get_feature_flag(features, key::String, default::Bool)::Bool
    isa(features, Dict) ? (haskey(features, key) ? features[key] : default) : (haskey(features, Symbol(key)) ? getfield(features, Symbol(key)) : default)
end

function _build_env_header(project_name::String, features)::Vector{String}
    lines = [
        "# .env - Proyecto $project_name",
        "# Generado por QuickTemplates.jl"
    ]

    # features puede ser Dict o NamedTuple - safe access
    has_features = isa(features, Dict) ? any(values(features)) : !isempty(features)
    has_features && push!(lines, "# Este archivo sobreescribe ~/.config/QuickTemplates/.env para este proyecto")
    push!(lines, "")

    return lines
end

function _add_drwatson_env!(lines::Vector{String})
    append!(lines, [
        "# === DrWatson Configuration ===",
        "# Project-specific configurations",
        "# DATA_STORAGE_PATH=\"/path/to/large/datasets\"",
        ""
    ])
end

function _add_data_storage_env!(lines::Vector{String})
    append!(lines, [
        "# === Data Storage (descomentar si datos grandes) ===",
        "# DATA_DIR=\"/mnt/backup/datos\"",
        ""
    ])
end

function _add_database_env!(lines::Vector{String})
    append!(lines, [
        "# === Database (descomentar si datos grandes -> DuckDB) ===",
        "# DB_PATH=\"\${DATA_DIR}/database.duckdb\"",
        "# DB_READONLY=false"
    ])
end

# === Post-generation (divided into specialized functions) ===

function run_postgen(project_path::String, config)
    println("📦 Ejecutando post-generación...")

    _run_git_init(project_path)
    _run_pkg_instantiate(project_path, config)
    _run_drwatson_setup(project_path, config)
    _run_dev_workspace_setup(project_path, config)
    _run_docs_workspace_setup(project_path, config)
    _run_github_repo_creation(project_path, config)
    _run_dev_auto_setup(project_path, config)
end

function _run_git_init(project_path::String)
    try
        run(Cmd(`git init`, dir=project_path))
        run(Cmd(`git add .`, dir=project_path))
        run(Cmd(`git commit -m "Initial commit via QuickTemplates.jl"`, dir=project_path))
        println("  ✓ Git inicializado")
    catch e
        @warn "Git init falló: $e"
    end
end

function _run_pkg_instantiate(project_path::String, config)
    try
        run(Cmd(`julia --project -e "using Pkg; Pkg.instantiate()"`, dir=project_path))
        println("  ✓ Dependencias instaladas (main)")

        features = haskey(config, :features) ? config.features : Dict()
        _get_feature_flag(features, "tests") && _instantiate_workspace(project_path, "test")
    catch e
        @warn "Julia instantiate falló: $e"
    end
end

_instantiate_workspace(project_path::String, workspace::String) = try
    run(Cmd(`julia --project=$workspace -e "using Pkg; Pkg.instantiate()"`, dir=project_path))
    println("  ✓ Dependencias instaladas ($workspace)")
catch e
    @warn "$workspace workspace instantiate falló: $e"
end

function _run_drwatson_setup(project_path::String, config)
    features = haskey(config, :features) ? config.features : Dict()
    _get_feature_flag(features, "drwatson") && println("  ✓ DrWatson configurado")
end

function _run_dev_workspace_setup(project_path::String, config)
    features = haskey(config, :features) ? config.features : Dict()
    _get_feature_flag(features, "dev_mode") || return
    _instantiate_workspace(project_path, "dev")
end

function _run_docs_workspace_setup(project_path::String, config)
    features = haskey(config, :features) ? config.features : Dict()
    _get_feature_flag(features, "docs") || return
    _instantiate_workspace(project_path, "docs")
end

function _run_github_repo_creation(project_path::String, config)
    github = _get_github_config(config)
    github.create_repo || return

    try
        metadata = _get_project_metadata(config)
        _create_github_repo(metadata, github)
        _add_github_remote(project_path, metadata)
        _push_to_github_if_enabled(project_path, github)
    catch e
        @warn "GitHub repo creation falló: $e. Continuar manualmente."
    end
end

_get_github_config(config) = haskey(config, :github) ? config.github : config

function _create_github_repo(metadata, github)
    visibility = github.private ? "--private" : "--public"
    repo_name = "$(metadata.github_user)/$(metadata.name)"
    run(`gh repo create $repo_name $visibility`)
    println("  ✓ Repositorio GitHub creado: $repo_name")
end

function _add_github_remote(project_path::String, metadata)
    repo_name = "$(metadata.github_user)/$(metadata.name)"
    run(Cmd(`git remote add origin git@github.com:$repo_name.git`, dir=project_path))
end

function _push_to_github_if_enabled(project_path::String, github)
    github.auto_push || return

    current_branch = strip(read(Cmd(`git branch --show-current`, dir=project_path), String))

    # Test SSH connection usando success() - Julia idiomatic
    ssh_available = try
        # GitHub SSH retorna exit code 1 cuando autenticación es exitosa
        # (muestra mensaje de bienvenida pero no permite shell interactiva)
        process = run(pipeline(`ssh -T git@github.com`, stderr=devnull); wait=false)
        wait(process)
        process.exitcode in (0, 1)  # 0=OK, 1=authenticated no shell, 255=connection failed
    catch
        false
    end

    if ssh_available
        try
            run(Cmd(`git push -u origin $current_branch`, dir=project_path))
            println("  ✓ Push a GitHub exitoso ($current_branch)")
        catch e
            @warn "Push falló: $e\n   Verificar permisos del repositorio"
        end
    else
        @warn "SSH no disponible o no configurado\n   Configurar: https://docs.github.com/en/authentication/connecting-to-github-with-ssh\n   Push manual: git push -u origin $current_branch"
    end
end

function _run_dev_auto_setup(project_path::String, config)
    dev = haskey(config, :dev) ? config.dev : config
    auto_setup = haskey(config, :dev) ? dev.auto_setup : (haskey(config, :dev_auto_setup) ? config.dev_auto_setup : false)
    auto_setup || return

    data = prepare_template_data(config)

    _generate_startup_jl(project_path, data)
    _generate_dev_setup_script(project_path, data)

    println("  ✓ Dev workspace configurado")
    println("    Instalar paquetes: julia scripts/dev_setup.jl")
end

function _generate_startup_jl(project_path::String, data::Dict)
    startup_path = joinpath(project_path, ".julia/config/startup.jl")
    render_template_to_file(
        joinpath(TEMPLATES_DIR, ".julia/config/startup.jl.mustache"),
        startup_path,
        data
    )
end

function _generate_dev_setup_script(project_path::String, data::Dict)
    scripts_dir = joinpath(project_path, "scripts")
    mkpath(scripts_dir)
    render_template_to_file(
        joinpath(TEMPLATES_DIR, "scripts/dev_setup.jl.mustache"),
        joinpath(scripts_dir, "dev_setup.jl"),
        data
    )
end

end # module
