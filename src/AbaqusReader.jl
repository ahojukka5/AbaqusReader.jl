# This file is a part of JuliaFEM.
# License is MIT: see https://github.com/JuliaFEM/AbaqusReader.jl/blob/master/LICENSE

module AbaqusReader

using Logging
import TOML

# Mesh parsing module
include("mesh/element_database.jl")
include("mesh/utilities.jl")
include("mesh/parsers.jl")
include("mesh/assembly_parser.jl")
include("mesh/reader.jl")

# Model parsing module
include("model/types.jl")
include("model/state.jl")
include("model/keywords.jl")
include("model/sections.jl")
include("model/reader.jl")

# Utilities
include("create_surface_elements.jl")
include("boundary_surface.jl")
include("abaqus_download.jl")

# Export public API
export abaqus_read_mesh, abaqus_parse_mesh
export abaqus_read_model, abaqus_parse_model
export create_surface_elements
export element_boundary
export boundary_surface
export SurfaceTriangle
export abaqus_download
export register_element!

end
