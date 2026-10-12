"""
    abaqus_download(model_name, env=ENV; dryrun=false) -> String

Download an ABAQUS example model from a remote repository.

This helper is not exported. It is for tests and local examples that set
`ABAQUS_DOWNLOAD_URL`. It is not part of the public parser API
(`abaqus_read_mesh` / `abaqus_read_model`).

# Arguments
- `model_name`: Name of the model file to download (e.g., `"piston_ring_2d.inp"`)
- `env`: Environment dictionary (defaults to `ENV`)
- `dryrun::Bool`: If `true`, skip actual download (for testing)

# Returns
- `String`: Full path to the downloaded file
- Returns path immediately if file already exists locally

# Required Environment Variables
- `ABAQUS_DOWNLOAD_URL`: Base URL for downloading models
  - Example: `"https://example.com/models"`
  - The model file will be fetched from `\$ABAQUS_DOWNLOAD_URL/\$model_name`

# Optional Environment Variables
- `ABAQUS_DOWNLOAD_DIR`: Directory where files will be saved
  - Defaults to current directory if not set
  - Will create directory if it doesn't exist

# Examples
```julia
using AbaqusReader: abaqus_download, abaqus_read_mesh

# Set up environment variables
ENV["ABAQUS_DOWNLOAD_URL"] = "https://example.com/abaqus/models"
ENV["ABAQUS_DOWNLOAD_DIR"] = "/path/to/models"

# Download a model. The helper is not exported.
filepath = abaqus_download("piston_ring_2d.inp")

# Use the downloaded file
mesh = abaqus_read_mesh(filepath)
```

# Errors
Throws an error if:
- `ABAQUS_DOWNLOAD_URL` is not set and file doesn't exist locally
- Download fails (network error, file not found, etc.)

# Notes
- Files are only downloaded once; subsequent calls return the existing file path
- Useful for testing, tutorials, and reproducible examples
- Check the AbaqusReader repository for available example models
"""
function abaqus_download(model_name, env=ENV; dryrun=false)
    path = get(env, "ABAQUS_DOWNLOAD_DIR", "")
    fn = joinpath(path, model_name)
    if isfile(fn)  # already downloaded
        return fn
    end
    if !haskey(env, "ABAQUS_DOWNLOAD_URL")
        error("ABAQUS input file $fn not found and `ABAQUS_DOWNLOAD_URL` not ",
            "set, unable to download file. To enable automatic model ",
            "downloading, set url to models to environment variable
            `ABAQUS_DOWNLOAD_URL`")
    end
    url = joinpath(env["ABAQUS_DOWNLOAD_URL"], model_name)
    @debug "Downloading model $model_name to $fn"
    dryrun || download(url, fn)
    return fn
end
