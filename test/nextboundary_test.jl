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

@testset "next boundary tests" begin

    @test (1,13,1) == next(NextBoundary(datesut, OutputTypeDiff()), (1,12,1), 2, +)
    @test (1,13,1) == next(NextBoundary(datesut, OutputTypeDiff()), (1,1,1), 2, +)
    @test (1,1,1) == next(NextBoundary(datesut, OutputTypeDiff()), (1,-10,1), 2, +)

    for m in 1:12
        @test (1,13,1) == next(NextBoundary(datesut, OutputTypeDiff()), (1,m,1), 2, +)
        @test (1,0,1) == next(NextBoundary(datesut, OutputTypeDiff()), (1,m,1), 2, -)
    end

    @test (1,1,32) == next(NextBoundary(datesut, OutputTypeDiff()), (1,1,1), 3, +)
    @test (1,1,0) == next(NextBoundary(datesut, OutputTypeDiff()), (1,1,1), 3, -)

    @test (1,1,1) == next(NextBoundary(datesut, OutputTypeDiff()), (1,1,1), 1, +) # no success
    @test (1,1,1) == next(NextBoundary(datesut, OutputTypeDiff()), (1,1,1), 1, -) # no success
end

@testset "next boundary value diff tests" begin

    bcsut = SUT("bytecount (buggy)", (x::Integer) -> byte_count_bug(x))

    @test (10, ) == next(NextBoundary(bcsut, OutputDelta()), (3, ), 1, +)

    @test (10, ) == next(NextBoundary(bcsut, OutputDelta()), (3, ), 1, +)
    @test (-10, ) == next(NextBoundary(bcsut, OutputDelta()), (-3, ), 1, -)

    @test (1000, ) == next(NextBoundary(bcsut, OutputDelta()), (499, ), 1, +)
    @test (1000, ) == next(NextBoundary(bcsut, OutputDelta()), (950, ), 1, +)
    @test (1000, ) == next(NextBoundary(bcsut, OutputDelta()), (998, ), 1, +)

    @test (999_950, ) == next(NextBoundary(bcsut, OutputDelta()), (999_948, ), 1, +)
    @test (1_000_000, ) == next(NextBoundary(bcsut, OutputDelta()), (999_951, ), 1, +)
    @test (999_950, ) == next(NextBoundary(bcsut, OutputDelta()), (999_450, ), 1, +)

    @test (999, ) == next(NextBoundary(bcsut, OutputDelta()), (1049, ), 1, -)
    @test (999, ) == next(NextBoundary(bcsut, OutputDelta()), (1500, ), 1, -)
end
