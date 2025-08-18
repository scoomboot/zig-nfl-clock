// rules_engine.zig — NFL clock rules implementation
//
// repo   : https://github.com/zig-nfl-clock
// docs   : https://zig-nfl-clock.github.io/docs/lib/game_clock/utils/rules_engine
// author : https://github.com/fisty
//
// Vibe coded by Scoom.

// ╔══════════════════════════════════════ PACK ══════════════════════════════════════╗

    const std = @import("std");

    /// NFL clock rules engine implementation.
    ///
    /// This module implements the official NFL timing rules, managing clock behavior
    /// based on play outcomes, game situations, and special circumstances like
    /// two-minute warnings, timeouts, and penalties.

    /// NFL timing constants (in seconds)
    pub const TimingConstants = struct {
        /// Length of a quarter in seconds
        pub const QUARTER_LENGTH: u32 = 900; // 15 minutes
        /// Play clock duration in seconds
        pub const PLAY_CLOCK_DURATION: u32 = 40;
        /// Play clock after timeout or injury
        pub const PLAY_CLOCK_AFTER_TIMEOUT: u32 = 25;
        /// Two-minute warning time
        pub const TWO_MINUTE_WARNING: u32 = 120;
        /// Overtime quarter length (regular season)
        pub const OVERTIME_LENGTH: u32 = 600; // 10 minutes
        /// Timeout duration in seconds
        pub const TIMEOUT_DURATION: u32 = 60;
        /// Injury timeout duration
        pub const INJURY_TIMEOUT_DURATION: u32 = 120;
    };

// ╚══════════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ TYPES ══════════════════════════════════════╗

    /// Rules engine specific error set
    pub const RulesEngineError = error{
        InvalidQuarter,
        InvalidDown,
        InvalidDistance,
        InvalidTimeoutCount,
        InvalidSituation,
        InvalidGameSituation,
        RuleViolation,
        ClockManagementError,
    };

    /// Error context for rules engine
    pub const RulesErrorContext = struct {
        error_type: RulesEngineError,
        situation: ?GameSituation = null,
        message: []const u8,
        rule_reference: []const u8,
    };

    /// Play outcome types that affect clock
    pub const PlayOutcome = enum {
        incomplete_pass,
        complete_pass_inbounds,
        complete_pass_out_of_bounds,
        run_inbounds,
        run_out_of_bounds,
        touchdown,
        field_goal_attempt,
        punt,
        kickoff,
        penalty,
        timeout,
        injury,
        two_minute_warning,
        quarter_end,
        sack,
        fumble_inbounds,
        fumble_out_of_bounds,
        interception,
        safety,
    };

    /// Clock stop reasons
    pub const ClockStopReason = enum {
        incomplete_pass,
        out_of_bounds,
        penalty,
        timeout,
        injury,
        score,
        two_minute_warning,
        quarter_end,
        first_down,  // Only stops clock in final 2 minutes
        change_of_possession,
        official_timeout,
    };

    /// Game situation context
    pub const GameSituation = struct {
        quarter: u8,
        time_remaining: u32,
        down: u8,
        distance: u8,
        is_overtime: bool,
        home_timeouts: u8,
        away_timeouts: u8,
        possession_team: Team,
        is_two_minute_drill: bool,
    };

    /// Clock management decision
    pub const ClockDecision = struct {
        should_stop: bool,
        stop_reason: ?ClockStopReason,
        restart_on_ready: bool,
        restart_on_snap: bool,
        play_clock_reset: bool,
        play_clock_duration: u32,
    };

    /// Team designation
    pub const Team = enum { home, away };

    /// Penalty information
    pub const PenaltyInfo = struct {
        yards: i8,
        clock_impact: enum {
            no_impact,
            stop_clock,
            reset_play_clock,
            ten_second_runoff,
        },
        against_team: enum { offense, defense },
    };

// ╚══════════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ INIT ══════════════════════════════════════╗

    /// NFL Rules Engine
    pub const RulesEngine = struct {
        /// Current game situation
        situation: GameSituation,
        /// Track if clock is currently running
        clock_running: bool,
        /// Track if we're in hurry-up offense
        hurry_up_mode: bool,

        /// Initialize rules engine with default game start.
        ///
        /// Creates a new rules engine with standard NFL game settings.
        ///
        /// __Return__
        ///
        /// - Initialized RulesEngine with default game state
        pub fn init() RulesEngine {
            return .{
                .situation = .{
                    .quarter = 1,
                    .time_remaining = TimingConstants.QUARTER_LENGTH,
                    .down = 1,
                    .distance = 10,
                    .is_overtime = false,
                    .home_timeouts = 3,
                    .away_timeouts = 3,
                    .possession_team = .away,
                    .is_two_minute_drill = false,
                },
                .clock_running = false,
                .hurry_up_mode = false,
            };
        }

        /// Initialize with custom situation.
        ///
        /// Creates a rules engine with specified game situation.
        ///
        /// __Parameters__
        ///
        /// - `situation`: Custom game situation to initialize with
        ///
        /// __Return__
        ///
        /// - Initialized RulesEngine with custom situation
        pub fn initWithSituation(situation: GameSituation) RulesEngine {
            return .{
                .situation = situation,
                .clock_running = false,
                .hurry_up_mode = false,
            };
        }

        /// Process a play outcome and determine clock behavior.
        ///
        /// Evaluates the play outcome and applies NFL clock rules.
        ///
        /// __Parameters__
        ///
        /// - `self`: Mutable reference to RulesEngine
        /// - `outcome`: The type of play that occurred
        ///
        /// __Return__
        ///
        /// - ClockDecision with appropriate clock management actions
        pub fn processPlay(self: *RulesEngine, outcome: PlayOutcome) ClockDecision {
            var decision = ClockDecision{
                .should_stop = false,
                .stop_reason = null,
                .restart_on_ready = false,
                .restart_on_snap = true,
                .play_clock_reset = true,
                .play_clock_duration = TimingConstants.PLAY_CLOCK_DURATION,
            };

            // Check for two-minute warning first
            if (shouldTriggerTwoMinuteWarning(self.situation)) {
                decision.should_stop = true;
                decision.stop_reason = .two_minute_warning;
                decision.restart_on_ready = false;
                self.situation.is_two_minute_drill = true;
                return decision;
            }

            switch (outcome) {
                .incomplete_pass => {
                    decision.should_stop = true;
                    decision.stop_reason = .incomplete_pass;
                    decision.restart_on_snap = true;
                },
                .complete_pass_out_of_bounds, .run_out_of_bounds => {
                    decision.should_stop = true;
                    decision.stop_reason = .out_of_bounds;
                    // Clock restarts on ready for play except in final 2 minutes of each half
                    decision.restart_on_ready = !isInsideTwoMinutes(self.situation);
                    decision.restart_on_snap = isInsideTwoMinutes(self.situation);
                },
                .complete_pass_inbounds, .run_inbounds => {
                    // Clock continues to run unless first down in final 2 minutes
                    if (self.isFirstDown() and isInsideTwoMinutes(self.situation)) {
                        decision.should_stop = true;
                        decision.stop_reason = .first_down;
                        decision.restart_on_ready = true;
                    }
                },
                .touchdown, .field_goal_attempt, .safety => {
                    decision.should_stop = true;
                    decision.stop_reason = .score;
                    decision.restart_on_ready = false;
                    decision.restart_on_snap = false; // Kickoff will restart
                },
                .timeout => {
                    decision.should_stop = true;
                    decision.stop_reason = .timeout;
                    decision.restart_on_snap = true;
                    decision.play_clock_duration = TimingConstants.PLAY_CLOCK_AFTER_TIMEOUT;
                },
                .injury => {
                    decision.should_stop = true;
                    decision.stop_reason = .injury;
                    decision.restart_on_ready = true;
                    decision.play_clock_duration = TimingConstants.PLAY_CLOCK_AFTER_TIMEOUT;
                },
                .penalty => {
                    decision.should_stop = true;
                    decision.stop_reason = .penalty;
                    // Clock restart depends on penalty type and game situation
                    decision.restart_on_ready = true;
                },
                .punt, .kickoff => {
                    decision.should_stop = true;
                    decision.stop_reason = .change_of_possession;
                    decision.restart_on_snap = true;
                },
                .quarter_end => {
                    decision.should_stop = true;
                    decision.stop_reason = .quarter_end;
                    decision.restart_on_ready = false;
                    decision.restart_on_snap = false;
                },
                .sack => {
                    // Sack is treated like a running play - clock continues
                    if (isInsideTwoMinutes(self.situation)) {
                        // May stop for first down
                        if (self.isFirstDown()) {
                            decision.should_stop = true;
                            decision.stop_reason = .first_down;
                            decision.restart_on_ready = true;
                        }
                    }
                },
                .fumble_out_of_bounds => {
                    decision.should_stop = true;
                    decision.stop_reason = .out_of_bounds;
                    decision.restart_on_ready = !isInsideTwoMinutes(self.situation);
                    decision.restart_on_snap = isInsideTwoMinutes(self.situation);
                },
                .fumble_inbounds, .interception => {
                    // Change of possession
                    decision.should_stop = true;
                    decision.stop_reason = .change_of_possession;
                    decision.restart_on_snap = true;
                },
                else => {},
            }

            return decision;
        }

        /// Process a penalty and determine clock impact.
        ///
        /// Evaluates penalty and applies appropriate clock rules.
        ///
        /// __Parameters__
        ///
        /// - `self`: Mutable reference to RulesEngine
        /// - `penalty`: Information about the penalty
        ///
        /// __Return__
        ///
        /// - ClockDecision with penalty-specific clock behavior
        pub fn processPenalty(self: *RulesEngine, penalty: PenaltyInfo) ClockDecision {
            var decision = ClockDecision{
                .should_stop = true,
                .stop_reason = .penalty,
                .restart_on_ready = true,
                .restart_on_snap = false,
                .play_clock_reset = true,
                .play_clock_duration = TimingConstants.PLAY_CLOCK_AFTER_TIMEOUT,
            };

            switch (penalty.clock_impact) {
                .stop_clock => {
                    decision.should_stop = true;
                    decision.restart_on_ready = true;
                },
                .ten_second_runoff => {
                    // 10-second runoff applies in final minute of either half
                    if (self.situation.time_remaining <= 60 and 
                        (self.situation.quarter == 2 or self.situation.quarter == 4)) {
                        // Subtract 10 seconds from game clock
                        if (self.situation.time_remaining > 10) {
                            self.situation.time_remaining -= 10;
                        } else {
                            self.situation.time_remaining = 0;
                            decision.stop_reason = .quarter_end;
                        }
                    }
                },
                .reset_play_clock => {
                    decision.play_clock_reset = true;
                },
                .no_impact => {
                    decision.should_stop = false;
                    decision.stop_reason = null;
                },
            }

            return decision;
        }

        /// Check if timeout is available for team.
        ///
        /// Verifies if specified team has remaining timeouts.
        ///
        /// __Parameters__
        ///
        /// - `self`: Mutable reference to RulesEngine
        /// - `team`: Team to check timeouts for
        ///
        /// __Return__
        ///
        /// - Boolean indicating if timeout is available
        pub fn canCallTimeout(self: *RulesEngine, team: Team) bool {
            return switch (team) {
                .home => self.situation.home_timeouts > 0,
                .away => self.situation.away_timeouts > 0,
            };
        }

        /// Use a timeout.
        ///
        /// Consumes one timeout for the specified team.
        ///
        /// __Parameters__
        ///
        /// - `self`: Mutable reference to RulesEngine
        /// - `team`: Team using the timeout
        ///
        /// __Return__
        ///
        /// - void
        ///
        /// __Errors__
        ///
        /// - `NoTimeoutsRemaining`: When team has no timeouts left
        pub fn useTimeout(self: *RulesEngine, team: Team) !void {
            if (!self.canCallTimeout(team)) {
                return error.NoTimeoutsRemaining;
            }

            switch (team) {
                .home => self.situation.home_timeouts -= 1,
                .away => self.situation.away_timeouts -= 1,
            }
        }

        /// Advance to next quarter.
        ///
        /// Transitions game to the next quarter and resets timeouts at halftime.
        ///
        /// __Parameters__
        ///
        /// - `self`: Mutable reference to RulesEngine
        ///
        /// __Return__
        ///
        /// - void
        pub fn advanceQuarter(self: *RulesEngine) void {
            self.situation.quarter += 1;
            self.situation.time_remaining = TimingConstants.QUARTER_LENGTH;
            
            // Reset timeouts at halftime
            if (self.situation.quarter == 3) {
                self.situation.home_timeouts = 3;
                self.situation.away_timeouts = 3;
            }
            
            // Check for overtime
            if (self.situation.quarter > 4) {
                self.situation.is_overtime = true;
                self.situation.time_remaining = TimingConstants.OVERTIME_LENGTH;
            }
            
            self.situation.is_two_minute_drill = false;
        }

        /// Check if game is over.
        ///
        /// Determines if the game has ended based on quarter and time.
        ///
        /// __Parameters__
        ///
        /// - `self`: Mutable reference to RulesEngine
        ///
        /// __Return__
        ///
        /// - Boolean indicating if game has ended
        pub fn isGameOver(self: *RulesEngine) bool {
            if (self.situation.is_overtime) {
                // Overtime rules: sudden death in regular season
                return self.situation.time_remaining == 0;
            }
            
            return self.situation.quarter >= 4 and self.situation.time_remaining == 0;
        }

        /// Check if half is over.
        ///
        /// Determines if current half has ended.
        ///
        /// __Parameters__
        ///
        /// - `self`: Mutable reference to RulesEngine
        ///
        /// __Return__
        ///
        /// - Boolean indicating if half has ended
        pub fn isHalfOver(self: *RulesEngine) bool {
            return (self.situation.quarter == 2 or self.situation.quarter == 4) and 
                   self.situation.time_remaining == 0;
        }

        /// Reset for new possession.
        ///
        /// Sets up game state for a team's new possession.
        ///
        /// __Parameters__
        ///
        /// - `self`: Mutable reference to RulesEngine
        /// - `team`: Team taking possession
        ///
        /// __Return__
        ///
        /// - void
        pub fn newPossession(self: *RulesEngine, team: Team) void {
            self.situation.possession_team = team;
            self.situation.down = 1;
            self.situation.distance = 10;
        }

        /// Update down and distance.
        ///
        /// Updates game state based on yards gained on the play.
        ///
        /// __Parameters__
        ///
        /// - `self`: Mutable reference to RulesEngine
        /// - `yards_gained`: Yards gained on the play (negative for loss)
        ///
        /// __Return__
        ///
        /// - void
        pub fn updateDownAndDistance(self: *RulesEngine, yards_gained: i8) void {
            const new_distance = @as(i16, self.situation.distance) - yards_gained;
            
            if (new_distance <= 0) {
                // First down
                self.situation.down = 1;
                self.situation.distance = 10;
            } else if (self.situation.down >= 4) {
                // Turnover on downs - switch possession
                self.situation.possession_team = if (self.situation.possession_team == .home) .away else .home;
                self.situation.down = 1;
                self.situation.distance = 10;
            } else {
                self.situation.down += 1;
                self.situation.distance = @intCast(@max(0, new_distance));
            }
        }

        /// Check if it's a first down
        fn isFirstDown(self: *RulesEngine) bool {
            return self.situation.down == 1;
        }

        /// Validate game situation.
        ///
        /// Ensures the game situation is valid according to NFL rules.
        ///
        /// __Parameters__
        ///
        /// - `self`: Const reference to RulesEngine
        ///
        /// __Return__
        ///
        /// - void on success
        ///
        /// __Errors__
        ///
        /// - `RulesEngineError.InvalidGameSituation`: If situation is invalid
        pub fn validateSituation(self: *const RulesEngine, situation: anytype) RulesEngineError!void {
            const game_situation = if (@TypeOf(situation) == GameSituation) 
                situation 
            else if (@TypeOf(situation) == *const GameSituation or @TypeOf(situation) == *GameSituation)
                situation.*
            else 
                self.situation;
            
            // Validate quarter
            if (game_situation.quarter < 1 or game_situation.quarter > 5) {
                return RulesEngineError.InvalidSituation;
            }

            // Validate down
            if (game_situation.down < 1 or game_situation.down > 4) {
                return RulesEngineError.InvalidSituation;
            }

            // Validate distance
            if (game_situation.distance > 100) {
                return RulesEngineError.InvalidSituation;
            }

            // Validate timeouts
            if (game_situation.home_timeouts > 3 or game_situation.away_timeouts > 3) {
                return RulesEngineError.InvalidSituation;
            }

            // Validate time remaining
            const max_time = if (game_situation.is_overtime)
                TimingConstants.OVERTIME_LENGTH
            else
                TimingConstants.QUARTER_LENGTH;

            if (game_situation.time_remaining > max_time) {
                return RulesEngineError.InvalidSituation;
            }

            // Check two-minute drill consistency
            if (game_situation.is_two_minute_drill and 
                game_situation.time_remaining > TimingConstants.TWO_MINUTE_WARNING) {
                return RulesEngineError.InvalidSituation;
            }
        }

        /// Validate clock decision.
        ///
        /// Ensures a clock decision is internally consistent.
        ///
        /// __Parameters__
        ///
        /// - `self`: Const reference to RulesEngine
        /// - `decision`: Clock decision to validate
        ///
        /// __Return__
        ///
        /// - void on success
        ///
        /// __Errors__
        ///
        /// - `RulesEngineError.ClockManagementError`: If decision is invalid
        pub fn validateClockDecision(self: *const RulesEngine, decision: ClockDecision) RulesEngineError!void {
            _ = self;

            // Can't restart on both ready and snap
            if (decision.restart_on_ready and decision.restart_on_snap) {
                return RulesEngineError.ClockManagementError;
            }

            // If clock is stopped, must have a reason
            if (decision.should_stop and decision.stop_reason == null) {
                return RulesEngineError.ClockManagementError;
            }

            // Play clock duration must be valid
            if (decision.play_clock_duration != TimingConstants.PLAY_CLOCK_DURATION and
                decision.play_clock_duration != TimingConstants.PLAY_CLOCK_AFTER_TIMEOUT and
                decision.play_clock_duration != 0) {
                return RulesEngineError.ClockManagementError;
            }
        }

        /// Recover from rules engine error.
        ///
        /// Attempts to recover from a specific error condition.
        ///
        /// __Parameters__
        ///
        /// - `self`: Mutable reference to RulesEngine
        /// - `err`: The error to recover from
        ///
        /// __Return__
        ///
        /// - void
        pub fn recoverFromError(self: *RulesEngine, err: RulesEngineError) void {
            switch (err) {
                RulesEngineError.InvalidQuarter => {
                    self.situation.quarter = 1;
                    self.situation.time_remaining = TimingConstants.QUARTER_LENGTH;
                },
                RulesEngineError.InvalidDown => {
                    self.situation.down = 1;
                    self.situation.distance = 10;
                },
                RulesEngineError.InvalidDistance => {
                    self.situation.distance = 10;
                },
                RulesEngineError.InvalidTimeoutCount => {
                    self.situation.home_timeouts = @min(self.situation.home_timeouts, 3);
                    self.situation.away_timeouts = @min(self.situation.away_timeouts, 3);
                },
                RulesEngineError.InvalidGameSituation => {
                    // Reset to safe defaults
                    self.situation = .{
                        .quarter = 1,
                        .time_remaining = TimingConstants.QUARTER_LENGTH,
                        .down = 1,
                        .distance = 10,
                        .is_overtime = false,
                        .home_timeouts = 3,
                        .away_timeouts = 3,
                        .possession_team = .home,
                        .is_two_minute_drill = false,
                    };
                },
                RulesEngineError.RuleViolation => {
                    // Rule violations require specific handling
                    // Reset to beginning of down
                    self.situation.down = 1;
                },
                RulesEngineError.ClockManagementError => {
                    // Reset clock state
                    self.clock_running = false;
                    self.hurry_up_mode = false;
                },
            }
        }
    };

// ╚══════════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ CORE ══════════════════════════════════════╗

    /// Check if two-minute warning should trigger.
    ///
    /// Determines if game is at the two-minute warning point.
    ///
    /// __Parameters__
    ///
    /// - `situation`: Current game situation
    ///
    /// __Return__
    ///
    /// - Boolean indicating if two-minute warning should occur
    pub fn shouldTriggerTwoMinuteWarning(situation: GameSituation) bool {
        // Two-minute warning occurs in 2nd and 4th quarters
        if (situation.quarter != 2 and situation.quarter != 4) {
            return false;
        }

        // Don't trigger if already in two-minute drill
        if (situation.is_two_minute_drill) {
            return false;
        }

        // Check if we just crossed the 2-minute threshold
        return situation.time_remaining == TimingConstants.TWO_MINUTE_WARNING;
    }

    /// Check if we're inside two minutes of a half.
    ///
    /// Determines if game is within final two minutes of a half.
    ///
    /// __Parameters__
    ///
    /// - `situation`: Current game situation
    ///
    /// __Return__
    ///
    /// - Boolean indicating if within two minutes
    pub fn isInsideTwoMinutes(situation: GameSituation) bool {
        return situation.is_two_minute_drill or 
               (situation.time_remaining <= TimingConstants.TWO_MINUTE_WARNING and
                (situation.quarter == 2 or situation.quarter == 4));
    }


    /// Get time to subtract for a typical play.
    ///
    /// Calculates expected time consumption based on play type.
    ///
    /// __Parameters__
    ///
    /// - `outcome`: Type of play executed
    /// - `hurry_up`: Whether team is in hurry-up offense
    ///
    /// __Return__
    ///
    /// - Duration in seconds for the play
    pub fn getPlayDuration(outcome: PlayOutcome, hurry_up: bool) u32 {
        // Average play durations in seconds
        const base_duration: u32 = switch (outcome) {
            .incomplete_pass => 5,
            .complete_pass_inbounds => 7,
            .complete_pass_out_of_bounds => 6,
            .run_inbounds => 6,
            .run_out_of_bounds => 5,
            .sack => 8,
            .punt => 6,
            .field_goal_attempt => 5,
            .kickoff => 6,
            else => 0,
        };

        // Hurry-up offense reduces play duration
        return if (hurry_up) @max(3, base_duration - 2) else base_duration;
    }


// ╚══════════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ TEST ══════════════════════════════════════╗

    test "incomplete pass stops clock" {
        var engine = RulesEngine.init();
        const decision = engine.processPlay(.incomplete_pass);
        
        try std.testing.expect(decision.should_stop);
        try std.testing.expect(decision.stop_reason == .incomplete_pass);
        try std.testing.expect(decision.restart_on_snap);
    }

    test "out of bounds clock restart rules" {
        var engine = RulesEngine.init();
        
        // Outside 2 minutes - clock restarts on ready
        engine.situation.time_remaining = 300;
        var decision = engine.processPlay(.run_out_of_bounds);
        try std.testing.expect(decision.restart_on_ready);
        try std.testing.expect(!decision.restart_on_snap);
        
        // Inside 2 minutes - clock restarts on snap
        engine.situation.time_remaining = 90;
        engine.situation.quarter = 2;
        decision = engine.processPlay(.run_out_of_bounds);
        try std.testing.expect(!decision.restart_on_ready);
        try std.testing.expect(decision.restart_on_snap);
    }

    test "timeout management" {
        var engine = RulesEngine.init();
        
        try std.testing.expect(engine.canCallTimeout(.home));
        try engine.useTimeout(.home);
        try std.testing.expectEqual(@as(u8, 2), engine.situation.home_timeouts);
        
        // Use all timeouts
        try engine.useTimeout(.home);
        try engine.useTimeout(.home);
        try std.testing.expect(!engine.canCallTimeout(.home));
        
        // Should error on no timeouts
        try std.testing.expectError(error.NoTimeoutsRemaining, engine.useTimeout(.home));
    }

    test "quarter advancement" {
        var engine = RulesEngine.init();
        
        engine.advanceQuarter();
        try std.testing.expectEqual(@as(u8, 2), engine.situation.quarter);
        try std.testing.expectEqual(TimingConstants.QUARTER_LENGTH, engine.situation.time_remaining);
        
        // Advance to halftime
        engine.advanceQuarter();
        try std.testing.expectEqual(@as(u8, 3), engine.situation.quarter);
        // Timeouts should be reset
        try std.testing.expectEqual(@as(u8, 3), engine.situation.home_timeouts);
    }

    test "down and distance updates" {
        var engine = RulesEngine.init();
        
        // Gain 5 yards on first down
        engine.updateDownAndDistance(5);
        try std.testing.expectEqual(@as(u8, 2), engine.situation.down);
        try std.testing.expectEqual(@as(u8, 5), engine.situation.distance);
        
        // Gain 10 yards for first down
        engine.updateDownAndDistance(10);
        try std.testing.expectEqual(@as(u8, 1), engine.situation.down);
        try std.testing.expectEqual(@as(u8, 10), engine.situation.distance);
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════════╝