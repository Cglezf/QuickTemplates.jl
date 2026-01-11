# UUID Idempotence Tests
# TestHelpers ya está incluido en runtests.jl, no re-incluir

@testset "UUID Idempotence Tests" begin
    @testset "add_uuid() genera UUID nuevo si proyecto NO existe" begin
        mktempdir() do tmpdir
            # Config con PROJECT_DIR que no existe aún
            config = mock_config(
                metadata=valid_metadata(
                    name="NewProject",
                    project_dir=tmpdir
                )
            )

            # add_uuid debe generar UUID nuevo
            config_with_uuid = QuickTemplates.add_uuid(config)

            @test haskey(config_with_uuid, :uuid)
            @test !isempty(config_with_uuid.uuid)
            @test length(config_with_uuid.uuid) == 36  # UUID v4 format
            @test contains(config_with_uuid.uuid, "-")  # UUID tiene guiones
        end
    end

    @testset "add_uuid() preserva UUID si proyecto YA existe" begin
        mktempdir() do tmpdir
            project_name = "ExistingProject"
            project_path = joinpath(tmpdir, project_name)
            mkpath(project_path)

            # Crear Project.toml con UUID existente
            existing_uuid = "abc12345-1234-5678-9abc-123456789012"
            project_toml = """
            name = "$project_name"
            uuid = "$existing_uuid"
            version = "0.1.0"
            """
            write(joinpath(project_path, "Project.toml"), project_toml)

            # Config apuntando al proyecto existente
            config = mock_config(
                metadata=valid_metadata(
                    name=project_name,
                    project_dir=tmpdir
                )
            )

            # add_uuid debe PRESERVAR UUID existente
            config_with_uuid = QuickTemplates.add_uuid(config)

            @test config_with_uuid.uuid == existing_uuid
            @test config_with_uuid.uuid != ""
        end
    end

    @testset "add_uuid() es IDEMPOTENTE - múltiples ejecuciones" begin
        mktempdir() do tmpdir
            project_name = "IdempotentProject"
            project_path = joinpath(tmpdir, project_name)
            mkpath(project_path)

            # Crear Project.toml inicial
            original_uuid = "def12345-abcd-5678-9def-123456789012"
            project_toml = """
            name = "$project_name"
            uuid = "$original_uuid"
            version = "0.1.0"
            """
            write(joinpath(project_path, "Project.toml"), project_toml)

            config = mock_config(
                metadata=valid_metadata(
                    name=project_name,
                    project_dir=tmpdir
                )
            )

            # Primera ejecución - debe preservar UUID
            config1 = QuickTemplates.add_uuid(config)
            @test config1.uuid == original_uuid

            # Segunda ejecución - MISMO UUID
            config2 = QuickTemplates.add_uuid(config)
            @test config2.uuid == original_uuid

            # Tercera ejecución - MISMO UUID
            config3 = QuickTemplates.add_uuid(config)
            @test config3.uuid == original_uuid

            # CRÍTICO: Todas las ejecuciones retornan MISMO UUID
            @test config1.uuid == config2.uuid == config3.uuid == original_uuid
        end
    end

    @testset "_read_existing_uuid() lee UUID correctamente" begin
        mktempdir() do tmpdir
            project_path = joinpath(tmpdir, "TestProject")
            mkpath(project_path)

            # Proyecto sin Project.toml
            uuid1 = QuickTemplates._read_existing_uuid(project_path)
            @test isnothing(uuid1)

            # Crear Project.toml con UUID
            test_uuid = "test-uuid-1234-5678"
            toml_content = """
            name = "TestProject"
            uuid = "$test_uuid"
            """
            write(joinpath(project_path, "Project.toml"), toml_content)

            # Debe leer UUID existente
            uuid2 = QuickTemplates._read_existing_uuid(project_path)
            @test uuid2 == test_uuid
        end
    end

    @testset "_read_existing_uuid() maneja Project.toml corrupto" begin
        mktempdir() do tmpdir
            project_path = joinpath(tmpdir, "CorruptProject")
            mkpath(project_path)

            # Crear Project.toml inválido
            write(joinpath(project_path, "Project.toml"), "invalid toml {{{")

            # Debe retornar nothing sin error
            uuid = QuickTemplates._read_existing_uuid(project_path)
            @test isnothing(uuid)
        end
    end

    @testset "_read_existing_uuid() maneja Project.toml sin UUID" begin
        mktempdir() do tmpdir
            project_path = joinpath(tmpdir, "NoUUIDProject")
            mkpath(project_path)

            # Crear Project.toml sin campo uuid
            toml_content = """
            name = "NoUUIDProject"
            version = "0.1.0"
            """
            write(joinpath(project_path, "Project.toml"), toml_content)

            # Debe retornar nothing
            uuid = QuickTemplates._read_existing_uuid(project_path)
            @test isnothing(uuid)
        end
    end
end
