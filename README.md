# TrixiSmartShockFinder.jl
[![Build Status](https://github.com/trixi-framework/TrixiSmartShockFinder.jl/workflows/CI/badge.svg)](https://github.com/trixi-framework/TrixiSmartShockFinder.jl/actions?query=workflow%3ACI)
[![Coveralls](https://coveralls.io/repos/github/trixi-framework/TrixiSmartShockFinder.jl/badge.svg?branch=main)](https://coveralls.io/github/trixi-framework/TrixiSmartShockFinder.jl?branch=main)
[![License: MIT](https://img.shields.io/badge/License-MIT-success.svg)](https://opensource.org/licenses/MIT)

Spin-off repository of [Trixi.jl](https://github.com/trixi-framework/Trixi.jl)
with neural network-based shock indicators.

**Note: This repository is currently not under development and has been archived. If you are
interested in using any of this, please get in touch with the developers of the
[Trixi.jl](https://github.com/trixi-framework/Trixi.jl) package.


## Usage
To run any of the elixirs with the neurl network-based indicators, you first need to install
all required auxiliary packages by running the following code in the Julia REPL:
```julia
julia> using Pkg

julia> Pkg.add(["BSON", "Flux", "OrdinaryDiffEq", "Trixi"])
```

Then, clone this repository
```shell
git clone git@github.com:trixi-framework/TrixiSmartShockFinder.jl.git
```
enter the directory, and start Julia (tested with Julia v1.9) with the project set to
the clone directory
```
cd TrixiSmartShockFinder.jl
julia --project=.
```

Now run one of the elixirs in the `examples` folder, e.g.,
```julia
using TrixiSmartShockFinder
trixi_include("examples/tree_2d_dgsem/elixir_euler_blast_wave_neuralnetwork_perssonperaire.jl")
```

## Authors
TrixiSmartShockFinder.jl was initiated by
[Michael Schlottke-Lakemper](https://lakemper.eu) (University of Augsburg, Germany) and
Julia Odenthal (University of Cologne, Germany).


## License and contributing
TrixiSmartShockFinder.jl is licensed under the MIT license (see [LICENSE.md](LICENSE.md)).
