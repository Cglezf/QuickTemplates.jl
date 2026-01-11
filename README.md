# QuickTemplates.jl

Generador moderno de paquetes Julia 1.12+ con arquitectura production-ready.

## Features

- 🔒 **Seguro**: UUID idempotence + path traversal prevention
- ⚡ **Rápido**: Const memoization (~31x speedup)
- 🔄 **Idempotente**: Re-ejecutable sin romper código existente
- 🧪 **Robusto**: 105 tests (Aqua + LocalCoverage + security)
- 🏗️ **Extensible**: Multiple dispatch architecture
- 📦 **Completo**: CI + docs + formatter + dev workspace + notebooks

## Instalación

```bash
git clone https://github.com/Cglezf/QuickTemplates.jl
cd QuickTemplates.jl
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

## Uso Rápido

### Primera vez (configurar identidad)

```julia
using QuickTemplates
setup_identity()  # Crea ~/.config/QuickTemplates/.env
```

### Crear nuevo proyecto

```julia
using QuickTemplates

init_config()     # Crea config.toml
# Editar config.toml: name = "MiPaquete"
generate()        # Genera proyecto completo
```

## Features Disponibles

Activa en `config.toml` → `[features]`:

**Core Julia:**

- `tests = true` - Aqua QA + tolerances + LocalCoverage
- `docs = true` - Documenter.jl + GitHub Pages
- `ci = true` - GitHub Actions + TagBot + Dependabot
- `formatter = true` - JuliaFormatter.jl (estilo Blue)

**Developer Mode:**

- `dev_mode = false` - dev/ workspace con BenchmarkTools + Revise + OhMyREPL

**Scientific Computing:**

- `drwatson = false` - DrWatson.jl: scripts/, data/, plots/, notebooks/, papers/
- `notebooks = false` - Jupyter notebooks + .vscode/settings.json optimizado

**Optional:**

- `logging = false` - Stdlib Logging (zero deps)
- `result_types = false` - Railway-oriented programming (Ok/Err types)

## Ejemplo config.toml

```toml
[project]
name = "MiPaquete"
license = "MIT"
julia_version = "1.12"

[features]
tests = true
docs = true
ci = true
formatter = true
```

## Arquitectura

**Principios de Diseño:**

- **ZERO_FALLBACKS**: Todos los defaults en `defaults.toml` (no hardcodeados)
- **DRY Helpers**: Funciones reutilizables para construcción de sub-structs
- **Fail-Fast**: Validación temprana de inputs con errores explícitos
- **Type Stability**: Multiple dispatch con `@inline` para performance

**Módulos Core:**

- `Config.jl` - Structs composables + validación + helpers
- `Generator.jl` - Multiple dispatch extensible por features
- `FormatterConfig.jl` - JuliaFormatter (@kwdef defaults)
- `Result.jl` - Railway-oriented programming (opcional)
- `Exceptions.jl` - Custom errors con pretty printing

**Extensible vía Multiple Dispatch:**

```julia
generate_feature(::Val{:myfeature}, path, config) = ...
```

---

**Julia 1.12+ required** | MIT License
