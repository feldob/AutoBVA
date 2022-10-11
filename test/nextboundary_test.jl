@testset "Next basic types test (success)" begin

    @test false == next(true, IntExtensionOperator)
    @test true == next(false, IntReductionOperator)

    @test 3 == next(2, IntExtensionOperator)
    @test 1 == next(2, IntReductionOperator)
    @test 0 == next(2, IntReductionOperator, 2)

    @test (0,3) == next((1,3), 1, IntReductionOperator)
    @test (1,3,3) == next((1,2,3), 2, IntExtensionOperator)
    @test (1,0,3) == next((1,2,3), 2, IntReductionOperator, 2)

    @test (0,"whatever") == next((1,"whatever"), 1, IntReductionOperator)
    @test (0,nothing) == next((1,nothing), 1, IntReductionOperator)
end

@testset "next boundary tests" begin

    @test (1,13,1) == next(NextBoundary(datesut, OutputTypeDiff()), (1,12,1), 2, IntExtensionOperator)
    @test (1,13,1) == next(NextBoundary(datesut, OutputTypeDiff()), (1,1,1), 2, IntExtensionOperator)
    @test (1,1,1) == next(NextBoundary(datesut, OutputTypeDiff()), (1,-10,1), 2, IntExtensionOperator)

    for m in 1:12
        @test (1,13,1) == next(NextBoundary(datesut, OutputTypeDiff()), (1,m,1), 2, IntExtensionOperator)
        @test (1,0,1) == next(NextBoundary(datesut, OutputTypeDiff()), (1,m,1), 2, IntReductionOperator)
    end

    @test (1,1,32) == next(NextBoundary(datesut, OutputTypeDiff()), (1,1,1), 3, IntExtensionOperator)
    @test (1,1,0) == next(NextBoundary(datesut, OutputTypeDiff()), (1,1,1), 3, IntReductionOperator)

    @test (1,1,1) == next(NextBoundary(datesut, OutputTypeDiff()), (1,1,1), 1, IntExtensionOperator) # no success
    @test (1,1,1) == next(NextBoundary(datesut, OutputTypeDiff()), (1,1,1), 1, IntReductionOperator) # no success
end

@testset "next boundary value diff tests" begin

    @test (10, ) == next(NextBoundary(bcsut, OutputDelta()), (3, ), 1, IntExtensionOperator)

    @test (10, ) == next(NextBoundary(bcsut, OutputDelta()), (3, ), 1, IntExtensionOperator)
    @test (-10, ) == next(NextBoundary(bcsut, OutputDelta()), (-3, ), 1, IntReductionOperator)

    @test (1000, ) == next(NextBoundary(bcsut, OutputDelta()), (499, ), 1, IntExtensionOperator)
    @test (1000, ) == next(NextBoundary(bcsut, OutputDelta()), (950, ), 1, IntExtensionOperator)
    @test (1000, ) == next(NextBoundary(bcsut, OutputDelta()), (998, ), 1, IntExtensionOperator)

    @test (999_950, ) == next(NextBoundary(bcsut, OutputDelta()), (999_948, ), 1, IntExtensionOperator)
    @test (1_000_000, ) == next(NextBoundary(bcsut, OutputDelta()), (999_951, ), 1, IntExtensionOperator)
    @test (999_950, ) == next(NextBoundary(bcsut, OutputDelta()), (999_450, ), 1, IntExtensionOperator)

    @test (999, ) == next(NextBoundary(bcsut, OutputDelta()), (1049, ), 1, IntReductionOperator)
    @test (999, ) == next(NextBoundary(bcsut, OutputDelta()), (1500, ), 1, IntReductionOperator)
end
