# By default, Julia/LLVM does not use fused multiply-add operations (FMAs).
# Since these FMAs can increase the performance of many numerical algorithms,
# we need to opt-in explicitly.
# See https://ranocha.de/blog/Optimizing_EC_Trixi for further details.
@muladd begin
#! format: noindent

"""
    IndicatorNeuralNetwork

Artificial neural network based indicator used for shock-capturing or AMR.
Depending on the indicator_type, different input values and corresponding trained networks are used.

`indicator_type = NeuralNetworkPerssonPeraire()`
- Input: The energies in lower modes as well as nnodes(dg).

`indicator_type = NeuralNetworkRayHesthaven()`
- 1d Input: Cell average of the cell and its neighboring cells as well as the interface values.
- 2d Input: Linear modal values of the cell and its neighboring cells.

- Ray, Hesthaven (2018)
  "An artificial neural network as a troubled-cell indicator"
  [doi:10.1016/j.jcp.2018.04.029](https://doi.org/10.1016/j.jcp.2018.04.029)
- Ray, Hesthaven (2019)
  "Detecting troubled-cells on two-dimensional unstructured grids using a neural network"
  [doi:10.1016/j.jcp.2019.07.043](https://doi.org/10.1016/j.jcp.2019.07.043)

`indicator_type = CNN (Only in 2d)`
- Based on convolutional neural network.
- 2d Input: Interpolation of the nodal values of the `indicator.variable` to the 4x4 LGL nodes.

If `alpha_continuous == true` the continuous network output for troubled cells (`alpha > 0.5`) is considered.
If the cells are good (`alpha < 0.5`), `alpha` is set to `0`.
If `alpha_continuous == false`, the blending factor is set to `alpha = 0` for good cells and
`alpha = 1` for troubled cells.

!!! warning "Experimental implementation"
    This is an experimental feature and may change in future releases.

"""
struct IndicatorNeuralNetwork{IndicatorType, RealT <: Real, Variable, Chain, Cache} <:
       AbstractIndicator
    indicator_type::IndicatorType
    alpha_max::RealT
    alpha_min::RealT
    alpha_smooth::Bool
    alpha_continuous::Bool
    alpha_amr::Bool
    variable::Variable
    network::Chain
    cache::Cache
end

# this method is used when the indicator is constructed as for shock-capturing volume integrals
function IndicatorNeuralNetwork(equations::AbstractEquations, basis;
                                indicator_type,
                                alpha_max = 0.5,
                                alpha_min = 0.001,
                                alpha_smooth = true,
                                alpha_continuous = true,
                                alpha_amr = false,
                                variable,
                                network)
    alpha_max, alpha_min = promote(alpha_max, alpha_min)
    IndicatorType = typeof(indicator_type)
    cache = create_cache(IndicatorNeuralNetwork{IndicatorType}, equations, basis)
    IndicatorNeuralNetwork{IndicatorType, typeof(alpha_max), typeof(variable),
                           typeof(network), typeof(cache)}(indicator_type, alpha_max,
                                                           alpha_min, alpha_smooth,
                                                           alpha_continuous, alpha_amr,
                                                           variable,
                                                           network, cache)
end

# this method is used when the indicator is constructed as for AMR
function IndicatorNeuralNetwork(semi::AbstractSemidiscretization;
                                indicator_type,
                                alpha_max = 0.5,
                                alpha_min = 0.001,
                                alpha_smooth = true,
                                alpha_continuous = true,
                                alpha_amr = true,
                                variable,
                                network)
    alpha_max, alpha_min = promote(alpha_max, alpha_min)
    IndicatorType = typeof(indicator_type)
    cache = create_cache(IndicatorNeuralNetwork{IndicatorType}, semi)
    IndicatorNeuralNetwork{IndicatorType, typeof(alpha_max), typeof(variable),
                           typeof(network), typeof(cache)}(indicator_type, alpha_max,
                                                           alpha_min, alpha_smooth,
                                                           alpha_continuous, alpha_amr,
                                                           variable,
                                                           network, cache)
end

function Base.show(io::IO, indicator::IndicatorNeuralNetwork)
    @nospecialize indicator # reduce precompilation time

    print(io, "IndicatorNeuralNetwork(")
    print(io, indicator.indicator_type)
    print(io, ", alpha_max=", indicator.alpha_max)
    print(io, ", alpha_min=", indicator.alpha_min)
    print(io, ", alpha_smooth=", indicator.alpha_smooth)
    print(io, ", alpha_continuous=", indicator.alpha_continuous)
    print(io, indicator.variable)
    print(io, ")")
end

function Base.show(io::IO, ::MIME"text/plain", indicator::IndicatorNeuralNetwork)
    @nospecialize indicator # reduce precompilation time

    if get(io, :compact, false)
        show(io, indicator)
    else
        setup = [
            "indicator type" => indicator.indicator_type,
            "max. α" => indicator.alpha_max,
            "min. α" => indicator.alpha_min,
            "smooth α" => (indicator.alpha_smooth ? "yes" : "no"),
            "continuous α" => (indicator.alpha_continuous ? "yes" : "no"),
            "indicator variable" => indicator.variable,
        ]
        summary_box(io, "IndicatorNeuralNetwork", setup)
    end
end

# Convert probability for troubled cell to indicator value for shockcapturing/AMR
@inline function probability_to_indicator(probability_troubled_cell, alpha_continuous,
                                          alpha_amr,
                                          alpha_min, alpha_max)
    # Initialize indicator to zero
    alpha_element = zero(probability_troubled_cell)

    if alpha_continuous && !alpha_amr
        # Set good cells to 0 and troubled cells to continuous value of the network prediction
        if probability_troubled_cell > 0.5
            alpha_element = probability_troubled_cell
        else
            alpha_element = zero(probability_troubled_cell)
        end

        # Take care of the case close to pure FV
        if alpha_element > 1 - alpha_min
            alpha_element = one(alpha_element)
        end

        # Scale the probability for a troubled cell (in [0,1]) to the maximum allowed alpha
        alpha_element *= alpha_max
    elseif !alpha_continuous && !alpha_amr
        # Set good cells to 0 and troubled cells to 1
        if probability_troubled_cell > 0.5
            alpha_element = alpha_max
        else
            alpha_element = zero(alpha_max)
        end
    elseif alpha_amr
        # The entire continuous output of the neural network is used for AMR
        alpha_element = probability_troubled_cell

        # Scale the probability for a troubled cell (in [0,1]) to the maximum allowed alpha
        alpha_element *= alpha_max
    end

    return alpha_element
end

"""
    NeuralNetworkPerssonPeraire

Indicator type for creating an `IndicatorNeuralNetwork` indicator.

!!! warning "Experimental implementation"
    This is an experimental feature and may change in future releases.

See also: [`IndicatorNeuralNetwork`](@ref)
"""
struct NeuralNetworkPerssonPeraire end

"""
    NeuralNetworkRayHesthaven

Indicator type for creating an `IndicatorNeuralNetwork` indicator.

!!! warning "Experimental implementation"
    This is an experimental feature and may change in future releases.

See also: [`IndicatorNeuralNetwork`](@ref)
"""
struct NeuralNetworkRayHesthaven end

"""
    NeuralNetworkCNN

Indicator type for creating an `IndicatorNeuralNetwork` indicator.

!!! warning "Experimental implementation"
    This is an experimental feature and may change in future releases.

See also: [`IndicatorNeuralNetwork`](@ref)
"""
struct NeuralNetworkCNN end
end # @muladd
