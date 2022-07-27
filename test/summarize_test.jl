@testset "Clustering from dataframe test" begin
    ctfs = ClusteringFeature[ sl_d, jc_d, jc_u ]
    setup = ClusteringSummarization("clustering_example.csv", "bytecount", ctfs)
    summary = summarize(setup)

    @test summary isa BoundarySummary
end