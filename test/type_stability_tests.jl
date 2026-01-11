using Test
using QuickTemplates
using QuickTemplates.Config
using QuickTemplates.Generator
using QuickTemplates.Result

@testset "Type Stability & Feature Tests" begin
    @testset "Type Stability" begin
        defaults = load_defaults()
        user = Dict("project" => Dict("name" => "TestPkg"))
        env = Dict(
            "AUTHOR_FULLNAME" => "Test",
            "GITHUB_USER" => "test",
            "GITHUB_EMAIL" => "test@test.com",
            "PROJECT_DIR" => mktempdir()
        )

        # CRITICAL: Test type stability con @inferred
        @testset "Config type stability" begin
            config = @inferred merge_configs(defaults, user, env)
            @test config isa ProjectConfig
            @test config.metadata isa ProjectMetadata
            @test config.ci isa CIConfig
            @test config.github isa GitHubConfig
            @test config.testing isa TestingConfig
            @test config.formatter isa FormatterPrefs
            @test config.dev isa DevWorkspace
        end

        @testset "Generator type stability" begin
            config = merge_configs(defaults, user, env)
            config_nt = (
                metadata=config.metadata,
                ci=config.ci,
                github=config.github,
                testing=config.testing,
                formatter=config.formatter,
                dev=config.dev,
                features=config.features,
                logging_min_level=config.logging_min_level,
                env_vars=config.env_vars,
                uuid="test-uuid"
            )

            data = @inferred Generator.prepare_template_data(config_nt)
            @test data isa Dict{String,Any}
        end
    end

    @testset "Sub-structs Composability" begin
        @testset "ProjectMetadata" begin
            metadata = ProjectMetadata(
                "TestPkg", "Author", "user", "email@test.com", "/tmp",
                "MIT", "1.12", "0.1.0", "main"
            )

            @test metadata.name == "TestPkg"
            @test metadata.license == "MIT"
            @test metadata.julia_version == "1.12"
        end

        @testset "CIConfig" begin
            ci = CIConfig(["1.12", "pre"], ["ubuntu-latest"], "1.12", true)

            @test ci.julia_versions == ["1.12", "pre"]
            @test ci.codecov == true
        end

        @testset "GitHubConfig" begin
            github = GitHubConfig(false, true, false)

            @test github.create_repo == false
            @test github.private == true
        end

        @testset "TestingConfig" begin
            testing = TestingConfig(true, 1.5e-8, 0.0, 1e-5, 1e-8)

            @test testing.use_aqua == true
            @test testing.rtol ≈ 1.5e-8
        end
    end

    @testset "Feature: drwatson" begin
        mktempdir() do project_dir
            config = (
                project_name="TestPkg",
                features=Dict("drwatson" => true)
            )

            project_path = joinpath(project_dir, "TestPkg")
            mkpath(project_path)

            Generator.generate_feature(Val(:drwatson), project_path, config)

            # Verify DrWatson directory structure
            @test isdir(joinpath(project_path, "scripts"))
            @test isdir(joinpath(project_path, "data"))
            @test isdir(joinpath(project_path, "plots"))
            @test isdir(joinpath(project_path, "notebooks"))
            @test isdir(joinpath(project_path, "papers"))

            # Verify example script created
            @test isfile(joinpath(project_path, "scripts/01_example.jl"))

            # Verify gitignore appended
            gitignore_content = read(joinpath(project_path, ".gitignore"), String)
            @test contains(gitignore_content, "data/")

            # Verify notebook created (DrWatson implies notebooks)
            @test isfile(joinpath(project_path, "notebooks/01_analysis.ipynb"))
        end
    end

    @testset "Feature: notebooks" begin
        mktempdir() do project_dir
            config = (
                project_name="TestPkg",
                julia_version="1.12",
                features=Dict("notebooks" => true)
            )

            project_path = joinpath(project_dir, "TestPkg")
            mkpath(project_path)

            Generator.generate_feature(Val(:notebooks), project_path, config)

            # Verify notebooks directory created
            @test isdir(joinpath(project_path, "notebooks"))

            # Verify notebook created
            @test isfile(joinpath(project_path, "notebooks/01_analysis.ipynb"))

            # Verify .vscode directory and settings.json created
            @test isdir(joinpath(project_path, ".vscode"))
            @test isfile(joinpath(project_path, ".vscode/settings.json"))

            # Verify settings.json content
            settings_content = read(joinpath(project_path, ".vscode/settings.json"), String)
            @test contains(settings_content, "julia.environmentPath")
            @test contains(settings_content, raw"${workspaceFolder}")

            # Verify gitignore appended
            gitignore_content = read(joinpath(project_path, ".gitignore"), String)
            @test contains(gitignore_content, ".ipynb_checkpoints")
        end
    end

    @testset "Feature: dev_mode" begin
        mktempdir() do project_dir
            config = (
                project_name="TestPkg",
                features=Dict("dev_mode" => true),
                dev_packages=["Revise", "OhMyREPL", "TestEnv"]
            )

            project_path = joinpath(project_dir, "TestPkg")
            mkpath(project_path)

            Generator.generate_feature(Val(:dev_mode), project_path, config)

            # Verify dev workspace created
            @test isdir(joinpath(project_path, "dev"))
            @test isfile(joinpath(project_path, "dev/Project.toml"))

            # Verify content has dev packages reference
            dev_toml = read(joinpath(project_path, "dev/Project.toml"), String)
            @test contains(dev_toml, "Revise") || contains(dev_toml, "dev")
        end
    end

    @testset "Feature: result_types" begin
        mktempdir() do project_dir
            config = (
                project_name="TestPkg",
                features=Dict("result_types" => true)
            )

            project_path = joinpath(project_dir, "TestPkg")
            mkpath(project_path)

            Generator.generate_feature(Val(:result_types), project_path, config)

            # Verify Result.jl module generated
            @test isfile(joinpath(project_path, "src/Result.jl"))

            result_content = read(joinpath(project_path, "src/Result.jl"), String)
            @test contains(result_content, "Result")
            @test contains(result_content, "Ok")
            @test contains(result_content, "Err")
        end
    end

    @testset "Result Module - Railway Helpers" begin
        @testset "unwrap_or" begin
            @test unwrap_or(0, Ok(42)) == 42
            @test unwrap_or(0, Err("fail")) == 0
            @test unwrap_or("default", Err("error")) == "default"
        end

        @testset "map_err" begin
            ok_result = Ok(42)
            err_result = Err("failed")

            @test map_err(e -> "Error: $e", ok_result) == ok_result
            @test map_err(e -> "Error: $e", err_result) == Err("Error: failed")
        end

        @testset "and_then_err" begin
            ok_result = Ok(42)
            err_result = Err("failed")

            @test and_then_err(e -> Err("Wrapped: $e"), ok_result) == ok_result
            @test and_then_err(e -> Err("Wrapped: $e"), err_result) == Err("Wrapped: failed")
        end

        @testset "transpose_results" begin
            # All Ok
            all_ok = [Ok(1), Ok(2), Ok(3)]
            @test transpose_results(all_ok) == Ok([1, 2, 3])

            # Mixed (first Err wins)
            mixed = [Ok(1), Err("fail"), Ok(3)]
            @test transpose_results(mixed) == Err("fail")

            # All Err (first Err wins)
            all_err = [Err("e1"), Err("e2")]
            @test transpose_results(all_err) == Err("e1")

            # Empty
            empty_results = Result{Int,String}[]
            @test transpose_results(empty_results) == Ok(Int[])
        end

        @testset "collect_oks and collect_errs" begin
            mixed = [Ok(1), Err("x"), Ok(3), Err("y"), Ok(5)]

            @test collect_oks(mixed) == [1, 3, 5]
            @test collect_errs(mixed) == ["x", "y"]
        end

        @testset "bind operator >>" begin
            result = Ok(5) >> (x -> Ok(x * 2)) >> (x -> Ok(x + 1))
            @test result == Ok(11)

            fail_result = Ok(5) >> (x -> Err("failed")) >> (x -> Ok(x + 1))
            @test fail_result == Err("failed")
        end
    end

    @testset "ZERO_FALLBACKS Validation" begin
        # Verify no hardcoded fallbacks in Config builders
        defaults = load_defaults()
        user = Dict("project" => Dict("name" => "Test"))
        env = Dict(
            "AUTHOR_FULLNAME" => "A",
            "GITHUB_USER" => "u",
            "GITHUB_EMAIL" => "e@e.com",
            "PROJECT_DIR" => mktempdir()
        )

        config = merge_configs(defaults, user, env)

        # All values should come from defaults.toml, not hardcoded
        @test config.metadata.license == defaults["project"]["license"]
        @test config.metadata.julia_version == defaults["project"]["julia_version"]
        @test config.ci.julia_versions == defaults["ci"]["julia_versions"]
        @test config.testing.rtol == defaults["testing"]["rtol"]
    end

    @testset "Generator Functions Composability" begin
        mktempdir() do tmpdir
            config = (
                metadata=ProjectMetadata("Test", "A", "u", "e@e.com", tmpdir, "MIT", "1.12", "0.1.0", "main"),
                ci=CIConfig(["1.12"], ["ubuntu-latest"], "1.12", true),
                github=GitHubConfig(false, true, false),
                testing=TestingConfig(true, 1.5e-8, 0.0, 1e-5, 1e-8),
                formatter=FormatterPrefs("blue", 4, 92, true, true, true, false, false, false, false, false, "unix", true, false, false, false, false),
                dev=DevWorkspace(false, String[]),
                features=Dict{String,Bool}(),
                logging_min_level="Info",
                env_vars=Dict{String,String}(),
                uuid="test-uuid"
            )

            # Test individual helper functions
            @test Generator._get_metadata_field(config, :name) == "Test"
            @test Generator._get_metadata_field(config, :license) == "MIT"

            ci_data = Generator._build_ci_data(config)
            @test ci_data["julia_versions"] == ["1.12"]
            @test ci_data["codecov"] == true

            github_data = Generator._build_github_data(config)
            @test github_data["create_repo"] == false
            @test github_data["private"] == true
        end
    end
end
