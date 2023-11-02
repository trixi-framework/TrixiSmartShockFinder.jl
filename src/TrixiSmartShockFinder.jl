module TrixiSmartShockFinder

using MuladdMacro: @muladd
using Trixi
using Trixi: AbstractIndicator, AbstractEquations, AbstractSemidiscretization, @threaded

include("indicators.jl")
include("indicators_1d.jl")
include("indicators_2d.jl")

export IndicatorNeuralNetwork, NeuralNetworkPerssonPeraire, NeuralNetworkRayHesthaven,
       NeuralNetworkCNN

end # module TrixiSmartShockFinder
