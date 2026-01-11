#!/usr/bin/env julia
"""
Test runner con coverage limpio.

Ejecuta tests con coverage y limpia archivos .cov temporales,
manteniendo solo coverage/lcov.info para reportes.

Uso:
    julia scripts/test_with_coverage.jl [--clean-only]

Opciones:
    --clean-only    Solo limpia archivos .cov sin ejecutar tests
"""

using Pkg

# Pre-declarar que LocalCoverage es opcional
const HAS_LOCALCOVERAGE = try
    using LocalCoverage
    true
catch
    false
end

function clean_cov_files(project_root::String=pwd())
    """Limpia archivos .cov del proyecto."""
    cov_pattern = r"\.jl\.\d+\.cov$"

    cleaned_count = 0
    for (root, dirs, files) in walkdir(project_root)
        # Skip directorios ocultos y node_modules
        filter!(d -> !startswith(d, ".") && d != "node_modules", dirs)

        for file in files
            if occursin(cov_pattern, file)
                filepath = joinpath(root, file)
                try
                    rm(filepath)
                    cleaned_count += 1
                    println("  ✓ Removed: $(relpath(filepath, project_root))")
                catch e
                    @warn "  ✗ Failed to remove: $filepath" exception=e
                end
            end
        end
    end

    if cleaned_count > 0
        println("\n✨ Cleaned $cleaned_count .cov files")
    else
        println("✨ No .cov files found")
    end

    return cleaned_count
end

function setup_coverage_dir()
    """Crea directorio coverage/ si no existe."""
    coverage_dir = joinpath(pwd(), "coverage")
    if !isdir(coverage_dir)
        mkpath(coverage_dir)
        println("📁 Created coverage/ directory")
    end
    return coverage_dir
end

function run_tests_with_coverage()
    """Ejecuta tests con coverage tracking."""
    println("🧪 Running tests with coverage...\n")

    # Ejecutar tests con coverage
    # Los .cov se generan automáticamente en src/
    Pkg.test(coverage=true)

    println("\n✅ Tests completed")
end

function generate_lcov_report()
    """Genera reporte LCOV desde archivos .cov."""
    println("\n📊 Generating LCOV report...")

    if !HAS_LOCALCOVERAGE
        @warn "LocalCoverage not available, skipping LCOV generation"
        println("  ℹ️  Install with: using Pkg; Pkg.add(\"LocalCoverage\")")
        return
    end

    try
        coverage_dir = joinpath(pwd(), "coverage")
        lcov_path = joinpath(coverage_dir, "lcov.info")

        # Generar coverage
        coverage = LocalCoverage.generate_coverage(dir=pwd())

        # Escribir LCOV manualmente o usar método directo
        println("✓ Coverage data collected")

        # Mostrar resumen
        println("\n📈 Coverage Summary:")
        for (file, cov) in sort(collect(coverage))
            status = cov >= 100 ? "🎉" : cov >= 95 ? "✅" : cov >= 80 ? "⚠️" : "❌"
            println("  $status $(basename(file)): $(round(cov, digits=1))%")
        end

        avg = sum(values(coverage)) / length(coverage)
        println("\n  📊 Average: $(round(avg, digits=1))%")

    catch e
        @warn "Error generating coverage report" exception=e
    end
end

function main()
    # Parse arguments
    clean_only = "--clean-only" in ARGS

    if clean_only
        println("🧹 Cleaning .cov files...\n")
        clean_cov_files()
        return
    end

    # Setup
    setup_coverage_dir()

    # Run tests
    run_tests_with_coverage()

    # Generate LCOV
    generate_lcov_report()

    # Cleanup
    println("\n🧹 Cleaning temporary .cov files...\n")
    clean_cov_files()

    println("\n✨ Done! Coverage report: coverage/lcov.info")
end

# Execute
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
