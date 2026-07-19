# SnowflakeId.jl

[![CI](https://github.com/DarrylGamroth/SnowflakeId.jl/actions/workflows/ci.yml/badge.svg)](https://github.com/DarrylGamroth/SnowflakeId.jl/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/DarrylGamroth/SnowflakeId.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/DarrylGamroth/SnowflakeId.jl)
[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](LICENSE)

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

The generator uses `SystemEpochClock()` by default. A custom clock must subtype
`AbstractEpochClock` and implement `time_millis`.

This generator detects clock regressions; if the system clock moves backwards relative to the last observed timestamp, `next_id` will throw an `ArgumentError`. Ensure your time source is monotonic (e.g., NTP configured properly) to avoid regressions.

## Migrating from 0.1

SnowflakeId 0.2 requires Clocks 0.3. Replace `EpochClock()` with
`SystemEpochClock()`. Custom millisecond clock providers must subtype
`AbstractEpochClock` instead of `AbstractClock` and implement `time_millis`.

The Hwloc dependency has been removed; no application change is required.

## License

SnowflakeId.jl is licensed under the
[Apache License, Version 2.0](https://www.apache.org/licenses/LICENSE-2.0).
The Snowflake ID generator is adapted from
[Agrona](https://github.com/aeron-io/agrona), copyright Real Logic Limited.
See [LICENSE](LICENSE) and [NOTICE](NOTICE) for details.
