module TestHelpers

using QuickTemplates.Config

export valid_metadata, valid_ci, valid_github, valid_testing, valid_formatter, valid_dev
export mock_config

# === Sub-struct Fixtures ===

valid_ci() = CIConfig(["1.12"], ["ubuntu-latest"], "1.12", true)

valid_github(; create_repo=false, private=true, auto_push=false) =
    GitHubConfig(create_repo, private, auto_push)

valid_testing() = TestingConfig(true, 1.5e-8, 0.0, 1e-5, 1e-8)

valid_formatter() = FormatterPrefs(
    "blue", 4, 92, true, true, true, false, false,
    false, false, false, "unix", true, false, false, false, false
)

valid_dev() = DevWorkspace(true, String[])

function valid_metadata(; name="TestPkg", author_fullname="Author", github_user="user",
    github_email="email@test.com", project_dir=mktempdir(), license="MIT",
    julia_version="1.12", initial_version="0.1.0", default_branch="main")

    ProjectMetadata(name, author_fullname, github_user, github_email, project_dir,
        license, julia_version, initial_version, default_branch)
end

# === Mock Config Builder ===

function mock_config(; metadata=valid_metadata(), ci=valid_ci(), github=valid_github(),
    testing=valid_testing(), formatter=valid_formatter(), dev=valid_dev(),
    features=Dict{String,Bool}(), logging_min_level="Info",
    env_vars=Dict{String,String}())

    ProjectConfig(metadata, ci, github, testing, formatter, dev, features,
        logging_min_level, env_vars)
end

end # module
