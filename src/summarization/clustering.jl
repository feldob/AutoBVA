struct ClusteringResult <: BoundaryResult
    df::DataFrame
    silhouettescore::Float64
end

clusterframes(r::ClusteringResult) = groupby(r.df, :cluster)
numclusters(r::ClusteringResult) = unique(r.df[!,:cluster]) |> length

function single_clustering(df_o::DataFrame, df::DataFrame, VG::ValidityGroup)
    df_n = DataFrame(df)
    df_n.clustering = fill!(Vector{String}(undef, nrow(df_n)), string(VG))
    df_n.cluster = 1:nrow(df_n)  # individual clusters

    if nrow(df_o) != nrow(df) # reduced, so classify all!
        df_o.clustering = fill!(Vector{String}(undef, nrow(df_o)), string(VG))

        d = Dict{String, Int}()
        foreach(r -> d[string(r[:output], r[:n_output])] = r.cluster, eachrow(df_n))
        df_o.cluster = map(r -> d[string(r[:output], r[:n_output])], eachrow(df_o))

        df_n = df_o
    end

    @assert nrow(df_n) == nrow(df_o)

    return ClusteringResult(df_n, 1.0) # fake score
end

function normalizecolumns(m)
    mins, maxs = minimum(m, dims=1), maximum(m, dims=1)
    span = (maxs .- mins) .+ 1e-20
    (m .- mins) ./ span
end

normalizerows(m) = normalizecolumns(m')'

empty_clustering(df::DataFrame) = ClusteringResult(hcat(df, DataFrame(clustering = String[], cluster = Int[])), 0.0) # fake score

function feature_matrix(setup::ClusteringSummarization, VG::ValidityGroup, df::DataFrame)
    _nfeatures = sum(nfeatures.(setup.features))
    x = zeros(_nfeatures, nrow(df))

    "calculate feature matrix..." |> print
    currentidx = 1
    for feature in setup.features
        res = call(feature, df)
        for idx in eachindex(res)
            x[currentidx,:] = res[idx]
            currentidx += 1
        end
    end
    " done." |> println

    return normalizerows(x)
end

# classify according to nearest cluster center
# FIXME currently does not use clfs as features, but is manually set. reason: rowwise calculation of feature is not suitable for uniqueness, and must therefore be adjusted to take the row as first param and the dataframe of existing data as second.
function regular_classify(df_n::DataFrame, df_o::DataFrame, df_s::DataFrame, x, cluster_centers, features)::DataFrame
    df_s.clustering = fill!(Vector{String}(undef, nrow(df_s)), df_n[1,:clustering])   
    df_s.cluster = fill!(Vector{Int}(undef, nrow(df_s)), 0) # empty init

    mins, maxs = minimum(x, dims=2), maximum(x, dims=2)
    span = (maxs .- mins) .+ 1e-20

    "classification:"|> println

    #_nfeatures = sum(nfeatures.(clfs))

    counter = 0
    for row in eachrow(df_s)
        #f = zeros(Float64, _nfeatures)
        # currentidx = 1
        # for clf in clfs
        #     res = call(clf, row)
        #     for idx in eachindex(res)
        #         f[currentidx] = res[idx]
        #         currentidx += 1
        #     end
        # end

        # features are selected according to screening: [ sl_d, jc_d, jc_u ] in that order
        f = zeros(Float64, 4)
        f[1] = Strlendist()(row[:output], row[:n_output])
        f[2] = StringDistances.Jaccard(2)(row[:output], row[:n_output])
        f[3] = uniqueness(StringDistances.Jaccard(2), row[:output], df_o[:, :output])
        f[4] = uniqueness(StringDistances.Jaccard(2), row[:n_output], df_o[:, :n_output])

        f = (f .- mins) ./ span # normalize

        cl_dists = [ euclidean(f, c) for c in eachcol(cluster_centers) ] # TODO bottleneck?
        row[:cluster] = argmin(cl_dists)

        counter += 1
        if counter % 100 == 0
            "$counter/$(nrow(df_s))" |> println
        end
    end

    return vcat(df_n, df_s)
end

highdiveval(m, f) = map(x -> x ≥ maximum(f) * 1, f) |> findlast

function bestclustering(setup::ClusteringSummarization, x::AbstractMatrix{Float64}, dists=pairwise(Euclidean(), x, dims=2))

    winnerselect = setup.highdiv ? highdiveval : (m,f)->argmax(f)

    cl_sizes = 2:10 # reasonable cluster size range
    best_RS = Vector(undef, length(cl_sizes))
    best_fitnesses = Vector(undef, length(cl_sizes))

     for i in cl_sizes
        RS = Vector(undef, setup.rounds)
        fitnesses = Vector{Float64}(undef, setup.rounds)
        for j in 1:setup.rounds
            if j % 30 == 1
                "cl_size $i, round $j/$(setup.rounds)" |> println
            end
            R = kmeans(x, i; maxiter=200)

            a = assignments(R) # get the assignments of points to clusters
            c = counts(R) # get the cluster sizes

            RS[j] = R
            fitnesses[j] = mean(silhouettes(a,c, dists))
        end

        winner_i = argmax(fitnesses)
        best_RS[i-1] = RS[winner_i]
        best_fitnesses[i-1] = fitnesses[winner_i]
     end

     winner_overall = winnerselect(best_RS, best_fitnesses)
     #"silhouette scores per size (2:10):" |> println
     #best_fitnesses |> println

     return best_RS[winner_overall], best_fitnesses[winner_overall]
end

function regular_clustering(setup::ClusteringSummarization, df_o::DataFrame, df::DataFrame, VG::ValidityGroup)

    if nrow(df) > MAX_CLUSTERING_SIZE    # still too many, do heuristic "Monte Carlo" Model
        df_m = diverse_subset(setup, df, MAX_CLUSTERING_SIZE)   # TODO copy
        return regular_clustering(setup, df_o, df_m, VG) # TODO copy
    end

    df_n = DataFrame(df)
    df_n.clustering = fill!(Vector{String}(undef, nrow(df_n)), string(VG))

    x_norm = feature_matrix(setup, VG, df)
    x_dists = pairwise(Euclidean(), x_norm, dims=2)

    "start clustering..." |> print
    bc, silh_score = bestclustering(setup, x_norm, x_dists)
    " done." |> println

    df_n.cluster = assignments(bc)

    if nrow(df_n) != nrow(df_o) # if its reduced, classify all points
        df_n = regular_classify(df_n, df_o, x_norm, bc.centers, setup.features)
    end

    @assert nrow(df_n) == nrow(df_o)

    return ClusteringResult(df_n, silh_score)
end

function clustering(setup::ClusteringSummarization,
                        VG::ValidityGroup)
    df_s = filtervaliditygroup(Val{VG}, setup.df)

    "number of BC's for $VG: $(nrow(df_s))" |> println

    if isempty(df_s)
        return empty_clustering(df_s) # extend by columns to match other clusterings
    end

    df_f = nrow(df_s) > MAX_CLUSTERING_SIZE ? reduce_to_shortest_entries_per_same_output(df_s) : df_s # if too many risks out of memory -> reduce outputs

    return nrow(df_f) < 10 ? single_clustering(df_s, df_f, VG) : regular_clustering(setup, df_s, df_f, VG) # if too small for clustering, return indiv values as cluster
end

function summarize(setup::ClusteringSummarization, tofile::Bool=false)
    summary = BoundarySummary{ClusteringResult}()
    for VG in setup.VGs
        singlesummary = clustering(setup, VG)
        add(summary, VG, singlesummary)
    end

    if tofile
        result_path = setup.expdir * "_clusterings"
        mkpath(result_path)
        CSV.write(joinpath(result_path, setup.sutname * "_clustering.csv"), asone(summary))
    end

    return summary
end
