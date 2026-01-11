using Test
using QuickTemplates.Config

include("TestHelpers.jl")
using .TestHelpers

@testset "Security: Path Traversal Prevention" begin
    @testset "Project name validation - path traversal" begin
        # Path traversal con ../
        config = mock_config(metadata=valid_metadata(name="../EvilPackage"))
        @test_throws ErrorException validate(config)

        # Path traversal con / separator
        config = mock_config(metadata=valid_metadata(name="../../etc/passwd"))
        @test_throws ErrorException validate(config)

        # Path traversal con \ separator (Windows)
        config = mock_config(metadata=valid_metadata(name="..\\EvilPackage"))
        @test_throws ErrorException validate(config)

        # Hidden file (dot prefix)
        config = mock_config(metadata=valid_metadata(name=".HiddenPackage"))
        @test_throws ErrorException validate(config)

        # Absolute path attempt
        config = mock_config(metadata=valid_metadata(name="/tmp/EvilPackage"))
        @test_throws ErrorException validate(config)
    end

    @testset "Project name validation - Julia conventions" begin
        # Must start with uppercase
        config = mock_config(metadata=valid_metadata(name="lowercasePackage"))
        @test_throws ErrorException validate(config)

        # No special characters
        config = mock_config(metadata=valid_metadata(name="Package-Name"))
        @test_throws ErrorException validate(config)

        config = mock_config(metadata=valid_metadata(name="Package_Name"))
        @test_throws ErrorException validate(config)

        config = mock_config(metadata=valid_metadata(name="Package.jl"))
        @test_throws ErrorException validate(config)

        # Valid names
        config = mock_config(metadata=valid_metadata(name="ValidPackage"))
        @test validate(config) == true

        config = mock_config(metadata=valid_metadata(name="ValidPackage123"))
        @test validate(config) == true

        config = mock_config(metadata=valid_metadata(name="MyGreatPackage2"))
        @test validate(config) == true
    end

    @testset "GitHub user validation" begin
        # Invalid: starts with hyphen
        config = mock_config(metadata=valid_metadata(github_user="-invaliduser"))
        @test_throws ErrorException validate(config)

        # Invalid: ends with hyphen
        config = mock_config(metadata=valid_metadata(github_user="invaliduser-"))
        @test_throws ErrorException validate(config)

        # Invalid: special characters
        config = mock_config(metadata=valid_metadata(github_user="invalid_user"))
        @test_throws ErrorException validate(config)

        config = mock_config(metadata=valid_metadata(github_user="invalid.user"))
        @test_throws ErrorException validate(config)

        # Invalid: too long (>39 chars)
        config = mock_config(metadata=valid_metadata(github_user="a"^40))
        @test_throws ErrorException validate(config)

        # Valid usernames
        config = mock_config(metadata=valid_metadata(github_user="validuser"))
        @test validate(config) == true

        config = mock_config(metadata=valid_metadata(github_user="valid-user"))
        @test validate(config) == true

        config = mock_config(metadata=valid_metadata(github_user="valid-user-123"))
        @test validate(config) == true

        config = mock_config(metadata=valid_metadata(github_user="a"))
        @test validate(config) == true
    end

    @testset "Email validation" begin
        # Invalid: no @
        config = mock_config(metadata=valid_metadata(github_email="invalidemail.com"))
        @test_throws ErrorException validate(config)

        # Invalid: no domain
        config = mock_config(metadata=valid_metadata(github_email="user@"))
        @test_throws ErrorException validate(config)

        # Invalid: no TLD
        config = mock_config(metadata=valid_metadata(github_email="user@domain"))
        @test_throws ErrorException validate(config)

        # Invalid: whitespace
        config = mock_config(metadata=valid_metadata(github_email="user @domain.com"))
        @test_throws ErrorException validate(config)

        # Valid emails
        config = mock_config(metadata=valid_metadata(github_email="user@domain.com"))
        @test validate(config) == true

        config = mock_config(metadata=valid_metadata(github_email="user.name@domain.co.uk"))
        @test validate(config) == true

        config = mock_config(metadata=valid_metadata(github_email="user+tag@domain.com"))
        @test validate(config) == true
    end

    @testset "Path validation - symlink resolution" begin
        mktempdir() do tmpdir
            # Create a directory structure
            real_dir = joinpath(tmpdir, "real_projects")
            mkpath(real_dir)

            # Valid: normal directory
            config = mock_config(metadata=valid_metadata(
                name="ValidPackage",
                project_dir=real_dir
            ))
            @test validate(config) == true

            # Test with symlink (if platform supports it)
            if !Sys.iswindows()
                link_dir = joinpath(tmpdir, "link_projects")
                symlink(real_dir, link_dir)

                # Should resolve symlink and validate correctly
                config = mock_config(metadata=valid_metadata(
                    name="ValidPackage",
                    project_dir=link_dir
                ))
                @test validate(config) == true
            end
        end
    end

    @testset "Path validation - directory boundaries" begin
        mktempdir() do tmpdir
            project_dir = joinpath(tmpdir, "projects")
            mkpath(project_dir)

            # Valid: stays within boundary
            config = mock_config(metadata=valid_metadata(
                name="SafePackage",
                project_dir=project_dir
            ))
            @test validate(config) == true

            # Note: Path traversal via name already blocked by name validation
            # This test ensures defense in depth
        end
    end
end
