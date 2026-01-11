# QuickTemplates.jl

Modern Julia 1.12+ package generator with production-ready architecture designed for scientific computing workflows.

## Overview

QuickTemplates emerged from real-world needs in data science: managing multiple ML/research projects that required consistent patterns (Result types for error handling, DrWatson project structures, tolerance testing for numerical work) but found existing generators either too basic or required constant patching. Rather than fragmenting the ecosystem, this serves as a **learning-friendly, architecturally transparent** generator that data scientists new to Julia can understand, modify, and learn from while establishing ML/DS workflow best practices.

## Why QuickTemplates?

### For Data Scientists New to Julia

- **Pure Julia stack**: No Python dependencies (Copier), no complex plugin systems - easier mental model for Python/R users
- **Readable architecture**: Clear separation of concerns, well-documented design patterns
- **Learning resource**: Implements guard clauses, railway-oriented programming, multiple dispatch - core Julia idioms
- **AI-assisted review**: Architecture designed by human, code reviewed by AI to catch anti-patterns from other languages
- **Incremental complexity**: Start with basics, add ML/DS features as needed

### For ML/Data Science Workflows

**Native integrations** (built-in, not plugins):

- **DrWatson.jl**: Complete research project structure (scripts/, data/, plots/, papers/)
- **Result types**: Functional error handling (railway-oriented programming) - cleaner than try-catch chains
- **Tolerance testing**: Numerical comparison helpers (rtol, atol patterns) for ML model validation
- **Notebooks**: Jupyter + VSCode settings optimized for interactive Julia development
- **Dev workspace**: Isolated environment for benchmarking and development tools

### Architectural Advantages

**Design principles** that differentiate from PkgTemplates/BestieTemplate:

1. **ZERO_FALLBACKS Pattern**
   - All configuration in external `defaults.toml` (single source of truth)
   - No hardcoded values in source code
   - Testable, versionable defaults

2. **Sub-structs Composability**
   - Break monolithic configs into testable components
   - Each struct tested independently (ProjectMetadata, CIConfig, TestingConfig)
   - Easy to extend without touching core

3. **Security-first Validation**
   - 3-layer path traversal prevention
   - Input validation at boundaries (names, emails, paths)
   - Dedicated test suite for security patterns

4. **Multiple Dispatch Extensibility**
   - Add features via `generate_feature(Val{:my_feature}, path, config)`
   - Open-closed principle (extend without modifying)
   - Type-stable dispatch for compiler optimization

## Installation

```bash
git clone https://github.com/Cglezf/QuickTemplates.jl
cd QuickTemplates.jl
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

## Quick Start

### First Time Setup

```julia
using QuickTemplates
setup_identity()  # Creates ~/.config/QuickTemplates/.env
```

### Create New Package

```julia
using QuickTemplates

init_config()     # Creates config.toml
# Edit config.toml: name = "MyPackage"
generate()        # Generates complete project
```

## Available Features

Enable in `config.toml` → `[features]`:

**Core Julia:**

- `tests = true` - Aqua QA + tolerance helpers + LocalCoverage
- `docs = true` - Documenter.jl + GitHub Pages
- `ci = true` - GitHub Actions + TagBot + Dependabot
- `formatter = true` - JuliaFormatter.jl (Blue style)

**Developer Mode:**

- `dev_mode = false` - dev/ workspace with BenchmarkTools + Revise + OhMyREPL

**Scientific Computing:**

- `drwatson = false` - DrWatson.jl: scripts/, data/, plots/, notebooks/, papers/
- `notebooks = false` - Jupyter notebooks + .vscode/settings.json optimized

**Optional:**

- `logging = false` - Stdlib Logging (zero dependencies)
- `result_types = false` - Railway-oriented programming (Ok/Err types)

## Example config.toml

```toml
[project]
name = "MyPackage"
license = "MIT"
julia_version = "1.12"

[features]
tests = true
docs = true
ci = true
formatter = true
drwatson = true  # For scientific projects
result_types = true  # For functional error handling
```

## Architecture

For detailed architectural documentation, see:

- [ARCHITECTURE.md](docs/ARCHITECTURE.md) - Design patterns, performance, idioms
- [JULIA_PATTERNS.md](docs/JULIA_PATTERNS.md) - Generic Julia 1.12+ patterns
- [INTERACTIVE_CLI_PATTERNS.md](docs/INTERACTIVE_CLI_PATTERNS.md) - Term.jl, Comonicon.jl patterns

### Core Principles

1. **ZERO_FALLBACKS**: All defaults in `defaults.toml`, no hardcoded values
2. **Fail-Fast**: Early input validation with explicit errors
3. **Type Stability**: `@inferred` tested, compiler-optimized
4. **Composability**: Small, testable sub-structs
5. **Extensibility**: Multiple dispatch for features

### Core Modules

```julia
QuickTemplates.jl
├── Config.jl          # Composable structs + validation
├── Generator.jl       # Multiple dispatch per feature
├── FormatterConfig.jl # JuliaFormatter defaults
├── Result.jl          # Railway-oriented programming (optional)
└── Exceptions.jl      # Custom errors with pretty printing
```

### Extensibility Example

```julia
# Add custom feature via multiple dispatch
function Generator.generate_feature(::Val{:my_feature}, path, config)
    # Your feature implementation
    mkpath(joinpath(path, "custom_dir"))
    # ...
end
```

## Comparison with Alternatives

### vs PkgTemplates.jl

**PkgTemplates strengths:**

- Mature, battle-tested (JuliaCI official)
- Plugin ecosystem
- Mustache templating

**QuickTemplates focus:**

- Scientific computing workflows (DrWatson, tolerance testing)
- Architectural transparency (learning resource)
- Pure Julia stack (no Mustache.jl, simpler for beginners)
- Result types built-in (railway-oriented programming)

### vs BestieTemplate.jl

**BestieTemplate strengths:**

- Upgradeable via Copier engine
- Multiple customization levels (Tiny/Light/Moderate/Robust)
- Automatic reapplication through PRs

**QuickTemplates focus:**

- No Python dependencies (Copier requires PythonCall)
- Simpler mental model for Julia newcomers
- Native scientific features (not plugins)
- Explicit architecture for learning

## When to Use QuickTemplates?

**Good fit:**

- Learning Julia package development (clear architecture)
- Scientific computing / ML projects (DrWatson, Result types)
- Newcomers wanting pure Julia toolchain
- Projects needing tolerance testing patterns

**Better alternatives:**

- **PkgTemplates**: Production packages needing mature ecosystem
- **BestieTemplate**: Teams wanting auto-updates via Copier
- **Manual setup**: Experts with specific requirements

## Development Philosophy

This package emerged from practical data science needs but acknowledges it serves a specific niche. The maintainer is:

- **Data scientist learning Julia**: Coming from Python/R backgrounds, learning Julia ecosystem best practices
- **Open to ecosystem collaboration**: Interested in contributing patterns upstream if they add value to existing tools
- **Transparent about AI use**: Architecture designed by human, code reviewed by AI to catch anti-patterns from other languages
- **Focused on ML/DS practitioners**: Documentation targets data scientists transitioning to Julia

If features here (Result types for pipelines, DrWatson workflow integration, tolerance testing patterns) would benefit PkgTemplates or BestieTemplate, the maintainer is happy to extract and contribute them as plugins or enhancements.

## Testing

```julia
using Pkg
Pkg.test()  # 105 tests: Aqua QA + type stability + security + features
```

**Test suites:**

- `runtests.jl` - Integration tests (91 tests)
- `type_stability_tests.jl` - @inferred verification + Result module
- `security_tests.jl` - Path traversal prevention
- `uuid_idempotence_tests.jl` - UUID preservation patterns

## Documentation

- Spanish (original): [README.es.md](README.es.md)
- Architecture: [ARCHITECTURE.md](docs/ARCHITECTURE.md)
- Generic Julia patterns: [JULIA_PATTERNS.md](docs/JULIA_PATTERNS.md)
- CLI patterns: [INTERACTIVE_CLI_PATTERNS.md](docs/INTERACTIVE_CLI_PATTERNS.md)

## Contributing

Contributions welcome! Areas of interest:

- Extracting Result.jl as standalone package
- Contributing DrWatson patterns to PkgTemplates
- Security validation helpers for broader ecosystem

## License

MIT License - see [LICENSE](LICENSE)

## Acknowledgments

Inspired by:

- [PkgTemplates.jl](https://github.com/JuliaCI/PkgTemplates.jl) - Mature package generation
- [BestieTemplate.jl](https://github.com/JuliaBesties/BestieTemplate.jl) - Upgradeable templates
- [DrWatson.jl](https://github.com/JuliaDynamics/DrWatson.jl) - Scientific project structure

Built by a Julia newcomer learning best practices. Feedback and corrections appreciated!
