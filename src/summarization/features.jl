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
call(cf::ClusteringFeature, df::DataFrame, df_ref::DataFrame=df) = map(f -> f(df, df_ref), cf.ffunctions)

withindistance(m, df, ::Any=df) = m.(df[!, "output"], df[!, "n_output"])

function uniqueness(m, vector, vector_ref)
    if vector === vector_ref
        uniq_pw = pairwise(m, vector)
        return sum(uniq_pw, dims = 2)
    else #TODO improve impl!
        return map(v -> sum(v_ref -> m(v, v_ref), vector_ref), vector)
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
