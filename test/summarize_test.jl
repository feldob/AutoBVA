@testset "Clustering from dataframe test" begin
    ctfs = ClusteringFeature[ sl_d, jc_d, jc_u ]
    df = loadsummary("clustering_example.csv")
    setup = ClusteringSummarization("exptest", df, "bytecount", ctfs)
    summarize(setup)
    @test true
end