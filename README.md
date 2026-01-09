# SnowflakeId.jl

[![CI](https://github.com/DarrylGamroth/SnowflakeId.jl/actions/workflows/ci.yml/badge.svg)](https://github.com/DarrylGamroth/SnowflakeId.jl/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/DarrylGamroth/SnowflakeId.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/DarrylGamroth/SnowflakeId.jl)

## Snowflake ID Generator

A port of [Agrona's](https://github.com/aeron-io/agrona) implementation of Twitter's Snowflake ID generator for Julia

# Usage
```Julia
using SnowflakeId

# Use the node id 123
s = SnowflakeIdGenerator(123)

# Get the next id
id = next_id(s)
```

## Clock behavior
This generator detects clock regressions; if the system clock moves backwards relative to the last observed timestamp, `next_id` will throw an `ArgumentError`. Ensure your time source is monotonic (e.g., NTP configured properly) to avoid regressions.
