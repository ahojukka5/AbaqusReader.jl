# Supported Elements

AbaqusReader.jl supports 60+ ABAQUS element types across multiple categories. Element variants (e.g., C3D8R, C3D8H) with the same node count map to the same generic element type, as the package focuses on mesh topology rather than analysis-specific details like integration schemes.

## 3D Solid Elements

### Tetrahedral Elements

| ABAQUS Element | Nodes | Generic Type | Description |
|----------------|:-----:|--------------|-------------|
| **C3D4** | 4 | `:Tet4` | 4-node linear tetrahedron. **Should be avoided** except as filler in low-stress regions - exhibits slow convergence and is overly stiff. |
| **C3D4H** | 4 | `:Tet4` | 4-node linear tetrahedron, hybrid formulation for nearly incompressible materials. Use only as filler element. |
| **C3D10** | 10 | `:Tet10` | 10-node quadratic tetrahedron. **Recommended** for tetrahedral meshes - suitable for general usage, good for complex geometries. |
| **C3D10H** | 10 | `:Tet10` | 10-node quadratic tetrahedron, hybrid formulation for nearly incompressible materials. More expensive than nonhybrid. |
| **C3D10M** | 10 | `:Tet10` | 10-node modified tetrahedron. **Excellent choice** - minimal locking, works well in contact and large deformation. |
| **C3D10R** | 10 | `:Tet10` | 10-node quadratic tetrahedron, reduced integration. May develop volumetric locking with nearly incompressible materials. |

### Wedge/Prism Elements

| ABAQUS Element | Nodes | Generic Type | Description |
|----------------|:-----:|--------------|-------------|
| **C3D6** | 6 | `:Wedge6` | 6-node linear triangular prism. Use only when necessary to complete a mesh, far from critical areas. Requires fine meshing. |
| **C3D15** | 15 | `:Wedge15` | 15-node quadratic triangular prism. Better accuracy than C3D6, good for transitioning between mesh densities. |

### Hexahedral (Brick) Elements

| ABAQUS Element | Nodes | Generic Type | Description |
|----------------|:-----:|--------------|-------------|
| **C3D8** | 8 | `:Hex8` | 8-node linear brick with full integration. Does not lock with nearly incompressible materials. May suffer from shear locking in bending. |
| **C3D8H** | 8 | `:Hex8` | 8-node linear brick, hybrid formulation. For incompressible or nearly incompressible materials. |
| **C3D8I** | 8 | `:Hex8` | 8-node brick with incompatible modes. Enhanced for bending - eliminates parasitic shear. Best with rectangular element shapes. |
| **C3D8R** | 8 | `:Hex8` | 8-node brick, reduced integration with hourglass control. **Very popular** - significantly reduces running time. Use with reasonably fine meshes. |
| **C3D8RH** | 8 | `:Hex8` | 8-node brick, reduced integration and hybrid. Combines benefits of reduced integration with pressure interpolation. |
| **C3D20** | 20 | `:Hex20` | 20-node quadratic brick, full integration (27 points). Higher accuracy for smooth problems, captures stress concentrations well. |
| **C3D20E** | 20 | `:Hex20` | 20-node quadratic brick, enhanced strain formulation. Improved behavior for some applications. |
| **C3D20H** | 20 | `:Hex20` | 20-node quadratic brick, hybrid. For nearly incompressible materials to avoid volumetric locking. |
| **C3D20R** | 20 | `:Hex20` | 20-node brick, reduced integration (8 points). **Recommended over C3D20** - generally more accurate and ~3.5× faster. |
| **C3D20RH** | 20 | `:Hex20` | 20-node brick, reduced integration and hybrid. Efficient with hybrid formulation for nearly incompressible materials. |

### Cohesive Elements

| ABAQUS Element | Nodes | Generic Type | Description |
|----------------|:-----:|--------------|-------------|
| **COH3D8** | 8 | `:Hex8` | 8-node 3D cohesive element for modeling adhesive joints, gaskets, and delamination. |

## Shell Elements

### Triangular Shells

| ABAQUS Element | Nodes | Generic Type | Description |
|----------------|:-----:|--------------|-------------|
| **S3** | 3 | `:Tri3` | 3-node triangular general-purpose shell, full integration. Use second-order triangular shells when possible. |
| **S3R** | 3 | `:Tri3` | 3-node triangular shell, reduced integration. Faster than S3, suitable for large models. |
| **STRI3** | 3 | `:Tri3` | 3-node triangular shell element. Alternative triangular shell formulation. |
| **STRI65** | 6 | `:Tri6` | 6-node triangular shell. More accurate than 3-node shells, quadratic interpolation captures stress concentrations better. |

### Quadrilateral Shells

| ABAQUS Element | Nodes | Generic Type | Description |
|----------------|:-----:|--------------|-------------|
| **S4** | 4 | `:Quad4` | 4-node quadrilateral shell, full integration. General-purpose for thin and thick shells. |
| **S4R** | 4 | `:Quad4` | 4-node quadrilateral shell, reduced integration with hourglass control. **Recommended for most shell applications** - good balance of accuracy and efficiency. |
| **S8R** | 8 | `:Quad8` | 8-node quadrilateral shell, reduced integration. Very accurate for smooth problems, better for geometric features and stress concentrations. |

## 2D Continuum Elements

### Plane Stress (CPS)

For structures where stress in one direction is negligible (thin plates loaded in their plane).

| ABAQUS Element | Nodes | Generic Type | Description |
|----------------|:-----:|--------------|-------------|
| **CPS3** | 3 | `:Tri3` | 3-node linear plane stress triangle. **Avoid except as filler** - constant stress element, very fine mesh needed. Use CPS6 or quads. |
| **CPS4** | 4 | `:Quad4` | 4-node bilinear plane stress quadrilateral, full integration. Does not lock for nearly incompressible materials. |
| **CPS4R** | 4 | `:Quad4` | 4-node plane stress quad, reduced integration with hourglass control. **Recommended for most plane stress analyses** - computationally efficient. |
| **CPS4I** | 4 | `:Quad4` | 4-node plane stress quad with incompatible modes. Enhanced for bending. Best with rectangular element shapes. |
| **CPS6** | 6 | `:Tri6` | 6-node modified plane stress triangle. Better than CPS3 for triangular meshes, minimal locking. |
| **CPS8** | 8 | `:Quad8` | 8-node quadratic plane stress quad, full integration. Higher accuracy for smooth problems. |
| **CPS8R** | 8 | `:Quad8` | 8-node plane stress quad, reduced integration. **Generally more accurate than CPS8** and significantly faster. |

### Plane Strain (CPE)

For structures with no strain in one direction (long structures with uniform cross-section).

| ABAQUS Element | Nodes | Generic Type | Description |
|----------------|:-----:|--------------|-------------|
| **CPE3** | 3 | `:Tri3` | 3-node linear plane strain triangle. **Overly stiff, avoid** except as filler in noncritical regions. |
| **CPE4** | 4 | `:Quad4` | 4-node bilinear plane strain quad, full integration. Selective reduced integration prevents volumetric locking. |
| **CPE4R** | 4 | `:Quad4` | 4-node plane strain quad, reduced integration with hourglass control. **Widely used** - computationally efficient, requires reasonably fine mesh. |
| **CPE4I** | 4 | `:Quad4` | 4-node plane strain quad with incompatible modes. Eliminates parasitic shear in bending. Best with rectangular shapes. |
| **CPE6** | 6 | `:Tri6` | 6-node modified plane strain triangle. Improved over linear triangles, minimal locking, robust in finite deformation. |
| **CPE8** | 8 | `:Quad8` | 8-node quadratic plane strain quad, full integration. Higher accuracy for smooth problems and curved boundaries. |
| **CPE8R** | 8 | `:Quad8` | 8-node plane strain quad, reduced integration. **Recommended** for second-order plane strain analysis - more accurate and efficient than CPE8. |

### Axisymmetric (CAX)

For rotationally symmetric structures and loading.

| ABAQUS Element | Nodes | Generic Type | Description |
|----------------|:-----:|--------------|-------------|
| **CAX3** | 3 | `:Tri3` | 3-node linear axisymmetric triangle. **Should be avoided** - constant stress element with slow convergence. Use CAX6 or quads. |
| **CAX4** | 4 | `:Quad4` | 4-node bilinear axisymmetric quad, full integration. Selective reduced integration prevents locking with incompressible materials. |
| **CAX4R** | 4 | `:Quad4` | 4-node axisymmetric quad, reduced integration with hourglass control. **Most commonly used** axisymmetric element - good balance of accuracy and efficiency. |
| **CAX4I** | 4 | `:Quad4` | 4-node axisymmetric quad with incompatible modes. Enhanced bending behavior, eliminates parasitic shear stresses. |
| **CAX6** | 6 | `:Tri6` | 6-node modified axisymmetric triangle. Improved over first-order triangles, minimal locking, works well in contact. |
| **CAX8** | 8 | `:Quad8` | 8-node quadratic axisymmetric quad, full integration. Higher accuracy for smooth problems and curved geometries. |
| **CAX8R** | 8 | `:Quad8` | 8-node axisymmetric quad, reduced integration. **Recommended** for second-order axisymmetric analysis - more accurate and efficient. |

## Beam and Truss Elements

| ABAQUS Element | Nodes | Generic Type | Description |
|----------------|:-----:|--------------|-------------|
| **T2D2** | 2 | `:Seg2` | 2-node linear 2D truss element. Models pin-jointed structures with only axial loads (no bending). |
| **T3D2** | 2 | `:Seg2` | 2-node linear 3D truss element. For spatial structures carrying only axial loads. Common in space frames and towers. |
| **B31** | 2 | `:Seg2` | 2-node linear beam in space. Timoshenko beam theory includes transverse shear deformation. Use when shear is important. |
| **B32** | 3 | `:Seg3` | 3-node quadratic beam in space. Timoshenko beam theory. Quadratic interpolation for curved beams and improved bending accuracy. |
| **B33** | 2 | `:Seg2` | 2-node linear beam with cubic interpolation. Euler-Bernoulli beam theory (no shear). Better for slender beams. |

## Element Suffix Meanings

Understanding the suffix letters helps in selecting the right element:

- **R** = **Reduced integration** - Fewer integration points, faster computation, may need finer mesh to avoid hourglassing in first-order elements
- **H** = **Hybrid formulation** - Independent pressure interpolation for nearly incompressible or fully incompressible materials
- **I** = **Incompatible modes** - Enhanced for better bending behavior, eliminates parasitic shear stresses
- **M** = **Modified formulation** - Improved performance with minimal locking, works well in contact problems
- **E** = **Enhanced strain** - Improved formulation for certain applications

## Quick Selection Guide

- **Need accuracy with coarse mesh?** Use second-order elements (10, 15, 20, 8 nodes)
- **Need computational efficiency?** Use reduced integration (R suffix) with adequate mesh density
- **Nearly incompressible material?** Use hybrid elements (H suffix)
- **Bending-dominated problem?** Consider incompatible modes (I suffix) or second-order elements
- **Contact analysis?** Consider modified elements (M suffix, e.g., C3D10M)
- **Avoid** first-order triangles and tets (C3D4, CPS3, CPE3, CAX3) except as filler elements

## Adding New Element Types

Adding support for new ABAQUS element types is straightforward - element definitions are stored in a TOML database file rather than in code. See the [Contributing Guide](contributing.md) for detailed instructions.

## Handling Unknown Element Types

If you encounter an ABAQUS element type that is not yet in the database, AbaqusReader will provide a clear error message with instructions on how to proceed.

### Dynamic Registration (Quick Fix)

For immediate use, you can register an element type dynamically before reading your mesh:

```julia
using AbaqusReader

# Register a C3D10I element (10-node incompatible mode tetrahedron)
register_element!("C3D10I", 10, "Tet10")

# Now you can read meshes containing C3D10I elements
mesh = abaqus_read_mesh("model_with_c3d10i.inp")
```

The `register_element!` function takes three arguments:

- `element_name`: The ABAQUS element name (case-insensitive, will be uppercased)
- `num_nodes`: Number of nodes in the element
- `element_type`: The generic topology type (e.g., "Tet4", "Hex8", "Tri3", "Quad4", "Seg2")

This is useful when:

- You need to quickly process a file with an uncommon element variant
- You're testing or prototyping
- You don't want to modify the package source

### Permanent Addition (Recommended)

For element types that should be permanently available:

1. Edit `data/abaqus_elements.toml` in the AbaqusReader.jl repository
2. Add a new section following the existing format:

   ```toml
   [ELEMENT_NAME]
   nodes = <number_of_nodes>
   type = "<topology_type>"
   description = "Element description from ABAQUS documentation"
   ```

3. Run tests to verify: `julia --project=. test/runtests.jl`
4. Submit a pull request to <https://github.com/ahojukka5/AbaqusReader.jl>

See [Issue #67](https://github.com/ahojukka5/AbaqusReader.jl/issues/67) for the discussion that led to this feature.

### Common Element Variations

ABAQUS uses many variations of standard elements with the same node layout but different analysis characteristics:

- **Integration variations**: C3D8 vs C3D8R (full vs reduced integration)
- **Material model variations**: C3D8 vs C3D8H (standard vs hybrid for incompressible materials)
- **Formulation variations**: C3D8 vs C3D8I (standard vs incompatible modes)
- **Physics variations**: CPS4 vs CPE4 (plane stress vs plane strain)

Since AbaqusReader focuses on **mesh topology** rather than analysis formulations, these variations with the same node count map to the same generic element type. The specific ABAQUS element name is preserved in the parsed data for reference.
