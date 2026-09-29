# Examples

This page demonstrates the two main ways to use AbaqusReader.jl.

## Example 1: Reading Just the Mesh

The simplest use case - extract only geometry and topology for visualization or conversion:

```julia
using AbaqusReader

# Read mesh data from an ABAQUS input file
mesh = abaqus_read_mesh("my_model.inp")

# mesh is a Dict with the following keys:
# - "nodes": Dict mapping node IDs to coordinates [x, y, z]
# - "elements": Dict mapping element IDs to connectivity arrays
# - "element_types": Dict mapping element IDs to element type symbols (topology)
# - "element_codes": Dict mapping element IDs to original ABAQUS element names
# - "node_sets": Dict mapping set names to arrays of node IDs
# - "element_sets": Dict mapping set names to arrays of element IDs
# - "surface_sets": Dict mapping surface names to arrays of (element_id, face_symbol) tuples
# - "surface_types": Dict mapping surface names to surface type (e.g., :ELEMENT)

# Access node coordinates
node_1_coords = mesh["nodes"][1]  # [x, y, z]

# Access all nodes in a node set
sym_nodes = mesh["node_sets"]["SYMMETRY"]

# Access elements in an element set
volume_elements = mesh["element_sets"]["PART1"]

# Get element connectivity
element_1_nodes = mesh["elements"][1]  # Array of node IDs

# Get element type (topological type, e.g., Tri3, Quad4, Tet4, Hex8)
element_1_type = mesh["element_types"][1]  # e.g., :Tet4, :Hex8

# Get original ABAQUS element code (e.g., CPS3, CPE3, C3D8R)
element_1_code = mesh["element_codes"][1]  # e.g., :CPS3, :C3D8R

# Use element codes to determine physics formulation if needed
if mesh["element_codes"][1] == :CPS3
    println("Element 1 is plane stress")
elseif mesh["element_codes"][1] == :CPE3
    println("Element 1 is plane strain")
elseif mesh["element_codes"][1] == :CAX3
    println("Element 1 is axisymmetric")
end
```

### Use Cases for Mesh-Only Parsing

- **Mesh visualization**: Extract geometry for plotting with Makie.jl, Plots.jl, or external tools
- **Format conversion**: Convert ABAQUS meshes to other FEM formats
- **Custom FEM**: Build your own finite element implementation on ABAQUS geometries
- **Mesh inspection**: Quickly check mesh quality, element counts, node sets

## Example 2: Reading the Complete Model

When you need to reproduce the entire simulation, not just the geometry:

```julia
using AbaqusReader

# Read the complete model definition
model = abaqus_read_model("simulation.inp")

# model is an AbaqusReader.Model instance with fields:
# - mesh: Dict (same as returned by abaqus_read_mesh)
# - materials: Dict mapping material names to Material structs
# - properties: Dict of section properties
# - boundary_conditions: Array of BoundaryCondition structs
# - steps: Array of Step structs defining the analysis sequence

# Access the mesh (same as mesh-only parsing)
nodes = model.mesh["nodes"]
elements = model.mesh["elements"]

# Access material definitions
steel = model.materials["STEEL"]
# Materials contain properties like:
# - elastic: Young's modulus, Poisson's ratio
# - density: Material density
# - plastic: Yield stress, plastic strain curves

# Access boundary conditions
for bc in model.boundary_conditions
    println("BC on set: $(bc.set_name)")
    println("  DOF: $(bc.dof)")
    println("  Value: $(bc.value)")
end

# Access analysis steps
for step in model.steps
    println("Step: $(step.name)")
    println("  Type: $(step.type)")
    # Steps contain loads, BCs, and output requests specific to that step
end
```

### Use Cases for Complete Model Parsing

- **Simulation reproduction**: Extract all parameters to reproduce analysis in another solver
- **Model verification**: Programmatically check material properties, BCs, and loads
- **Parameter studies**: Extract and modify simulation parameters for batch studies
- **Documentation**: Auto-generate simulation documentation from .inp files
- **Solver development**: Use complete ABAQUS models as test cases for custom solvers

## Example 3: Extracting Surface Elements

Create explicit surface elements from volume element faces:

```julia
using AbaqusReader

# Read mesh
mesh = abaqus_read_mesh("model.inp")

# Create surface elements for a named surface
# This converts implicit surface definitions (element + face)
# into explicit surface element connectivity
surface_elements = create_surface_elements(mesh, "LOAD_SURFACE")

# Returns Dict with:
# - element IDs as keys
# - node connectivity arrays as values
# Surface elements are numbered starting from max(element_ids) + 1

# Example: Apply loads to surface nodes
surface_nodes = Set()
for (elem_id, connectivity) in surface_elements
    union!(surface_nodes, connectivity)
end
println("Surface has $(length(surface_nodes)) unique nodes")
```

## Example 4: Downloading Test Models

AbaqusReader includes a helper to download example ABAQUS models:

```julia
using AbaqusReader

# Download an example model (downloads to current directory)
filename = abaqus_download("piston_ring_2d")

# Then read it
mesh = abaqus_read_mesh(filename)

# The file is now available locally for further analysis
println("Downloaded: $filename")
println("Nodes: ", length(mesh["nodes"]))
println("Elements: ", length(mesh["elements"]))
```

This is useful for:

- Testing your analysis pipeline
- Learning the package with real models
- Benchmarking performance
- Creating reproducible examples

## Example 5: Mesh Statistics and Quality Checks

Extract useful information about your mesh:

```julia
using AbaqusReader
using Statistics

mesh = abaqus_read_mesh("model.inp")

# Count elements by type
element_type_counts = Dict{Symbol, Int}()
for elem_type in values(mesh["element_types"])
    element_type_counts[elem_type] = get(element_type_counts, elem_type, 0) + 1
end

println("Element type distribution:")
for (etype, count) in element_type_counts
    println("  $etype: $count elements")
end

# Node set statistics
println("\nNode sets:")
for (set_name, node_ids) in mesh["node_sets"]
    println("  $set_name: $(length(node_ids)) nodes")
end

# Element set statistics  
println("\nElement sets:")
for (set_name, elem_ids) in mesh["element_sets"]
    println("  $set_name: $(length(elem_ids)) elements")
end

# Calculate bounding box
all_coords = collect(values(mesh["nodes"]))
x_coords = [c[1] for c in all_coords]
y_coords = [c[2] for c in all_coords]
z_coords = [c[3] for c in all_coords]

println("\nBounding box:")
println("  X: [$(minimum(x_coords)), $(maximum(x_coords))]")
println("  Y: [$(minimum(y_coords)), $(maximum(y_coords))]")
println("  Z: [$(minimum(z_coords)), $(maximum(z_coords))]")
```

## Example 6: Converting to Other Formats

Export mesh data to different formats for use in other tools:

```julia
using AbaqusReader

mesh = abaqus_read_mesh("model.inp")

# Export to VTK format (pseudo-code - requires a VTK writer package)
# using WriteVTK
# vtk_grid("output", mesh["nodes"], mesh["elements"])

# Export nodes to CSV
using DelimitedFiles

# Create node matrix [id, x, y, z]
node_matrix = zeros(length(mesh["nodes"]), 4)
for (i, (node_id, coords)) in enumerate(sort(collect(mesh["nodes"])))
    node_matrix[i, :] = [node_id, coords...]
end

writedlm("nodes.csv", node_matrix, ',')
println("Exported $(size(node_matrix, 1)) nodes to nodes.csv")

# Export element connectivity
open("elements.csv", "w") do io
    println(io, "element_id,type,connectivity...")
    for (elem_id, connectivity) in sort(collect(mesh["elements"]))
        elem_type = mesh["element_types"][elem_id]
        println(io, "$elem_id,$elem_type,$(join(connectivity, ','))")
    end
end
println("Exported $(length(mesh["elements"])) elements to elements.csv")
```

## Example 7: Visualization with Makie.jl (Conceptual)

While AbaqusReader doesn't include visualization, the mesh data can be easily visualized:

```julia
using AbaqusReader
# using GLMakie  # Uncomment if you have Makie installed

mesh = abaqus_read_mesh("model.inp")

# Extract node coordinates as a matrix
node_ids = sort(collect(keys(mesh["nodes"])))
coords = hcat([mesh["nodes"][id] for id in node_ids]...)'

# For shell or 2D meshes, plot nodes
# scatter3d(coords[:, 1], coords[:, 2], coords[:, 3], markersize=5)

# For volume meshes, extract surface elements first
# surface_elems = create_surface_elements(mesh, "OUTER_SURFACE")
# Then use a mesh plotting function

# Alternatively, export to VTK and use ParaView for visualization
```

**Tip:** For serious visualization, consider exporting to VTK format and using ParaView, or use Julia packages like Makie.jl or PlotlyJS.jl for interactive 3D plots.

## Example 8: Working with Surface Definitions

Extract and manipulate surface definitions for boundary conditions or loads:

```julia
using AbaqusReader

mesh = abaqus_read_mesh("model.inp")

# Check what surfaces are defined
println("Available surfaces:")
for (surf_name, surf_def) in mesh["surface_sets"]
    println("  $surf_name: $(length(surf_def)) faces")
    println("    Type: $(mesh["surface_types"][surf_name])")
end

# Create explicit surface elements for a specific surface
surface_name = "LOAD_SURFACE"
surface_elements = create_surface_elements(mesh, surface_name)

println("\nSurface '$surface_name' details:")
println("  Number of surface elements: $(length(surface_elements))")

# Extract all unique nodes on the surface
surface_nodes = Set{Int}()
for (elem_id, connectivity) in surface_elements
    union!(surface_nodes, connectivity)
end

println("  Number of surface nodes: $(length(surface_nodes))")
println("  Node IDs: $(sort(collect(surface_nodes)))")

# Get coordinates of surface nodes
surface_coords = [mesh["nodes"][nid] for nid in sort(collect(surface_nodes))]
println("  First surface node: $(surface_coords[1])")

# This surface node information can be used to:
# - Apply pressure loads
# - Define contact surfaces
# - Extract results at specific locations
# - Create visualizations of boundaries
```

## Working with Specific Element Types

The package automatically handles different ABAQUS element types:

```julia
mesh = abaqus_read_mesh("mixed_elements.inp")

# Find all tetrahedral elements
tet_elements = [id for (id, etype) in mesh["element_types"] if etype == :Tet4]

# Find all hexahedral elements  
hex_elements = [id for (id, etype) in mesh["element_types"] if etype == :Hex8]

# Get connectivity for specific element type
for elem_id in tet_elements
    nodes = mesh["elements"][elem_id]
    @assert length(nodes) == 4  # Tet4 has 4 nodes
end
```

## Tips and Best Practices

### Quiet Operation

By default, AbaqusReader operates quietly. If you need debug output for troubleshooting:

```julia
using Logging

with_logger(ConsoleLogger(stderr, Logging.Debug)) do
    mesh = abaqus_read_mesh("model.inp")
end
```

### Large Models

For large models, mesh-only parsing is significantly faster than complete model parsing:

```julia
# Fast - only parses mesh sections
@time mesh = abaqus_read_mesh("large_model.inp")

# Slower - parses everything
@time model = abaqus_read_model("large_model.inp")
```

Choose the appropriate function for your needs to optimize performance.

### Assemblies

`abaqus_read_mesh` reads `*PART`, `*INSTANCE`, and `*ASSEMBLY` input and
returns one mesh. Instance translation and rotation are applied, and the same
part may be placed more than once. Set and surface names on the flattened
mesh are prefixed with the instance name. `abaqus_read_model` does not
flatten assemblies.
