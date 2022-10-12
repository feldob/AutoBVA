@testset "Next basic types test (success)" begin

    @test false == apply(IntAdditionOperator(), true)
    @test true == apply(IntSubtractionOperator(), false)

    @test 3 == apply(IntAdditionOperator(), 2)
    @test 1 == apply(IntSubtractionOperator(), 2)
    @test 0 == apply(IntSubtractionOperator(), 2, 2)

    @test (0,3) == apply(IntSubtractionOperator(), (1,3), 1)
    @test (1,3,3) == apply(IntAdditionOperator(), (1,2,3), 2)
    @test (1,0,3) == apply(IntSubtractionOperator(), (1,2,3), 2, 2)

    @test (0,"whatever") == apply(IntSubtractionOperator(), (1,"whatever"), 1)
    @test (0,nothing) == apply(IntSubtractionOperator(), (1,nothing), 1)
end

@testset "apply boundary tests" begin

    @test (1,13,1) == apply(NextBoundary(datesut, OutputTypeDiff()), IntAdditionOperator(), (1,12,1), 2)
    @test (1,13,1) == apply(NextBoundary(datesut, OutputTypeDiff()), IntAdditionOperator(), (1,1,1), 2)
    @test (1,1,1) == apply(NextBoundary(datesut, OutputTypeDiff()), IntAdditionOperator(), (1,-10,1), 2)

    for m in 1:12
        @test (1,13,1) == apply(NextBoundary(datesut, OutputTypeDiff()), IntAdditionOperator(), (1,m,1), 2)
        @test (1,0,1) == apply(NextBoundary(datesut, OutputTypeDiff()), IntSubtractionOperator(), (1,m,1), 2)
    end

    @test (1,1,32) == apply(NextBoundary(datesut, OutputTypeDiff()), IntAdditionOperator(), (1,1,1), 3)
    @test (1,1,0) == apply(NextBoundary(datesut, OutputTypeDiff()), IntSubtractionOperator(), (1,1,1), 3)

    @test (1,1,1) == apply(NextBoundary(datesut, OutputTypeDiff()), IntAdditionOperator(), (1,1,1), 1) # no success
    @test (1,1,1) == apply(NextBoundary(datesut, OutputTypeDiff()), IntSubtractionOperator(), (1,1,1), 1) # no success
end

@testset "apply boundary value diff tests" begin

    @test (10, ) == apply(NextBoundary(bcsut, OutputDelta()), IntAdditionOperator(), (3, ), 1)

    @test (10, ) == apply(NextBoundary(bcsut, OutputDelta()), IntAdditionOperator(), (3, ), 1)
    @test (-10, ) == apply(NextBoundary(bcsut, OutputDelta()), IntSubtractionOperator(), (-3, ), 1)

    @test (1000, ) == apply(NextBoundary(bcsut, OutputDelta()), IntAdditionOperator(), (499, ), 1)
    @test (1000, ) == apply(NextBoundary(bcsut, OutputDelta()), IntAdditionOperator(), (950, ), 1)
    @test (1000, ) == apply(NextBoundary(bcsut, OutputDelta()), IntAdditionOperator(), (998, ), 1)

    @test (999_950, ) == apply(NextBoundary(bcsut, OutputDelta()), IntAdditionOperator(), (999_948, ), 1)
    @test (1_000_000, ) == apply(NextBoundary(bcsut, OutputDelta()), IntAdditionOperator(), (999_951, ), 1)
    @test (999_950, ) == apply(NextBoundary(bcsut, OutputDelta()), IntAdditionOperator(), (999_450, ), 1)

    @test (999, ) == apply(NextBoundary(bcsut, OutputDelta()), IntSubtractionOperator(), (1049, ), 1)
    @test (999, ) == apply(NextBoundary(bcsut, OutputDelta()), IntSubtractionOperator(), (1500, ), 1)
end
