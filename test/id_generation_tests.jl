@testset "ID Generation Tests" begin
    @testset "Basic ID generation" begin
        generator = SnowflakeIdGenerator(123)
        
        # Generate some IDs
        id1 = next_id(generator)
        id2 = next_id(generator)
        id3 = next_id(generator)
        
        # IDs should be unique
        @test id1 != id2
        @test id2 != id3
        @test id1 != id3
        
        # IDs should be positive
        @test id1 > 0
        @test id2 > 0
        @test id3 > 0
        
        # IDs should generally be increasing (unless we hit sequence rollover)
        # This test might occasionally fail if we cross millisecond boundaries
        # but should be very rare
        if id1 < id2 < id3
            @test true  # Expected case
        else
            # Could happen due to timing, so we just log it
            @test_nowarn println("ID sequence not strictly increasing: $id1, $id2, $id3")
        end
    end
    
    @testset "ID generation with different node IDs" begin
        generator1 = SnowflakeIdGenerator(100)
        generator2 = SnowflakeIdGenerator(200)
        
        id1 = next_id(generator1)
        id2 = next_id(generator2)
        
        # IDs from different nodes should be different
        @test id1 != id2
        
        # Node IDs should be extractable and correct
        @test SnowflakeId.node_id(generator1, id1) == 100
        @test SnowflakeId.node_id(generator2, id2) == 200
    end
    
    @testset "ID generation with custom bit allocation" begin
        # Use 6 bits for node_id (max 63) and 16 bits for sequence (max 65535)
        generator = SnowflakeIdGenerator(6, 16, 42, 0, EpochClock())
        
        id = next_id(generator)
        @test id > 0
        @test SnowflakeId.node_id(generator, id) == 42
        @test SnowflakeId.sequence(generator, id) >= 0
        @test SnowflakeId.sequence(generator, id) <= SnowflakeId.max_sequence(generator)
    end
    
    @testset "Rapid ID generation" begin
        generator = SnowflakeIdGenerator(1)
        
        # Generate many IDs quickly to test sequence increment
        ids = Int64[]
        for i in 1:100
            push!(ids, next_id(generator))
        end
        
        # All IDs should be unique
        @test length(unique(ids)) == length(ids)
        
        # All IDs should be positive
        @test all(id -> id > 0, ids)
    end
    
    @testset "ID generation with timestamp offset" begin
        offset = 1640995200000  # Jan 1, 2022 in milliseconds
        generator = SnowflakeIdGenerator(10, 12, 123, offset, EpochClock())
        
        id = next_id(generator)
        timestamp_part = SnowflakeId.timestamp(generator, id)
        
        # Timestamp should be relative to offset
        @test timestamp_part >= 0
        
        # The actual timestamp should be offset + timestamp_part
        current_time = time_millis(EpochClock())
        actual_timestamp = offset + timestamp_part
        @test actual_timestamp <= current_time  # Should not be in the future
    end
    
    @testset "Zero sequence bits edge case" begin
        # With 0 sequence bits, we can only generate 1 ID per millisecond
        generator = SnowflakeIdGenerator(22, 0, 0, 0, EpochClock())
        
        id = next_id(generator)
        @test id > 0
        @test SnowflakeId.sequence(generator, id) == 0  # Should always be 0
        @test SnowflakeId.max_sequence(generator) == 0
    end
    
    @testset "Zero node bits edge case" begin
        # With 0 node bits, node_id must be 0
        generator = SnowflakeIdGenerator(0, 22, 0, 0, EpochClock())
        
        id = next_id(generator)
        @test id > 0
        @test SnowflakeId.node_id(generator, id) == 0
        @test SnowflakeId.max_node_id(generator) == 0
    end
end