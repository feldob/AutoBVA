@testset "Next basic types test (success)" begin

    @test false == next(true, +)
    @test true == next(false, -)

    @test 3 == next(2, +)
    @test 1 == next(2, -)
    @test 0 == next(2, -, 2)

    @test (0,3) == next((1,3), 1, -)
    @test (1,3,3) == next((1,2,3), 2, +)
    @test (1,0,3) == next((1,2,3), 2, -, 2)

    @test (0,"whatever") == next((1,"whatever"), 1, -)
    @test (0,nothing) == next((1,nothing), 1, -)
end
