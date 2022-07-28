struct ClusteringSetup <: BoundaryCandidateSummarization
    df::DataFrame
    sutname::AbstractString
    features::AbstractVector{<:ClusteringFeature}
    rounds::Integer
    expdir::AbstractString
    VGs::Tuple{Vararg{ValidityGroup}}
    qualvsdiv::Float64

    #TODO make sure to convert df into "String only".
    function ClusteringSetup(df::DataFrame, sutname, features, expdir=""; rounds=1, VGs=instances(ValidityGroup), qualvsdiv=1.0)
        new(df, sutname, features, rounds, expdir, VGs, qualvsdiv)
    end

    function ClusteringSetup(dffile::AbstractString, sutname, features; rounds=1, VGs=instances(ValidityGroup), qualvsdiv=1.0)
        expdir = dirname(abspath(dffile))
        expdir |> println
        ClusteringSetup(loadsummary(dffile), sutname, features, expdir; VGs, rounds, qualvsdiv)
    end
end

struct ClusteringResult <: BoundaryResult
    df::DataFrame
    silhouettescore::Float64
end

clusterframes(r::ClusteringResult) = groupby(r.df, :cluster)
numclusters(r::ClusteringResult) = unique(r.df[!,:cluster]) |> length
silhouettescore(r::ClusteringResult) = r.silhouettescore

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

function feature_matrix(features::Vector{ClusteringFeature}, df::DataFrame, df_ref::DataFrame=df)
    _nfeatures = sum(nfeatures.(features))
    x = zeros(_nfeatures, nrow(df))

    #TODO df might have to be cut into chunks to make this manageable (100 or 1000 or so)
    "calculate feature matrix..." |> print
    currentidx = 1
    for feature in features
        res = call(feature, df, df_ref)
        for idx in eachindex(res)
            x[currentidx,:] = res[idx]
            currentidx += 1
        end
    end
    " done." |> println

    #FIXME potential normalization error further down the line, when calculating the cluster belongingness in "classify"...
    # TODO possible solution is to add the extreme values for the dimensions up front as inputs to the feature-matrix calculation.
    return normalizerows(x)
end

feature_matrix(setup::ClusteringSetup, df::DataFrame) = feature_matrix(setup.features, df)

# classify according to nearest cluster center
function regular_classify(df_n::DataFrame, df_o::DataFrame, df_s::DataFrame, x, cluster_centers, features)::DataFrame
    df_s.clustering = fill!(Vector{String}(undef, nrow(df_s)), df_n[1,:clustering])   

    "classification:"|> println

    x = feature_matrix(features, df_s, df_o)

    # shortest euclidean distance to center "wins" and defines the cluster per boundary candidate in df_s
    df_s[:cluster] = map(bc -> argmin.(euclidean.(bc, cluster_centers)), eachcol(df_s))

    return vcat(df_n, df_s)
end

function bestclustering(setup::ClusteringSetup, x::AbstractMatrix{Float64}, dists=pairwise(Euclidean(), x, dims=2))

    winnerselect(m,f) = (map(x -> x ≥ maximum(f) * setup.qualvsdiv, f) |> findlast)

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

function diverse_subset(s::ClusteringSetup, df::DataFrame, matrix_size::Integer)

    df = df[sample(1:size(df,1), size(df,1), replace=false),:]  # shuffle content to maximize spread in each round

    churn = div(matrix_size, 10)   # number of incrementally removed entries of low diversity

    df_res = df[1:matrix_size-churn, :]  # dataframe to be incrementally improved

    "total size: $(nrow(df))" |> println
    df_remainder = df[matrix_size+1:end, :]    # remaining entries to be tested to qualify
    while !isempty(df_remainder)
        lastentry = min(churn, nrow(df_remainder))              # decide cutting point
        "size remainder: $(nrow(df_remainder)))" |> println
        df_next = df_remainder[1:lastentry, :]                  # get next batch
        df_remainder = df_remainder[lastentry+1:end, :]         # remove selection from remainder

        df_res = vcat(df_res, df_next)                          # combine the existing and new ones
        x_norm = feature_matrix(s.sutname, df_res)              # calculate the diversity
        divsum = sum(x_norm, dims = 2)[:,1]                     # calculate overall diversity per entry as sum
        idx = partialsortperm(divsum, 1:3)                      # lowest div candidate indices
        df_res = df_res[Not(idx),:]                             # remove entries that do not contribute to diversity
    end

    return df_res
end


function regular_clustering(setup::ClusteringSetup, df_o::DataFrame, df::DataFrame, VG::ValidityGroup)

    if nrow(df) > MAX_CLUSTERING_SIZE    # still too many, do heuristic "Monte Carlo" Model
        df_m = diverse_subset(setup, df, MAX_CLUSTERING_SIZE)
        return regular_clustering(setup, df_o, df_m, VG) # TODO copy
    end

    df_n = DataFrame(df)
    df_n.clustering = fill!(Vector{String}(undef, nrow(df_n)), string(VG))

    x_norm = feature_matrix(setup, df)
    x_dists = pairwise(Euclidean(), x_norm, dims=2)

    "start clustering..." |> println
    bc, silh_score = bestclustering(setup, x_norm, x_dists)
    "...done." |> println

    df_n.cluster = assignments(bc)

    if nrow(df_n) != nrow(df_o) # if its reduced, classify all points
        df_n = regular_classify(df_n, df_o, x_norm, bc.centers, setup.features)
    end

    @assert nrow(df_n) == nrow(df_o)

    return ClusteringResult(df_n, silh_score)
end

function clustering(setup::ClusteringSetup,
                        VG::ValidityGroup)
    df_s = filtervaliditygroup(Val{VG}, setup.df)

    "number of BC's for $VG: $(nrow(df_s))" |> println

    if isempty(df_s)
        return empty_clustering(df_s) # extend by columns to match other clusterings
    end

    df_f = nrow(df_s) > MAX_CLUSTERING_SIZE ? reduce_to_shortest_entries_per_same_output(df_s) : df_s # if too many risks out of memory -> reduce outputs

    return nrow(df_f) < 10 ? single_clustering(df_s, df_f, VG) : regular_clustering(setup, df_s, df_f, VG) # if too small for clustering, return indiv values as cluster
end

function summarize(setup::ClusteringSetup, tofile::Bool=false)
    summary = BoundarySummary{ClusteringResult}()
    for VG in setup.VGs
        singlesummary = clustering(setup, VG)
        add(summary, VG, singlesummary)
    end

    if tofile
        mkpath(setup.expdir)
        CSV.write(joinpath(setup.expdir, setup.sutname * "_clustering.csv"), asone(summary))
    end

    return summary
end

function screen(s::ClusteringSetup, tofile::Bool=false)

    feature_perms = collect(combinations(s.features))
    feature_perms = filter(x -> length(x) > 1, feature_perms) # combine at least 2 features!

    df_scores = DataFrame(id = String[], score = Float32[], nclust = Int8[])

    expdir = joinpath(s.expdir, "screening")
    for feature_perm in feature_perms
        expid_s = join(id.(feature_perm), "-")
        expid_s |> println

        setup_perm = ClusteringSetup(s.df, "$(s.sutname)_$(expid_s)", feature_perm, expdir; rounds=s.rounds, VGs=s.VGs, qualvsdiv=s.qualvsdiv)
        summary = summarize(setup_perm, tofile)

        res = result(summary, s.VGs[1]) #TODO assumes that only one is run here.
        silhouette_score = silhouettescore(res)
        push!(df_scores, (expid_s, silhouette_score, numclusters(res)))
    end

    sort!(df_scores, [:score, :nclust])

    if tofile
        CSV.write(joinpath(expdir, "$(s.sutname)_clustering_scores.csv"), df_scores)
    end

    return summary
end