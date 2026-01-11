# QuickTemplates.jl

Generador moderno de paquetes Julia 1.12+ con arquitectura production-ready diseñada para flujos de trabajo de computación científica.

## Descripción General

QuickTemplates surgió de necesidades reales: gestionar múltiples proyectos científicos que requerían patrones consistentes (tipos Result, integración DrWatson, testing de tolerancias) pero encontraban que los generadores existentes eran demasiado básicos o requerían parches constantes para flujos ML/DS. En lugar de fragmentar con otra plantilla más, construimos un generador **amigable para principiantes, arquitectónicamente transparente** que los recién llegados a Julia pueden entender, modificar y aprender.

## ¿Por Qué QuickTemplates?

### Para Principiantes en Julia

- **Stack puro Julia**: Sin dependencias Python (copier), sin sistemas complejos de plugins
- **Arquitectura legible**: Clara separación de responsabilidades (ver [ARCHITECTURE.md](docs/ARCHITECTURE.md))
- **Recurso de aprendizaje**: Patrones bien documentados (guard clauses, railway-oriented programming, multiple dispatch)
- **Revisión asistida por IA**: Código revisado por IA para detectar errores comunes de otros lenguajes
- **Complejidad incremental**: Empieza simple, agrega features según necesites

### Para Computación Científica

**Integraciones nativas** (no plugins ni dependencias externas):

- **DrWatson.jl**: Estructura completa de proyecto (scripts/, data/, plots/, papers/)
- **Result types**: Railway-oriented programming para manejo de errores
- **Tolerance testing**: Helpers de comparación de floats (patrones rtol, atol)
- **Notebooks**: Jupyter + configuración VSCode optimizada para kernels Julia
- **Dev workspace**: Ambiente separado para BenchmarkTools, Revise, OhMyREPL

### Ventajas Arquitectónicas

**Principios de diseño** que diferencian de PkgTemplates/BestieTemplate:

1. **Patrón ZERO_FALLBACKS**
   - Toda configuración en `defaults.toml` externo (única fuente de verdad)
   - Sin valores hardcodeados en código fuente
   - Defaults testeables y versionables

2. **Composabilidad Sub-structs**
   - Divide configs monolíticos en componentes testeables
   - Cada struct probado independientemente (ProjectMetadata, CIConfig, TestingConfig)
   - Fácil de extender sin tocar el core

3. **Validación Security-first**
   - Prevención path traversal de 3 capas
   - Validación de inputs en límites (nombres, emails, paths)
   - Suite de tests dedicada a patrones de seguridad

4. **Extensibilidad Multiple Dispatch**
   - Agrega features vía `generate_feature(Val{:my_feature}, path, config)`
   - Principio open-closed (extender sin modificar)
   - Dispatch type-stable para optimización del compilador

## Instalación

```bash
git clone https://github.com/Cglezf/QuickTemplates.jl
cd QuickTemplates.jl
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

## Inicio Rápido

### Primera Vez

```julia
using QuickTemplates
setup_identity()  # Crea ~/.config/QuickTemplates/.env
```

### Crear Nuevo Paquete

```julia
using QuickTemplates

init_config()     # Crea config.toml
# Editar config.toml: name = "MiPaquete"
generate()        # Genera proyecto completo
```

## Features Disponibles

Activa en `config.toml` → `[features]`:

**Core Julia:**

- `tests = true` - Aqua QA + helpers de tolerancia + LocalCoverage
- `docs = true` - Documenter.jl + GitHub Pages
- `ci = true` - GitHub Actions + TagBot + Dependabot
- `formatter = true` - JuliaFormatter.jl (estilo Blue)

**Developer Mode:**

- `dev_mode = false` - dev/ workspace con BenchmarkTools + Revise + OhMyREPL

**Scientific Computing:**

- `drwatson = false` - DrWatson.jl: scripts/, data/, plots/, notebooks/, papers/
- `notebooks = false` - Jupyter notebooks + .vscode/settings.json optimizado

**Optional:**

- `logging = false` - Stdlib Logging (zero dependencias)
- `result_types = false` - Railway-oriented programming (tipos Ok/Err)

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
drwatson = true  # Para proyectos científicos
result_types = true  # Para manejo funcional de errores
```

## Arquitectura

Para documentación arquitectónica detallada, ver:

- [ARCHITECTURE.md](docs/ARCHITECTURE.md) - Patrones de diseño, performance, idiomas
- [JULIA_PATTERNS.md](docs/JULIA_PATTERNS.md) - Patrones genéricos Julia 1.12+
- [INTERACTIVE_CLI_PATTERNS.md](docs/INTERACTIVE_CLI_PATTERNS.md) - Patrones Term.jl, Comonicon.jl

### Principios Core

1. **ZERO_FALLBACKS**: Todos los defaults en `defaults.toml`, sin valores hardcodeados
2. **Fail-Fast**: Validación temprana de inputs con errores explícitos
3. **Type Stability**: Testeado con `@inferred`, optimizado por compilador
4. **Composabilidad**: Sub-structs pequeños y testeables
5. **Extensibilidad**: Multiple dispatch para features

### Módulos Core

```julia
QuickTemplates.jl
├── Config.jl          # Structs composables + validación
├── Generator.jl       # Multiple dispatch por feature
├── FormatterConfig.jl # Defaults JuliaFormatter
├── Result.jl          # Railway-oriented programming (opcional)
└── Exceptions.jl      # Errores personalizados con pretty printing
```

### Ejemplo de Extensibilidad

```julia
# Agrega feature personalizada vía multiple dispatch
function Generator.generate_feature(::Val{:my_feature}, path, config)
    # Tu implementación de feature
    mkpath(joinpath(path, "custom_dir"))
    # ...
end
```

## Comparación con Alternativas

### vs PkgTemplates.jl

**Fortalezas PkgTemplates:**

- Maduro, battle-tested (oficial JuliaCI)
- Ecosistema de plugins
- Templating Mustache

**Enfoque QuickTemplates:**

- Flujos de trabajo computación científica (DrWatson, tolerance testing)
- Transparencia arquitectónica (recurso de aprendizaje)
- Stack puro Julia (sin Mustache.jl, más simple para principiantes)
- Result types integrados (railway-oriented programming)

### vs BestieTemplate.jl

**Fortalezas BestieTemplate:**

- Actualizable vía motor Copier
- Múltiples niveles de personalización (Tiny/Light/Moderate/Robust)
- Reaplicación automática mediante PRs

**Enfoque QuickTemplates:**

- Sin dependencias Python (Copier requiere PythonCall)
- Modelo mental más simple para principiantes Julia
- Features científicas nativas (no plugins)
- Arquitectura explícita para aprendizaje

## ¿Cuándo Usar QuickTemplates?

**Buen ajuste:**

- Aprender desarrollo de paquetes Julia (arquitectura clara)
- Proyectos computación científica / ML (DrWatson, Result types)
- Principiantes que quieren toolchain Julia puro
- Proyectos que necesitan patrones de tolerance testing

**Mejores alternativas:**

- **PkgTemplates**: Paquetes producción que necesitan ecosistema maduro
- **BestieTemplate**: Equipos que quieren auto-updates vía Copier
- **Setup manual**: Expertos con requerimientos específicos

## Filosofía de Desarrollo

Este paquete surgió de necesidades prácticas pero reconoce que puede no ser el mejor ajuste para la comunidad general. El mantenedor:

- **Aprendiendo Julia**: Aún no suficientemente experimentado para contribuir con confianza a PkgTemplates/BestieTemplate
- **Abierto a colaboración**: Interesado en contribuir features upstream si agregan valor
- **Transparente sobre uso de IA**: Arquitectura diseñada por humano, código revisado por IA para detectar errores de principiante
- **Enfocado en educación**: Documentación enfatiza "por qué" sobre "qué"

Si las features aquí (Result types, patrones DrWatson, validaciones de seguridad) beneficiarían a PkgTemplates o BestieTemplate, el mantenedor está feliz de extraerlas y contribuirlas upstream.

## Testing

```julia
using Pkg
Pkg.test()  # 105 tests: Aqua QA + type stability + security + features
```

**Suites de tests:**

- `runtests.jl` - Tests de integración (91 tests)
- `type_stability_tests.jl` - Verificación @inferred + módulo Result
- `security_tests.jl` - Prevención path traversal
- `uuid_idempotence_tests.jl` - Patrones de preservación UUID

## Documentación

- Inglés: [README.md](README.md)
- Arquitectura: [ARCHITECTURE.md](docs/ARCHITECTURE.md)
- Patrones genéricos Julia: [JULIA_PATTERNS.md](docs/JULIA_PATTERNS.md)
- Patrones CLI: [INTERACTIVE_CLI_PATTERNS.md](docs/INTERACTIVE_CLI_PATTERNS.md)

## Contribuir

¡Contribuciones bienvenidas! Áreas de interés:

- Extraer Result.jl como paquete standalone
- Contribuir patrones DrWatson a PkgTemplates
- Helpers de validación de seguridad para ecosistema más amplio

## Licencia

MIT License - ver [LICENSE](LICENSE)

## Agradecimientos

Inspirado por:

- [PkgTemplates.jl](https://github.com/JuliaCI/PkgTemplates.jl) - Generación madura de paquetes
- [BestieTemplate.jl](https://github.com/JuliaBesties/BestieTemplate.jl) - Templates actualizables
- [DrWatson.jl](https://github.com/JuliaDynamics/DrWatson.jl) - Estructura proyecto científico

¡Construido por un principiante en Julia aprendiendo best practices. Feedback y correcciones apreciados!
