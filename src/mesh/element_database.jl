"""
    load_element_database()

Load element information from the TOML database file.

Returns a Dict mapping element symbols to tuples of (node_count, element_type).
"""
function load_element_database()
    toml_path = joinpath(@__DIR__, "..", "..", "data", "abaqus_elements.toml")
    element_data = TOML.parsefile(toml_path)

    # Convert to the format expected by the rest of the code
    element_info = Dict{Symbol,Tuple{Int,Symbol}}()
    for (elem_name, elem_props) in element_data
        elem_symbol = Symbol(elem_name)
        num_nodes = elem_props["nodes"]
        elem_type = Symbol(elem_props["type"])
        element_info[elem_symbol] = (num_nodes, elem_type)
    end

    return element_info
end

# Load element definitions at module initialization
const ELEMENT_INFO = load_element_database()

"""
    register_element!(element_name::String, num_nodes::Int, element_type::String)

Register a new element type dynamically without modifying the TOML database.
Useful for handling element variations not yet in the database.

# Arguments
- `element_name`: ABAQUS element name (e.g., "C3D10I", "C3D8RT")
- `num_nodes`: Number of nodes in the element
- `element_type`: Topology type (e.g., "Tet10", "Hex8", "Tri3", "Quad4")

# Example
```julia
# Register a C3D10I element (10-node incompatible mode tet)
register_element!("C3D10I", 10, "Tet10")

# Now you can read meshes containing C3D10I elements
mesh = abaqus_read_mesh("model_with_c3d10i.inp")
```

To make the element permanently available, consider adding it to 
`data/abaqus_elements.toml` and submitting a pull request.
"""
function register_element!(element_name::String, num_nodes::Int, element_type::String)
    elem_symbol = Symbol(uppercase(element_name))
    type_symbol = Symbol(element_type)
    ELEMENT_INFO[elem_symbol] = (num_nodes, type_symbol)
    @debug "Registered element $element_name: $num_nodes nodes, type $element_type"
    return nothing
end

"""
    element_has_nodes(eltype::Symbol) -> Int

Get the number of nodes for a given element type.
Throws an informative error if the element type is not registered.
"""
function element_has_nodes(eltype::Symbol)
    if !haskey(ELEMENT_INFO, eltype)
        throw_unknown_element_error(eltype)
    end
    return ELEMENT_INFO[eltype][1]
end

"""
    element_has_type(eltype::Symbol) -> Symbol

Get the mesh topology type for a given element type.
Throws an informative error if the element type is not registered.
"""
function element_has_type(eltype::Symbol)
    if !haskey(ELEMENT_INFO, eltype)
        throw_unknown_element_error(eltype)
    end
    return ELEMENT_INFO[eltype][2]
end

"""
    throw_unknown_element_error(eltype::Symbol)

Throw an informative error message for unknown element types.
"""
function throw_unknown_element_error(eltype::Symbol)
    error("""
    Unknown ABAQUS element type: $eltype

    This element type is not in the element database. You have two options:

    1. TEMPORARY FIX - Register the element dynamically before reading the mesh:
       
       using AbaqusReader
       register_element!("$eltype", num_nodes, "ElementType")
       
       Where:
       - num_nodes: number of nodes in the element (e.g., 4, 8, 10, 20)
       - ElementType: mesh topology (e.g., "Tet4", "Hex8", "Tri3", "Quad4")
       
       Example: register_element!("C3D10I", 10, "Tet10")

    2. PERMANENT FIX - Add the element to the database:
       
       a) Edit data/abaqus_elements.toml in the AbaqusReader.jl repository
       b) Add a new section following the existing format:
          
          [$eltype]
          nodes = <number_of_nodes>
          type = "<topology_type>"
          description = "Element description from ABAQUS documentation"
       
       c) Run tests to verify: julia --project=. test/runtests.jl
       d) Submit a pull request to: https://github.com/ahojukka5/AbaqusReader.jl

    See https://github.com/ahojukka5/AbaqusReader.jl#element-types for more information.
    """)
end

# Legacy API for backward compatibility with tests
element_has_nodes(::Type{Val{T}}) where T = element_has_nodes(T)
element_has_type(::Type{Val{T}}) where T = element_has_type(T)
