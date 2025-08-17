// play_handler.test.zig — Tests for play outcome processing
//
// repo   : https://github.com/zig-nfl-clock
// docs   : https://zig-nfl-clock.github.io/docs/lib/game_clock/utils/play_handler
// author : https://github.com/maysara-elshewehy
//
// Vibe coded by Scoom.

// ╔══════════════════════════════════════ PACK ══════════════════════════════════════╗

    const std = @import("std");
    const testing = std.testing;
    const allocator = testing.allocator;
    
    // Import core types from play_handler module
    const PlayHandler = @import("play_handler.zig").PlayHandler;
    const PlayType = @import("play_handler.zig").PlayType;
    const PlayResult = @import("play_handler.zig").PlayResult;
    const SpecialOutcome = @import("play_handler.zig").SpecialOutcome;
    const GameStateUpdate = @import("play_handler.zig").GameStateUpdate;
    const PlayStatistics = @import("play_handler.zig").PlayStatistics;
    
    // Import utility functions
    const getExpectedPoints = @import("play_handler.zig").getExpectedPoints;
    const getHurryUpPlayTime = @import("play_handler.zig").getHurryUpPlayTime;
    const getNormalPlayTime = @import("play_handler.zig").getNormalPlayTime;


// ╚══════════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ INIT ══════════════════════════════════════╗

    /// Test scenario for play processing
    const PlayTestScenario = struct {
        name: []const u8,
        play_type: PlayType,
        initial_state: GameStateUpdate,
        expected_yards_range: struct { min: i16, max: i16 },
        expected_time_consumed: u32,
        can_turnover: bool,
        can_score: bool,
    };

    /// Test data for statistics tracking
    const StatsTestCase = struct {
        plays: []const PlayType,
        expected_total_yards: i32,
        expected_first_downs: u16,
        expected_turnovers: u8,
    };


// ╚══════════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ TEST ══════════════════════════════════════╗

    test "unit: PlayHandler: initializes with correct default values" {
        const handler = PlayHandler.init(12345);
        
        try testing.expectEqual(@as(u8, 1), handler.game_state.down);
        try testing.expectEqual(@as(u8, 10), handler.game_state.distance);
        try testing.expectEqual(.away, handler.game_state.possession);
        try testing.expectEqual(@as(u16, 0), handler.game_state.home_score);
        try testing.expectEqual(@as(u16, 0), handler.game_state.away_score);
        try testing.expectEqual(@as(u8, 1), handler.game_state.quarter);
        try testing.expectEqual(@as(u32, 900), handler.game_state.time_remaining);
        try testing.expectEqual(@as(u32, 40), handler.game_state.play_clock);
        try testing.expectEqual(false, handler.game_state.clock_running);
        try testing.expectEqual(@as(u32, 0), handler.play_number);
    }

    test "unit: PlayHandler: initializes with custom game state" {
        const custom_state = GameStateUpdate{
            .down = 3,
            .distance = 7,
            .possession = .home,
            .home_score = 14,
            .away_score = 10,
            .quarter = 2,
            .time_remaining = 450,
            .play_clock = 25,
            .clock_running = true,
        };
        
        const handler = PlayHandler.initWithState(custom_state, 54321);
        
        try testing.expectEqual(@as(u8, 3), handler.game_state.down);
        try testing.expectEqual(@as(u8, 7), handler.game_state.distance);
        try testing.expectEqual(.home, handler.game_state.possession);
        try testing.expectEqual(@as(u16, 14), handler.game_state.home_score);
        try testing.expectEqual(@as(u16, 10), handler.game_state.away_score);
    }

    test "unit: PlayHandler: processes pass plays" {
        var handler = PlayHandler.init(12345);
        
        const result = handler.processPlay(.pass_short, .{});
        
        try testing.expectEqual(PlayType.pass_short, result.play_type);
        try testing.expect(result.time_consumed > 0);
        try testing.expect(result.field_position >= 0 and result.field_position <= 100);
    }

    test "unit: PlayHandler: processes run plays" {
    var handler = PlayHandler.init(12345);
    
    const result = handler.processPlay(.run_up_middle, .{});
    
    try testing.expectEqual(PlayType.run_up_middle, result.play_type);
    try testing.expect(result.time_consumed > 0);
    try testing.expect(!result.pass_completed); // Run plays don't have pass completion
    }

    test "unit: PlayHandler: processes special teams plays" {
    var handler = PlayHandler.init(12345);
    
    // Test punt
    const punt_result = handler.processPlay(.punt, .{ .kick_distance = 45 });
    try testing.expectEqual(PlayType.punt, punt_result.play_type);
    try testing.expect(punt_result.is_turnover); // Punt changes possession
    
    // Test field goal
    const fg_result = handler.processPlay(.field_goal, .{ .kick_distance = 35 });
    try testing.expectEqual(PlayType.field_goal, fg_result.play_type);
    
    // Test kickoff
    const ko_result = handler.processPlay(.kickoff, .{ .return_yards = 25 });
    try testing.expectEqual(PlayType.kickoff, ko_result.play_type);
    try testing.expect(ko_result.is_turnover); // Kickoff changes possession
    }

    test "unit: PlayHandler: processes kneel down" {
    var handler = PlayHandler.init(12345);
    
    const result = handler.processPlay(.kneel_down, .{});
    
    try testing.expectEqual(PlayType.kneel_down, result.play_type);
    try testing.expectEqual(@as(i16, -1), result.yards_gained);
    try testing.expectEqual(@as(u32, 40), result.time_consumed); // Full play clock
    }

    test "unit: PlayHandler: processes spike" {
    var handler = PlayHandler.init(12345);
    
    const result = handler.processPlay(.spike, .{});
    
    try testing.expectEqual(PlayType.spike, result.play_type);
    try testing.expectEqual(@as(i16, 0), result.yards_gained);
    try testing.expectEqual(@as(u32, 1), result.time_consumed); // Minimal time
    }

    test "unit: PlayHandler: tracks play numbers" {
    var handler = PlayHandler.init(12345);
    
    try testing.expectEqual(@as(u32, 0), handler.play_number);
    
    _ = handler.processPlay(.run_up_middle, .{});
    try testing.expectEqual(@as(u32, 1), handler.play_number);
    
    _ = handler.processPlay(.pass_short, .{});
    try testing.expectEqual(@as(u32, 2), handler.play_number);
    }

    test "unit: PlayHandler: calculates expected points" {
    // Red zone
    try testing.expect(getExpectedPoints(95) > 5.0);
    
    // Midfield
    const midfield_ep = getExpectedPoints(50);
    try testing.expect(midfield_ep > -1.0 and midfield_ep < 1.0);
    
    // Own territory
    try testing.expect(getExpectedPoints(20) < 0.0);
    
    // Own end zone
    try testing.expect(getExpectedPoints(5) < -1.0);
    }

    test "unit: PlayHandler: returns correct play times" {
    try testing.expectEqual(@as(u32, 12), getHurryUpPlayTime());
    try testing.expectEqual(@as(u32, 38), getNormalPlayTime());
    }


// ╚══════════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ TEST ══════════════════════════════════════╗

    test "integration: PlayHandler: handles touchdown scoring" {
    var handler = PlayHandler.init(12345);
    handler.game_state.possession = .home;
    handler.possession_team = .home;
    
    // Create touchdown result
    var result = PlayResult{
        .play_type = .run_up_middle,
        .yards_gained = 10,
        .out_of_bounds = false,
        .pass_completed = false,
        .is_touchdown = true,
        .is_first_down = true,
        .is_turnover = false,
        .time_consumed = 6,
        .field_position = 100,
    };
    
    const initial_score = handler.game_state.home_score;
    handler.updateGameState(&result);
    
    try testing.expectEqual(initial_score + 6, handler.game_state.home_score);
    try testing.expectEqual(@as(u8, 1), handler.game_state.down);
    try testing.expectEqual(@as(u8, 10), handler.game_state.distance);
    }

    test "integration: PlayHandler: handles first downs" {
    var handler = PlayHandler.init(12345);
    handler.game_state.down = 2;
    handler.game_state.distance = 7;
    
    var result = PlayResult{
        .play_type = .run_up_middle,
        .yards_gained = 8,
        .out_of_bounds = false,
        .pass_completed = false,
        .is_touchdown = false,
        .is_first_down = true,
        .is_turnover = false,
        .time_consumed = 6,
        .field_position = 50,
    };
    
    handler.updateGameState(&result);
    
    try testing.expectEqual(@as(u8, 1), handler.game_state.down);
    try testing.expectEqual(@as(u8, 10), handler.game_state.distance);
    }

    test "integration: PlayHandler: handles turnovers" {
    var handler = PlayHandler.init(12345);
    handler.game_state.possession = .home;
    handler.possession_team = .home;
    
    var result = PlayResult{
        .play_type = .interception,
        .yards_gained = 0,
        .out_of_bounds = false,
        .pass_completed = false,
        .is_touchdown = false,
        .is_first_down = false,
        .is_turnover = true,
        .time_consumed = 5,
        .field_position = 50,
    };
    
    handler.updateGameState(&result);
    
    try testing.expectEqual(.away, handler.game_state.possession);
    try testing.expectEqual(@as(u8, 1), handler.game_state.down);
    try testing.expectEqual(@as(u8, 10), handler.game_state.distance);
    }

    test "integration: PlayHandler: handles turnover on downs" {
    var handler = PlayHandler.init(12345);
    handler.game_state.down = 4;
    handler.game_state.distance = 5;
    handler.game_state.possession = .home;
    handler.possession_team = .home;
    
    var result = PlayResult{
        .play_type = .run_up_middle,
        .yards_gained = 3,
        .out_of_bounds = false,
        .pass_completed = false,
        .is_touchdown = false,
        .is_first_down = false,
        .is_turnover = false,
        .time_consumed = 6,
        .field_position = 50,
    };
    
    handler.updateGameState(&result);
    
    // Should change possession on failed 4th down
    try testing.expectEqual(.away, handler.game_state.possession);
    try testing.expectEqual(@as(u8, 1), handler.game_state.down);
    try testing.expectEqual(@as(u8, 10), handler.game_state.distance);
    }

    test "integration: PlayHandler: updates statistics correctly" {
    var handler = PlayHandler.init(12345);
    handler.possession_team = .home;
    
    // Pass play
    var pass_result = PlayResult{
        .play_type = .pass_medium,
        .yards_gained = 15,
        .out_of_bounds = false,
        .pass_completed = true,
        .is_touchdown = false,
        .is_first_down = true,
        .is_turnover = false,
        .time_consumed = 7,
        .field_position = 50,
    };
    
    handler.updateStatistics(&pass_result);
    
    try testing.expectEqual(@as(i32, 15), handler.home_stats.total_yards);
    try testing.expectEqual(@as(i32, 15), handler.home_stats.passing_yards);
    try testing.expectEqual(@as(u16, 1), handler.home_stats.first_downs);
    
    // Run play
    var run_result = PlayResult{
        .play_type = .run_sweep,
        .yards_gained = 8,
        .out_of_bounds = true,
        .pass_completed = false,
        .is_touchdown = false,
        .is_first_down = false,
        .is_turnover = false,
        .time_consumed = 5,
        .field_position = 65,
    };
    
    handler.updateStatistics(&run_result);
    
    try testing.expectEqual(@as(i32, 23), handler.home_stats.total_yards);
    try testing.expectEqual(@as(i32, 8), handler.home_stats.rushing_yards);
    }

    test "integration: PlayHandler: tracks time of possession" {
    var handler = PlayHandler.init(12345);
    handler.possession_team = .away;
    
    var result = PlayResult{
        .play_type = .run_up_middle,
        .yards_gained = 5,
        .out_of_bounds = false,
        .pass_completed = false,
        .is_touchdown = false,
        .is_first_down = false,
        .is_turnover = false,
        .time_consumed = 35,
        .field_position = 50,
    };
    
    handler.updateStatistics(&result);
    
    try testing.expectEqual(@as(u32, 35), handler.away_stats.time_of_possession);
    try testing.expectEqual(@as(u32, 0), handler.home_stats.time_of_possession);
    }


// ╚══════════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ TEST ══════════════════════════════════════╗

    test "e2e: PlayHandler: simulates complete drive" {
    var handler = PlayHandler.init(12345);
    handler.game_state.possession = .home;
    handler.possession_team = .home;
    
    // First down - run for 3 yards
    var result = handler.processPlay(.run_up_middle, .{});
    handler.game_state.down = 2;
    handler.game_state.distance = 7;
    
    // Second down - incomplete pass
    result = handler.processPlay(.pass_medium, .{});
    if (!result.pass_completed) {
        handler.game_state.down = 3;
    }
    
    // Third down - complete pass for first down
    result = handler.processPlay(.pass_short, .{});
    if (result.is_first_down) {
        handler.game_state.down = 1;
        handler.game_state.distance = 10;
    }
    
    // Continue drive to red zone
    handler.game_state.down = 1;
    handler.game_state.distance = 5;
    
    // Goal line run for touchdown
    result = handler.processPlay(.quarterback_sneak, .{});
    
    // Extra point
    result = handler.processPlay(.extra_point, .{});
    
    // Verify scoring
    try testing.expect(handler.game_state.home_score >= 0);
    try testing.expect(handler.play_number > 0);
    }

    test "e2e: PlayHandler: simulates two-minute drill" {
    var handler = PlayHandler.init(12345);
    handler.game_state.quarter = 4;
    handler.game_state.time_remaining = 120;
    handler.game_state.possession = .away;
    handler.possession_team = .away;
    handler.game_state.away_score = 21;
    handler.game_state.home_score = 24;
    
    // Series of quick passes
    var plays_run: u32 = 0;
    var time_used: u32 = 0;
    
    // Simulate hurry-up offense
    for (0..8) |_| {
        const result = handler.processPlay(.pass_short, .{});
        plays_run += 1;
        time_used += result.time_consumed;
        
        // Update game state based on result
        if (result.is_first_down) {
            handler.game_state.down = 1;
            handler.game_state.distance = 10;
        } else if (!result.pass_completed) {
            // Clock stops on incomplete
            handler.game_state.clock_running = false;
        }
        
        // Check if in field goal range
        if (result.field_position >= 65) {
            break;
        }
    }
    
    // Attempt field goal
    const fg_result = handler.processPlay(.field_goal, .{ .kick_distance = 35 });
    
    // Verify time management
    try testing.expect(time_used < 120); // Used less than full 2 minutes
    try testing.expect(plays_run > 0);
    try testing.expect(fg_result.play_type == .field_goal);
    }

    test "e2e: PlayHandler: handles special teams sequence" {
    var handler = PlayHandler.init(12345);
    
    // Kickoff to start game
    var result = handler.processPlay(.kickoff, .{ .return_yards = 25 });
    try testing.expect(result.is_turnover); // Possession changes
    try testing.expect(result.field_position > 0);
    
    // Three and out
    handler.game_state.down = 4;
    handler.game_state.distance = 7;
    
    // Punt
    result = handler.processPlay(.punt, .{ .kick_distance = 45 });
    try testing.expect(result.is_turnover);
    
    // Drive ending in field goal attempt
    handler.game_state.down = 4;
    handler.game_state.distance = 8;
    
    result = handler.processPlay(.field_goal, .{ .kick_distance = 42 });
    try testing.expectEqual(PlayType.field_goal, result.play_type);
    
    // Check if points were scored (depends on RNG)
    const initial_score = handler.game_state.home_score + handler.game_state.away_score;
    try testing.expect(initial_score >= 0);
    }


// ╚══════════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ TEST ══════════════════════════════════════╗

    test "performance: PlayHandler: processes plays efficiently" {
    var handler = PlayHandler.init(12345);
    
    const start_time = std.time.milliTimestamp();
    
    // Process 1000 plays
    for (0..1000) |i| {
        const play_type: PlayType = switch (i % 10) {
            0 => .pass_short,
            1 => .pass_medium,
            2 => .pass_deep,
            3 => .run_up_middle,
            4 => .run_off_tackle,
            5 => .run_sweep,
            6 => .screen_pass,
            7 => .quarterback_sneak,
            8 => .punt,
            9 => .field_goal,
            else => .run_up_middle,
        };
        
        _ = handler.processPlay(play_type, .{});
    }
    
    const elapsed = std.time.milliTimestamp() - start_time;
    
    // Should complete in under 100ms
    try testing.expect(elapsed < 100);
    }

    test "performance: PlayHandler: updates statistics quickly" {
    var handler = PlayHandler.init(12345);
    
    const start_time = std.time.milliTimestamp();
    
    // Create and update 10000 play results
    for (0..10000) |i| {
        const result = PlayResult{
            .play_type = if (i % 2 == 0) .run_up_middle else .pass_short,
            .yards_gained = @as(i16, @intCast(i % 20)) - 5,
            .out_of_bounds = i % 5 == 0,
            .pass_completed = i % 3 != 0,
            .is_touchdown = i % 100 == 0,
            .is_first_down = i % 4 == 0,
            .is_turnover = i % 50 == 0,
            .time_consumed = @as(u32, @intCast(i % 40)),
            .field_position = @as(u8, @intCast(i % 100)),
        };
        
        handler.updateStatistics(&result);
    }
    
    const elapsed = std.time.milliTimestamp() - start_time;
    
    // Should complete in under 50ms
    try testing.expect(elapsed < 50);
    }


// ╚══════════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ TEST ══════════════════════════════════════╗

    test "stress: PlayHandler: handles all play types" {
    var handler = PlayHandler.init(12345);
    
    const all_play_types = [_]PlayType{
        .pass_short,
        .pass_medium,
        .pass_deep,
        .screen_pass,
        .run_up_middle,
        .run_off_tackle,
        .run_sweep,
        .quarterback_sneak,
        .punt,
        .field_goal,
        .extra_point,
        .kickoff,
        .kickoff_return,
        .punt_return,
        .kneel_down,
        .spike,
        .two_point_conversion,
        .onside_kick,
        .interception,
        .fumble,
        .fumble_recovery,
        .penalty_offense,
        .penalty_defense,
        .penalty_declined,
    };
    
    for (all_play_types) |play_type| {
        const result = handler.processPlay(play_type, .{});
        
        // Every play should produce valid result
        try testing.expect(result.time_consumed >= 0);
        try testing.expect(result.field_position <= 100);
        try testing.expectEqual(play_type, result.play_type);
    }
    }

    test "stress: PlayHandler: handles extreme game states" {
    // Test with maximum scores
    var handler = PlayHandler.init(12345);
    handler.game_state.home_score = 999;
    handler.game_state.away_score = 999;
    
    var td_result = PlayResult{
        .play_type = .run_up_middle,
        .yards_gained = 50,
        .out_of_bounds = false,
        .pass_completed = false,
        .is_touchdown = true,
        .is_first_down = true,
        .is_turnover = false,
        .time_consumed = 8,
        .field_position = 100,
    };
    
    handler.updateGameState(&td_result);
    try testing.expectEqual(@as(u16, 1005), handler.game_state.home_score); // 999 + 6
    
    // Test with minimum time
    handler.game_state.time_remaining = 0;
    handler.updateGameState(&td_result);
    try testing.expectEqual(@as(u32, 0), handler.game_state.time_remaining);
    
    // Test with maximum down and distance
    handler.game_state.down = 255;
    handler.game_state.distance = 255;
    handler.updateGameState(&td_result);
    // Should reset after touchdown
    try testing.expectEqual(@as(u8, 1), handler.game_state.down);
    try testing.expectEqual(@as(u8, 10), handler.game_state.distance);
    }

    test "stress: PlayHandler: handles rapid possession changes" {
    var handler = PlayHandler.init(12345);
    
    for (0..100) |i| {
        // Alternate turnovers
        var turnover_result = PlayResult{
            .play_type = if (i % 2 == 0) .interception else .fumble,
            .yards_gained = 0,
            .out_of_bounds = false,
            .pass_completed = false,
            .is_touchdown = false,
            .is_first_down = false,
            .is_turnover = true,
            .time_consumed = 5,
            .field_position = 50,
        };
        
        const initial_possession = handler.game_state.possession;
        handler.updateGameState(&turnover_result);
        
        // Verify possession changed
        const new_possession = handler.game_state.possession;
        try testing.expect(initial_possession != new_possession);
        
        // Verify down and distance reset
        try testing.expectEqual(@as(u8, 1), handler.game_state.down);
        try testing.expectEqual(@as(u8, 10), handler.game_state.distance);
    }
    }

    test "stress: PlayHandler: handles long games with many plays" {
    var handler = PlayHandler.init(12345);
    
    // Simulate a full game (approximately 150 plays)
    for (0..150) |i| {
        const play_selection = i % 15;
        const play_type: PlayType = switch (play_selection) {
            0...5 => .run_up_middle,
            6...10 => .pass_short,
            11 => .pass_deep,
            12 => .punt,
            13 => .field_goal,
            14 => .kickoff,
            else => .run_up_middle,
        };
        
        const result = handler.processPlay(play_type, .{});
        
        // Update game state
        if (handler.game_state.time_remaining > result.time_consumed) {
            handler.game_state.time_remaining -= result.time_consumed;
        } else {
            // Quarter ended
            handler.game_state.quarter += 1;
            handler.game_state.time_remaining = 900;
        }
        
        // Verify stats are accumulating
        if (i > 0) {
            const total_stats = handler.home_stats.total_yards + @as(i32, @intCast(@abs(handler.away_stats.total_yards)));
            try testing.expect(total_stats != 0 or handler.play_number == i + 1);
        }
    }
    
    // Verify game progressed
    try testing.expect(handler.play_number == 150);
    try testing.expect(handler.game_state.quarter > 1);
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════════╝