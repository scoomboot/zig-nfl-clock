// rules_engine.test.zig — Tests for NFL game clock rules engine
//
// repo   : https://github.com/zig-nfl-clock
// docs   : https://zig-nfl-clock.github.io/docs/lib/game_clock/utils/rules_engine/rules_engine.test.zig
// author : https://github.com/maysara-elshewehy
//
// Vibe coded by Scoom.

const std = @import("std");
const testing = std.testing;
const RulesEngine = @import("rules_engine.zig").RulesEngine;
const PlayOutcome = @import("rules_engine.zig").PlayOutcome;
const ClockStopReason = @import("rules_engine.zig").ClockStopReason;
const GameSituation = @import("rules_engine.zig").GameSituation;
const ClockDecision = @import("rules_engine.zig").ClockDecision;
const PenaltyInfo = @import("rules_engine.zig").PenaltyInfo;
const TimingConstants = @import("rules_engine.zig").TimingConstants;

// Import utility functions
const shouldTriggerTwoMinuteWarning = @import("rules_engine.zig").shouldTriggerTwoMinuteWarning;
const isInsideTwoMinutes = @import("rules_engine.zig").isInsideTwoMinutes;
const getPlayDuration = @import("rules_engine.zig").getPlayDuration;

// ╔══════════════════════════════════════ PACK ══════════════════════════════════════╗

    const allocator = testing.allocator;


// ╚══════════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ INIT ══════════════════════════════════════╗

    /// Test scenario for play outcomes
    const PlayScenario = struct {
        name: []const u8,
        outcome: PlayOutcome,
        situation: GameSituation,
        expected_stop: bool,
        expected_reason: ?ClockStopReason,
        expected_restart_on_ready: bool,
        expected_restart_on_snap: bool,
    };

    /// Test scenario for penalties
    const PenaltyScenario = struct {
        name: []const u8,
        penalty: PenaltyInfo,
        situation: GameSituation,
        expected_runoff: bool,
        expected_stop: bool,
    };


// ╚══════════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ TEST ══════════════════════════════════════╗

    test "unit: RulesEngine: initializes with default values" {
        var engine = RulesEngine.init();
        
        try testing.expectEqual(@as(u8, 1), engine.situation.quarter);
        try testing.expectEqual(TimingConstants.QUARTER_LENGTH, engine.situation.time_remaining);
        try testing.expectEqual(@as(u8, 1), engine.situation.down);
        try testing.expectEqual(@as(u8, 10), engine.situation.distance);
        try testing.expectEqual(false, engine.situation.is_overtime);
        try testing.expectEqual(@as(u8, 3), engine.situation.home_timeouts);
        try testing.expectEqual(@as(u8, 3), engine.situation.away_timeouts);
        try testing.expectEqual(false, engine.clock_running);
        try testing.expectEqual(false, engine.hurry_up_mode);
    }

    test "unit: RulesEngine: initializes with custom situation" {
        const custom_situation = GameSituation{
            .quarter = 3,
            .time_remaining = 450,
            .down = 2,
            .distance = 7,
            .is_overtime = false,
            .home_timeouts = 2,
            .away_timeouts = 1,
            .possession_team = .home,
            .is_two_minute_drill = false,
        };
        
        var engine = RulesEngine.initWithSituation(custom_situation);
        
        try testing.expectEqual(@as(u8, 3), engine.situation.quarter);
        try testing.expectEqual(@as(u32, 450), engine.situation.time_remaining);
        try testing.expectEqual(@as(u8, 2), engine.situation.down);
        try testing.expectEqual(@as(u8, 7), engine.situation.distance);
    }

    test "unit: RulesEngine: processes incomplete pass correctly" {
        var engine = RulesEngine.init();
        const decision = engine.processPlay(.incomplete_pass);
        
        try testing.expect(decision.should_stop);
        try testing.expectEqual(ClockStopReason.incomplete_pass, decision.stop_reason);
        try testing.expect(!decision.restart_on_ready);
        try testing.expect(decision.restart_on_snap);
        try testing.expect(decision.play_clock_reset);
    }

    test "unit: RulesEngine: processes out of bounds outside two minutes" {
        var engine = RulesEngine.init();
        engine.situation.time_remaining = 300; // 5 minutes
        
        const decision = engine.processPlay(.run_out_of_bounds);
        
        try testing.expect(decision.should_stop);
        try testing.expectEqual(ClockStopReason.out_of_bounds, decision.stop_reason);
        try testing.expect(decision.restart_on_ready);
        try testing.expect(!decision.restart_on_snap);
    }

    test "unit: RulesEngine: processes out of bounds inside two minutes" {
        var engine = RulesEngine.init();
        engine.situation.quarter = 2;
        engine.situation.time_remaining = 90; // 1:30
        
        const decision = engine.processPlay(.run_out_of_bounds);
        
        try testing.expect(decision.should_stop);
        try testing.expectEqual(ClockStopReason.out_of_bounds, decision.stop_reason);
        try testing.expect(!decision.restart_on_ready);
        try testing.expect(decision.restart_on_snap);
    }

    test "unit: RulesEngine: processes touchdown" {
        var engine = RulesEngine.init();
        const decision = engine.processPlay(.touchdown);
        
        try testing.expect(decision.should_stop);
        try testing.expectEqual(ClockStopReason.score, decision.stop_reason);
        try testing.expect(!decision.restart_on_ready);
        try testing.expect(!decision.restart_on_snap);
    }

    test "unit: RulesEngine: processes timeout" {
        var engine = RulesEngine.init();
        const decision = engine.processPlay(.timeout);
        
        try testing.expect(decision.should_stop);
        try testing.expectEqual(ClockStopReason.timeout, decision.stop_reason);
        try testing.expect(decision.restart_on_snap);
        try testing.expectEqual(TimingConstants.PLAY_CLOCK_AFTER_TIMEOUT, decision.play_clock_duration);
    }

    test "unit: RulesEngine: manages timeouts correctly" {
        var engine = RulesEngine.init();
        
        // Check initial timeouts
        try testing.expect(engine.canCallTimeout(.home));
        try testing.expect(engine.canCallTimeout(.away));
        
        // Use home timeout
        try engine.useTimeout(.home);
        try testing.expectEqual(@as(u8, 2), engine.situation.home_timeouts);
        
        // Use all away timeouts
        try engine.useTimeout(.away);
        try engine.useTimeout(.away);
        try engine.useTimeout(.away);
        try testing.expectEqual(@as(u8, 0), engine.situation.away_timeouts);
        
        // Cannot use more timeouts
        try testing.expect(!engine.canCallTimeout(.away));
        try testing.expectError(error.NoTimeoutsRemaining, engine.useTimeout(.away));
    }

    test "unit: RulesEngine: detects two-minute warning" {
        const situation_no_warning = GameSituation{
            .quarter = 1,
            .time_remaining = 120,
            .down = 1,
            .distance = 10,
            .is_overtime = false,
            .home_timeouts = 3,
            .away_timeouts = 3,
            .possession_team = .home,
            .is_two_minute_drill = false,
        };
        
        try testing.expect(!shouldTriggerTwoMinuteWarning(situation_no_warning));
        
        const situation_warning = GameSituation{
            .quarter = 2,
            .time_remaining = 120,
            .down = 1,
            .distance = 10,
            .is_overtime = false,
            .home_timeouts = 3,
            .away_timeouts = 3,
            .possession_team = .home,
            .is_two_minute_drill = false,
        };
        
        try testing.expect(shouldTriggerTwoMinuteWarning(situation_warning));
    }

    test "unit: RulesEngine: checks inside two minutes correctly" {
        const outside_two_min = GameSituation{
        .quarter = 2,
        .time_remaining = 150,
        .down = 1,
        .distance = 10,
        .is_overtime = false,
        .home_timeouts = 3,
        .away_timeouts = 3,
        .possession_team = .home,
        .is_two_minute_drill = false,
    };
    
    try testing.expect(!isInsideTwoMinutes(outside_two_min));
    
    const inside_two_min = GameSituation{
        .quarter = 4,
        .time_remaining = 90,
        .down = 1,
        .distance = 10,
        .is_overtime = false,
        .home_timeouts = 3,
        .away_timeouts = 3,
        .possession_team = .home,
        .is_two_minute_drill = false,
    };
    
    try testing.expect(isInsideTwoMinutes(inside_two_min));
    }

    test "unit: RulesEngine: calculates play duration" {
    // Normal play
    const normal_incomplete = getPlayDuration(.incomplete_pass, false);
    try testing.expectEqual(@as(u32, 5), normal_incomplete);
    
    const normal_run = getPlayDuration(.run_inbounds, false);
    try testing.expectEqual(@as(u32, 6), normal_run);
    
    // Hurry-up offense
    const hurry_incomplete = getPlayDuration(.incomplete_pass, true);
    try testing.expectEqual(@as(u32, 3), hurry_incomplete);
    
    const hurry_run = getPlayDuration(.run_inbounds, true);
    try testing.expectEqual(@as(u32, 4), hurry_run);
    }


// ╚══════════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ TEST ══════════════════════════════════════╗

    test "integration: RulesEngine: handles quarter transitions" {
    var engine = RulesEngine.init();
    
    // Start in Q1
    try testing.expectEqual(@as(u8, 1), engine.situation.quarter);
    
    // Advance to Q2
    engine.advanceQuarter();
    try testing.expectEqual(@as(u8, 2), engine.situation.quarter);
    try testing.expectEqual(TimingConstants.QUARTER_LENGTH, engine.situation.time_remaining);
    
    // Advance to halftime (Q3)
    engine.advanceQuarter();
    try testing.expectEqual(@as(u8, 3), engine.situation.quarter);
    // Timeouts should be reset
    try testing.expectEqual(@as(u8, 3), engine.situation.home_timeouts);
    try testing.expectEqual(@as(u8, 3), engine.situation.away_timeouts);
    
    // Advance to Q4
    engine.advanceQuarter();
    try testing.expectEqual(@as(u8, 4), engine.situation.quarter);
    
    // Advance to overtime
    engine.advanceQuarter();
    try testing.expect(engine.situation.is_overtime);
    try testing.expectEqual(TimingConstants.OVERTIME_LENGTH, engine.situation.time_remaining);
    }

    test "integration: RulesEngine: processes penalties correctly" {
    var engine = RulesEngine.init();
    
    // Regular penalty
    const regular_penalty = PenaltyInfo{
        .yards = 5,
        .clock_impact = .stop_clock,
        .against_team = .offense,
    };
    
    var decision = engine.processPenalty(regular_penalty);
    try testing.expect(decision.should_stop);
    try testing.expectEqual(ClockStopReason.penalty, decision.stop_reason);
    try testing.expect(decision.restart_on_ready);
    
    // Ten-second runoff in final minute
    engine.situation.quarter = 4;
    engine.situation.time_remaining = 45;
    
    const runoff_penalty = PenaltyInfo{
        .yards = 5,
        .clock_impact = .ten_second_runoff,
        .against_team = .offense,
    };
    
    decision = engine.processPenalty(runoff_penalty);
    try testing.expectEqual(@as(u32, 35), engine.situation.time_remaining);
    }

    test "integration: RulesEngine: handles first down inside two minutes" {
    var engine = RulesEngine.init();
    engine.situation.quarter = 4;
    engine.situation.time_remaining = 90;
    engine.situation.down = 1;
    
    // First down inside two minutes should stop clock
    const decision = engine.processPlay(.run_inbounds);
    
    try testing.expect(decision.should_stop);
    try testing.expectEqual(ClockStopReason.first_down, decision.stop_reason);
    try testing.expect(decision.restart_on_ready);
    }

    test "integration: RulesEngine: manages possession changes" {
    var engine = RulesEngine.init();
    
    // Initial possession
    engine.newPossession(.home);
    try testing.expectEqual(.home, engine.situation.possession_team);
    try testing.expectEqual(@as(u8, 1), engine.situation.down);
    try testing.expectEqual(@as(u8, 10), engine.situation.distance);
    
    // Change possession
    engine.newPossession(.away);
    try testing.expectEqual(.away, engine.situation.possession_team);
    try testing.expectEqual(@as(u8, 1), engine.situation.down);
    try testing.expectEqual(@as(u8, 10), engine.situation.distance);
    }

    test "integration: RulesEngine: updates down and distance" {
    var engine = RulesEngine.init();
    
    // Gain 5 yards on first down
    engine.updateDownAndDistance(5);
    try testing.expectEqual(@as(u8, 2), engine.situation.down);
    try testing.expectEqual(@as(u8, 5), engine.situation.distance);
    
    // Gain 3 yards on second down
    engine.updateDownAndDistance(3);
    try testing.expectEqual(@as(u8, 3), engine.situation.down);
    try testing.expectEqual(@as(u8, 2), engine.situation.distance);
    
    // Get first down
    engine.updateDownAndDistance(5);
    try testing.expectEqual(@as(u8, 1), engine.situation.down);
    try testing.expectEqual(@as(u8, 10), engine.situation.distance);
    }

    test "integration: RulesEngine: handles turnover on downs" {
    var engine = RulesEngine.init();
    engine.situation.possession_team = .home;
    engine.situation.down = 4;
    engine.situation.distance = 5;
    
    // Fail to get first down on 4th down
    engine.updateDownAndDistance(3);
    
    // Should change possession
    try testing.expectEqual(.away, engine.situation.possession_team);
    try testing.expectEqual(@as(u8, 1), engine.situation.down);
    try testing.expectEqual(@as(u8, 10), engine.situation.distance);
    }


// ╚══════════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ TEST ══════════════════════════════════════╗

    test "e2e: RulesEngine: simulates two-minute drill" {
    var engine = RulesEngine.init();
    engine.situation.quarter = 4;
    engine.situation.time_remaining = 120;
    engine.situation.possession_team = .home;
    engine.situation.home_timeouts = 2;
    
    // First play - incomplete pass
    var decision = engine.processPlay(.incomplete_pass);
    try testing.expect(decision.should_stop);
    
    // Second play - complete pass out of bounds
    decision = engine.processPlay(.complete_pass_out_of_bounds);
    try testing.expect(decision.should_stop);
    try testing.expect(decision.restart_on_snap); // Inside 2 minutes
    
    // Third play - run inbounds for first down
    engine.situation.down = 1;
    decision = engine.processPlay(.run_inbounds);
    try testing.expect(decision.should_stop); // First down stops clock
    try testing.expectEqual(ClockStopReason.first_down, decision.stop_reason);
    
    // Use timeout
    try testing.expect(engine.canCallTimeout(.home));
    try engine.useTimeout(.home);
    decision = engine.processPlay(.timeout);
    try testing.expect(decision.should_stop);
    try testing.expectEqual(@as(u8, 1), engine.situation.home_timeouts);
    }

    test "e2e: RulesEngine: simulates end of game scenario" {
    var engine = RulesEngine.init();
    
    // Set up end of Q4
    engine.situation.quarter = 4;
    engine.situation.time_remaining = 10;
    engine.situation.possession_team = .away;
    engine.situation.down = 3;
    engine.situation.distance = 7;
    
    // Try field goal
    const decision = engine.processPlay(.field_goal_attempt);
    try testing.expect(decision.should_stop);
    try testing.expectEqual(ClockStopReason.score, decision.stop_reason);
    
    // Check if game is over
    engine.situation.time_remaining = 0;
    try testing.expect(engine.isGameOver());
    
    // Start overtime
    engine.advanceQuarter();
    try testing.expect(engine.situation.is_overtime);
    try testing.expect(!engine.isGameOver()); // OT has time
    
    // End of overtime
    engine.situation.time_remaining = 0;
    try testing.expect(engine.isGameOver());
    }

    test "e2e: RulesEngine: handles complete drive with penalties" {
    var engine = RulesEngine.init();
    engine.newPossession(.home);
    
    // First down run
    var decision = engine.processPlay(.run_inbounds);
    try testing.expect(!decision.should_stop); // Clock keeps running
    engine.updateDownAndDistance(3);
    
    // Second down penalty
    const holding = PenaltyInfo{
        .yards = -10,
        .clock_impact = .stop_clock,
        .against_team = .offense,
    };
    decision = engine.processPenalty(holding);
    try testing.expect(decision.should_stop);
    
    // Now 2nd and 17
    engine.situation.distance = 17;
    
    // Pass play
    decision = engine.processPlay(.complete_pass_inbounds);
    engine.updateDownAndDistance(15);
    try testing.expectEqual(@as(u8, 3), engine.situation.down);
    try testing.expectEqual(@as(u8, 2), engine.situation.distance);
    
    // Third down conversion
    decision = engine.processPlay(.run_inbounds);
    engine.updateDownAndDistance(5);
    try testing.expectEqual(@as(u8, 1), engine.situation.down);
    try testing.expectEqual(@as(u8, 10), engine.situation.distance);
    }


// ╚══════════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ TEST ══════════════════════════════════════╗

    test "performance: RulesEngine: processes plays quickly" {
    var engine = RulesEngine.init();
    
    const start_time = std.time.milliTimestamp();
    
    // Process 10000 plays
    for (0..10000) |i| {
        const play_type: PlayOutcome = switch (i % 5) {
            0 => .incomplete_pass,
            1 => .complete_pass_inbounds,
            2 => .run_inbounds,
            3 => .run_out_of_bounds,
            4 => .sack,
            else => .run_inbounds,
        };
        
        _ = engine.processPlay(play_type);
    }
    
    const elapsed = std.time.milliTimestamp() - start_time;
    
    // Should complete in under 50ms
    try testing.expect(elapsed < 50);
    }

    test "performance: RulesEngine: handles rapid timeout management" {
    const start_time = std.time.milliTimestamp();
    
    // Create and manage 1000 game situations
    for (0..1000) |_| {
        var engine = RulesEngine.init();
        
        // Use timeouts
        while (engine.canCallTimeout(.home)) {
            try engine.useTimeout(.home);
        }
        while (engine.canCallTimeout(.away)) {
            try engine.useTimeout(.away);
        }
        
        // Advance quarters to reset timeouts
        engine.advanceQuarter();
        engine.advanceQuarter();
        
        // Check timeouts are reset at halftime
        try testing.expectEqual(@as(u8, 3), engine.situation.home_timeouts);
    }
    
    const elapsed = std.time.milliTimestamp() - start_time;
    
    // Should complete in under 50ms
    try testing.expect(elapsed < 50);
    }


// ╚══════════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ TEST ══════════════════════════════════════╗

    test "stress: RulesEngine: handles all play outcomes" {
    var engine = RulesEngine.init();
    
    const all_outcomes = [_]PlayOutcome{
        .incomplete_pass,
        .complete_pass_inbounds,
        .complete_pass_out_of_bounds,
        .run_inbounds,
        .run_out_of_bounds,
        .touchdown,
        .field_goal_attempt,
        .punt,
        .kickoff,
        .penalty,
        .timeout,
        .injury,
        .two_minute_warning,
        .quarter_end,
        .sack,
        .fumble_inbounds,
        .fumble_out_of_bounds,
        .interception,
        .safety,
    };
    
    for (all_outcomes) |outcome| {
        const decision = engine.processPlay(outcome);
        
        // Every play should have a valid decision
        try testing.expect(decision.play_clock_reset);
        try testing.expect(decision.play_clock_duration > 0);
        
        // Verify stop reasons match outcomes
        switch (outcome) {
            .incomplete_pass => try testing.expectEqual(ClockStopReason.incomplete_pass, decision.stop_reason),
            .touchdown, .field_goal_attempt, .safety => try testing.expectEqual(ClockStopReason.score, decision.stop_reason),
            .timeout => try testing.expectEqual(ClockStopReason.timeout, decision.stop_reason),
            .injury => try testing.expectEqual(ClockStopReason.injury, decision.stop_reason),
            .quarter_end => try testing.expectEqual(ClockStopReason.quarter_end, decision.stop_reason),
            else => {},
        }
    }
    }

    test "stress: RulesEngine: handles extreme game situations" {
    // Test with minimum values
    var min_situation = GameSituation{
        .quarter = 1,
        .time_remaining = 0,
        .down = 1,
        .distance = 0,
        .is_overtime = false,
        .home_timeouts = 0,
        .away_timeouts = 0,
        .possession_team = .home,
        .is_two_minute_drill = false,
    };
    
    var engine = RulesEngine.initWithSituation(min_situation);
    try testing.expect(engine.isHalfOver());
    try testing.expect(!engine.canCallTimeout(.home));
    try testing.expect(!engine.canCallTimeout(.away));
    
    // Test with maximum values
    var max_situation = GameSituation{
        .quarter = 255,
        .time_remaining = 999999,
        .down = 255,
        .distance = 255,
        .is_overtime = true,
        .home_timeouts = 255,
        .away_timeouts = 255,
        .possession_team = .away,
        .is_two_minute_drill = true,
    };
    
    engine = RulesEngine.initWithSituation(max_situation);
    try testing.expect(engine.canCallTimeout(.home));
    try testing.expect(engine.canCallTimeout(.away));
    try testing.expect(engine.situation.is_overtime);
    }

    test "stress: RulesEngine: handles rapid state changes" {
    var engine = RulesEngine.init();
    
    // Rapidly change game state
    for (0..100) |i| {
        // Change quarter
        engine.situation.quarter = @as(u8, @intCast((i % 5) + 1));
        
        // Change time
        engine.situation.time_remaining = @as(u32, @intCast(i * 10 % 900));
        
        // Change down and distance
        engine.situation.down = @as(u8, @intCast((i % 4) + 1));
        engine.situation.distance = @as(u8, @intCast(i % 20));
        
        // Toggle possession
        engine.situation.possession_team = if (i % 2 == 0) .home else .away;
        
        // Process random plays
        const play_type: PlayOutcome = switch (i % 3) {
            0 => .incomplete_pass,
            1 => .run_inbounds,
            2 => .penalty,
            else => .run_inbounds,
        };
        
        const decision = engine.processPlay(play_type);
        
        // Verify decision is valid
        try testing.expect(decision.play_clock_duration <= 40);
        if (decision.should_stop) {
            try testing.expect(decision.stop_reason != null);
        }
    }
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════════╝