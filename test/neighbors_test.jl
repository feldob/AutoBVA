
@testset "single dimensional neighborhood tests" begin

    @test (2,) == AutoBVA.singlechangecopy((1,), 1, 2)
    @test (2,2) == AutoBVA.singlechangecopy((1,2), 1, 2)
    @test (1,3,3) == AutoBVA.singlechangecopy((1,2,3), 2, 3)

    # edge case tests
    foreach(t -> (@test AutoBVA.edgecase((-), t)), typemin.([Bool, UInt8, UInt32]))
    foreach(t -> (@test AutoBVA.edgecase((+), t)), typemax.([Bool, UInt8, UInt32]))

    foreach(t -> (@test false == AutoBVA.edgecase((-), t)), [true, UInt8(3), UInt32(3)])
    foreach(t -> (@test false == AutoBVA.edgecase((+), t)), [false, UInt8(3), UInt32(3)])

    lns = LocalNeighborSearch(SUTProblem("test", (a::Bool,b::Int64,c::Int8) -> 0.0)) # no derivative
    @test false == AutoBVA.significant_neighborhood_boundariness(lns, (true, 1, UInt8(1)))
end