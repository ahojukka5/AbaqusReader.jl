# This file is a part of JuliaFEM.
# License is MIT: see https://github.com/JuliaFEM/AbaqusReader.jl/blob/master/LICENSE

"""
    element_mapping

This mapping table contains information what node ids locally match
each side of element.
"""
const element_mapping = Dict(
    # Tetrahedra
    :Tet4 => Dict(
        :S1 => (:Tri3, [1, 3, 2]),
        :S2 => (:Tri3, [1, 2, 4]),
        :S3 => (:Tri3, [2, 3, 4]),
        :S4 => (:Tri3, [1, 4, 3])),
    :Tet10 => Dict(
        :S1 => (:Tri6, [1, 3, 2, 7, 6, 5]),
        :S2 => (:Tri6, [1, 2, 4, 5, 9, 8]),
        :S3 => (:Tri6, [2, 3, 4, 6, 10, 9]),
        :S4 => (:Tri6, [1, 4, 3, 8, 10, 7])),

    # Hexahedra
    :Hex8 => Dict(
        :S1 => (:Quad4, [1, 2, 3, 4]),
        :S2 => (:Quad4, [5, 8, 7, 6]),
        :S3 => (:Quad4, [1, 5, 6, 2]),
        :S4 => (:Quad4, [2, 6, 7, 3]),
        :S5 => (:Quad4, [3, 7, 8, 4]),
        :S6 => (:Quad4, [4, 8, 5, 1])),
    :Hex20 => Dict(
        :S1 => (:Quad8, [1, 2, 3, 4, 9, 10, 11, 12]),
        :S2 => (:Quad8, [5, 8, 7, 6, 16, 15, 14, 13]),
        :S3 => (:Quad8, [1, 5, 6, 2, 17, 13, 18, 9]),
        :S4 => (:Quad8, [2, 6, 7, 3, 18, 14, 19, 10]),
        :S5 => (:Quad8, [3, 7, 8, 4, 19, 15, 20, 11]),
        :S6 => (:Quad8, [4, 8, 5, 1, 20, 16, 17, 12])),

    # Wedges / prisms
    :Wedge6 => Dict(
        :S1 => (:Quad4, [1, 4, 5, 2]),
        :S2 => (:Quad4, [2, 5, 6, 3]),
        :S3 => (:Quad4, [3, 6, 4, 1]),
        :S4 => (:Tri3, [1, 2, 3]),
        :S5 => (:Tri3, [4, 6, 5])),
    :Wedge15 => Dict(
        :S1 => (:Quad8, [1, 4, 5, 2, 10, 11, 12, 8]),
        :S2 => (:Quad8, [2, 5, 6, 3, 12, 13, 14, 9]),
        :S3 => (:Quad8, [3, 6, 4, 1, 14, 15, 10, 7]),
        :S4 => (:Tri6, [1, 2, 3, 8, 9, 7]),
        :S5 => (:Tri6, [4, 6, 5, 15, 13, 11])),

    # Shells (tri/quads) for completeness in surface extraction
    :Tri3 => Dict(:S1 => (:Seg2, [1, 2]), :S2 => (:Seg2, [2, 3]), :S3 => (:Seg2, [3, 1])),
    :Tri6 => Dict(:S1 => (:Seg3, [1, 2, 4]), :S2 => (:Seg3, [2, 3, 5]), :S3 => (:Seg3, [3, 1, 6])),
    :Quad4 => Dict(
        :S1 => (:Seg2, [1, 2]),
        :S2 => (:Seg2, [2, 3]),
        :S3 => (:Seg2, [3, 4]),
        :S4 => (:Seg2, [4, 1])),
    :Quad8 => Dict(
        :S1 => (:Seg3, [1, 2, 5]),
        :S2 => (:Seg3, [2, 3, 6]),
        :S3 => (:Seg3, [3, 4, 7]),
        :S4 => (:Seg3, [4, 1, 8])))

""" Given element code, element side and global connectivity, determine boundary
element. E.g. for Tet4 we have 4 sides S1..S4 and boundary element is of type Tri3.
"""
function create_surface_element(element_type::Symbol, element_side::Symbol,
    element_connectivity::Vector{Int})

    if !haskey(element_mapping, element_type)
        error("Unable to find surface element for element of type ",
            "$element_type for side $element_side, update element ",
            "mapping table.")
    end

    if !haskey(element_mapping[element_type], element_side)
        error("Unable to find child element side mapping for element ",
            "of type $element_type for side $element_side, update ",
            "element mapping table.")
    end

    surfel, surfel_lconn = element_mapping[element_type][element_side]
    surfel_gconn = element_connectivity[surfel_lconn]
    return surfel, surfel_gconn
end

"""
    create_surface_elements(mesh::Dict, surface_name::String) -> Vector{Tuple{Symbol, Vector{Int}}}

Create explicit surface elements from an implicit surface definition in an ABAQUS mesh.

ABAQUS surfaces are typically defined implicitly as (element, face) pairs. This function
converts those implicit definitions into explicit surface elements with their own connectivity,
which is useful for applying boundary conditions, extracting surface nodes, or visualization.

# Arguments
- `mesh::Dict`: Mesh dictionary as returned by [`abaqus_read_mesh`](@ref)
- `surface_name::String`: Name of the surface to extract (must exist in `mesh["surface_sets"]`)

# Returns
`Vector{Tuple{Symbol, Vector{Int}}}` where each tuple contains:
- Element type symbol (e.g., `:Tri3`, `:Quad4`) for the surface element
- Node connectivity vector for that surface element

# Examples
```julia
using AbaqusReader

# Read mesh with surface definitions
mesh = abaqus_read_mesh("model.inp")

# Check available surfaces
println("Available surfaces: ", keys(mesh["surface_sets"]))

# Create surface elements for a named surface
surface_elems = create_surface_elements(mesh, "LOAD_SURFACE")

# Extract unique nodes on the surface
surface_nodes = Set{Int}()
for (elem_type, connectivity) in surface_elems
    union!(surface_nodes, connectivity)
end
println("Surface has \$(length(surface_nodes)) unique nodes")

# Get coordinates of surface nodes
surface_coords = [mesh["nodes"][nid] for nid in surface_nodes]

# Apply boundary conditions to surface nodes
for node_id in surface_nodes
    # Apply BC at node_id...
end
```

# Surface Element Types
Depending on the parent volume element type and face, surface elements can be:
- `:Tri3` - 3-node triangle (from tet faces, wedge faces)
- `:Tri6` - 6-node triangle (from quadratic tet faces)
- `:Quad4` - 4-node quadrilateral (from hex faces, wedge faces)
- `:Quad8` - 8-node quadrilateral (from quadratic hex faces)

# See Also
- [`abaqus_read_mesh`](@ref): Read mesh data containing surface definitions
- [`abaqus_read_model`](@ref): Read complete model with surfaces

# Notes
- Surface must exist in `mesh["surface_sets"]` or an error will be thrown
- The parent elements referenced in the surface definition must exist in the mesh
- Each (element, face) pair generates one surface element
- Useful for extracting boundary nodes for applying loads or boundary conditions
"""
function create_surface_elements(mesh::Dict, surface_name::String)
    surface = mesh["surface_sets"][surface_name]
    elements = mesh["elements"]
    eltypes = mesh["element_types"]
    result = Tuple{Symbol,Vector{Int}}[]
    for (elid, side) in surface
        surface_element = create_surface_element(eltypes[elid], side, elements[elid])
        push!(result, surface_element)
    end
    return result
end
