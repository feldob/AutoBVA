
@testset "Strlendist" begin
    @test 0 == evaluate(Strlendist(), "1", "2")
    @test 1 == evaluate(Strlendist(), "a","bb")

    # inputs that are not strings
    @test_throws MethodError evaluate(Strlendist(), 1, 2)
    @test_throws MethodError evaluate(Strlendist(), 1, "2")
    @test_throws MethodError evaluate(Strlendist(), "1", 2)

    # symmetry
    for i in 1:10
        rand1 = string(rand(Int))
        rand2 = string(rand(Int))
        @test evaluate(Strlendist(), rand1, rand2) == evaluate(Strlendist(), rand2, rand1)
    end

    # TODO add associativity/transitivity tests

end

@testset "ProgramDerivative" begin

    @test evaluate(ProgramDerivative(), "a", "a", (1, ), (1, )) |> isnan
    @test Inf == evaluate(ProgramDerivative(), "a", "aa", (1, ), (1, ))

    @test 1 == evaluate(ProgramDerivative(), "a", "aa", (1, ), (2, ))
    @test 1/2 == evaluate(ProgramDerivative(), "a", "aa", (1, ), (3, ))
    @test 1/3 == evaluate(ProgramDerivative(), "a", "aa", (1, ), (4, ))
    @test 1/4 == evaluate(ProgramDerivative(), "a", "aa", (1, ), (5, ))

    @test 0 == evaluate(ProgramDerivative(), "a", "a", (1, ), (2, ))
    @test 0 == evaluate(ProgramDerivative(), "a", "a", (1, ), (1000, ))
    
    # error if wrongly typed arguments
    @test_throws MethodError evaluate(ProgramDerivative(), 1, "a", (1, ), (2, ))
    @test_throws MethodError evaluate(ProgramDerivative(), "a", 1, (1, ), (2, ))
    @test_throws MethodError evaluate(ProgramDerivative(), "a", 1, (1, 2), (2, ))
    @test_throws MethodError evaluate(ProgramDerivative(), "a", 1, (), ())

    #@test_throws InexactError evaluate(ProgramDerivative(), "-40", "-20", (Int8(-40),), (Int8(-20),)) # problem with Int8 that previously threw an exception.
    @test 0.0 == evaluate(ProgramDerivative(), "-40", "-20", (Int64(-40),), (Int8(-20),)) # mitigation
end