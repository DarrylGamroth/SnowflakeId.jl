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
