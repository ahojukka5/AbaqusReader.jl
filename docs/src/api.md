# API Reference

```@meta
DocTestSetup = quote
    using AbaqusReader
end
```

## Overview

AbaqusReader.jl exports the following main functions for working with ABAQUS input files:

- File-based API: `abaqus_read_mesh`, `abaqus_read_model` (read from .inp files)
- String-based API: `abaqus_parse_mesh`, `abaqus_parse_model` (parse from string buffers)
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
register_element!
create_surface_elements
element_boundary
boundary_faces
```

