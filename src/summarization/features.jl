struct ClusteringFeature
    id::String
    ffunctions::Vector{Function}
    function ClusteringFeature(id, metric, ffunctions::Vector{Function})
        ffunctions_mapped = map(f -> (x,y=x) -> f(metric,x,y), ffunctions)
        return new(id, ffunctions_mapped)
    end
end

id(cf::ClusteringFeature) = cf.id
nfeatures(cf::ClusteringFeature) = length(cf.ffunctions)
function call(cf::ClusteringFeature, df::DataFrame, df_ref::DataFrame=df)
    x = Array{Float64}(undef, nfeatures(cf), nrow(df))
    for (idx, f) in enumerate(cf.ffunctions)
        x[idx, :] = f(df, df_ref)
    end
    return x
end

withindistance(m, df, ::Any=df) = m.(df[!, "output"], df[!, "n_output"])

function uniqueness_stable(m, vector, vector_ref)
    "stable calculation:" |> println
    currentperc = 0
    "$currentperc%" |> print
    x = Vector{Float64}(undef, length(vector))
    for (idx, v) in enumerate(vector)
        x[idx] = sum(pairwise(m, [v], vector_ref))
        nextpercent = trunc(Int64, idx/length(vector)*100)
        if nextpercent > currentperc
            currentperc = nextpercent
            print("\r")
            print("$currentperc%")
        end
    end
    println()
    return x
end

function uniqueness_fast(m, vector, vector_ref)
    uniq_pw = pairwise(m, vector, vector_ref)
    return sum(uniq_pw, dims = 2)
end

#not fastest, but memory efficient solution (more robust)
function uniqueness(m, vector, vector_ref)
    # only if small, go with fast solution
    if length(vector) * length(vector_ref) > 20_000_000
        return uniqueness_stable(m, vector, vector_ref)
    else
        return uniqueness_fast(m, vector, vector_ref)
    end

end

uniqueness_left(m, df, df_ref::Any=df) = uniqueness(m, df[!,"output"], df_ref[!,"output"])
uniqueness_right(m, df, df_ref::Any=df) = uniqueness(m, df[!,"n_output"], df_ref[!,"n_output"])

sl_d = ClusteringFeature("sl_d", Strlendist(), Function[withindistance])
jc_d = ClusteringFeature("jc_d",StringDistances.Overlap(2), Function[withindistance])
lv_d = ClusteringFeature("lv_d",NMD(2), Function[withindistance])

sl_u = ClusteringFeature("sl_u", Strlendist(), Function[uniqueness_left, uniqueness_right])
jc_u = ClusteringFeature("jc_u", StringDistances.Overlap(2), Function[uniqueness_left, uniqueness_right])
lv_u = ClusteringFeature("lv_u", NMD(2), Function[uniqueness_left, uniqueness_right])

global const ALL_BVA_CLUSTERING_FEATURES = [ sl_d, jc_d, lv_d, sl_u, jc_u, lv_u ]
