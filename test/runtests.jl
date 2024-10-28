using Test

@time @testset "TrixiSmartShockFinder.jl tests" begin
    include("test_unit.jl")
    include("test_tree_1d_euler.jl")
    include("test_tree_2d_euler.jl")
end
