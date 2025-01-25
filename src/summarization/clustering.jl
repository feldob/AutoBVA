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

function normalizerows(m::T, mins=minimum(m, dims=2)[:,1], maxs=maximum(m, dims=2)[:,1]) where {N <: Number, T <: AbstractMatrix{N}}
    span = (maxs .- mins) .+ 1e-20
    (m .- mins) ./ span
end

empty_clustering(df::DataFrame) = ClusteringResult(hcat(df, DataFrame(clustering = String[], cluster = Int[])), 0.0) # fake score

function feature_matrix(features::Vector{ClusteringFeature}, df::DataFrame, df_ref::DataFrame=df)
    x = Array{Float64}(undef, sum(nfeatures.(features)), nrow(df))

    "calculate feature matrix of size $(nrow(df))..." |> println

    feature_idx = 1
    for feature in features
        begin
            "$(id(feature))" |> println
            x[feature_idx:feature_idx+(nfeatures(feature)-1), :] = call(feature, df, df_ref)
            feature_idx += nfeatures(feature)
        end
    end
    " done." |> println

    return x
end

feature_matrix(setup::ClusteringSetup, df::DataFrame) = feature_matrix(setup.features, df)

# classify according to nearest cluster center
function regular_classify(df_n::DataFrame, df_o::DataFrame, cluster_centers, features, mins, maxs)::DataFrame
    df_s::DataFrame=nonincluded(df_n, df_o)
    df_s.clustering = fill!(Vector{String}(undef, nrow(df_s)), df_n[1,:clustering])   

    "classification (size overall $(nrow(df_o)), model $(nrow(df_n)), unassigned $(nrow(df_s)))):"|> println

    x = normalizerows(feature_matrix(features, df_s, df_n), mins, maxs)

    df_s.cluster = Vector{Int}(undef, nrow(df_s))
    # shortest euclidean distance to center "wins" and defines the cluster per boundary candidate in df_s
    for (idx, bc) in enumerate(eachcol(x))
        closeness_clusters = map(c -> euclidean(bc,c), eachcol(cluster_centers))
        df_s.cluster[idx] = argmin(closeness_clusters)
    end

    return vcat(df_n, df_s)
end

function bestclustering(setup::ClusteringSetup, x::AbstractMatrix{Float64}, dists=pairwise(Euclidean(), x, dims=2))

    winnerselect(m,f) = (map(x -> x ≥ maximum(f) * setup.qualvsdiv, f) |> findlast)

    cl_sizes = 2:min(size(x)[2], 16) # reasonable cluster size range
    best_RS = Vector(undef, length(cl_sizes))
    best_fitnesses = Vector{Float64}(undef, length(cl_sizes))

     for i in cl_sizes
        RS = Vector(undef, setup.rounds)
        fitnesses = Vector{Float64}(undef, setup.rounds)
        for j in 1:setup.rounds
            if j % 30 == 1
                "cl_size $i, round $j/$(setup.rounds)" |> println
            end
            R = kmeans(x, i; maxiter=200)

            a = assignments(R) # get the assignments of points to clusters
            #c = counts(R) # get the cluster sizes

            RS[j] = R
            fitnesses[j] = mean(silhouettes(a, dists))
        end

        winner_i = argmax(fitnesses)
        best_RS[i-1] = RS[winner_i]
        best_fitnesses[i-1] = fitnesses[winner_i]
        "best silhouette score: $(fitnesses[winner_i])" |> println
     end

     winner_overall = winnerselect(best_RS, best_fitnesses)
     #"silhouette scores per size (2:10):" |> println
     #best_fitnesses |> println

     return best_RS[winner_overall], best_fitnesses[winner_overall]
end

function diverse_subset(s::ClusteringSetup, df::DataFrame, matrix_size::Integer)

    df = df[sample(1:size(df,1), size(df,1), replace=false),:]  # shuffle content to maximize spread in each round

    churn = div(matrix_size, 10)                                # number of incrementally removed entries of low diversity

    df_res = df[1:matrix_size-churn, :]                         # dataframe to be incrementally improved

    "total size: $(nrow(df))" |> println
    df_remainder = df[matrix_size+1:end, :]                     # remaining entries to be tested to qualify
    while !isempty(df_remainder)
        "size res before merging: $(nrow(df_res))" |> println
        if nrow(df_remainder) < 2 * churn
            lastentry = nrow(df_remainder)
        else
            lastentry = min(churn, nrow(df_remainder))          # decide cutting point
        end

        "size remainder: $(nrow(df_remainder)))" |> println
        df_next = df_remainder[1:lastentry, :]                  # get next batch
        df_remainder = df_remainder[lastentry+1:end, :]         # remove selection from remainder

        df_res = vcat(df_res, df_next)                          # combine the existing and new ones
        x_norm = normalizerows(feature_matrix(s, df_res))       # calculate the diversity
        divsum = sum(x_norm, dims = 1)[1,:]                     # calculate overall diversity per entry as sum
        if nrow(df_res) > matrix_size
            lastentry = nrow(df_res) - matrix_size
        end
        idx = partialsortperm(divsum, 1:lastentry)              # lowest div candidate indices
        df_res = df_res[Not(idx),:]                             # remove entries that do not contribute to diversity
        "size res after merging: $(nrow(df_res))" |> println
    end

    "$(nrow(df_res)) ≤ $(matrix_size)" |> println
    @assert nrow(df_res) ≤ matrix_size
    return df_res
end

function nonincluded(df_n::DataFrame, df_o::DataFrame)

    df_n_plain = df_n[:, 1:end-3] # remove all clustering entries (back to original)

    model_rows = Set{DataFrameRow}()
    foreach(r -> push!(model_rows, r), eachrow(df_n_plain)) # set of existing ones for lookup

    df_o_plain = df_o[:,Not(:count)]
    remaining_rows = Set{Int}()
    foreach(e -> e[2] ∉ model_rows ? push!(remaining_rows, e[1]) : nothing, enumerate(eachrow(df_o_plain)))

    df_r = df_o[sort(collect(remaining_rows)),:]

    @assert nrow(df_r) + nrow(df_n) == nrow(df_o)

    return df_r
end

function divide_by_popularity(df::DataFrame, cutoff=10_000)
    if typeof(df.count[1]) <: AbstractString
        df.count = parse.(Int, df.count)
    end
    popularity = 0
    local df_multiples
    while true
        popularity += 1
        df_multiples = subset(df, :count => ByRow(>(popularity)))
        nrow(df_multiples) > cutoff || break
    end

    df_singles = subset(df, :count => ByRow(≤(popularity)))
    return df_multiples, df_singles, popularity
end

#TODO unlikely, but at times, the number of multiples may be larger than MAX_CLUSTERING_SIZE, how to handle!?
function regular_clustering(setup::ClusteringSetup, df_o::DataFrame, df::DataFrame, VG::ValidityGroup, max_cluster_size=MAX_CLUSTERING_SIZE)

    if nrow(df) > max_cluster_size # still too many
        # diversity based subselection
        df_m = diverse_subset(setup, df, max_cluster_size)

        # random subselection
        #df_m = df[sample(1:size(df,1), size(df,1), replace=false),:]
        #df_m = delete!(df_m, collect(max_cluster_size+1:nrow(df)))

        return regular_clustering(setup, df_o, df_m, VG, max_cluster_size)
    end

    df_n = DataFrame(df)
    df_n.clustering = fill!(Vector{String}(undef, nrow(df_n)), string(VG))

    x = feature_matrix(setup, df)
    x_norm = normalizerows(x)
    x_dists = pairwise(Euclidean(), x_norm, dims=2)

    "start clustering..." |> println
    bc, silh_score = bestclustering(setup, x_norm, x_dists)
    "...done. best size is $(sort(counts(bc))) with score: $silh_score" |> println

    df_n.cluster = assignments(bc)

    if nrow(df_n) != nrow(df_o) # if its reduced, classify all points
        x_mins, x_maxs = minimum(x, dims=2)[:,1], maximum(x, dims=2)[:,1]
        df_n = regular_classify(df_n, df_o, bc.centers, setup.features, x_mins, x_maxs)
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

    df_f = reduce_to_shortest_entries_per_same_output(df_s)

    classification_threshold = 2
    if nrow(df_f) < .01 * nrow(df_s)    # in case the results can be 1) reduced substantially clustering might not be necessary if SUT has only a manageable number of possible output combinations
        classification_threshold = 20
    end

    return nrow(df_f) < classification_threshold ? single_clustering(df_s, df_f, VG) : regular_clustering(setup, df_s, df_f, VG) # if too small for clustering, return indiv values as cluster
end

function write_silhouettescores(setup::ClusteringSetup, summary::BoundarySummary)
    silh_file = joinpath(setup.expdir, "silhouettes.csv")
    if !isfile(silh_file)
        open(silh_file, "w") do io
            write(io, "sutname,VV,VE,EE,VV_clusters,VE_clusters,EE_clusters,VV_points,VE_points,EE_points\n")
        end
    end

    open(silh_file, "a") do io
        scores, nclust, npoints = [], [], []

        for vg in instances(ValidityGroup)
            if contains(summary, vg)
                clustresult = result(summary, vg)
                push!(scores, silhouettescore(clustresult))
                push!(nclust, numclusters(clustresult))
                push!(npoints, nrow(clustresult.df))
            else
                push!(scores, missing)
                push!(nclust, missing)
                push!(npoints, missing)
            end
        end

        write(io, "$(setup.sutname)," * join(scores, ',') * "," * join(nclust, ',') * "," * join(npoints, ',') * "\n")
    end
end

function summarize(setup::ClusteringSetup; wtd::Bool=false)
    clust_path = joinpath(setup.expdir, setup.sutname * "_clustering.csv")

    if wtd && isfile(clust_path) #TODO this is an inconsistency, that returns a dataframe, while the output further below is a BoundarySummary. This only happens of the clustering file already exists (to safe time when processing large batches), but should still be streamlined.
       return CSV.read(clust_path, DataFrame)
    end

    summary = BoundarySummary{ClusteringResult}()
    for VG in setup.VGs
        singlesummary = clustering(setup, VG)
        add(summary, VG, singlesummary)
    end

    if wtd
        mkpath(setup.expdir)
        write_silhouettescores(setup, summary)
        #TODO write stats about quality - but here we only look at one sut - concatenate to a quality file!?
        CSV.write(clust_path, asone(summary))
    end

    return summary
end

function screen(s::ClusteringSetup; wtd::Bool=false)

    feature_perms = collect(combinations(s.features))
    feature_perms = filter(x -> length(x) > 1, feature_perms) # combine at least 2 features!

    df_scores = DataFrame(id = String[], score = Float32[], nclust = Int8[])

    expdir = joinpath(s.expdir, "clustering_screening")
    for feature_perm in feature_perms
        expid_s = join(id.(feature_perm), "-")
        expid_s |> println

        setup_perm = ClusteringSetup(s.df, "$(s.sutname)_$(expid_s)", feature_perm, expdir; rounds=s.rounds, VGs=s.VGs, qualvsdiv=s.qualvsdiv)
        summary = summarize(setup_perm; wtd)

        res = result(summary, s.VGs[1]) #TODO assumes that only one is run here.
        silhouette_score = silhouettescore(res)
        push!(df_scores, (expid_s, silhouette_score, numclusters(res)))
    end

    sort!(df_scores, [:score, :nclust])

    if wtd
        CSV.write(joinpath(expdir, "$(s.sutname)_clustering_scores.csv"), df_scores)
    end

    return summary
end