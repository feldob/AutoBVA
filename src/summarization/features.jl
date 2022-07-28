struct ClusteringFeature
    id::String
    ffunctions::Vector{Function}
    function ClusteringFeature(id, metric, ffunctions::Vector{Function})
        ffunctions_mapped = map(f -> (x) -> f(metric,x), ffunctions)
        return new(id, ffunctions_mapped)
    end
end

id(cf::ClusteringFeature) = cf.id
nfeatures(cf::ClusteringFeature) = length(cf.ffunctions)
call(cf::ClusteringFeature, df::DataFrame) = map(f -> f(df), cf.ffunctions)

withindistance(m, df) = m.(df[!, "output"], df[!, "n_output"])


function uniqueness(m, vector::AbstractVector{<:AbstractString})
    uniq_pw = pairwise(m, vector)
    sum(uniq_pw, dims = 2)
end

uniqueness_left(m, df) = uniqueness(m, df[:,"output"])
uniqueness_right(m, df) = uniqueness(m, df[:,"n_output"])

function uniqueness(m, v::AbstractString, vs::AbstractVector{<:AbstractString})
    return sum(x -> m(x,v), vs)
end

sl_d = ClusteringFeature("sl_d", Strlendist(), Function[withindistance])     # index 1, SELECTED
jc_d = ClusteringFeature("jc_d",StringDistances.Overlap(2), Function[withindistance]) # index 2, SELECTED
lv_d = ClusteringFeature("lv_d",NMD(2), Function[withindistance])

sl_u = ClusteringFeature("sl_u", Strlendist(), Function[uniqueness_left, uniqueness_right])
jc_u = ClusteringFeature("jc_u", StringDistances.Overlap(2), Function[uniqueness_left, uniqueness_right]) # index 5, SELECTED
lv_u = ClusteringFeature("lv_u", NMD(2), Function[uniqueness_left, uniqueness_right])

global const ALL_BVA_CLUSTERING_FEATURES = [ sl_d, jc_d, lv_d, sl_u, jc_u, lv_u ]
