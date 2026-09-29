# AbaqusReader.jl - parse ABAQUS input files to Julia

[![ci][ci-img]][ci-url]
[![codecov][coverage-img]][coverage-url]
[![docs-stable][docs-stable-img]][docs-stable-url]
[![docs-dev][docs-dev-img]][docs-dev-url]

![AbaqusReader.jl - Modern FEM Mesh Parser](docs/src/assets/readme-hero.webp)

## 🚀 Try the Online Visualizer!

**[Launch Online Visualizer →](https://ahojukka5.github.io/AbaqusReader.jl/dev/)**

Drag and drop your ABAQUS `.inp` files to see them visualized in 3D - no installation required!
Click "Open Visualizer" button on the documentation page to access the interactive 3D viewer.

---

AbaqusReader.jl provides two distinct ways to read ABAQUS `.inp` files, depending on your needs.

**Design Philosophy**: We provide **topology** (geometry and connectivity), not **physics** (formulations and behavior). Read [our design philosophy](docs/src/philosophy.md) for why we reject ABAQUS's element proliferation and use clean topological types instead.

## Two Approaches for Two Different Needs

### 1. **Mesh-Only Parsing** - `abaqus_read_mesh()`

When you only need the **geometry and topology** (nodes, elements, sets), use this function.
It returns a simple dictionary structure containing just the mesh data - perfect for:

- Visualizing geometry
- Converting meshes to other formats
- Quick mesh inspection
- Building your own FEM implementations on top of ABAQUS geometries

### 2. **Complete Model Parsing** - `abaqus_read_model()`

When you need to **reproduce the entire simulation**, use this function.
It parses the complete simulation recipe including mesh, materials, boundary conditions,
load steps, and analysis parameters - everything needed to:

- Fully understand the simulation setup
- Reproduce the analysis in another solver
- Extract complete simulation definitions programmatically
- Analyze or modify simulation parameters

---

## Quick Start

### Reading Just the Mesh

Simple and fast - extract only geometry and topology:

```julia
using AbaqusReader
abaqus_read_mesh("cube_tet4.inp")
```

```text
Dict{String,Dict} with 7 entries:
  "nodes"         => Dict(7=>[0.0, 10.0, 10.0],4=>[10.0, 0.0, 0.0],9=>[10.0, 10…
  "element_sets"  => Dict("CUBE"=>[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 1…
  "element_types" => Dict{Integer,Symbol}(Pair{Integer,Symbol}(2, :Tet4),Pair{I…
  "elements"      => Dict{Integer,Array{Integer,1}}(Pair{Integer,Array{Integer,…
  "surface_sets"  => Dict("LOAD"=>Tuple{Int64,Symbol}[(16, :S1), (8, :S1)],"ORD…
  "surface_types" => Dict("LOAD"=>:ELEMENT,"ORDER"=>:ELEMENT)
  "node_sets"     => Dict("SYM23"=>[5, 6, 7, 8],"SYM12"=>[5, 6, 3, 4],"NALL"=>[…
```

Like said, `mesh` is a simple dictionary containing other dictionaries like
`elements`, `nodes`, `element_sets` and so on. This is a good starting point to
construct your own finite element implementations based on real models done using
ABAQUS.

### Reading the Complete Model

When you need the full simulation recipe, not just the mesh:

```julia
model = abaqus_read_model("abaqus_file.inp")
```

This returns an `AbaqusReader.Model` instance containing the complete simulation definition:

- **Mesh**: All geometry (nodes, elements, sets, surfaces)
- **Materials**: Material definitions with properties (elastic, plastic, etc.)
- **Sections**: Property assignments linking materials to element sets
- **Boundary Conditions**: Constraints, loads, prescribed displacements
- **Steps**: Analysis steps with their specific conditions and outputs

With this complete model, you have everything needed to reproduce the simulation.

## Element Types: Topology, Not Physics

**Key Design Decision**: We use **topological types** (Tri3, Quad4, Tet4, Hex8) instead of ABAQUS's physics-specific names (CPS3, CPE3, CAX3).

> ⚠️ **ABAQUS element design is a warning example in software engineering.** From a computer science perspective, their approach violates separation of concerns and demonstrates what NOT to do. We're proud software engineers, and we don't replicate bad design.

### The Problem with ABAQUS's Approach

ABAQUS defines 100+ element types by mixing **orthogonal concerns**:

- `CPS3` = plane stress triangle
- `CPE3` = plane strain triangle  
- `CAX3` = axisymmetric triangle

All three have **identical topology** (3 nodes, triangular) but different **physics formulations**.

Modern languages (Julia, C++, Rust) solve this with **templates, traits, or multiple dispatch** - keeping concerns separate and composable. ABAQUS is stuck in 1970s procedural thinking.

### Our Solution

We separate these concerns properly:

- **Topology** (what we provide): Geometric shape and connectivity → `Tri3`
- **Physics** (user's domain): Stress state, material model → compose via multiple dispatch

This gives you:

- ✓ **Correct architecture**: Orthogonal concerns stay separated
- ✓ **Modern design**: Uses language features, not nomenclature hacks
- ✓ **Linear complexity**: 10-20 types instead of 100+
- ✓ **Solver-agnostic**: Works with any FEM code
- ✓ **Extensible**: Add physics without touching topology

**Original ABAQUS names are preserved** in metadata for traceability.

See [Design Philosophy](docs/src/philosophy.md) for why ABAQUS is a cautionary tale and how modern software does it right.

## Supported Elements

The following ABAQUS element types are currently supported. Note that element variants (e.g., C3D8R, C3D8H) with the same node count map to the same generic element type, as the package focuses on mesh topology rather than analysis-specific details like integration schemes.

### 3D Solid Elements

| ABAQUS Element | Nodes | Generic Type | Notes |
|----------------|:-----:|--------------|-------|
| C3D4, C3D4H | 4 | `:Tet4` | Linear tetrahedron |
| C3D10, C3D10H, C3D10M, C3D10R | 10 | `:Tet10` | Quadratic tetrahedron |
| C3D6 | 6 | `:Wedge6` | Linear wedge/prism |
| C3D15 | 15 | `:Wedge15` | Quadratic wedge/prism |
| C3D8, C3D8H, C3D8I, C3D8R, C3D8RH | 8 | `:Hex8` | Linear hexahedron |
| C3D20, C3D20E, C3D20H, C3D20R, C3D20RH | 20 | `:Hex20` | Quadratic hexahedron |
| COH3D8 | 8 | `:Hex8` | Cohesive element |

### Shell Elements

| ABAQUS Element | Nodes | Generic Type | Notes |
|----------------|:-----:|--------------|-------|
| S3, S3R, STRI3 | 3 | `:Tri3` | Triangular shell |
| STRI65 | 6 | `:Tri6` | 6-node triangular shell |
| S4, S4R | 4 | `:Quad4` | Quadrilateral shell |
| S8R | 8 | `:Quad8` | 8-node quadrilateral shell |

### 2D Continuum Elements

| ABAQUS Element | Nodes | Generic Type | Notes |
|----------------|:-----:|--------------|-------|
| CPS3 | 3 | `:Tri3` | Plane stress triangle |
| CPS4, CPS4R, CPS4I | 4 | `:Quad4` | Plane stress quad |
| CPS6 | 6 | `:Tri6` | Plane stress 6-node triangle |
| CPS8, CPS8R | 8 | `:Quad8` | Plane stress 8-node quad |
| CPE3 | 3 | `:Tri3` | Plane strain triangle |
| CPE4, CPE4R, CPE4I | 4 | `:Quad4` | Plane strain quad |
| CPE6 | 6 | `:Tri6` | Plane strain 6-node triangle |
| CPE8, CPE8R | 8 | `:Quad8` | Plane strain 8-node quad |
| CAX3 | 3 | `:Tri3` | Axisymmetric triangle |
| CAX4, CAX4R, CAX4I | 4 | `:Quad4` | Axisymmetric quad |
| CAX6 | 6 | `:Tri6` | Axisymmetric 6-node triangle |
| CAX8, CAX8R | 8 | `:Quad8` | Axisymmetric 8-node quad |

### Beam and Truss Elements

| ABAQUS Element | Nodes | Generic Type | Notes |
|----------------|:-----:|--------------|-------|
| T2D2, T3D2 | 2 | `:Seg2` | 2D/3D truss |
| B31, B33 | 2 | `:Seg2` | Linear beam |
| B32 | 3 | `:Seg3` | Quadratic beam |

**Element Suffixes:**

- `R` = Reduced integration
- `H` = Hybrid formulation  
- `I` = Incompatible modes
- `M` = Modified formulation
- `E` = Enhanced

### Adding New Element Types

Adding new element types is easy! Element definitions are stored in a TOML file (`data/abaqus_elements.toml`) rather than in code. To add a new element:

1. Open `data/abaqus_elements.toml`
1. Add an entry following the existing format:

```toml
[YOUR_ELEMENT]
nodes = 8
type = "Hex8"
description = "Your element description"
```

1. No code changes needed - the element will be automatically available!

See `docs/src/element_database.md` for detailed instructions on adding elements.

## Test Data

The `testdata/` directory holds ABAQUS `.inp` files tracked with Git LFS.
`testdata/README.md` lists them. Two of the files are:

```julia
using AbaqusReader

mesh = abaqus_read_mesh("testdata/3d_beam.inp")
mesh = abaqus_read_mesh("testdata/piston_large.inp")
```

[ci-img]: https://github.com/ahojukka5/AbaqusReader.jl/workflows/CI/badge.svg
[ci-url]: https://github.com/ahojukka5/AbaqusReader.jl/actions?query=workflow%3ACI+branch%3Amaster

[coverage-img]: https://codecov.io/gh/ahojukka5/AbaqusReader.jl/branch/master/graph/badge.svg?token=3aZGJjDsY9
[coverage-url]: https://codecov.io/gh/ahojukka5/AbaqusReader.jl

[docs-stable-img]: https://img.shields.io/badge/docs-stable-blue.svg
[docs-stable-url]: https://ahojukka5.github.io/AbaqusReader.jl/stable

[docs-dev-img]: https://img.shields.io/badge/docs-latest-blue.svg
[docs-dev-url]: https://ahojukka5.github.io/AbaqusReader.jl/latest
