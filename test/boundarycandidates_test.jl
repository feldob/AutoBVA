@testset "boundary candidate archive tests" begin

    bca = BoundaryCandidateArchive(myidentity_sut)

    @test myidentity_sut == sut(bca)

    @test 0 == size(bca)

    @test_throws MethodError add(bca, nothing)
    @test_throws MethodError add((bca, "oops",))

    add(bca, (Int8(1),))
    add(bca, (Int8(1),))
    add(bca, (true,))

    @test 2 == size(bca)    # same entry added three times, but different types

    add(bca, (Int8(2),))
    
    @test 3 == size(bca)
end