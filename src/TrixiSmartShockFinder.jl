module TrixiSmartShockFinder

using MuladdMacro: @muladd
using Flux: params
using Trixi
using Trixi: AbstractIndicator, AbstractEquations, AbstractSemidiscretization, @threaded,
             summary_box, eachdirection, get_node_vars, multiply_scalar_dimensionwise!,
             apply_smoothing!, gauss_lobatto_nodes_weights, polynomial_interpolation_matrix,
             has_any_neighbor, has_neighbor, has_children, trixi_include

include("indicators.jl")
include("indicators_1d.jl")
include("indicators_2d.jl")

export IndicatorNeuralNetwork, NeuralNetworkPerssonPeraire, NeuralNetworkRayHesthaven,
       NeuralNetworkCNN
export trixi_include

end # module TrixiSmartShockFinder
