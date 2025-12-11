# Test Data

This directory contains ABAQUS `.inp` files for testing and benchmarking AbaqusReader.jl.

All files are tracked with **Git LFS** to keep the repository size manageable.

## Getting the Files

The large test files are stored using Git LFS. To download them:

### Prerequisites

1. **Install Git LFS** (if not already installed):

   ```bash
   # macOS (using Homebrew)
   brew install git-lfs
   
   # Linux (Ubuntu/Debian)
   sudo apt-get install git-lfs
   
   # Windows (using Chocolatey)
   choco install git-lfs
   ```

2. **Initialize Git LFS** in your repository:

   ```bash
   git lfs install
   ```

### Downloading the Files

After cloning the repository, pull the LFS files:

```bash
# Pull all LFS files
git lfs pull

# Or pull specific files
git lfs pull --include "testdata/piston_large.inp"
```

**Note:** If you've already cloned the repository, you may need to run `git lfs
pull` to download the actual file contents. Without this, you'll only have LFS
pointer files (small text files) instead of the actual `.inp` files.•

### Verifying LFS Files

To check if LFS files are properly downloaded:

```bash
# List LFS tracked files
git lfs ls-files

# Check file sizes (should show actual sizes, not just a few bytes)
ls -lh testdata/*.inp
```

## Files

| File                  | Size    | Elements | Description                                          | Source        |
|-----------------------|---------|----------|------------------------------------------------------|---------------|
| `3d_beam.inp`         | 34 KB   | ~300     | 3D beam with Tet4 elements                           | JuliaFEM.jl   |
| `beam_3d_tet10.inp`   | 157 KB  | ~1,500   | 3D beam with Tet10 (quadratic) elements              | JuliaFEM.jl   |
| `flange_coupling.inp` | 1.2 MB  | ~12,000  | Flange coupling with tie contact                     | JuliaFEM.jl   |
| `piston_medium.inp`   | 2.5 MB  | ~9,000   | Medium-sized piston mesh                             | JuliaFEM.jl   |
| `piston_large.inp`    | 15 MB   | ~46,000  | Large piston mesh for performance testing            | JuliaFEM.jl   |

## Usage

```julia
using AbaqusReader

# Test with a small file
mesh = abaqus_read_mesh("testdata/3d_beam.inp")
println("Nodes: ", length(mesh["nodes"]))
println("Elements: ", length(mesh["elements"]))

# Test with a large file (performance)
@time mesh = abaqus_read_mesh("testdata/piston_large.inp")
```

## Adding More Files

To add new test files:

1. Place the `.inp` file in this directory
2. Add it to Git LFS tracking: `git lfs track "*.inp"`
3. Update this README with file details
4. Commit: `git add testdata/yourfile.inp testdata/README.md`

## Sources

All files originally from **JuliaFEM.jl** project backup (2025-11-06):

- Repository: https://github.com/JuliaFEM/JuliaFEM.jl
- License: MIT (same as AbaqusReader.jl)
- Original paths preserved in file history

These files represent real-world FEM models and provide excellent test cases for:

- Different element types (Tet4, Tet10, Hex8)
- Various mesh sizes (300 to 46,000 elements)
- Complex geometries (pistons, flange couplings)
- Performance benchmarking
