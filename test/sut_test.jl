@testset "sut constructor tests" begin

    @test SUT("double", (x::Int) -> 2x) isa SUT{Tuple{Int}}
    @test SUT("tuple", (x::Tuple) -> nothing) isa SUT{Tuple{Tuple}} # Tuple can be set as input

    @test "name" == SUT("name", (x) -> true) |> AutoBVA.name # verify correct name setting and retrieval

    # verify correct output of argtypes
    @test (Int,) == SUT("name", (x::Int) -> true) |> argtypes
    @test (Any,) == SUT("name", (x) -> true) |> argtypes
    @test (Bool, String, Any) == SUT("name", (a::Bool, b::String, c) -> nothing) |> argtypes

    @test_throws AssertionError SUT("noargs", () -> false) # at least one argument
    @test_throws AssertionError SUT("noargs", string) # system-wide unique name

    @test SUT("wrapped", (x::Int) -> string(x)) isa SUT{Tuple{Int}} # use of existing method, wrapping in lambda
end

@testset "sut call tests" begin

    # as defined in sut.jl: myidentity_sut = SUT("identity", (x::Int8) -> x)

    @test 1 == call(myidentity_sut, Int8(1))
    @test 1 == call(myidentity_sut, 1)
    @test 1 == call(myidentity_sut, (1,))
    @test 1 == call(myidentity_sut, true)

    # @test call(tuple_sut, (1,)) |> isnothing # FIXME at some point support tuples as inputs?!

    @test_throws MethodError call(myidentity_sut, "invalid")
    @test_throws InexactError call(myidentity_sut, 128) # too large input, cannot be converted from Int64 to Int8
end