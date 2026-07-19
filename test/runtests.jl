# Copyright 2014-2025 Real Logic Limited.
# Copyright 2025-2026 Rubus Technologies Inc.
# SPDX-License-Identifier: Apache-2.0
#
# Ported from Agrona and substantially modified for Julia.

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
