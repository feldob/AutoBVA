@testset "CTS tests" begin

    @test in(Int8, compatibletypes(Int64))
    @test in(Bool, compatibletypes(Int8))
    @test 1 == compatibletypes(Bool) |> length

    @test in(Bool, cts_supportedtypes())
    @test !in(Any, cts_supportedtypes())
    @test !in(String, cts_supportedtypes())
end