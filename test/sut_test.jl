@testset "sut constructor tests" begin

    @test SUT((x::Int) -> 2x) isa SUT{Tuple{Int}}

    @test "name1" == SUT((x) -> true, "name1") |> AutoBVA.name # verify correct name setting and retrieval

    # verify correct output of argtypes
    @test (Int,) == SUT((x::Int) -> true) |> argtypes
    @test (Any,) == SUT((x) -> true) |> argtypes
    @test (Bool, String, Any) == SUT((a::Bool, b::String, c) -> nothing) |> argtypes

    @test SUT((x::Int) -> string(x)) isa SUT{Tuple{Int}} # use of existing method, wrapping in lambda
end

@testset "sut call tests" begin

    # as defined in sut.jl: myidentity_sut = SUT((x::Int8) -> x)

    @test call(myidentity_sut, Int8(1)) isa SUTOutput
    @test 1 == call(myidentity_sut, Int8(1)) |> value
    @test valid::OutputType == call(myidentity_sut, Int8(1)) |> outputtype
    @test 1 == call(myidentity_sut, 1) |> value
    @test 1 == call(myidentity_sut, (1,)) |> value
    @test 1 == call(myidentity_sut, true) |> value

    # @test call(tuple_sut, (1,)) |> isnothing # FIXME at some point support tuples as inputs?!

    @test_throws MethodError call(myidentity_sut, "invalid")
    @test_throws InexactError call(myidentity_sut, 128) # too large input, cannot be converted from Int64 to Int8
end

@testset "sut with String param" begin

    doublestringsut = SUT((x::String) -> x * " " * x, "double string")
    @test doublestringsut isa SUT{Tuple{String}}
    @test "test test"== stringified(call(doublestringsut, "test"))
end

@testset "sut with String param passed explicitly as argtyes" begin

    doublestringsut = SUT((x) -> x * " " * x, "double string 2", (String,))
    @test doublestringsut isa SUT{Tuple{String}}
    @test "test test"== stringified(call(doublestringsut, "test"))
end