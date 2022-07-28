@testset "Clustering from dataframe test" begin
    ctfs = ClusteringFeature[ sl_d, jc_d, jc_u ]
    setup = ClusteringSetup("clustering_example.csv", "bytecount", ctfs)
    summary = summarize(setup, false) # dont write to disk

    @test summary isa BoundarySummary
end

# TODO move to calling repo once working
@testset "screening test" begin
    setup = ClusteringSetup("clustering_example.csv", "bytecount", ALL_BVA_CLUSTERING_FEATURES; rounds=1, VGs=(VV,))
    screen(setup, true) # dont write to disk
end