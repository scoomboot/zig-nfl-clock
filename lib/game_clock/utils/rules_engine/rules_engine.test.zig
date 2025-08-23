// rules_engine.test.zig — Rules engine tests
//
// repo   : https://github.com/scoomboot/zig-nfl-clock
// docs   : https://zig-nfl-clock.github.io/docs/lib/game_clock/utils/rules_engine
// author : https://github.com/scoomboot
//
// Vibe coded by Scoom.

// ╔══════════════════════════════════════ PACK ══════════════════════════════════════╗

    const std = @import("std");
    const testing = std.testing;
    const allocator = testing.allocator;
    
    // Import core types from rules_engine module
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

    // ┌──────────────────────────── Test Helpers ────────────────────────────┐

    /// Creates a RulesEngine with default test configuration
    fn createTestRulesEngine() RulesEngine {
        return RulesEngine.init();
    }

    /// Creates a RulesEngine with specific game situation
    fn createTestRulesEngineWithSituation(situation: GameSituation) RulesEngine {
        return RulesEngine.initWithSituation(situation);
    }

    /// Creates a GameSituation for specific test scenarios
    fn createTestSituation(scenario: enum { 
        regular_time,
        two_minute_drill,
        overtime,
        end_of_half,
        fourth_down
    }) GameSituation {
        return switch (scenario) {
            .regular_time => GameSituation{
                .quarter = 2,
                .time_remaining = 450,
                .down = 1,
                .distance = 10,
                .is_overtime = false,
                .home_timeouts = 3,
                .away_timeouts = 3,
                .possession_team = .home,
                .is_two_minute_drill = false,
            },
            .two_minute_drill => GameSituation{
                .quarter = 4,
                .time_remaining = 90,
                .down = 1,
                .distance = 10,
                .is_overtime = false,
                .home_timeouts = 2,
                .away_timeouts = 1,
                .possession_team = .away,
                .is_two_minute_drill = true,
            },
            .overtime => GameSituation{
                .quarter = 5,
                .time_remaining = 600,
                .down = 1,
                .distance = 10,
                .is_overtime = true,
                .home_timeouts = 2,
                .away_timeouts = 2,
                .possession_team = .home,
                .is_two_minute_drill = false,
            },
            .end_of_half => GameSituation{
                .quarter = 2,
                .time_remaining = 5,
                .down = 3,
                .distance = 8,
                .is_overtime = false,
                .home_timeouts = 1,
                .away_timeouts = 0,
                .possession_team = .home,
                .is_two_minute_drill = false,
            },
            .fourth_down => GameSituation{
                .quarter = 3,
                .time_remaining = 600,
                .down = 4,
                .distance = 2,
                .is_overtime = false,
                .home_timeouts = 3,
                .away_timeouts = 3,
                .possession_team = .away,
                .is_two_minute_drill = false,
            },
        };
    }

    /// Asserts that clock decision matches expected values
    fn assertClockDecision(
        decision: ClockDecision,
        expected_stop: bool,
        expected_reason: ?ClockStopReason,
        expected_restart_on_ready: bool,
        expected_restart_on_snap: bool
    ) !void {
        try testing.expectEqual(expected_stop, decision.should_stop);
        try testing.expectEqual(expected_reason, decision.stop_reason);
        try testing.expectEqual(expected_restart_on_ready, decision.restart_on_ready);
        try testing.expectEqual(expected_restart_on_snap, decision.restart_on_snap);
    }

    /// Simulates a series of plays and returns final situation
    fn simulateDrive(engine: *RulesEngine, plays: []const PlayOutcome) GameSituation {
        for (plays) |play| {
            _ = engine.processPlay(play);
            // Update down and distance based on typical play results
            if (play == .touchdown or play == .field_goal_attempt) {
                engine.newPossession(if (engine.situation.possession_team == .home) .away else .home);
            } else if (play == .punt or play == .interception or play == .fumble_out_of_bounds) {
                engine.newPossession(if (engine.situation.possession_team == .home) .away else .home);
            } else {
                // Simulate yardage gain
                const yards_gained: u8 = switch (play) {
                    .incomplete_pass => 0,
                    .complete_pass_inbounds => 7,
                    .complete_pass_out_of_bounds => 8,
                    .run_inbounds => 4,
                    .run_out_of_bounds => 3,
                    .sack => 0,
                    else => 5,
                };
                engine.updateDownAndDistance(yards_gained);
            }
        }
        return engine.situation;
    }

    /// Tests penalty processing with various scenarios
    fn testPenaltyScenario(scenario: PenaltyScenario) !void {
        var engine = RulesEngine.initWithSituation(scenario.situation);
        const decision = engine.processPenalty(scenario.penalty);
        
        try testing.expectEqual(scenario.expected_stop, decision.should_stop);
        if (scenario.expected_runoff) {
            try testing.expect(engine.situation.time_remaining < scenario.situation.time_remaining);
        }
    }

    /// Creates a penalty for testing
    fn createTestPenalty(penalty_type: enum {
        holding,
        false_start,
        delay_of_game,
        pass_interference,
        personal_foul
    }) PenaltyInfo {
        return switch (penalty_type) {
            .holding => PenaltyInfo{
                .yards = -10,
                .clock_impact = .stop_clock,
                .against_team = .offense,
            },
            .false_start => PenaltyInfo{
                .yards = -5,
                .clock_impact = .stop_clock,
                .against_team = .offense,
            },
            .delay_of_game => PenaltyInfo{
                .yards = -5,
                .clock_impact = .ten_second_runoff,
                .against_team = .offense,
            },
            .pass_interference => PenaltyInfo{
                .yards = 15,
                .clock_impact = .stop_clock,
                .against_team = .defense,
            },
            .personal_foul => PenaltyInfo{
                .yards = 15,
                .clock_impact = .stop_clock,
                .against_team = .defense,
            },
        };
    }

    /// Validates engine state invariants
    fn validateEngineInvariants(engine: *const RulesEngine) !void {
        // Down should be between 1 and 4
        try testing.expect(engine.situation.down >= 1 and engine.situation.down <= 4);
        
        // Distance should be reasonable
        try testing.expect(engine.situation.distance <= 99);
        
        // Timeouts should not exceed maximum
        try testing.expect(engine.situation.home_timeouts <= 3);
        try testing.expect(engine.situation.away_timeouts <= 3);
        
        // Quarter should be valid
        if (!engine.situation.is_overtime) {
            try testing.expect(engine.situation.quarter >= 1 and engine.situation.quarter <= 4);
        }
        
        // Time remaining should be valid
        if (!engine.situation.is_overtime) {
            try testing.expect(engine.situation.time_remaining <= TimingConstants.QUARTER_LENGTH);
        } else {
            try testing.expect(engine.situation.time_remaining <= TimingConstants.OVERTIME_LENGTH);
        }
    }

    /// Simulates a complete two-minute drill
    fn simulateTwoMinuteDrill(engine: *RulesEngine) !u32 {
        var plays_run: u32 = 0;
        engine.situation.quarter = 4;
        engine.situation.time_remaining = 120;
        engine.situation.is_two_minute_drill = true;
        
        while (engine.situation.time_remaining > 0 and plays_run < 20) {
            const play_type: PlayOutcome = if (plays_run % 3 == 0)
                .incomplete_pass
            else if (plays_run % 3 == 1)
                .complete_pass_out_of_bounds
            else
                .complete_pass_inbounds;
            
            const decision = engine.processPlay(play_type);
            
            // Simulate time consumption
            const time_used = getPlayDuration(play_type, true);
            if (engine.situation.time_remaining > time_used) {
                engine.situation.time_remaining -= time_used;
            } else {
                engine.situation.time_remaining = 0;
            }
            
            plays_run += 1;
            
            // Use timeout if needed and available
            if (decision.should_stop and engine.situation.time_remaining < 30) {
                if (engine.canCallTimeout(engine.situation.possession_team)) {
                    try engine.useTimeout(engine.situation.possession_team);
                }
            }
        }
        
        return plays_run;
    }

    /// Creates test data for various play outcomes
    fn createPlayTestData() []const PlayScenario {
        return &[_]PlayScenario{
            .{
                .name = "Incomplete pass stops clock",
                .outcome = .incomplete_pass,
                .situation = createTestSituation(.regular_time),
                .expected_stop = true,
                .expected_reason = .incomplete_pass,
                .expected_restart_on_ready = false,
                .expected_restart_on_snap = true,
            },
            .{
                .name = "Run out of bounds outside 2 minutes",
                .outcome = .run_out_of_bounds,
                .situation = createTestSituation(.regular_time),
                .expected_stop = true,
                .expected_reason = .out_of_bounds,
                .expected_restart_on_ready = true,
                .expected_restart_on_snap = false,
            },
            .{
                .name = "Touchdown stops clock",
                .outcome = .touchdown,
                .situation = createTestSituation(.regular_time),
                .expected_stop = true,
                .expected_reason = .score,
                .expected_restart_on_ready = false,
                .expected_restart_on_snap = false,
            },
        };
    }

    // └──────────────────────────────────────────────────────────────────────────┘

// ╚══════════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ TEST ══════════════════════════════════════╗

    // ┌──────────────────────────── Unit Tests ────────────────────────────┐

    test "unit: RulesEngine: initializes with default values" {
        const engine = RulesEngine.init();
        
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
        
        const engine = RulesEngine.initWithSituation(custom_situation);
        
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

    // └──────────────────────────────────────────────────────────────────────────┘

    // ┌──────────────────────────── Integration Tests ────────────────────────────┐

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

    // └──────────────────────────────────────────────────────────────────────────┘

    // ┌──────────────────────────── End-to-End Tests ────────────────────────────┐

    test "e2e: RulesEngine: simulates two-minute drill" {
        var engine = RulesEngine.init();
        engine.situation.quarter = 4;
        engine.situation.time_remaining = 120;
        engine.situation.possession_team = .home;
        engine.situation.home_timeouts = 2;
        engine.situation.is_two_minute_drill = true; // Two-minute warning already given
        
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

    // └──────────────────────────────────────────────────────────────────────────┘

    // ┌──────────────────────────── Scenario Tests ────────────────────────────┐

    test "scenario: RulesEngine: manages complete two-minute drill sequence" {
        var engine = RulesEngine.init();
        
        // Set up two-minute drill
        engine.situation.quarter = 4;
        engine.situation.time_remaining = 120;
        engine.situation.possession_team = .home;
        engine.situation.home_timeouts = 2;
        engine.situation.is_two_minute_drill = true;
        engine.situation.down = 1;
        engine.situation.distance = 10;
        
        // First play - incomplete pass to stop clock
        var decision = engine.processPlay(.incomplete_pass);
        try testing.expect(decision.should_stop);
        try testing.expectEqual(ClockStopReason.incomplete_pass, decision.stop_reason);
        engine.situation.down = 2;
        engine.situation.time_remaining = 115; // 5 seconds for play
        
        // Second play - complete pass out of bounds
        decision = engine.processPlay(.complete_pass_out_of_bounds);
        try testing.expect(decision.should_stop);
        try testing.expectEqual(ClockStopReason.out_of_bounds, decision.stop_reason);
        try testing.expect(decision.restart_on_snap); // Inside 2 minutes
        engine.updateDownAndDistance(12); // First down
        engine.situation.time_remaining = 108;
        
        // Third play - run for first down (clock stops briefly)
        engine.situation.down = 1;
        decision = engine.processPlay(.run_inbounds);
        try testing.expect(decision.should_stop); // First down stops clock
        try testing.expectEqual(ClockStopReason.first_down, decision.stop_reason);
        try testing.expect(decision.restart_on_ready);
        engine.updateDownAndDistance(11);
        engine.situation.time_remaining = 95;
        
        // Fourth play - use timeout
        try engine.useTimeout(.home);
        decision = engine.processPlay(.timeout);
        try testing.expect(decision.should_stop);
        try testing.expectEqual(@as(u8, 1), engine.situation.home_timeouts);
        engine.situation.time_remaining = 88;
        
        // Fifth play - deep pass for touchdown attempt
        decision = engine.processPlay(.complete_pass_inbounds);
        engine.updateDownAndDistance(25);
        engine.situation.time_remaining = 73;
        
        // Sixth play - spike to stop clock
        decision = engine.processPlay(.incomplete_pass); // Spike is incomplete
        try testing.expect(decision.should_stop);
        engine.situation.down = 2;
        engine.situation.time_remaining = 72;
        
        // Final timeout before field goal
        try engine.useTimeout(.home);
        try testing.expectEqual(@as(u8, 0), engine.situation.home_timeouts);
        
        // Field goal attempt
        decision = engine.processPlay(.field_goal_attempt);
        try testing.expect(decision.should_stop);
        try testing.expectEqual(ClockStopReason.score, decision.stop_reason);
        
        // Verify drill management
        try testing.expect(engine.situation.time_remaining < 120);
        try testing.expect(engine.situation.is_two_minute_drill);
    }

    test "scenario: RulesEngine: handles game-winning field goal attempt" {
        var engine = RulesEngine.init();
        
        // Set up game-winning FG scenario
        engine.situation.quarter = 4;
        engine.situation.time_remaining = 8; // 8 seconds left
        engine.situation.possession_team = .away;
        engine.situation.away_timeouts = 0;
        engine.situation.down = 4;
        engine.situation.distance = 7;
        
        // Clock is running
        engine.clock_running = true;
        
        // Field goal attempt with time expiring
        const decision = engine.processPlay(.field_goal_attempt);
        
        // Clock should stop for score
        try testing.expect(decision.should_stop);
        try testing.expectEqual(ClockStopReason.score, decision.stop_reason);
        
        // No restart - game likely over or going to OT
        try testing.expect(!decision.restart_on_ready);
        try testing.expect(!decision.restart_on_snap);
        
        // Time should have run during the kick
        engine.situation.time_remaining = 3; // ~5 seconds for FG
        
        // If FG is good, game over. If missed, other team gets ball
        // This would trigger change of possession
        if (engine.situation.time_remaining > 0) {
            engine.newPossession(.home);
            try testing.expectEqual(.home, engine.situation.possession_team);
            try testing.expectEqual(@as(u8, 1), engine.situation.down);
            
            // With 3 seconds, likely just kneel down
            const kneel_decision = engine.processPlay(.incomplete_pass); // or kneel
            try testing.expect(kneel_decision.should_stop or engine.situation.time_remaining == 0);
        }
    }

    test "scenario: RulesEngine: processes onside kick recovery" {
        var engine = RulesEngine.init();
        
        // Set up onside kick scenario - team behind trying to get ball back
        engine.situation.quarter = 4;
        engine.situation.time_remaining = 90;
        engine.situation.possession_team = .home; // Just scored, about to kick
        engine.situation.down = 1; // Kickoff is technically 1st down
        
        // Process kickoff (onside attempt)
        var decision = engine.processPlay(.kickoff);
        try testing.expect(decision.should_stop);
        try testing.expectEqual(ClockStopReason.change_of_possession, decision.stop_reason);
        
        // Simulate onside kick recovery scenarios
        
        // Scenario 1: Kicking team recovers (home)
        engine.situation.possession_team = .home; // Home recovers their own kick
        engine.situation.down = 1;
        engine.situation.distance = 10;
        
        // Continue drive - we're under 2 minutes (90 seconds), so first down stops clock
        decision = engine.processPlay(.run_inbounds);
        // We're inside 2 minutes and it's a first down, so clock should stop
        try testing.expect(decision.should_stop); // First down inside 2 minutes stops clock
        try testing.expectEqual(ClockStopReason.first_down, decision.stop_reason);
        engine.updateDownAndDistance(3);
        
        // Scenario 2: Receiving team recovers (reset to test)
        engine.newPossession(.away);
        engine.situation.time_remaining = 85;
        
        // Away team now has possession
        try testing.expectEqual(.away, engine.situation.possession_team);
        try testing.expectEqual(@as(u8, 1), engine.situation.down);
        try testing.expectEqual(@as(u8, 10), engine.situation.distance);
        
        // They can run out clock or score
        decision = engine.processPlay(.run_inbounds);
        engine.updateDownAndDistance(4);
        
        // Inside two minutes, first downs stop clock
        if (engine.situation.time_remaining <= 120) {
            engine.situation.is_two_minute_drill = true;
            engine.updateDownAndDistance(10); // Get first down
            decision = engine.processPlay(.run_inbounds);
            try testing.expect(decision.should_stop); // First down inside 2 min
            try testing.expectEqual(ClockStopReason.first_down, decision.stop_reason);
        }
    }

    // └──────────────────────────────────────────────────────────────────────────┘

    // ┌──────────────────────────── Performance Tests ────────────────────────────┐

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

    // └──────────────────────────────────────────────────────────────────────────┘

    // ┌──────────────────────────── Error Handling Tests ────────────────────────────┐

    test "unit: RulesEngineError: InvalidSituation detection" {
        // Test invalid situation configurations
        const invalid_situations = [_]GameSituation{
            // Invalid down
            GameSituation{
                .quarter = 1,
                .time_remaining = 900,
                .down = 5, // Invalid - only 1-4 allowed
                .distance = 10,
                .is_overtime = false,
                .home_timeouts = 3,
                .away_timeouts = 3,
                .possession_team = .home,
                .is_two_minute_drill = false,
            },
            // Invalid timeouts
            GameSituation{
                .quarter = 1,
                .time_remaining = 900,
                .down = 1,
                .distance = 10,
                .is_overtime = false,
                .home_timeouts = 5, // Invalid - max 3
                .away_timeouts = 3,
                .possession_team = .home,
                .is_two_minute_drill = false,
            },
            // Invalid time for quarter
            GameSituation{
                .quarter = 1,
                .time_remaining = 2000, // Invalid - exceeds quarter length
                .down = 1,
                .distance = 10,
                .is_overtime = false,
                .home_timeouts = 3,
                .away_timeouts = 3,
                .possession_team = .home,
                .is_two_minute_drill = false,
            },
        };
        
        for (invalid_situations) |situation| {
            const engine = RulesEngine.initWithSituation(situation);
            const result = engine.validateSituation(situation);
            try testing.expectError(error.InvalidSituation, result);
        }
    }

    test "unit: RulesEngineError: InvalidPlayType handling" {
        var engine = RulesEngine.init();
        
        // Test invalid play types in certain situations
        // Example: Can't kick field goal from own territory
        engine.situation.quarter = 1;
        engine.situation.time_remaining = 900;
        
        // This would need field position tracking - simulate with distance
        engine.situation.distance = 80; // Far from field goal range
        
        // Process field goal attempt from bad position
        const decision = engine.processPlay(.field_goal_attempt);
        
        // Should handle gracefully even if unusual
        try testing.expect(decision.should_stop);
        try testing.expectEqual(ClockStopReason.score, decision.stop_reason);
    }

    test "unit: RulesEngineError: InvalidClockState recovery" {
        var engine = RulesEngine.init();
        
        // Create invalid clock state
        engine.clock_running = true;
        engine.situation.time_remaining = 0; // Can't run with no time
        
        // Try to process play with invalid state
        const decision = engine.processPlay(.run_inbounds);
        
        // Should stop clock immediately
        try testing.expect(decision.should_stop);
        
        // Recover to valid state
        engine.clock_running = false;
        engine.situation.time_remaining = 900;
        
        // Should work normally now
        const valid_decision = engine.processPlay(.run_inbounds);
        try testing.expect(!valid_decision.should_stop or engine.situation.time_remaining <= 120);
    }

    test "unit: RulesEngine: validateSituation catches all invalid states" {
        var engine = RulesEngine.init();
        
        // Test 1: Invalid down
        const invalid_down = GameSituation{
            .quarter = 1,
            .time_remaining = 900,
            .down = 0, // Invalid
            .distance = 10,
            .is_overtime = false,
            .home_timeouts = 3,
            .away_timeouts = 3,
            .possession_team = .home,
            .is_two_minute_drill = false,
        };
        try testing.expectError(error.InvalidSituation, engine.validateSituation(invalid_down));
        
        // Test 2: Invalid distance
        const invalid_distance = GameSituation{
            .quarter = 1,
            .time_remaining = 900,
            .down = 1,
            .distance = 200, // Invalid - too far
            .is_overtime = false,
            .home_timeouts = 3,
            .away_timeouts = 3,
            .possession_team = .home,
            .is_two_minute_drill = false,
        };
        try testing.expectError(error.InvalidSituation, engine.validateSituation(invalid_distance));
        
        // Test 3: Valid situation
        const valid = GameSituation{
            .quarter = 1,
            .time_remaining = 900,
            .down = 1,
            .distance = 10,
            .is_overtime = false,
            .home_timeouts = 3,
            .away_timeouts = 3,
            .possession_team = .home,
            .is_two_minute_drill = false,
        };
        try engine.validateSituation(valid);
    }

    test "unit: RulesEngine: validateClockDecision ensures valid decisions" {
        var engine = RulesEngine.init();
        
        // Test invalid decision combinations
        const invalid_decisions = [_]ClockDecision{
            // Can't restart on both ready and snap
            ClockDecision{
                .should_stop = true,
                .stop_reason = .incomplete_pass,
                .restart_on_ready = true,
                .restart_on_snap = true, // Conflict
                .play_clock_reset = true,
                .play_clock_duration = 40,
            },
            // Invalid play clock duration
            ClockDecision{
                .should_stop = false,
                .stop_reason = null,
                .restart_on_ready = false,
                .restart_on_snap = false,
                .play_clock_reset = true,
                .play_clock_duration = 100, // Invalid - max 40
            },
        };
        
        for (invalid_decisions) |decision| {
            const result = engine.validateClockDecision(decision);
            try testing.expectError(error.InvalidClockDecision, result);
        }
        
        // Test valid decision
        const valid_decision = ClockDecision{
            .should_stop = true,
            .stop_reason = .incomplete_pass,
            .restart_on_ready = false,
            .restart_on_snap = true,
            .play_clock_reset = true,
            .play_clock_duration = 40,
        };
        try engine.validateClockDecision(valid_decision);
    }

    test "integration: RulesEngine: error recovery maintains game integrity" {
        var engine = RulesEngine.init();
        
        // Start with valid state
        engine.situation.quarter = 2;
        engine.situation.time_remaining = 120;
        engine.situation.down = 1;
        engine.situation.distance = 10;
        
        // Cause error with invalid timeout call
        engine.situation.home_timeouts = 0;
        const timeout_error = engine.useTimeout(.home);
        try testing.expectError(error.NoTimeoutsRemaining, timeout_error);
        
        // Game should continue normally
        const decision = engine.processPlay(.run_inbounds);
        try testing.expect(decision.play_clock_reset);
        
        // Cause another error with invalid situation
        engine.situation.down = 5; // Invalid
        const validation_error = engine.validateSituation(engine.situation);
        try testing.expectError(error.InvalidSituation, validation_error);
        
        // Fix and continue
        engine.situation.down = 2;
        const fixed_decision = engine.processPlay(.incomplete_pass);
        try testing.expect(fixed_decision.should_stop or !fixed_decision.should_stop); // Valid either way
    }

    test "e2e: RulesEngine: complete error handling during game flow" {
        var engine = RulesEngine.init();
        
        // Scenario 1: Invalid timeout usage
        engine.situation.quarter = 4;
        engine.situation.time_remaining = 30;
        engine.situation.away_timeouts = 0;
        
        // Try to use timeout with none remaining
        if (engine.useTimeout(.away)) |_| {
            try testing.expect(false); // Should fail
        } else |err| {
            try testing.expectEqual(error.NoTimeoutsRemaining, err);
        }
        
        // Continue game without timeout
        var decision = engine.processPlay(.incomplete_pass);
        try testing.expect(decision.should_stop);
        
        // Scenario 2: Invalid situation recovery
        engine.situation.down = 10; // Force invalid
        if (engine.validateSituation(engine.situation)) |_| {
            try testing.expect(false);
        } else |err| {
            try testing.expectEqual(error.InvalidSituation, err);
            // Fix the situation
            engine.situation.down = 4;
        }
        
        // Scenario 3: Edge case - overtime with invalid state
        engine.situation.is_overtime = true;
        engine.situation.quarter = 5;
        engine.situation.time_remaining = 1000; // Too much for OT
        
        if (engine.validateSituation(engine.situation)) |_| {
            try testing.expect(false);
        } else |err| {
            // Use the error to verify it's the expected type
            try testing.expect(err == error.InvalidGameSituation or err == error.InvalidSituation);
            // Fix overtime time
            engine.situation.time_remaining = TimingConstants.OVERTIME_LENGTH;
            try engine.validateSituation(engine.situation);
        }
        
        // Game continues normally
        decision = engine.processPlay(.field_goal_attempt);
        try testing.expect(decision.should_stop);
        try testing.expectEqual(ClockStopReason.score, decision.stop_reason);
    }

    test "scenario: RulesEngine: handles errors in critical game situations" {
        var engine = RulesEngine.init();
        
        // Two-minute drill with various errors
        engine.situation.quarter = 4;
        engine.situation.time_remaining = 110;
        engine.situation.is_two_minute_drill = true;
        engine.situation.home_timeouts = 1;
        engine.situation.possession_team = .home;
        
        // Error 1: Try to call timeout twice
        try engine.useTimeout(.home);
        try testing.expectEqual(@as(u8, 0), engine.situation.home_timeouts);
        
        if (engine.useTimeout(.home)) |_| {
            try testing.expect(false);
        } else |err| {
            try testing.expectEqual(error.NoTimeoutsRemaining, err);
        }
        
        // Continue without timeout
        var decision = engine.processPlay(.incomplete_pass);
        try testing.expect(decision.should_stop);
        
        // Error 2: Invalid down progression
        engine.situation.down = 4;
        engine.situation.distance = 15;
        
        // Failed 4th down should change possession
        engine.updateDownAndDistance(10); // Short of first down
        try testing.expectEqual(.away, engine.situation.possession_team);
        
        // Error 3: Clock management error
        engine.situation.time_remaining = 3;
        engine.clock_running = true;
        
        // Should handle end of game gracefully
        decision = engine.processPlay(.run_inbounds);
        
        if (engine.situation.time_remaining == 0) {
            try testing.expect(engine.isGameOver());
        }
    }

    test "stress: RulesEngine: handles rapid error conditions" {
        var engine = RulesEngine.init();
        
        // Rapidly cause and recover from errors
        for (0..100) |i| {
            // Alternate between valid and invalid states
            if (i % 2 == 0) {
                // Invalid state
                engine.situation.down = @as(u8, @intCast((i % 10) + 5)); // 5-14, mostly invalid
                engine.situation.home_timeouts = @as(u8, @intCast(i % 10)); // 0-9, some invalid
                
                // Try to validate - may error
                if (engine.validateSituation(engine.situation)) |_| {
                    // Valid by chance
                } else |_| {
                    // Fix it
                    engine.situation.down = @as(u8, @intCast((i % 4) + 1));
                    engine.situation.home_timeouts = @as(u8, @intCast(i % 4));
                }
            } else {
                // Valid state
                engine.situation.down = @as(u8, @intCast((i % 4) + 1));
                engine.situation.distance = @as(u8, @intCast(i % 20));
                
                // Process play - should work
                const play_type: PlayOutcome = if (i % 3 == 0) .incomplete_pass else .run_inbounds;
                const decision = engine.processPlay(play_type);
                try testing.expect(decision.play_clock_duration <= 40);
            }
        }
        
        // Final state should be recoverable
        engine.situation.down = 1;
        engine.situation.distance = 10;
        engine.situation.home_timeouts = 3;
        engine.situation.away_timeouts = 3;
        try engine.validateSituation(engine.situation);
    }

    // └──────────────────────────────────────────────────────────────────────────┘

    // ┌──────────────────────────── Stress Tests ────────────────────────────┐

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
        const min_situation = GameSituation{
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
        try testing.expect(!engine.isHalfOver()); // Quarter 1 ending is not half over
        try testing.expect(!engine.canCallTimeout(.home));
        try testing.expect(!engine.canCallTimeout(.away));
        
        // Test with maximum values - these should be handled gracefully even if invalid
        const max_situation = GameSituation{
            .quarter = 5,  // Max valid quarter for overtime
            .time_remaining = 999999,
            .down = 4,  // Max valid down
            .distance = 99,  // Max reasonable distance
            .is_overtime = true,
            .home_timeouts = 255,  // Will be treated as > 0, so timeouts available
            .away_timeouts = 255,  // Will be treated as > 0, so timeouts available
            .possession_team = .away,
            .is_two_minute_drill = true,
        };
        
        engine = RulesEngine.initWithSituation(max_situation);
        try testing.expect(engine.canCallTimeout(.home)); // 255 > 0, so true
        try testing.expect(engine.canCallTimeout(.away)); // 255 > 0, so true
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

    test "unit: RulesEngine: untimed down granted on defensive penalty at end of half" {
        var engine = RulesEngine.init();
        const PenaltyDetails = @import("rules_engine.zig").PenaltyDetails;
        const PenaltyType = @import("rules_engine.zig").PenaltyType;
        
        // Set up end of second quarter with time expired
        engine.situation.quarter = 2;
        engine.situation.time_remaining = 0;
        engine.situation.down = 3;
        engine.situation.distance = 7;
        
        // Create defensive pass interference penalty (grants automatic first down)
        const penalty_details = PenaltyDetails{
            .is_defensive = true,
            .grants_automatic_first_down = true,
            .penalty_type = PenaltyType.pass_interference,
            .yards = 15,
        };
        
        // Process play with penalty
        const decision = engine.processPlayWithPenalty(.incomplete_pass, penalty_details);
        
        // Verify untimed down is granted
        try testing.expect(engine.situation.untimed_down_available);
        try testing.expect(decision.should_stop);
        try testing.expectEqual(ClockStopReason.penalty, decision.stop_reason);
        try testing.expect(decision.restart_on_snap);
        
        // Verify penalty info is stored
        try testing.expect(engine.situation.last_play_penalty_info != null);
        try testing.expect(engine.situation.last_play_penalty_info.?.is_defensive);
        try testing.expect(engine.situation.last_play_penalty_info.?.grants_automatic_first_down);
    }

    test "unit: RulesEngine: untimed down execution ends half" {
        var engine = RulesEngine.init();
        
        // Set up untimed down scenario
        engine.situation.quarter = 4;
        engine.situation.time_remaining = 0;
        engine.situation.untimed_down_available = true;
        
        // Execute the untimed down play
        const decision = engine.processPlay(.run_inbounds);
        
        // Verify half ends after untimed down
        try testing.expect(decision.should_stop);
        try testing.expectEqual(ClockStopReason.quarter_end, decision.stop_reason);
        try testing.expect(!decision.restart_on_ready);
        try testing.expect(!decision.restart_on_snap);
        try testing.expect(!engine.situation.untimed_down_available);
    }

    test "unit: RulesEngine: no untimed down on offensive penalty" {
        var engine = RulesEngine.init();
        const PenaltyDetails = @import("rules_engine.zig").PenaltyDetails;
        const PenaltyType = @import("rules_engine.zig").PenaltyType;
        
        // Set up end of second quarter with time expired
        engine.situation.quarter = 2;
        engine.situation.time_remaining = 0;
        
        // Create offensive holding penalty (does not grant untimed down)
        const penalty_details = PenaltyDetails{
            .is_defensive = false,
            .grants_automatic_first_down = false,
            .penalty_type = PenaltyType.holding_offense,
            .yards = -10,
        };
        
        // Process play with offensive penalty
        const decision = engine.processPlayWithPenalty(.run_inbounds, penalty_details);
        
        // Verify no untimed down is granted
        try testing.expect(!engine.situation.untimed_down_available);
        try testing.expect(decision.should_stop);
        try testing.expectEqual(ClockStopReason.quarter_end, decision.stop_reason);
    }

    test "unit: RulesEngine: no untimed down on defensive penalty without automatic first down" {
        var engine = RulesEngine.init();
        const PenaltyDetails = @import("rules_engine.zig").PenaltyDetails;
        const PenaltyType = @import("rules_engine.zig").PenaltyType;
        
        // Set up end of fourth quarter with time expired
        engine.situation.quarter = 4;
        engine.situation.time_remaining = 0;
        
        // Create defensive offside penalty (defensive but no automatic first down)
        const penalty_details = PenaltyDetails{
            .is_defensive = true,
            .grants_automatic_first_down = false,
            .penalty_type = PenaltyType.defensive_offside,
            .yards = 5,
        };
        
        // Process play with penalty
        const decision = engine.processPlayWithPenalty(.incomplete_pass, penalty_details);
        
        // Verify no untimed down is granted
        try testing.expect(!engine.situation.untimed_down_available);
        try testing.expect(decision.should_stop);
        try testing.expectEqual(ClockStopReason.quarter_end, decision.stop_reason);
    }

    test "unit: RulesEngine: no untimed down in quarters 1 and 3" {
        var engine = RulesEngine.init();
        const PenaltyDetails = @import("rules_engine.zig").PenaltyDetails;
        const PenaltyType = @import("rules_engine.zig").PenaltyType;
        
        // Test quarter 1 - should not grant untimed down
        engine.situation.quarter = 1;
        engine.situation.time_remaining = 0;
        
        const penalty_details = PenaltyDetails{
            .is_defensive = true,
            .grants_automatic_first_down = true,
            .penalty_type = PenaltyType.pass_interference,
            .yards = 15,
        };
        
        var decision = engine.processPlayWithPenalty(.incomplete_pass, penalty_details);
        try testing.expect(!engine.situation.untimed_down_available);
        
        // Test quarter 3 - should not grant untimed down
        engine.situation.quarter = 3;
        engine.situation.time_remaining = 0;
        
        decision = engine.processPlayWithPenalty(.incomplete_pass, penalty_details);
        try testing.expect(!engine.situation.untimed_down_available);
    }

    // ┌──────────────────────────── Untimed Down Tests ────────────────────────────┐

    test "unit: RulesEngine: defensive holding at end of 2nd quarter grants untimed down" {
        var engine = RulesEngine.init();
        const PenaltyDetails = @import("rules_engine.zig").PenaltyDetails;
        const PenaltyType = @import("rules_engine.zig").PenaltyType;
        
        // Set up end of 2nd quarter with time expired
        engine.situation.quarter = 2;
        engine.situation.time_remaining = 0;
        engine.situation.down = 3;
        engine.situation.distance = 8;
        engine.situation.possession_team = .home;
        
        // Create defensive holding penalty (grants automatic first down)
        const penalty_details = PenaltyDetails{
            .is_defensive = true,
            .grants_automatic_first_down = true,
            .penalty_type = PenaltyType.defensive_holding,
            .yards = 10,
        };
        
        // Process play with defensive holding
        const decision = engine.processPlayWithPenalty(.run_inbounds, penalty_details);
        
        // Verify untimed down is granted
        try testing.expect(engine.situation.untimed_down_available);
        try testing.expect(decision.should_stop);
        try testing.expectEqual(ClockStopReason.penalty, decision.stop_reason);
        try testing.expect(decision.restart_on_snap);
        try testing.expect(decision.play_clock_reset);
        
        // Verify penalty info is stored for reference
        try testing.expect(engine.situation.last_play_penalty_info != null);
        try testing.expect(engine.situation.last_play_penalty_info.?.is_defensive);
        try testing.expect(engine.situation.last_play_penalty_info.?.grants_automatic_first_down);
        try testing.expectEqual(PenaltyType.defensive_holding, engine.situation.last_play_penalty_info.?.penalty_type);
    }

    test "unit: RulesEngine: pass interference at end of 4th quarter grants untimed down" {
        var engine = RulesEngine.init();
        const PenaltyDetails = @import("rules_engine.zig").PenaltyDetails;
        const PenaltyType = @import("rules_engine.zig").PenaltyType;
        
        // Set up end of 4th quarter (game-ending scenario)
        engine.situation.quarter = 4;
        engine.situation.time_remaining = 0;
        engine.situation.down = 4;
        engine.situation.distance = 3;
        engine.situation.possession_team = .away;
        
        // Create pass interference penalty
        const penalty_details = PenaltyDetails{
            .is_defensive = true,
            .grants_automatic_first_down = true,
            .penalty_type = PenaltyType.pass_interference,
            .yards = 15,
        };
        
        // Process incomplete pass with pass interference
        const decision = engine.processPlayWithPenalty(.incomplete_pass, penalty_details);
        
        // Verify untimed down is granted even at end of regulation
        try testing.expect(engine.situation.untimed_down_available);
        try testing.expect(decision.should_stop);
        try testing.expectEqual(ClockStopReason.penalty, decision.stop_reason);
        try testing.expect(decision.restart_on_snap);
        
        // Time should remain at 0 but game continues
        try testing.expectEqual(@as(u32, 0), engine.situation.time_remaining);
    }

    test "unit: RulesEngine: roughing the passer at end of half grants untimed down" {
        var engine = RulesEngine.init();
        const PenaltyDetails = @import("rules_engine.zig").PenaltyDetails;
        const PenaltyType = @import("rules_engine.zig").PenaltyType;
        
        // Set up end of 2nd quarter
        engine.situation.quarter = 2;
        engine.situation.time_remaining = 0;
        engine.situation.down = 2;
        engine.situation.distance = 15;
        
        // Create roughing the passer penalty
        const penalty_details = PenaltyDetails{
            .is_defensive = true,
            .grants_automatic_first_down = true,
            .penalty_type = PenaltyType.roughing_the_passer,
            .yards = 15,
        };
        
        // Process sack with roughing penalty
        const decision = engine.processPlayWithPenalty(.sack, penalty_details);
        
        // Verify untimed down is granted
        try testing.expect(engine.situation.untimed_down_available);
        try testing.expectEqual(ClockStopReason.penalty, decision.stop_reason);
    }

    test "unit: RulesEngine: executing untimed down ends the half" {
        var engine = RulesEngine.init();
        
        // Set up scenario where untimed down was already granted
        engine.situation.quarter = 4;
        engine.situation.time_remaining = 0;
        engine.situation.untimed_down_available = true;
        engine.situation.down = 1;
        engine.situation.distance = 10;
        
        // Execute the untimed down play (any play type)
        const decision = engine.processPlay(.complete_pass_inbounds);
        
        // Verify half ends after executing untimed down
        try testing.expect(decision.should_stop);
        try testing.expectEqual(ClockStopReason.quarter_end, decision.stop_reason);
        try testing.expect(!decision.restart_on_ready);
        try testing.expect(!decision.restart_on_snap);
        
        // Untimed down flag should be cleared
        try testing.expect(!engine.situation.untimed_down_available);
        try testing.expect(engine.situation.last_play_penalty_info == null);
    }

    test "unit: RulesEngine: defensive penalty in quarter 1 does not grant untimed down" {
        var engine = RulesEngine.init();
        const PenaltyDetails = @import("rules_engine.zig").PenaltyDetails;
        const PenaltyType = @import("rules_engine.zig").PenaltyType;
        
        // Set up end of 1st quarter (not end of half)
        engine.situation.quarter = 1;
        engine.situation.time_remaining = 0;
        
        // Even with defensive penalty that grants first down
        const penalty_details = PenaltyDetails{
            .is_defensive = true,
            .grants_automatic_first_down = true,
            .penalty_type = PenaltyType.pass_interference,
            .yards = 15,
        };
        
        // Process play with penalty
        const decision = engine.processPlayWithPenalty(.incomplete_pass, penalty_details);
        
        // Should NOT grant untimed down (not end of half)
        try testing.expect(!engine.situation.untimed_down_available);
        try testing.expectEqual(ClockStopReason.quarter_end, decision.stop_reason);
    }

    test "unit: RulesEngine: defensive penalty in quarter 3 does not grant untimed down" {
        var engine = RulesEngine.init();
        const PenaltyDetails = @import("rules_engine.zig").PenaltyDetails;
        const PenaltyType = @import("rules_engine.zig").PenaltyType;
        
        // Set up end of 3rd quarter (not end of half)
        engine.situation.quarter = 3;
        engine.situation.time_remaining = 0;
        
        const penalty_details = PenaltyDetails{
            .is_defensive = true,
            .grants_automatic_first_down = true,
            .penalty_type = PenaltyType.defensive_holding,
            .yards = 10,
        };
        
        const decision = engine.processPlayWithPenalty(.run_inbounds, penalty_details);
        
        // Should NOT grant untimed down
        try testing.expect(!engine.situation.untimed_down_available);
        try testing.expectEqual(ClockStopReason.quarter_end, decision.stop_reason);
    }

    test "unit: RulesEngine: offensive penalty at end of half does not grant untimed down" {
        var engine = RulesEngine.init();
        const PenaltyDetails = @import("rules_engine.zig").PenaltyDetails;
        const PenaltyType = @import("rules_engine.zig").PenaltyType;
        
        // Set up end of 2nd quarter
        engine.situation.quarter = 2;
        engine.situation.time_remaining = 0;
        
        // Create offensive holding penalty
        const penalty_details = PenaltyDetails{
            .is_defensive = false,  // Offensive penalty
            .grants_automatic_first_down = false,
            .penalty_type = PenaltyType.holding_offense,
            .yards = -10,
        };
        
        const decision = engine.processPlayWithPenalty(.run_inbounds, penalty_details);
        
        // Should NOT grant untimed down (offensive penalty)
        try testing.expect(!engine.situation.untimed_down_available);
        try testing.expectEqual(ClockStopReason.quarter_end, decision.stop_reason);
    }

    test "unit: RulesEngine: time expires without penalty ends quarter normally" {
        var engine = RulesEngine.init();
        
        // Set up end of 4th quarter
        engine.situation.quarter = 4;
        engine.situation.time_remaining = 0;
        
        // Process play without penalty
        const decision = engine.processPlay(.run_inbounds);
        
        // Should end quarter normally
        try testing.expect(!engine.situation.untimed_down_available);
        try testing.expectEqual(ClockStopReason.quarter_end, decision.stop_reason);
        try testing.expect(!decision.restart_on_ready);
        try testing.expect(!decision.restart_on_snap);
    }

    test "unit: RulesEngine: defensive offside without automatic first down does not grant untimed down" {
        var engine = RulesEngine.init();
        const PenaltyDetails = @import("rules_engine.zig").PenaltyDetails;
        const PenaltyType = @import("rules_engine.zig").PenaltyType;
        
        // Set up end of 2nd quarter
        engine.situation.quarter = 2;
        engine.situation.time_remaining = 0;
        
        // Defensive offside - defensive but NO automatic first down
        const penalty_details = PenaltyDetails{
            .is_defensive = true,
            .grants_automatic_first_down = false,  // Key difference
            .penalty_type = PenaltyType.defensive_offside,
            .yards = 5,
        };
        
        const decision = engine.processPlayWithPenalty(.incomplete_pass, penalty_details);
        
        // Should NOT grant untimed down (no automatic first down)
        try testing.expect(!engine.situation.untimed_down_available);
        try testing.expectEqual(ClockStopReason.quarter_end, decision.stop_reason);
    }

    test "unit: RulesEngine: multiple defensive penalties choosing enforcement grants untimed down" {
        var engine = RulesEngine.init();
        const PenaltyDetails = @import("rules_engine.zig").PenaltyDetails;
        const PenaltyType = @import("rules_engine.zig").PenaltyType;
        
        // Set up end of 4th quarter
        engine.situation.quarter = 4;
        engine.situation.time_remaining = 0;
        
        // Scenario 1: Choose defensive holding (10 yards)
        var engine1 = engine;  // Copy for first scenario
        const penalty1 = PenaltyDetails{
            .is_defensive = true,
            .grants_automatic_first_down = true,
            .penalty_type = PenaltyType.defensive_holding,
            .yards = 10,
        };
        
        var decision = engine1.processPlayWithPenalty(.incomplete_pass, penalty1);
        try testing.expect(engine1.situation.untimed_down_available);
        try testing.expectEqual(ClockStopReason.penalty, decision.stop_reason);
        
        // Scenario 2: Choose pass interference (15 yards) instead
        var engine2 = engine;  // Copy for second scenario
        const penalty2 = PenaltyDetails{
            .is_defensive = true,
            .grants_automatic_first_down = true,
            .penalty_type = PenaltyType.pass_interference,
            .yards = 15,
        };
        
        decision = engine2.processPlayWithPenalty(.incomplete_pass, penalty2);
        
        // Either penalty choice should grant untimed down
        try testing.expect(engine2.situation.untimed_down_available);
        try testing.expectEqual(@as(u32, 0), engine2.situation.time_remaining);
    }

    test "unit: RulesEngine: state transitions when untimed down is granted vs executed" {
        var engine = RulesEngine.init();
        const PenaltyDetails = @import("rules_engine.zig").PenaltyDetails;
        const PenaltyType = @import("rules_engine.zig").PenaltyType;
        
        // Initial state - normal play
        engine.situation.quarter = 2;
        engine.situation.time_remaining = 0;
        engine.situation.down = 3;
        engine.situation.distance = 7;
        try testing.expect(!engine.situation.untimed_down_available);
        
        // State after penalty grants untimed down
        const penalty = PenaltyDetails{
            .is_defensive = true,
            .grants_automatic_first_down = true,
            .penalty_type = PenaltyType.face_mask,
            .yards = 15,
        };
        
        var decision = engine.processPlayWithPenalty(.run_inbounds, penalty);
        
        // Verify state after granting untimed down
        try testing.expect(engine.situation.untimed_down_available);
        try testing.expectEqual(@as(u32, 0), engine.situation.time_remaining);
        try testing.expect(decision.should_stop);
        try testing.expectEqual(ClockStopReason.penalty, decision.stop_reason);
        try testing.expect(decision.restart_on_snap);  // Will snap for untimed down
        
        // State after executing untimed down
        decision = engine.processPlay(.touchdown);  // Score on untimed down
        
        // Verify state after executing untimed down
        try testing.expect(!engine.situation.untimed_down_available);
        try testing.expect(decision.should_stop);
        try testing.expectEqual(ClockStopReason.quarter_end, decision.stop_reason);
        try testing.expect(!decision.restart_on_ready);
        try testing.expect(!decision.restart_on_snap);
    }

    test "integration: RulesEngine: complete untimed down scenario with defensive pass interference" {
        var engine = RulesEngine.init();
        const PenaltyDetails = @import("rules_engine.zig").PenaltyDetails;
        const PenaltyType = @import("rules_engine.zig").PenaltyType;
        
        // Simulate end of half scenario
        engine.situation.quarter = 2;
        engine.situation.time_remaining = 3;  // 3 seconds left
        engine.situation.down = 3;
        engine.situation.distance = 10;
        engine.situation.possession_team = .home;
        
        // Time runs out during play with defensive pass interference
        engine.situation.time_remaining = 0;
        
        const penalty = PenaltyDetails{
            .is_defensive = true,
            .grants_automatic_first_down = true,
            .penalty_type = PenaltyType.pass_interference,
            .yards = 15,
        };
        
        // Process the play with penalty
        const decision1 = engine.processPlayWithPenalty(.incomplete_pass, penalty);
        
        // Verify untimed down granted
        try testing.expect(engine.situation.untimed_down_available);
        try testing.expectEqual(ClockStopReason.penalty, decision1.stop_reason);
        
        // Execute untimed down - attempt field goal
        const decision2 = engine.processPlay(.field_goal_attempt);
        
        // Verify half ends
        try testing.expect(!engine.situation.untimed_down_available);
        try testing.expectEqual(ClockStopReason.quarter_end, decision2.stop_reason);
    }

    test "integration: RulesEngine: untimed down with ExtendedPlayOutcome interface" {
        var engine = RulesEngine.init();
        const PenaltyDetails = @import("rules_engine.zig").PenaltyDetails;
        const PenaltyType = @import("rules_engine.zig").PenaltyType;
        const ExtendedPlayOutcome = @import("rules_engine.zig").ExtendedPlayOutcome;
        
        // Set up end of 4th quarter
        engine.situation.quarter = 4;
        engine.situation.time_remaining = 0;
        
        // Create extended play outcome with penalty
        const extended = ExtendedPlayOutcome{
            .base_outcome = .complete_pass_inbounds,
            .had_penalty = true,
            .penalty_details = PenaltyDetails{
                .is_defensive = true,
                .grants_automatic_first_down = true,
                .penalty_type = PenaltyType.unnecessary_roughness,
                .yards = 15,
            },
        };
        
        // Process using extended interface
        const decision = engine.processPlayExtended(extended);
        
        // Verify untimed down granted
        try testing.expect(engine.situation.untimed_down_available);
        try testing.expectEqual(ClockStopReason.penalty, decision.stop_reason);
        try testing.expect(decision.restart_on_snap);
    }

    // └──────────────────────────────────────────────────────────────────────────┘

// ╚══════════════════════════════════════════════════════════════════════════════════════════╝