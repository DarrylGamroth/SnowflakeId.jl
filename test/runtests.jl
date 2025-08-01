using Test
using SnowflakeId
using Clocks

@testset "SnowflakeId.jl Tests" begin
    include("constructor_tests.jl")
    include("id_generation_tests.jl")
    include("id_parsing_tests.jl")
    include("edge_case_tests.jl")
    include("concurrency_tests.jl")
end