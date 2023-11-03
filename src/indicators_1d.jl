# By default, Julia/LLVM does not use fused multiply-add operations (FMAs).
# Since these FMAs can increase the performance of many numerical algorithms,
# we need to opt-in explicitly.
# See https://ranocha.de/blog/Optimizing_EC_Trixi for further details.
@muladd begin
#! format: noindent

# this method is used when the indicator is constructed as for shock-capturing volume integrals
# empty cache is default
function Trixi.create_cache(::Type{<:IndicatorNeuralNetwork},
                            equations::AbstractEquations{1}, basis::LobattoLegendreBasis)
    return NamedTuple()
end

# cache for NeuralNetworkPerssonPeraire-type indicator
function Trixi.create_cache(::Type{IndicatorNeuralNetwork{NeuralNetworkPerssonPeraire}},
                            equations::AbstractEquations{1}, basis::LobattoLegendreBasis)
    alpha = Vector{real(basis)}()
    alpha_tmp = similar(alpha)
    A = Array{real(basis), ndims(equations)}

    prototype = A(undef, nnodes(basis))
    indicator_threaded = [similar(prototype) for _ in 1:Threads.nthreads()]
    modal_threaded = [similar(prototype) for _ in 1:Threads.nthreads()]

    return (; alpha, alpha_tmp, indicator_threaded, modal_threaded)
end

# cache for NeuralNetworkRayHesthaven-type indicator
function Trixi.create_cache(::Type{IndicatorNeuralNetwork{NeuralNetworkRayHesthaven}},
                            equations::AbstractEquations{1}, basis::LobattoLegendreBasis)
    alpha = Vector{real(basis)}()
    alpha_tmp = similar(alpha)
    A = Array{real(basis), ndims(equations)}

    prototype = A(undef, nnodes(basis))
    indicator_threaded = [similar(prototype) for _ in 1:Threads.nthreads()]
    neighbor_ids = Vector{Int}(undef, 2)

    return (; alpha, alpha_tmp, indicator_threaded, neighbor_ids)
end

# this method is used when the indicator is constructed as for AMR
function Trixi.create_cache(typ::Type{<:IndicatorNeuralNetwork},
                            mesh, equations::AbstractEquations{1}, dg::DGSEM, cache)
    create_cache(typ, equations, dg.basis)
end

function (indicator_ann::IndicatorNeuralNetwork{NeuralNetworkPerssonPeraire})(u::AbstractArray{
                                                                                               <:Any,
                                                                                               3
                                                                                               },
                                                                              mesh,
                                                                              equations,
                                                                              dg::DGSEM,
                                                                              cache;
                                                                              kwargs...)
    @unpack indicator_type, alpha_max, alpha_min, alpha_smooth, alpha_continuous, alpha_amr, variable, network = indicator_ann

    @unpack alpha, alpha_tmp, indicator_threaded, modal_threaded = indicator_ann.cache
    # TODO: Taal refactor, when to `resize!` stuff changed possibly by AMR?
    #       Shall we implement `resize!(semi::AbstractSemidiscretization, new_size)`
    #       or just `resize!` whenever we call the relevant methods as we do now?
    resize!(alpha, nelements(dg, cache))
    if alpha_smooth
        resize!(alpha_tmp, nelements(dg, cache))
    end

    @threaded for element in eachelement(dg, cache)
        indicator = indicator_threaded[Threads.threadid()]
        modal = modal_threaded[Threads.threadid()]

        # Calculate indicator variables at Gauss-Lobatto nodes
        for i in eachnode(dg)
            u_local = get_node_vars(u, equations, dg, i, element)
            indicator[i] = indicator_ann.variable(u_local, equations)
        end

        # Convert to modal representation
        multiply_scalar_dimensionwise!(modal, dg.basis.inverse_vandermonde_legendre,
                                       indicator)

        # Calculate total energies for all modes, without highest, without two highest
        total_energy = zero(eltype(modal))
        for i in 1:nnodes(dg)
            total_energy += modal[i]^2
        end
        total_energy_clip1 = zero(eltype(modal))
        for i in 1:(nnodes(dg) - 1)
            total_energy_clip1 += modal[i]^2
        end
        total_energy_clip2 = zero(eltype(modal))
        for i in 1:(nnodes(dg) - 2)
            total_energy_clip2 += modal[i]^2
        end

        # Calculate energy in highest modes
        X1 = (total_energy - total_energy_clip1) / total_energy
        X2 = (total_energy_clip1 - total_energy_clip2) / total_energy_clip1

        # There are two versions of the network:
        # The first one only takes the highest energy modes as input, the second one also the number of
        # nodes. Automatically use the correct input by checking the number of inputs of the network.
        if size(params(network)[1], 2) == 2
            network_input = SVector(X1, X2)
        elseif size(params(network)[1], 2) == 3
            network_input = SVector(X1, X2, nnodes(dg))
        end

        # Scale input data
        network_input = network_input /
                        max(maximum(abs, network_input), one(eltype(network_input)))
        probability_troubled_cell = network(network_input)[1]

        # Compute indicator value
        alpha[element] = probability_to_indicator(probability_troubled_cell,
                                                  alpha_continuous,
                                                  alpha_amr, alpha_min, alpha_max)
    end

    if alpha_smooth
        apply_smoothing!(mesh, alpha, alpha_tmp, dg, cache)
    end

    return alpha
end

function (indicator_ann::IndicatorNeuralNetwork{NeuralNetworkRayHesthaven})(u::AbstractArray{
                                                                                             <:Any,
                                                                                             3
                                                                                             },
                                                                            mesh,
                                                                            equations,
                                                                            dg::DGSEM,
                                                                            cache;
                                                                            kwargs...)
    @unpack indicator_type, alpha_max, alpha_min, alpha_smooth, alpha_continuous, alpha_amr, variable, network = indicator_ann

    @unpack alpha, alpha_tmp, indicator_threaded, neighbor_ids = indicator_ann.cache
    # TODO: Taal refactor, when to `resize!` stuff changed possibly by AMR?
    #       Shall we implement `resize!(semi::AbstractSemidiscretization, new_size)`
    #       or just `resize!` whenever we call the relevant methods as we do now?
    resize!(alpha, nelements(dg, cache))
    if alpha_smooth
        resize!(alpha_tmp, nelements(dg, cache))
    end

    c2e = zeros(Int, length(mesh.tree))
    for element in eachelement(dg, cache)
        c2e[cache.elements.cell_ids[element]] = element
    end

    @threaded for element in eachelement(dg, cache)
        indicator = indicator_threaded[Threads.threadid()]
        cell_id = cache.elements.cell_ids[element]

        for direction in eachdirection(mesh.tree)
            if !has_any_neighbor(mesh.tree, cell_id, direction)
                neighbor_ids[direction] = element
                continue
            end
            if has_neighbor(mesh.tree, cell_id, direction)
                neighbor_cell_id = mesh.tree.neighbor_ids[direction, cell_id]
                if has_children(mesh.tree, neighbor_cell_id) # Cell has small neighbor
                    if direction == 1
                        neighbor_ids[direction] = c2e[mesh.tree.child_ids[2,
                                                                          neighbor_cell_id]]
                    else
                        neighbor_ids[direction] = c2e[mesh.tree.child_ids[1,
                                                                          neighbor_cell_id]]
                    end
                else # Cell has same refinement level neighbor
                    neighbor_ids[direction] = c2e[neighbor_cell_id]
                end
            else # Cell is small and has large neighbor
                parent_id = mesh.tree.parent_ids[cell_id]
                neighbor_cell_id = mesh.tree.neighbor_ids[direction, parent_id]
                neighbor_ids[direction] = c2e[neighbor_cell_id]
            end
        end

        # Calculate indicator variables at Gauss-Lobatto nodes
        for i in eachnode(dg)
            u_local = get_node_vars(u, equations, dg, i, element)
            indicator[i] = indicator_ann.variable(u_local, equations)
        end

        # Cell average and interface values of the cell
        X2 = sum(indicator) / nnodes(dg)
        X4 = indicator[1]
        X5 = indicator[end]

        # Calculate indicator variables from left neighboring cell at Gauss-Lobatto nodes
        for i in eachnode(dg)
            u_local = get_node_vars(u, equations, dg, i, neighbor_ids[1])
            indicator[i] = indicator_ann.variable(u_local, equations)
        end
        X1 = sum(indicator) / nnodes(dg)

        # Calculate indicator variables from right neighboring cell at Gauss-Lobatto nodes
        for i in eachnode(dg)
            u_local = get_node_vars(u, equations, dg, i, neighbor_ids[2])
            indicator[i] = indicator_ann.variable(u_local, equations)
        end
        X3 = sum(indicator) / nnodes(dg)
        network_input = SVector(X1, X2, X3, X4, X5)

        # Scale input data
        network_input = network_input /
                        max(maximum(abs, network_input), one(eltype(network_input)))
        probability_troubled_cell = network(network_input)[1]

        # Compute indicator value
        alpha[element] = probability_to_indicator(probability_troubled_cell,
                                                  alpha_continuous,
                                                  alpha_amr, alpha_min, alpha_max)
    end

    if alpha_smooth
        apply_smoothing!(mesh, alpha, alpha_tmp, dg, cache)
    end

    return alpha
end
end # @muladd
