module AbaqusReader

using Logging
import TOML

# Mesh parsing module
include("mesh/element_database.jl")
include("mesh/utilities.jl")
include("mesh/parsers.jl")
include("mesh/assembly_parser.jl")
include("mesh/reader.jl")
include("mesh/writer.jl")
include("mesh/create_surface_elements.jl")

# Model parsing module
include("model/types.jl")
include("model/state.jl")
include("model/keywords.jl")
include("model/sections.jl")
include("model/reader.jl")

include("boundary_faces.jl")
# Not exported. Kept for tests that set ABAQUS_DOWNLOAD_URL.
include("abaqus_download.jl")

# Export public API
export abaqus_read_mesh, abaqus_parse_mesh
export abaqus_write_mesh, abaqus_mesh_string
export abaqus_read_model, abaqus_parse_model
export create_surface_elements
export element_boundary
export boundary_faces
export register_element!

end
