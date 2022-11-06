@testset "sut constructor tests" begin

    @test SUT("double", (x::Int) -> 2x) isa SUT{Tuple{Int}}

    @test "name1" == SUT("name1", (x) -> true) |> AutoBVA.name # verify correct name setting and retrieval

    # verify correct output of argtypes
    @test (Int,) == SUT("name2", (x::Int) -> true) |> argtypes
    @test (Any,) == SUT("name3", (x) -> true) |> argtypes
    @test (Bool, String, Any) == SUT("name4", (a::Bool, b::String, c) -> nothing) |> argtypes

    @test_throws AssertionError SUT("noargs1", () -> false) # at least one argument
    @test_throws AssertionError SUT("noargs2", string) # system-wide unique name

    @test SUT("wrapped", (x::Int) -> string(x)) isa SUT{Tuple{Int}} # use of existing method, wrapping in lambda
end

@testset "sut call tests" begin

    # as defined in sut.jl: myidentity_sut = SUT("myidentity", (x::Int8) -> x)

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

    doublestringsut = SUT("double string", (x::String) -> x * " " * x)
    @test doublestringsut isa SUT{Tuple{String}}
    @test "test test"== stringified(call(doublestringsut, "test"))
end

@testset "sut with String param passed explicitly as argtyes" begin

    doublestringsut = SUT("double string 2", (x) -> x * " " * x, (String,))
    @test doublestringsut isa SUT{Tuple{String}}
    @test "test test"== stringified(call(doublestringsut, "test"))
end