@testset "ID Parsing Tests" begin
    @testset "Timestamp extraction" begin
        generator = SnowflakeIdGenerator(123)
        id = next_id(generator)
        
        timestamp_ms = SnowflakeId.timestamp(generator, id)
        @test timestamp_ms >= 0
        
        # Timestamp should be reasonable (not too far in past or future)
        current_time = time_millis(EpochClock())
        @test timestamp_ms <= current_time
        @test timestamp_ms >= current_time - 1000  # Within last second
    end
    
    @testset "Node ID extraction" begin
        node_id = 456
        generator = SnowflakeIdGenerator(node_id)
        id = next_id(generator)
        
        extracted_node_id = SnowflakeId.node_id(generator, id)
        @test extracted_node_id == node_id
    end
    
    @testset "Sequence extraction" begin
        generator = SnowflakeIdGenerator(789)
        id = next_id(generator)
        
        sequence = SnowflakeId.sequence(generator, id)
        @test sequence >= 0
        @test sequence <= SnowflakeId.max_sequence(generator)
    end
    
    @testset "Multiple ID parsing consistency" begin
        generator = SnowflakeIdGenerator(8, 14, 100, 0, EpochClock())
        
        ids = [next_id(generator) for _ in 1:10]
        
        for id in ids
            # Node ID should always be consistent
            @test SnowflakeId.node_id(generator, id) == 100
            
            # Sequence should be valid
            seq = SnowflakeId.sequence(generator, id)
            @test seq >= 0
            @test seq <= SnowflakeId.max_sequence(generator)
            
            # Timestamp should be reasonable
            ts = SnowflakeId.timestamp(generator, id)
            @test ts >= 0
        end
    end
    
    @testset "Parsing with custom bit allocation" begin
        # 5 bits for node (max 31), 17 bits for sequence (max 131071)
        node_id = 25
        generator = SnowflakeIdGenerator(5, 17, node_id, 0, EpochClock())
        
        id = next_id(generator)
        
        @test SnowflakeId.node_id(generator, id) == node_id
        @test SnowflakeId.sequence(generator, id) <= 131071
        @test SnowflakeId.max_node_id(generator) == 31
        @test SnowflakeId.max_sequence(generator) == 131071
    end
    
    @testset "Parsing with timestamp offset" begin
        offset = 1609459200000  # Jan 1, 2021 in milliseconds
        generator = SnowflakeIdGenerator(10, 12, 123, offset, EpochClock())
        
        id = next_id(generator)
        
        # The timestamp in the ID should be relative to the offset
        timestamp_part = SnowflakeId.timestamp(generator, id)
        @test timestamp_part >= 0
        
        # Node ID should still be correct
        @test SnowflakeId.node_id(generator, id) == 123
    end
    
    @testset "Parsing edge cases - maximum values" begin
        # Test with maximum possible values
        generator = SnowflakeIdGenerator(11, 11, 2047, 0, EpochClock())  # 11 bits = max 2047
        
        id = next_id(generator)
        
        @test SnowflakeId.node_id(generator, id) == 2047
        @test SnowflakeId.max_node_id(generator) == 2047
        @test SnowflakeId.max_sequence(generator) == 2047  # 11 bits for sequence too
    end
    
    @testset "Parsing consistency across different generators" begin
        # Create two generators with different configurations
        gen1 = SnowflakeIdGenerator(8, 14, 100, 0, EpochClock())
        gen2 = SnowflakeIdGenerator(12, 10, 200, 0, EpochClock())
        
        id1 = next_id(gen1)
        id2 = next_id(gen2)
        
        # Each generator should parse its own ID correctly
        @test SnowflakeId.node_id(gen1, id1) == 100
        @test SnowflakeId.node_id(gen2, id2) == 200
        
        # But parsing with wrong generator should give different results
        # (This tests that the bit layout matters)
        parsed_with_gen2 = SnowflakeId.node_id(gen2, id1)
        @test parsed_with_gen2 != 100  # Should not match because bit layout is different
    end
    
    @testset "Round-trip consistency" begin
        # Test that we can generate an ID and parse all its components correctly
        generator = SnowflakeIdGenerator(10, 12, 456, 0, EpochClock())
        
        # Record current time before generation
        before_time = time_millis(EpochClock())
        id = next_id(generator)
        after_time = time_millis(EpochClock())
        
        # Parse components
        timestamp_part = SnowflakeId.timestamp(generator, id)
        node_id_part = SnowflakeId.node_id(generator, id)
        sequence_part = SnowflakeId.sequence(generator, id)
        
        # Verify components
        @test node_id_part == 456
        @test sequence_part >= 0 && sequence_part <= SnowflakeId.max_sequence(generator)
        @test timestamp_part >= before_time && timestamp_part <= after_time
    end
end