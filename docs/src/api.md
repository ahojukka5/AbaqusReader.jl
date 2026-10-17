# API Reference

```@meta
DocTestSetup = quote
    using AbaqusReader
end
```

## Overview

AbaqusReader.jl exports the following main functions for working with ABAQUS input files:

- Reading API: `abaqus_read_mesh`, `abaqus_read_model` (read from .inp files)
- String parsing API: `abaqus_parse_mesh`, `abaqus_parse_model` (parse from string buffers)
- Writing API: `abaqus_write_mesh`, `abaqus_mesh_string` (write mesh includes to .inp files or strings)
- Element registration: `register_element!` (add element types dynamically)
- Mesh utilities: `create_surface_elements`, `element_boundary`, `boundary_faces`

`abaqus_download` is not exported. It remains an unexported helper for
tests that set `ABAQUS_DOWNLOAD_URL`.

## Index

```@index
```

## Exported Functions

```@docs
abaqus_read_mesh
abaqus_parse_mesh
abaqus_read_model
abaqus_parse_model
abaqus_write_mesh
abaqus_mesh_string
register_element!
create_surface_elements
element_boundary
boundary_faces
```

