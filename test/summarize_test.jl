@testset "Clustering from dataframe test" begin
    ctfs = ClusteringFeature[ sl_d, jc_d, jc_u ]
    setup = ClusteringSetup("ByteCount_all.csv", "bytecount", ctfs)
    summary = summarize(setup; wtd=false) # dont write to disk

    @test summary isa BoundarySummary
end

# TODO move to calling repo once working
@testset "screening test" begin
    setup = ClusteringSetup("ByteCount_all.csv", "bytecount", ALL_BVA_CLUSTERING_FEATURES; rounds=100, VGs=(VV,))
    screen(setup; wtd=false) # dont write to disk
end