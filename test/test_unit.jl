module TestUnit

using Test
using TrixiSmartShockFinder
using TrixiSmartShockFinder: Trixi
using Trixi

# Load testing functions from Trixi.jl
include(joinpath(pkgdir(TrixiSmartShockFinder.Trixi), "test", "test_trixi.jl"))

# Start with a clean environment: remove Trixi.jl output directory if it exists
outdir = "out"
isdir(outdir) && rm(outdir, recursive = true)

# Run various unit (= non-elixir-triggered) tests
@testset "Unit tests" begin
#! format: noindent

@timed_testset "Printing indicators/controllers" begin
    equations = CompressibleEulerEquations2D(1.4)
    basis = LobattoLegendreBasis(3)
    indicator_neuralnetwork = IndicatorNeuralNetwork(equations, basis,
                                                     indicator_type = NeuralNetworkPerssonPeraire(),
                                                     variable = density,
                                                     network = nothing)
    @test_nowarn show(stdout, indicator_neuralnetwork)
end
end

end #module
