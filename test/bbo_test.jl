#myidentity_sut2 = SUT("identity2", (x::Union{Int8, Bool}) -> x) # TODO union support not implemented yet

@testset "local neighbor search LNS test" begin

    params = ParamsDict(:Method => :lns,
                        :SamplingStrategy => [ UniformSampling(Int8) ],
                        :MaxTime => 1)
    res = bboptimize(SUTProblem(myidentity_sut, [ IntMutationOperators ]); params...)

    @test res.method_output isa BCDOutput

    ranked_candidates = rank_unique(res.method_output; output=true, incl_metric=true, filter=true, tosort=true)

    @test nrow(ranked_candidates) > 0
end

@testset "boundary crossing search BCS test" begin

    params = ParamsDict(:Method => :bcs,
                        :SamplingStrategy => [ BituniformSampling(Int8, true) ],
                        :MaxTime => 1)
    res = bboptimize(SUTProblem(myidentity_sut, [ IntMutationOperators ]); params...)

    @test res.method_output isa BCDOutput

    ranked_candidates = rank_unique(res.method_output; output=true, incl_metric=true, filter=true, tosort=true)

    @test nrow(ranked_candidates) > 0
end

@testset "unsigned issue with dataframe grouping" begin
    df = DataFrame(:a => Integer[UInt64(1), -1], :n_a => Integer[UInt64(2), -2])

    @test_throws InexactError DataFrames.groupby(df, [:a, :n_a])

    df = AutoBVA.avoidInexactErrorWhenGrouping(df, ["a"])

    DataFrames.groupby(df, [:a, :n_a])
    @test true
end

@testset "string search test" begin

    string_identity_sut = SUT("string identity", (x::String) -> x)

    params = ParamsDict(:Method => :lns,
                        :SamplingStrategy => [ ABCStringSampling() ],
                        :MaxTime => 1)
    res = bboptimize(SUTProblem(string_identity_sut, [ BasicStringMutationOperators ]); params...)

    params = ParamsDict(:Method => :bcs,
                        :SamplingStrategy => [ ABCStringSampling() ],
                        :MaxTime => 1)
    res = bboptimize(SUTProblem(string_identity_sut, [ BasicStringMutationOperators ]); params...)

    ranked_candidates = rank_unique(res.method_output; output=true, incl_metric=true, filter=true, tosort=true)

    @test nrow(ranked_candidates) > 0
end

@testset "array example test" begin

    array_append_sut = SUT("array append", (x::Vector, y::Vector) -> vcat(x, y))

    params = ParamsDict(:Method => :lns,
                        :SamplingStrategy => fill(SomeArraySampling(), 2),
                        :MaxTime => 1)
    res = bboptimize(SUTProblem(array_append_sut, fill(BasicArrayMutationOperators, 2)); params...)

    params = ParamsDict(:Method => :bcs,
                        :SamplingStrategy => fill(SomeArraySampling(), 2),
                        :MaxTime => 1)
    res = bboptimize(SUTProblem(array_append_sut, fill(BasicArrayMutationOperators, 2)); params...)

    ranked_candidates = rank_unique(res.method_output; output=true, incl_metric=true, filter=true, tosort=true)

    @test nrow(ranked_candidates) > 0
end