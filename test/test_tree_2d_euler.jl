module TestExamples2DEuler

using Test
using TrixiSmartShockFinder
using TrixiSmartShockFinder: Trixi
using Trixi

# Load testing functions from Trixi.jl
include(joinpath(pkgdir(TrixiSmartShockFinder.Trixi), "test", "test_trixi.jl"))

EXAMPLES_DIR = pkgdir(Trixi, "examples", "tree_2d_dgsem")

# Start with a clean environment: remove Trixi.jl output directory if it exists
outdir = "out"
isdir(outdir) && rm(outdir, recursive = true)

@testset "Compressible Euler 2D" begin
#! format: noindent

@trixi_testset "elixir_euler_blast_wave_neuralnetwork_perssonperaire.jl" begin
    @test_trixi_include(joinpath(EXAMPLES_DIR,
                                 "elixir_euler_blast_wave_neuralnetwork_perssonperaire.jl"),
                        l2=[
                            0.4758794741390833,
                            0.21045415565179362,
                            0.21045325630191866,
                            0.7022517958549878,
                        ],
                        linf=[
                            1.710832148442441,
                            0.9711663578827681,
                            0.9703787873632452,
                            2.9619758810532653,
                        ],
                        initial_refinement_level=4,
                        maxiters=50)
end

@trixi_testset "elixir_euler_blast_wave_neuralnetwork_rayhesthaven.jl" begin
    @test_trixi_include(joinpath(EXAMPLES_DIR,
                                 "elixir_euler_blast_wave_neuralnetwork_rayhesthaven.jl"),
                        l2=[
                            0.472445774440313,
                            0.2090782039442978,
                            0.20885558673697927,
                            0.700569533591275,
                        ],
                        linf=[
                            1.7066492792835155,
                            0.9856122336679919,
                            0.9784316656930644,
                            2.9372978989672873,
                        ],
                        initial_refinement_level=4,
                        maxiters=50)
end

@trixi_testset "elixir_euler_blast_wave_neuralnetwork_rayhesthaven.jl with mortars" begin
    @test_trixi_include(joinpath(EXAMPLES_DIR,
                                 "elixir_euler_blast_wave_neuralnetwork_rayhesthaven.jl"),
                        l2=[
                            0.016486406327766923,
                            0.03097329879894433,
                            0.03101012918167401,
                            0.15157175775429868,
                        ],
                        linf=[
                            0.27688647744873407,
                            0.5653724536715139,
                            0.565695523611447,
                            2.513047611639946,
                        ],
                        refinement_patches=((type = "box",
                                             coordinates_min = (-0.25, -0.25),
                                             coordinates_max = (0.25, 0.25)),
                                            (type = "box",
                                             coordinates_min = (-0.125, -0.125),
                                             coordinates_max = (0.125, 0.125))),
                        initial_refinement_level=4,
                        maxiters=5)
end

@trixi_testset "elixir_euler_blast_wave_neuralnetwork_cnn.jl" begin
    @test_trixi_include(joinpath(EXAMPLES_DIR,
                                 "elixir_euler_blast_wave_neuralnetwork_cnn.jl"),
                        l2=[
                            0.4795795496408325,
                            0.2125148972465021,
                            0.21311260934645868,
                            0.7033388737692883,
                        ],
                        linf=[
                            1.8295385992182336,
                            0.9687795218482794,
                            0.9616033072376108,
                            2.9513245978047133,
                        ],
                        initial_refinement_level=4,
                        maxiters=50,
                        rtol=1.0e-7)
end

@trixi_testset "elixir_euler_sedov_blast_wave_neuralnetwork_perssonperaire.jl" begin
    @test_trixi_include(joinpath(EXAMPLES_DIR,
                                 "elixir_euler_sedov_blast_wave_neuralnetwork_perssonperaire.jl"),
                        l2=[
                            0.0845430093623868,
                            0.09271459184623232,
                            0.09271459184623232,
                            0.4377291875101709,
                        ],
                        linf=[
                            1.3608553480069898,
                            1.6822884847136004,
                            1.6822884847135997,
                            4.2201475428867035,
                        ],
                        maxiters=30,
                        coverage_override=(maxiters = 6,))
end

@trixi_testset "elixir_euler_kelvin_helmholtz_instability_amr_neuralnetwork_perssonperaire.jl" begin
    @test_trixi_include(joinpath(EXAMPLES_DIR,
                                 "elixir_euler_kelvin_helmholtz_instability_amr_neuralnetwork_perssonperaire.jl"),
                        # This stuff is experimental and annoying to test. In the future, we plan
                        # to move it to another repository. Thus, we save developer time right now
                        # and do not run these tests anymore.
                        # l2   = [0.0009823702998067061, 0.004943231496200673, 0.0048604522073091815, 0.00496983530893294],
                        # linf = [0.00855717053383187, 0.02087422420794427, 0.017121993783086185, 0.02720703869972585],
                        maxiters=30,
                        coverage_override=(maxiters = 2,))
end
end

end # module
