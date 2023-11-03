module TestExamples1DEuler

using Test
using TrixiSmartShockFinder
using Trixi

# Load testing functions from Trixi.jl
include(joinpath(pkgdir(TrixiSmartShockFinder.Trixi), "test", "test_trixi.jl"))

EXAMPLES_DIR = pkgdir(TrixiSmartShockFinder, "examples", "tree_1d_dgsem")

# Start with a clean environment: remove Trixi.jl output directory if it exists
outdir = "out"
isdir(outdir) && rm(outdir, recursive = true)

@testset "Compressible Euler 1D" begin
#! format: noindent

@trixi_testset "elixir_euler_blast_wave_neuralnetwork_perssonperaire.jl" begin
    @test_trixi_include(joinpath(EXAMPLES_DIR,
                                 "elixir_euler_blast_wave_neuralnetwork_perssonperaire.jl"),
                        l2=[0.21814833203212694, 0.2818328665444332, 0.5528379124720818],
                        linf=[1.5548653877320868, 1.4474018998129738, 2.071919577393772],
                        maxiters=30)
end

@trixi_testset "elixir_euler_blast_wave_neuralnetwork_rayhesthaven.jl" begin
    @test_trixi_include(joinpath(EXAMPLES_DIR,
                                 "elixir_euler_blast_wave_neuralnetwork_rayhesthaven.jl"),
                        l2=[0.22054468879127423, 0.2828269190680846, 0.5542369885642424],
                        linf=[
                            1.5623359741479623,
                            1.4290121654488288,
                            2.1040405133123072,
                        ],
                        maxiters=30)
end
end

end # module
