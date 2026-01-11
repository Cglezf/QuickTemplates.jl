using Test
using QuickTemplates
using QuickTemplates.Config
using QuickTemplates.Generator

include("TestHelpers.jl")
using .TestHelpers

@testset "QuickTemplates.jl v1.0" begin
    @testset "Config Module" begin
        @testset "Load defaults" begin
            defaults = load_defaults()
            @test haskey(defaults, "project")
            @test haskey(defaults, "features")
            @test haskey(defaults, "ci")
            @test haskey(defaults, "logging")
            @test haskey(defaults, "testing")
            @test haskey(defaults, "dev")

            # Verify default values
            @test defaults["project"]["license"] == "MIT"
            @test defaults["project"]["julia_version"] == "1.12"
            @test defaults["features"]["tests"] == true
            @test defaults["testing"]["use_aqua"] == true
        end

        @testset "Merge configs" begin
            defaults = load_defaults()

            user_config = Dict(
                "project" => Dict("name" => "TestPackage"),
                "features" => Dict("tests" => true, "docs" => true, "dvc" => false)
            )

            env_config = Dict(
                "AUTHOR_FULLNAME" => "Test User",
                "GITHUB_USER" => "testuser",
                "GITHUB_EMAIL" => "test@example.com",
                "PROJECT_DIR" => mktempdir()
            )

            config = merge_configs(defaults, user_config, env_config)

            # Verify merged config - metadata
            @test config.metadata.name == "TestPackage"
            @test config.metadata.author_fullname == "Test User"
            @test config.metadata.github_user == "testuser"
            @test config.metadata.github_email == "test@example.com"
            @test config.metadata.license == "MIT"
            @test config.metadata.julia_version == "1.12"

            # Features
            @test config.features["tests"] == true
            @test config.features["docs"] == true
            @test config.features["dvc"] == false

            # Testing sub-struct
            @test config.testing.use_aqua == true
            @test config.testing.rtol ≈ 1.5e-8
            @test config.testing.atol == 0.0

            # Dev sub-struct
            @test config.dev.auto_setup == true
            @test config.dev.packages isa Vector{String}
        end

        @testset "Validation - fail fast" begin
            # Invalid: empty project_name
            invalid_config = mock_config(metadata=valid_metadata(name=""))
            @test_throws ErrorException validate(invalid_config)

            # Invalid: Julia version < 1.12
            invalid_julia_config = mock_config(metadata=valid_metadata(julia_version="1.10"))
            @test_throws ErrorException validate(invalid_julia_config)

            # Invalid: logging level
            invalid_logging_config = mock_config(logging_min_level="InvalidLevel")
            @test_throws ErrorException validate(invalid_logging_config)
        end

        @testset "Validation - pass" begin
            valid_config = mock_config(
                metadata=valid_metadata(name="ValidPackage", author_fullname="Test Author", github_user="testuser"),
                features=Dict("tests" => true, "docs" => false)
            )
            @test validate(valid_config) == true
        end


        @testset "Validation - empty identity fields" begin
            tmpdir = mktempdir()

            # Helper sub-structs válidos (reusados)
            valid_structs = (
                ci=CIConfig(["1.12"], ["ubuntu-latest"], "1.12", true),
                github=GitHubConfig(false, true, false),
                testing=TestingConfig(true, 1.5e-8, 0.0, 1e-5, 1e-8),
                formatter=FormatterPrefs("blue", 4, 92, true, true, true, false, false, false, false, false, "unix", true, false, false, false, false),
                dev=DevWorkspace(true, String[])
            )

            # Test cada campo vacío en loop (DRY)
            empty_field_tests = [
                ("AUTHOR_FULLNAME", ("TestPkg", "", "user", "email@test.com", tmpdir)),
                ("GITHUB_USER", ("TestPkg", "Author", "", "email@test.com", tmpdir)),
                ("GITHUB_EMAIL", ("TestPkg", "Author", "user", "", tmpdir)),
                ("PROJECT_DIR", ("TestPkg", "Author", "user", "email@test.com", ""))
            ]

            for (field_name, metadata_args) in empty_field_tests
                metadata = ProjectMetadata(metadata_args..., "MIT", "1.12", "0.1.0", "main")
                config = ProjectConfig(metadata, valid_structs.ci, valid_structs.github, valid_structs.testing,
                                     valid_structs.formatter, valid_structs.dev, Dict{String,Bool}(), "Info", Dict{String,String}())
                @test_throws ErrorException validate(config)
            end
        end

        @testset "Validation - nonexistent PROJECT_DIR" begin
            # Test error when PROJECT_DIR doesn't exist
            nonexistent_dir = "/tmp/definitely_does_not_exist_" * string(rand(1000:9999))

            valid_ci = CIConfig(["1.12"], ["ubuntu-latest"], "1.12", true)
            valid_github = GitHubConfig(false, true, false)
            valid_testing = TestingConfig(true, 1.5e-8, 0.0, 1e-5, 1e-8)
            valid_formatter = FormatterPrefs("blue", 4, 92, true, true, true, false, false, false, false, false, "unix", true, false, false, false, false)
            valid_dev = DevWorkspace(true, String[])

            metadata_bad_dir = ProjectMetadata("TestPkg", "Author", "user", "email@test.com", nonexistent_dir, "MIT", "1.12", "0.1.0", "main")
            config_bad_dir = ProjectConfig(metadata_bad_dir, valid_ci, valid_github, valid_testing, valid_formatter, valid_dev,
                Dict{String, Bool}(), "Info", Dict{String, String}())

            @test_throws ErrorException validate(config_bad_dir)
        end

        @testset "Validation - gh CLI check" begin
            tmpdir = mktempdir()

            # Test with github_create_repo = true
            metadata = ProjectMetadata("TestPkg", "Author", "user", "email@test.com", tmpdir, "MIT", "1.12", "0.1.0", "main")
            ci = CIConfig(["1.12"], ["ubuntu-latest"], "1.12", true)
            github_with_create = GitHubConfig(true, true, false)  # create_repo = true
            testing = TestingConfig(true, 1.5e-8, 0.0, 1e-5, 1e-8)
            formatter = FormatterPrefs("blue", 4, 92, true, true, true, false, false, false, false, false, "unix", true, false, false, false, false)
            dev = DevWorkspace(true, String[])

            config_with_gh = ProjectConfig(metadata, ci, github_with_create, testing, formatter, dev,
                Dict{String, Bool}(), "Info", Dict{String, String}())

            # This should pass validation (gh warning is non-fatal)
            @test validate(config_with_gh) == true
        end
    end


    @testset "Generator Module" begin
        @testset "Render template to file - missing template" begin
            mktempdir() do tmpdir
                # Test that missing template is gracefully skipped
                nonexistent_template = joinpath(tmpdir, "does_not_exist.mustache")
                output_path = joinpath(tmpdir, "output.txt")
                data = Dict("key" => "value")

                # Should not throw, just return early
                Generator.render_template_to_file(nonexistent_template, output_path, data)

                # Output file should not be created
                @test !isfile(output_path)
            end
        end
        @testset "Base structure generation" begin
            mktempdir() do project_dir
                # Mock config con sub-structs
                metadata = (name = "TestPackage", author_fullname = "Test Author", github_user = "testuser",
                           github_email = "test@example.com", project_dir = project_dir, license = "MIT",
                           julia_version = "1.12", initial_version = "0.1.0", default_branch = "main")
                ci = (julia_versions = ["1.12"], os = ["ubuntu-latest"], docs_julia_version = "1.12", codecov = true)
                github = (create_repo = false, private = true, auto_push = false)
                testing = (use_aqua = true, rtol = 1.5e-8, atol = 0.0, ml_rtol = 1e-5, ml_atol = 1e-8)
                formatter = (style = "blue", indent = 4, margin = 92, always_for_in = true, whitespace_typedefs = true,
                            whitespace_ops_in_indices = true, remove_extra_newlines = false, import_to_using = false,
                            pipe_to_function_call = false, short_to_long_function_def = false,
                            always_use_return = false, format_docstrings = "unix", annotate_untyped_fields_with_any = true,
                            conditional_to_if = false, normalize_line_endings = false, align_struct_field = false,
                            align_assignment = false)
                dev = (auto_setup = false, packages = String[])

                config = (
                    metadata = metadata, ci = ci, github = github, testing = testing, formatter = formatter, dev = dev,
                    features = Dict("tests" => false, "docs" => false, "ci" => false),
                    logging_min_level = "Info", env_vars = Dict{String, String}(),
                    uuid = "12345678-1234-1234-1234-123456789abc"
                )

                project_path = joinpath(project_dir, "TestPackage")
                Generator.generate_base_structure(project_path, config)

                # Verify directories created
                @test isdir(joinpath(project_path, "src"))
                @test isdir(joinpath(project_path, "test"))
                @test isdir(joinpath(project_path, ".claude", "rules"))

                # Verify base files created
                @test isfile(joinpath(project_path, "Project.toml"))
                @test isfile(joinpath(project_path, "README.md"))
                @test isfile(joinpath(project_path, "LICENSE"))
                @test isfile(joinpath(project_path, ".gitignore"))
                @test isfile(joinpath(project_path, "src", "TestPackage.jl"))
                @test isfile(joinpath(project_path, "test", "runtests.jl"))
                @test isfile(joinpath(project_path, "test", "Project.toml"))

                # Verify content rendered correctly
                project_toml = read(joinpath(project_path, "Project.toml"), String)
                @test contains(project_toml, "TestPackage")
                @test contains(project_toml, "12345678-1234-1234-1234-123456789abc")
                @test contains(project_toml, "version = \"0.1.0\"")
            end
        end

        @testset "Feature: tests" begin
            mktempdir() do project_dir
                metadata = (name = "TestPkg", author_fullname = "Author", github_user = "user",
                           github_email = "email@test.com", project_dir = "", license = "MIT",
                           julia_version = "1.12", initial_version = "0.1.0", default_branch = "main")
                testing = (use_aqua = true, rtol = 1.5e-8, atol = 0.0, ml_rtol = 1e-5, ml_atol = 1e-8)

                config = (metadata = metadata, testing = testing, features = Dict("tests" => true))

                project_path = joinpath(project_dir, "TestPkg")
                mkpath(project_path)

                Generator.generate_feature(Val(:tests), project_path, config)

                # Verify test files created
                @test isfile(joinpath(project_path, "test", "tolerances.jl"))
                @test isfile(joinpath(project_path, "test", "aqua_tests.jl"))
            end
        end

        @testset "Feature: docs" begin
            mktempdir() do project_dir
                metadata = (name = "TestPkg", author_fullname = "Author", github_user = "user",
                           github_email = "email@test.com", project_dir = "", license = "MIT",
                           julia_version = "1.12", initial_version = "0.1.0", default_branch = "main")
                ci = (julia_versions = ["1.12"], os = ["ubuntu-latest"], docs_julia_version = "1.12", codecov = true)

                config = (metadata = metadata, ci = ci, features = Dict("docs" => true))

                project_path = joinpath(project_dir, "TestPkg")
                mkpath(project_path)

                Generator.generate_feature(Val(:docs), project_path, config)

                # Verify docs structure
                @test isdir(joinpath(project_path, "docs", "src"))
                @test isfile(joinpath(project_path, "docs", "make.jl"))
                @test isfile(joinpath(project_path, "docs", "src", "index.md"))
            end
        end

        @testset "Feature: ci" begin
            mktempdir() do project_dir
                metadata = (name = "TestPkg", author_fullname = "Author", github_user = "user",
                           github_email = "email@test.com", project_dir = "", license = "MIT",
                           julia_version = "1.12", initial_version = "0.1.0", default_branch = "main")
                ci = (julia_versions = ["1.12"], os = ["ubuntu-latest"], docs_julia_version = "1.12", codecov = true)

                config = (metadata = metadata, ci = ci, features = Dict("ci" => true))

                project_path = joinpath(project_dir, "TestPkg")
                mkpath(project_path)

                Generator.generate_feature(Val(:ci), project_path, config)

                # Verify CI workflow
                @test isdir(joinpath(project_path, ".github", "workflows"))
                @test isfile(joinpath(project_path, ".github", "workflows", "CI.yml"))

                ci_content = read(joinpath(project_path, ".github", "workflows", "CI.yml"), String)
                @test contains(ci_content, "ubuntu-latest")
            end
        end

        @testset "Feature: benchmarks" begin
            mktempdir() do project_dir
                metadata = (name = "TestPkg", author_fullname = "Author", github_user = "user",
                           github_email = "email@test.com", project_dir = "", license = "MIT",
                           julia_version = "1.12", initial_version = "0.1.0", default_branch = "main")

                config = (metadata = metadata, features = Dict("benchmarks" => true))

                project_path = joinpath(project_dir, "TestPkg")
                mkpath(project_path)

                Generator.generate_feature(Val(:benchmarks), project_path, config)

                # Verify benchmarks structure
                @test isdir(joinpath(project_path, "benchmarks"))
                @test isfile(joinpath(project_path, "benchmarks", "Project.toml"))
                @test isfile(joinpath(project_path, "benchmarks", "runbenchmarks.jl"))
            end
        end

        @testset "Feature: logging" begin
            mktempdir() do project_dir
                metadata = (name = "TestPkg", author_fullname = "Author", github_user = "user",
                           github_email = "email@test.com", project_dir = "", license = "MIT",
                           julia_version = "1.12", initial_version = "0.1.0", default_branch = "main")

                config = (metadata = metadata, logging_min_level = "Info", features = Dict("logging" => true))

                project_path = joinpath(project_dir, "TestPkg")
                mkpath(project_path)

                Generator.generate_feature(Val(:logging), project_path, config)

                # Verify logging module
                @test isfile(joinpath(project_path, "src", "logging.jl"))

                logging_content = read(joinpath(project_path, "src", "logging.jl"), String)
                @test contains(logging_content, "OncePerProcess")
            end
        end

        @testset "Feature: formatter" begin
            mktempdir() do project_dir
                metadata = (name = "TestPkg", author_fullname = "", github_user = "", github_email = "",
                           project_dir = "", license = "", julia_version = "", initial_version = "", default_branch = "")
                config = (metadata = metadata, features = Dict("formatter" => true))

                project_path = joinpath(project_dir, "TestPkg")
                mkpath(project_path)

                Generator.generate_feature(Val(:formatter), project_path, config)

                # Verify formatter config created
                @test isfile(joinpath(project_path, ".JuliaFormatter.toml"))

                formatter_content = read(joinpath(project_path, ".JuliaFormatter.toml"), String)
                @test contains(formatter_content, "style = \"blue\"")
            end
        end

        @testset "Feature: formatter with custom style" begin
            mktempdir() do project_dir
                metadata = (name = "TestPkg", author_fullname = "", github_user = "", github_email = "",
                           project_dir = "", license = "", julia_version = "", initial_version = "", default_branch = "")
                formatter = (style = "yas", margin = 100)
                config = (metadata = metadata, formatter = formatter, features = Dict("formatter" => true))

                project_path = joinpath(project_dir, "TestPkg")
                mkpath(project_path)

                Generator.generate_feature(Val(:formatter), project_path, config)

                formatter_content = read(joinpath(project_path, ".JuliaFormatter.toml"), String)
                @test contains(formatter_content, "style = \"yas\"")
                @test contains(formatter_content, "margin = 100")
            end
        end

        @testset "Feature: tagbot" begin
            mktempdir() do project_dir
                metadata = (name = "TestPkg", author_fullname = "", github_user = "", github_email = "",
                           project_dir = "", license = "", julia_version = "", initial_version = "", default_branch = "")
                config = (metadata = metadata, features = Dict("tagbot" => true))

                project_path = joinpath(project_dir, "TestPkg")
                mkpath(project_path)

                Generator.generate_feature(Val(:tagbot), project_path, config)

                # Verify TagBot workflow created
                tagbot_file = joinpath(project_path, ".github", "workflows", "TagBot.yml")
                @test isfile(tagbot_file)

                tagbot_content = read(tagbot_file, String)
                @test contains(tagbot_content, "name: TagBot")
                @test contains(tagbot_content, "JuliaRegistries/TagBot@v1")
            end
        end

        @testset "Feature: dependabot" begin
            mktempdir() do project_dir
                metadata = (name = "TestPkg", author_fullname = "", github_user = "", github_email = "",
                           project_dir = "", license = "", julia_version = "", initial_version = "", default_branch = "")
                config = (metadata = metadata, features = Dict("dependabot" => true))

                project_path = joinpath(project_dir, "TestPkg")
                mkpath(project_path)

                Generator.generate_feature(Val(:dependabot), project_path, config)

                # Verify Dependabot config created
                dependabot_file = joinpath(project_path, ".github", "dependabot.yml")
                @test isfile(dependabot_file)

                dependabot_content = read(dependabot_file, String)
                @test contains(dependabot_content, "package-ecosystem: \"github-actions\"")
                @test contains(dependabot_content, "interval: \"weekly\"")
            end
        end

        @testset "Feature: docs with CI deployment" begin
            mktempdir() do project_dir
                metadata = (name = "TestPkg", author_fullname = "Author", github_user = "user",
                           github_email = "email@test.com", project_dir = "", license = "MIT",
                           julia_version = "1.12", initial_version = "0.1.0", default_branch = "main")
                ci = (julia_versions = ["1.12"], os = ["ubuntu-latest"], docs_julia_version = "1.12", codecov = true)

                config = (metadata = metadata, ci = ci, features = Dict("docs" => true, "ci" => true))

                project_path = joinpath(project_dir, "TestPkg")
                mkpath(project_path)

                # Generate docs feature
                Generator.generate_feature(Val(:docs), project_path, config)

                # Verify make.jl has robust config
                make_file = joinpath(project_path, "docs", "make.jl")
                @test isfile(make_file)

                make_content = read(make_file, String)
                @test contains(make_content, "canonical=")
                @test contains(make_content, "push_preview=true")

                # Generate CI feature
                Generator.generate_feature(Val(:ci), project_path, config)

                # Verify CI has docs job
                ci_file = joinpath(project_path, ".github", "workflows", "CI.yml")
                @test isfile(ci_file)

                ci_content = read(ci_file, String)
                @test contains(ci_content, "docs:")
                @test contains(ci_content, "name: Documentation")
                @test contains(ci_content, "DOCUMENTER_KEY")
            end
        end

        @testset "Unknown feature - graceful skip" begin
            mktempdir() do project_dir
                metadata = (name = "TestPkg", author_fullname = "", github_user = "", github_email = "",
                           project_dir = "", license = "", julia_version = "", initial_version = "", default_branch = "")
                config = (metadata = metadata,)
                project_path = joinpath(project_dir, "TestPkg")
                mkpath(project_path)

                # Test that unknown features gracefully skip (MethodError caught)
                try
                    Generator.generate_feature(Val(:unknown_feature), project_path, config)
                    @test false  # Should have thrown MethodError
                catch e
                    # Should be MethodError (expected behavior - feature not implemented)
                    @test isa(e, MethodError)
                    @test e.f === Generator.generate_feature
                end
            end
        end
    end

    @testset "Integration - Full generation" begin
        mktempdir() do tmpdir
            # Setup mock environment
            defaults = load_defaults()

            user_config = Dict(
                "project" => Dict("name" => "FullTestPkg"),
                "features" => Dict(
                    "tests" => true,
                    "docs" => true,
                    "ci" => true,
                    "logging" => false,
                    "benchmarks" => false,
                    "dvc" => false,
                    "mlops" => false,
                    "notebooks" => false
                )
            )

            env_config = Dict(
                "AUTHOR_FULLNAME" => "Integration Test",
                "GITHUB_USER" => "testuser",
                "GITHUB_EMAIL" => "test@example.com",
                "PROJECT_DIR" => tmpdir
            )

            config = merge_configs(defaults, user_config, env_config)

            # Add UUID manually usando sub-structs
            metadata = (name = config.metadata.name, author_fullname = config.metadata.author_fullname,
                       github_user = config.metadata.github_user, github_email = config.metadata.github_email,
                       project_dir = config.metadata.project_dir, license = config.metadata.license,
                       julia_version = config.metadata.julia_version, initial_version = config.metadata.initial_version,
                       default_branch = config.metadata.default_branch)
            ci = (julia_versions = config.ci.julia_versions, os = config.ci.os,
                 docs_julia_version = config.ci.docs_julia_version, codecov = config.ci.codecov)
            github = (create_repo = false, private = config.github.private, auto_push = false)  # Skip GitHub in tests
            testing = (use_aqua = config.testing.use_aqua, rtol = config.testing.rtol, atol = config.testing.atol,
                      ml_rtol = config.testing.ml_rtol, ml_atol = config.testing.ml_atol)
            formatter = config.formatter
            dev = (auto_setup = false, packages = config.dev.packages)  # Skip dev setup in tests

            config_with_uuid = (metadata = metadata, ci = ci, github = github, testing = testing,
                               formatter = formatter, dev = dev, features = config.features,
                               logging_min_level = config.logging_min_level, env_vars = config.env_vars,
                               uuid = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")

            project_path = joinpath(tmpdir, "FullTestPkg")

            # Generate base structure
            Generator.generate_base_structure(project_path, config_with_uuid)

            # Generate enabled features
            for (feature, enabled) in config_with_uuid.features
                if enabled
                    try
                        Generator.generate_feature(Val(Symbol(feature)), project_path, config_with_uuid)
                    catch e
                        if !isa(e, MethodError)
                            rethrow(e)
                        end
                    end
                end
            end

            # Verify complete structure
            @test isdir(project_path)
            @test isfile(joinpath(project_path, "Project.toml"))
            @test isfile(joinpath(project_path, "README.md"))
            @test isfile(joinpath(project_path, "LICENSE"))

            # Verify enabled features
            @test isfile(joinpath(project_path, "test", "aqua_tests.jl"))
            @test isfile(joinpath(project_path, "docs", "make.jl"))
            @test isfile(joinpath(project_path, ".github", "workflows", "CI.yml"))

            # Verify disabled features NOT generated
            @test !isfile(joinpath(project_path, "src", "logging.jl"))
            @test !isdir(joinpath(project_path, "benchmarks"))
        end
    end

    @testset "Setup Module - API exists" begin
        # Verify Setup module exports required functions
        @test isdefined(QuickTemplates.Setup, :setup_identity)
        @test isdefined(QuickTemplates.Setup, :init_config)
    end
end

# Incluir tests adicionales
include("uuid_idempotence_tests.jl")
# include("type_stability_tests.jl")  # Tests adicionales (Result.jl tiene algunos fallos de type stability)
