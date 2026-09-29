# Contributing to AbaqusReader.jl

Thank you for your interest in contributing! This guide will help you add new element types, report issues, and improve the package.

## Adding New ABAQUS Element Types

AbaqusReader.jl uses an external TOML database for element definitions, making it easy to add new elements without modifying Julia code.

### Step-by-Step Guide

#### 1. Find Element Information

Look up the element in the ABAQUS Analysis User's Guide to determine:

- **Element name** (e.g., `C3D8R`, `S4R`, `CPE4`)
- **Number of nodes** (e.g., 8, 4, 4)
- **Element topology** (tetrahedral, hexahedral, shell, etc.)

#### 2. Edit the Element Database

Open `data/abaqus_elements.toml` and add a new section in the appropriate category:

```toml
[YOUR_ELEMENT_NAME]
nodes = <number>
type = "<GenericType>"
description = "<element description from ABAQUS manual>"
```

**Example - Adding a new shell element:**

```toml
[S8R5]
nodes = 8
type = "Quad8"
description = "8-node quadrilateral shell, reduced integration, 5 DOF per node"
```

#### 3. Choose the Correct Generic Type

Map your ABAQUS element to one of these generic types based on topology:

**3D Solid Elements:**

- `"Tet4"` - 4-node tetrahedron
- `"Tet10"` - 10-node tetrahedron
- `"Wedge6"` - 6-node triangular prism
- `"Wedge15"` - 15-node triangular prism
- `"Hex8"` - 8-node hexahedron
- `"Hex20"` - 20-node hexahedron
- `"Hex27"` - 27-node hexahedron (if needed)

**Shell Elements:**

- `"Tri3"` - 3-node triangle
- `"Tri6"` - 6-node triangle
- `"Quad4"` - 4-node quadrilateral
- `"Quad8"` - 8-node quadrilateral
- `"Quad9"` - 9-node quadrilateral (if needed)

**2D Continuum:**

- `"Tri3"` - 3-node triangle
- `"Tri6"` - 6-node triangle
- `"Quad4"` - 4-node quadrilateral
- `"Quad8"` - 8-node quadrilateral

**Beam/Truss:**

- `"Seg2"` - 2-node line
- `"Seg3"` - 3-node line

**Note:** Elements with the same node count and topology map to the same generic
type. For example, `C3D8`, `C3D8R`, `C3D8H`, and `C3D8I` all map to `"Hex8"`
since they're all 8-node hexahedra. Similarly, `CPS3` (plane stress), `CPE3`
(plane strain), and `CAX3` (axisymmetric) all map to `"Tri3"` since they're all
3-node triangles. AbaqusReader focuses on mesh topology, not analysis formulation.

#### 4. Add a Test

Add a test to `test/test_parse_mesh.jl` to verify the new element works:

```julia
@testset "YOUR_ELEMENT" begin
    mesh_data = """
    *HEADING
    Test
    *NODE
    1, 0.0, 0.0, 0.0
    2, 1.0, 0.0, 0.0
    # ... more nodes
    *ELEMENT, TYPE=YOUR_ELEMENT
    1, 1, 2, 3, 4, 5, 6, 7, 8
    """
    
    mesh = abaqus_parse_mesh(mesh_data)
    
    @test haskey(mesh, "elements")
    @test haskey(mesh, "element_types")
    @test mesh["element_types"][1] == :ExpectedGenericType
    @test length(mesh["elements"][1]) == EXPECTED_NODE_COUNT
end
```

#### 5. Test Your Changes

Run the test suite to ensure everything works:

```bash
julia --project=. -e 'using Pkg; Pkg.test()'
```

#### 6. Submit a Pull Request

1. Fork the repository on GitHub
2. Create a branch for your changes: `git checkout -b add-element-YOUR_ELEMENT`
3. Commit your changes: `git commit -am "Add support for YOUR_ELEMENT element"`
4. Push to your fork: `git push origin add-element-YOUR_ELEMENT`
5. Open a Pull Request on GitHub

### Element Database File Structure

The database is organized into categories for easier maintenance:

```toml
# =============================================================================
# 3D SOLID ELEMENTS - TETRAHEDRAL
# =============================================================================

[C3D4]
nodes = 4
type = "Tet4"
description = "4-node linear tetrahedron..."

# =============================================================================
# SHELL ELEMENTS - QUADRILATERAL
# =============================================================================

[S4R]
nodes = 4
type = "Quad4"
description = "4-node quadrilateral shell..."
```

Add your element in the appropriate category, or create a new category if needed.

### Understanding Element Suffixes

ABAQUS uses suffixes to indicate formulation variants:

- **R** = Reduced integration (fewer integration points)
- **H** = Hybrid formulation (for nearly incompressible materials)
- **I** = Incompatible modes (enhanced bending behavior)
- **M** = Modified formulation (reduced locking)
- **E** = Enhanced strain formulation

Example: `C3D8`, `C3D8R`, `C3D8H`, `C3D8I`, `C3D8RH` all have 8 nodes → map to `"Hex8"`

## Reporting Issues

When reporting issues, please include:

1. **Julia version:** `versioninfo()`
2. **Package version:** `] status AbaqusReader`
3. **Minimal example:** Simplest code that reproduces the issue
4. **Input file:** If possible, share the `.inp` file (or a minimal excerpt)
5. **Error message:** Complete error message and stack trace

### Good Issue Report Example

```text
**Description:** Parser fails on NGEN keyword

**Environment:**
- Julia 1.9.3
- AbaqusReader v0.2.6

**Minimal example:**
using AbaqusReader
mesh = abaqus_read_mesh("test.inp")

**Error:**
ERROR: KeyError: key :NGEN not found
...stack trace...

**Input file excerpt:**
*HEADING
Test
*NODE
1, 0.0, 0.0, 0.0
*NGEN
...
```

## Development Workflow

### Setting Up Development Environment

```bash
# Clone the repository
git clone https://github.com/ahojukka5/AbaqusReader.jl.git
cd AbaqusReader.jl

# Activate the project environment
julia --project=.

# Install dependencies
using Pkg
Pkg.instantiate()

# Run tests
Pkg.test()
```

### Code Style

- Follow standard Julia style conventions
- Keep functions focused (single responsibility)
- Add docstrings to public functions
- Prefer simple, readable code over clever code
- Use descriptive variable names

### Testing

- Add tests for new functionality
- Ensure all tests pass before submitting PR
- Test coverage should not decrease

### Documentation

- Update documentation for user-facing changes
- Add examples for new features
- Keep API documentation up to date

## Package Philosophy

AbaqusReader.jl is designed around **two distinct use cases**:

### 1. Mesh-Only Parsing (`abaqus_read_mesh`)

- Extract only geometry and topology
- Returns simple `Dict` structure
- Fast and lightweight
- No physics, materials, or boundary conditions

### 2. Complete Model Parsing (`abaqus_read_model`)

- Extract the complete simulation recipe
- Returns structured `Model` object
- Everything needed to reproduce the simulation

**Keep these two paths distinct!** Don't conflate mesh parsing with model parsing.

## Design Principles

When contributing, keep these principles in mind:

1. **Simplicity over cleverness** - This is a parser, not a performance-critical solver
2. **Clear function names** - Prefer explicit over generic names
3. **Backward compatibility** - Public API must remain stable
4. **Modern Julia** - Use Julia 1.0+ idioms (no deprecated features)
5. **Direct dispatch** - Prefer clear function calls over complex Val-based dispatch
6. **External data** - Element definitions in TOML, not hardcoded in Julia

## Questions?

- **Issues:** Open an issue on [GitHub](https://github.com/ahojukka5/AbaqusReader.jl/issues)
- **Discussions:** Use GitHub Discussions for questions and ideas
- **Email:** Contact the maintainers for sensitive issues

Thank you for contributing to AbaqusReader.jl! 🎉
