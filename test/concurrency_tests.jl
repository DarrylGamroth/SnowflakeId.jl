@testset "Concurrency Tests" begin
    @testset "Thread safety - basic" begin
        generator = SnowflakeIdGenerator(123)
        
        # Generate IDs from multiple tasks concurrently
        tasks = []
        results = Channel{Int64}(1000)
        
        # Create multiple tasks generating IDs
        for i in 1:10
            task = @async begin
                local_ids = Int64[]
                for j in 1:50
                    id = next_id(generator)
                    push!(local_ids, id)
                end
                for id in local_ids
                    put!(results, id)
                end
            end
            push!(tasks, task)
        end
        
        # Wait for all tasks to complete
        for task in tasks
            wait(task)
        end
        close(results)
        
        # Collect all generated IDs
        all_ids = Int64[]
        while isready(results)
            push!(all_ids, take!(results))
        end
        
        # All IDs should be unique
        @test length(unique(all_ids)) == length(all_ids)
        
        # All IDs should be positive
        @test all(id -> id > 0, all_ids)
        
        # All should have the same node ID
        for id in all_ids
            @test SnowflakeId.node_id(generator, id) == 123
        end
    end
    
    @testset "Thread safety - high contention" begin
        generator = SnowflakeIdGenerator(456)
        
        # Create high contention by having many tasks generate IDs simultaneously
        num_tasks = 20
        ids_per_task = 100
        all_ids = Vector{Int64}()
        lock = Threads.SpinLock()
        
        tasks = []
        for i in 1:num_tasks
            task = @async begin
                local_ids = Int64[]
                for j in 1:ids_per_task
                    id = next_id(generator)
                    push!(local_ids, id)
                end
                
                # Safely add to global collection
                Threads.lock(lock) do
                    append!(all_ids, local_ids)
                end
            end
            push!(tasks, task)
        end
        
        # Wait for all tasks
        for task in tasks
            wait(task)
        end
        
        # Verify results
        expected_total = num_tasks * ids_per_task
        @test length(all_ids) == expected_total
        @test length(unique(all_ids)) == expected_total  # All unique
        
        # All should be positive and have correct node ID
        @test all(id -> id > 0, all_ids)
        @test all(id -> SnowflakeId.node_id(generator, id) == 456, all_ids)
    end
    
    @testset "Multiple generators concurrency" begin
        # Test multiple generators running concurrently
        generators = [SnowflakeIdGenerator(i) for i in 1:5]
        
        all_ids = Vector{Int64}()
        lock = Threads.SpinLock()
        
        tasks = []
        for (i, gen) in enumerate(generators)
            task = @async begin
                local_ids = Int64[]
                for j in 1:100
                    id = next_id(gen)
                    push!(local_ids, id)
                end
                
                Threads.lock(lock) do
                    append!(all_ids, local_ids)
                end
                
                # Verify all IDs from this generator have correct node ID
                for id in local_ids
                    @test SnowflakeId.node_id(gen, id) == i
                end
            end
            push!(tasks, task)
        end
        
        # Wait for completion
        for task in tasks
            wait(task)
        end
        
        # All IDs should be unique across all generators
        @test length(unique(all_ids)) == length(all_ids)
        @test length(all_ids) == 500  # 5 generators × 100 IDs each
    end
    
    @testset "Sequence exhaustion under load" begin
        # Create a generator with very few sequence bits to force sequence exhaustion
        generator = SnowflakeIdGenerator(20, 2, 1, 0, EpochClock())  # Only 2 sequence bits (max 3)
        
        # Try to generate many IDs rapidly
        ids = Int64[]
        num_attempts = 100
        
        # This should work even with sequence exhaustion because the generator
        # will wait for the next millisecond when sequence is exhausted
        for i in 1:num_attempts
            id = next_id(generator)
            push!(ids, id)
        end
        
        # All IDs should be unique
        @test length(unique(ids)) == length(ids)
        
        # All should have correct node ID
        for id in ids
            @test SnowflakeId.node_id(generator, id) == 1
        end
        
        # Sequences should all be valid (0-3 for 2 bits)
        for id in ids
            seq = SnowflakeId.sequence(generator, id)
            @test seq >= 0
            @test seq <= 3
        end
    end
    
    @testset "Atomic operations correctness" begin
        generator = SnowflakeIdGenerator(789)
        
        # Test that the atomic operations maintain consistency
        # by generating IDs under contention and verifying properties
        
        results = Channel{Tuple{Int64, Int64, Int64}}(2000)  # (id, timestamp, sequence)
        
        tasks = []
        for i in 1:10
            task = @async begin
                for j in 1:100
                    id = next_id(generator)
                    ts = SnowflakeId.timestamp(generator, id)
                    seq = SnowflakeId.sequence(generator, id)
                    put!(results, (id, ts, seq))
                end
            end
            push!(tasks, task)
        end
        
        # Wait for completion
        for task in tasks
            wait(task)
        end
        close(results)
        
        # Collect results
        all_results = Tuple{Int64, Int64, Int64}[]
        while isready(results)
            push!(all_results, take!(results))
        end
        
        # Sort by ID to analyze sequence
        sort!(all_results, by = x -> x[1])
        
        # All IDs should be unique
        ids = [r[1] for r in all_results]
        @test length(unique(ids)) == length(ids)
        
        # For IDs with the same timestamp, sequences should be different
        timestamp_groups = Dict{Int64, Vector{Int64}}()
        for (id, ts, seq) in all_results
            if !haskey(timestamp_groups, ts)
                timestamp_groups[ts] = Int64[]
            end
            push!(timestamp_groups[ts], seq)
        end
        
        # Within each timestamp, all sequences should be unique
        for (ts, sequences) in timestamp_groups
            @test length(unique(sequences)) == length(sequences)
        end
    end
    
    @testset "Performance under concurrency" begin
        generator = SnowflakeIdGenerator(999)
        
        # Measure performance under concurrent load
        start_time = time()
        
        num_tasks = Threads.nthreads()
        ids_per_task = 1000
        total_expected = num_tasks * ids_per_task
        
        all_ids = Vector{Int64}()
        lock = Threads.SpinLock()
        
        tasks = []
        for i in 1:num_tasks
            task = @async begin
                local_ids = Int64[]
                for j in 1:ids_per_task
                    id = next_id(generator)
                    push!(local_ids, id)
                end
                
                Threads.lock(lock) do
                    append!(all_ids, local_ids)
                end
            end
            push!(tasks, task)
        end
        
        for task in tasks
            wait(task)
        end
        
        end_time = time()
        duration = end_time - start_time
        
        # Verify correctness
        @test length(all_ids) == total_expected
        @test length(unique(all_ids)) == total_expected
        
        # Performance should be reasonable (this is just a sanity check)
        ids_per_second = total_expected / duration
        @test ids_per_second > 1000  # Should generate at least 1000 IDs per second
        
        println("Generated $total_expected unique IDs in $(round(duration, digits=3))s ($(round(ids_per_second, digits=0)) IDs/sec)")
    end
end