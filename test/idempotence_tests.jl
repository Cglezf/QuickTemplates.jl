using Test
using QuickTemplates.Generator

@testset "Idempotencia y Modo Incremental" begin
    @testset "Force flag - sobrescribe si necesario" begin
        mktempdir() do tmpdir
            template_path = joinpath(dirname(@__DIR__), "templates", "root", "README.md.mustache")
            output_path = joinpath(tmpdir, "README.md")
            data = Dict("project_name" => "Test", "author_fullname" => "Author",
                       "github_user" => "user", "license" => "MIT")

            # Primera generación
            Generator.render_template_to_file(template_path, output_path, data; force=false)
            @test isfile(output_path)
            original_content = read(output_path, String)

            # Modificar archivo
            write(output_path, "# Modified content")
            modified_content = read(output_path, String)
            @test modified_content != original_content

            # Segunda generación SIN force - NO sobrescribe
            Generator.render_template_to_file(template_path, output_path, data; force=false)
            current_content = read(output_path, String)
            @test current_content == modified_content  # Sigue modificado

            # Tercera generación CON force - sobrescribe
            Generator.render_template_to_file(template_path, output_path, data; force=true)
            final_content = read(output_path, String)
            @test final_content != modified_content  # Fue sobrescrito
            @test contains(final_content, "Test")  # Tiene contenido del template
        end
    end

    @testset "DrWatson gitignore - no duplica" begin
        mktempdir() do tmpdir
            project_path = joinpath(tmpdir, "DrWatsonTest")
            mkpath(project_path)

            # Crear .gitignore inicial
            gitignore_path = joinpath(project_path, ".gitignore")
            write(gitignore_path, "*.jl.cov\n*.jl.mem\n")

            # Primera ejecución append DrWatson
            Generator._append_drwatson_gitignore(project_path)
            first_content = read(gitignore_path, String)
            first_count = count("# DrWatson .gitignore additions", first_content)
            @test first_count == 1

            # Segunda ejecución append DrWatson (debe ser idempotente)
            Generator._append_drwatson_gitignore(project_path)
            second_content = read(gitignore_path, String)
            second_count = count("# DrWatson .gitignore additions", second_content)

            # Verificar que NO duplicó
            @test second_count == 1
            @test first_content == second_content
        end
    end
end
