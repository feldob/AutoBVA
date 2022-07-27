@testset "Clustering from dataframe test" begin
    ctfs = ClusteringFeature[ sl_d, jc_d, jc_u ]
    setup = ClusteringSummarization("clustering_example.csv", "bytecount", ctfs)
    summary = summarize(setup, false)

    @test summary isa BoundarySummary
end

# TODO move to calling repo once working
@testset "screening test" begin
    setup = ClusteringSummarization("clustering_example.csv", "bytecount", ClusteringFeature[], 1, (VV,), true)
    screen(setup, false)
end