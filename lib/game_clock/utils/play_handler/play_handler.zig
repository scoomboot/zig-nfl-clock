// play_handler.zig — Play outcome processing
//
// repo   : https://github.com/fisty/zig-nfl-clock
// docs   : https://fisty.github.io/zig-nfl-clock/docs/lib/game_clock/utils/play_handler
// author : https://github.com/scoomboot
//
// Vibe coded by Scoom.

// ╔══════════════════════════════════════ PACK ═══════════════════════════════════════╗

    const std = @import("std");

    /// Play outcome processing and game state management.
    ///
    /// This module handles the processing of various NFL play types, updating
    /// game state, tracking statistics, and simulating realistic play outcomes
    /// including yards gained, turnovers, and scoring.

    /// Play type classifications
    pub const PlayType = enum {
        /// Pass plays
        pass_short,
        pass_medium,
        pass_deep,
        screen_pass,
        
        /// Run plays
        run_up_middle,
        run_off_tackle,
        run_sweep,
        quarterback_sneak,
        
        /// Special teams
        punt,
        field_goal,
        extra_point,
        kickoff,
        kickoff_return,
        punt_return,
        
        /// Scoring plays
        touchdown,
        
        /// Special situations
        kneel_down,
        spike,
        two_point_conversion,
        onside_kick,
        
        /// Turnovers
        interception,
        fumble,
        fumble_recovery,
        
        /// Penalties
        penalty_offense,
        penalty_defense,
        penalty_declined,
    };

    /// Play result information
    pub const PlayResult = struct {
        /// Type of play executed
        play_type: PlayType,
        /// Yards gained (negative for loss)
        yards_gained: i16,
        /// Whether play went out of bounds
        out_of_bounds: bool,
        /// Whether pass was completed (for pass plays)
        pass_completed: bool,
        /// Whether play resulted in touchdown
        is_touchdown: bool,
        /// Whether play resulted in first down
        is_first_down: bool,
        /// Whether there was a turnover
        is_turnover: bool,
        /// Time consumed by the play in seconds
        time_consumed: u32,
        /// Field position after play (0-100, 0 = own end zone)
        field_position: u8,
        /// Special outcome (if any)
        special_outcome: SpecialOutcome = .none,
    };

    /// Special play outcomes
    pub const SpecialOutcome = enum {
        none,
        safety,
        touchback,
        two_minute_warning,
        end_of_quarter,
        end_of_game,
        muffed_punt,
        blocked_kick,
        extra_point_blocked,
        extra_point_good,
        missed_field_goal,
        successful_onside_kick,
    };

    /// Possession team enum (unified type)
    pub const PossessionTeam = enum { home, away };

    /// Game state after play
    pub const GameStateUpdate = struct {
        /// New down (1-4)
        down: u8,
        /// Yards to go for first down
        distance: u8,
        /// Team with possession
        possession: PossessionTeam,
        /// Home team score
        home_score: u16,
        /// Away team score  
        away_score: u16,
        /// Quarter (1-4, 5+ for OT)
        quarter: u8,
        /// Time remaining in quarter
        time_remaining: u32,
        /// Play clock time
        play_clock: u32,
        /// Clock should be running
        clock_running: bool,
    };

    /// Play statistics for tracking
    pub const PlayStatistics = struct {
        /// Total offensive yards
        total_yards: i32,
        /// Passing yards
        passing_yards: i32,
        /// Rushing yards
        rushing_yards: i32,
        /// First downs achieved
        first_downs: u16,
        /// Third down conversions
        third_down_conversions: u16,
        /// Third down attempts
        third_down_attempts: u16,
        /// Time of possession in seconds
        time_of_possession: u32,
        /// Turnovers
        turnovers: u8,
        /// Penalties
        penalties: u8,
        /// Penalty yards
        penalty_yards: i16,
        /// Total plays run
        plays_run: u16,
    };

    /// Options for controlling play processing behavior
    pub const PlayOptions = struct {
        /// Enable random turnovers (interceptions, fumbles)
        enable_turnovers: bool = true,
        /// Chance of turnover as percentage (1-100)
        turnover_chance: u8 = 3,
    };

    /// Play handler specific error set
    pub const PlayHandlerError = error{
        InvalidPlayType,
        InvalidYardage,
        InvalidFieldPosition,
        InvalidDownAndDistance,
        InvalidGameState,
        InvalidStatistics,
        StatisticsOverflow,
        PlaySequenceError,
        InvalidPlayResult,
    };

    /// Error context for play handler
    pub const PlayErrorContext = struct {
        error_type: PlayHandlerError,
        play_type: ?PlayType = null,
        play_number: ?u32 = null,
        field_position: ?u8 = null,
        message: []const u8,
    };

// ╚════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ INIT ═══════════════════════════════════════╗

    /// Play handler for processing game plays
    pub const PlayHandler = struct {
        /// Current game state
        game_state: GameStateUpdate,
        /// Home team statistics
        home_stats: PlayStatistics,
        /// Away team statistics
        away_stats: PlayStatistics,
        /// Current possession team
        possession_team: PossessionTeam,
        /// Play sequence number
        play_number: u32,
        /// Random number generator for play variations
        rng: std.Random,
        /// Current field position (0-100, 0 = own end zone, 100 = opponent end zone)
        field_position: u8,

        /// Initialize play handler.
        ///
        /// Creates a new play handler with default game state.
        ///
        /// __Parameters__
        ///
        /// - `seed`: Random seed for play variations
        ///
        /// __Return__
        ///
        /// - Initialized PlayHandler instance
        pub fn init(seed: u64) PlayHandler {
            var prng = std.Random.DefaultPrng.init(seed);
            
            return .{
                .game_state = .{
                    .down = 1,
                    .distance = 10,
                    .possession = .away,
                    .home_score = 0,
                    .away_score = 0,
                    .quarter = 1,
                    .time_remaining = 900, // 15 minutes
                    .play_clock = 40,
                    .clock_running = false,
                },
                .home_stats = std.mem.zeroes(PlayStatistics),
                .away_stats = std.mem.zeroes(PlayStatistics),
                .possession_team = .away,
                .play_number = 0,
                .rng = prng.random(),
                .field_position = 25,  // Start at own 25-yard line
            };
        }

        /// Initialize with custom game state.
        ///
        /// Creates a play handler with specified game state.
        ///
        /// __Parameters__
        ///
        /// - `game_state`: Initial game state configuration
        /// - `seed`: Random seed for play variations
        ///
        /// __Return__
        ///
        /// - Initialized PlayHandler with custom state
        pub fn initWithState(game_state: GameStateUpdate, seed: u64) PlayHandler {
            var prng = std.Random.DefaultPrng.init(seed);
            
            return .{
                .game_state = game_state,
                .home_stats = std.mem.zeroes(PlayStatistics),
                .away_stats = std.mem.zeroes(PlayStatistics),
                .possession_team = game_state.possession,
                .play_number = 0,
                .rng = prng.random(),
                .field_position = 25,  // Start at own 25-yard line
            };
        }

        /// Process a play and update game state.
        ///
        /// Simulates play execution and updates all game statistics.
        ///
        /// __Parameters__
        ///
        /// - `self`: Mutable reference to PlayHandler
        /// - `play_type`: Type of play to execute
        /// - `options`: Optional play parameters (yards_attempted, kick_distance, return_yards)
        /// - `play_options`: Optional configuration for play processing behavior
        ///
        /// __Return__
        ///
        /// - PlayResult with play outcome details
        pub fn processPlay(self: *PlayHandler, play_type: PlayType, options: struct {
            yards_attempted: ?i16 = null,
            kick_distance: ?u8 = null,
            return_yards: ?i16 = null,
        }, play_options: ?PlayOptions) PlayResult {
            const opts = play_options orelse PlayOptions{};
            self.play_number += 1;
            
            var result = PlayResult{
                .play_type = play_type,
                .yards_gained = 0,
                .out_of_bounds = false,
                .pass_completed = false,
                .is_touchdown = false,
                .is_first_down = false,
                .is_turnover = false,
                .time_consumed = 0,
                .field_position = self.field_position, // Default midfield
            };

            switch (play_type) {
                .pass_short => result = self.processPassPlay(play_type, 5, 75, opts),
                .pass_medium => result = self.processPassPlay(play_type, 15, 60, opts),
                .pass_deep => result = self.processPassPlay(play_type, 30, 35, opts),
                .screen_pass => result = self.processPassPlay(play_type, 3, 70, opts),
                
                .run_up_middle => result = self.processRunPlay(play_type, 4, 15, opts),
                .run_off_tackle => result = self.processRunPlay(play_type, 5, 20, opts),
                .run_sweep => result = self.processRunPlay(play_type, 3, 25, opts),
                .quarterback_sneak => result = self.processRunPlay(play_type, 1, 85, opts),
                
                .punt => result = self.processPunt(options.kick_distance orelse 45),
                .field_goal => result = self.processFieldGoal(options.kick_distance orelse 35),
                .extra_point => result = self.processExtraPoint(),
                .kickoff => result = self.processKickoff(options.return_yards orelse 25),
                
                .kneel_down => result = self.processKneelDown(),
                .spike => result = self.processSpike(),
                
                .interception => result = self.processTurnover(.interception, options.return_yards orelse 10),
                .fumble => result = self.processTurnover(.fumble, 0),
                
                else => {},
            }

            // Update game state based on result
            self.updateGameState(&result);
    
            // Update statistics
            self.updateStatistics(&result);
    
            return result;
        }

        /// Update game state after play.
        ///
        /// Applies play result to game state including score and possession.
        ///
        /// __Parameters__
        ///
        /// - `self`: Mutable reference to PlayHandler
        /// - `result`: Play result to apply
        ///
        /// __Return__
        ///
        /// - void
        pub fn updateGameState(self: *PlayHandler, result: *PlayResult) void {
            // Update time
            if (self.game_state.time_remaining > result.time_consumed) {
                self.game_state.time_remaining -= result.time_consumed;
            } else {
                self.game_state.time_remaining = 0;
            }

            // Update field position
            if (!result.is_touchdown and !result.is_turnover) {
                const new_position = @as(i16, self.field_position) + result.yards_gained;
                self.field_position = @intCast(@min(100, @max(0, new_position)));
                result.field_position = self.field_position; // Update result with actual position
            }

            // Update down and distance
            if (result.is_touchdown) {
                // Reset for kickoff
                self.game_state.down = 1;
                self.game_state.distance = 10;
                self.field_position = 25; // Reset to kickoff position
                // Add touchdown points
                if (self.possession_team == .home) {
                    self.game_state.home_score += 6;
                } else {
                    self.game_state.away_score += 6;
                }
            } else if (result.is_first_down) {
                self.game_state.down = 1;
                self.game_state.distance = 10;
            } else if (result.is_turnover) {
                // Change possession
                self.possession_team = if (self.possession_team == .home) .away else .home;
                self.game_state.possession = self.possession_team;
                self.game_state.down = 1;
                self.game_state.distance = 10;
                // Flip field position for turnover (100 - current position)
                self.field_position = @intCast(100 - self.field_position);
            } else {
                // Normal down progression
                if (self.game_state.down < 4) {
                    self.game_state.down += 1;
                    const new_distance = @as(i16, self.game_state.distance) - result.yards_gained;
                    self.game_state.distance = @intCast(@max(0, new_distance));
                } else {
                    // Turnover on downs
                    self.possession_team = if (self.possession_team == .home) .away else .home;
                    self.game_state.possession = self.possession_team;
                    self.game_state.down = 1;
                    self.game_state.distance = 10;
                    // Flip field position for turnover on downs
                    self.field_position = @intCast(100 - self.field_position);
                }
            }

            // Update clock running status
            self.game_state.clock_running = !result.out_of_bounds and 
                                           result.pass_completed and 
                                           !result.is_touchdown;
    
            // Reset play clock
            self.game_state.play_clock = 40;
        }

        /// Update team statistics.
        ///
        /// Records play results in team statistics tracking.
        ///
        /// __Parameters__
        ///
        /// - `self`: Mutable reference to PlayHandler
        /// - `result`: Play result to record
        ///
        /// __Return__
        ///
        /// - void
        pub fn updateStatistics(self: *PlayHandler, result: *const PlayResult) void {
            const stats = if (self.possession_team == .home) &self.home_stats else &self.away_stats;
    
            // Update yardage
            stats.total_yards += result.yards_gained;
    
            switch (result.play_type) {
                .pass_short, .pass_medium, .pass_deep, .screen_pass => {
                    if (result.pass_completed) {
                        stats.passing_yards += result.yards_gained;
                    }
                },
                .run_up_middle, .run_off_tackle, .run_sweep, .quarterback_sneak => {
                    stats.rushing_yards += result.yards_gained;
                },
                else => {},
            }
    
            // Update first downs
            if (result.is_first_down) {
                stats.first_downs += 1;
            }
    
            // Update third down conversions
            if (self.game_state.down == 3 and result.is_first_down) {
                stats.third_down_conversions += 1;
            }
            if (self.game_state.down == 3) {
                stats.third_down_attempts += 1;
            }
    
            // Update turnovers
            if (result.is_turnover) {
                stats.turnovers += 1;
            }
    
            // Update time of possession
            stats.time_of_possession += result.time_consumed;
        }

        /// Process a pass play
        fn processPassPlay(self: *PlayHandler, play_type: PlayType, target_yards: i16, completion_pct: u8, play_options: PlayOptions) PlayResult {
            var result = PlayResult{
                .play_type = play_type,
                .yards_gained = 0,
                .out_of_bounds = false,
                .pass_completed = false,
                .is_touchdown = false,
                .is_first_down = false,
                .is_turnover = false,
                .time_consumed = 5,
                .field_position = self.field_position,
            };

            // Determine if pass is complete
            const roll = self.rng.intRangeAtMost(u8, 1, 100);
            result.pass_completed = roll <= completion_pct;

            if (result.pass_completed) {
                // Calculate yards gained with variance
                const variance = self.rng.intRangeAtMost(i16, -3, 5);
                result.yards_gained = target_yards + variance;
                result.time_consumed = 25;  // Completed pass takes more time
                
                // Check for out of bounds (20% chance on sideline passes)
                result.out_of_bounds = self.rng.intRangeAtMost(u8, 1, 100) <= 20;
                
                // Check for touchdown based on field position
                const yards_to_endzone = @as(i16, 100) - @as(i16, self.getFieldPosition());
                if (result.yards_gained >= yards_to_endzone) {
                    result.is_touchdown = true;
                    result.yards_gained = yards_to_endzone;
                }
                
                // Check for first down
                if (result.yards_gained >= self.game_state.distance) {
                    result.is_first_down = true;
                }
            } else {
                // Incomplete pass
                result.time_consumed = 8;  // Incomplete pass stops clock quickly
                
                // Small chance of interception on incomplete passes
                if (play_options.enable_turnovers and 
                    self.rng.intRangeAtMost(u8, 1, 100) <= play_options.turnover_chance) {
                    result.is_turnover = true;
                    result.play_type = .interception;
                }
            }

            return result;
        }

        /// Process a run play
        fn processRunPlay(self: *PlayHandler, play_type: PlayType, avg_yards: i16, big_play_pct: u8, play_options: PlayOptions) PlayResult {
            var result = PlayResult{
                .play_type = play_type,
                .yards_gained = 0,
                .out_of_bounds = false,
                .pass_completed = false,
                .is_touchdown = false,
                .is_first_down = false,
                .is_turnover = false,
                .time_consumed = 30,  // Running play consumes more clock
                .field_position = self.field_position,
            };

            // Check for big play
            const is_big_play = self.rng.intRangeAtMost(u8, 1, 100) <= big_play_pct;
    
            if (is_big_play) {
                result.yards_gained = avg_yards + self.rng.intRangeAtMost(i16, 5, 20);
            } else {
                // Normal distribution around average
                const variance = self.rng.intRangeAtMost(i16, -2, 3);
                result.yards_gained = avg_yards + variance;
            }

            // Check for fumble (configurable chance)
            if (play_options.enable_turnovers and 
                self.rng.intRangeAtMost(u8, 1, 100) <= @divFloor(play_options.turnover_chance, 3)) {
                result.is_turnover = true;
                result.play_type = .fumble;
                result.yards_gained = 0;
            }

            // Check for out of bounds (15% chance on outside runs)
            result.out_of_bounds = self.rng.intRangeAtMost(u8, 1, 100) <= 15;

            // Check for touchdown
            const yards_to_endzone = @as(i16, 100) - @as(i16, self.getFieldPosition());
            if (result.yards_gained >= yards_to_endzone) {
                result.is_touchdown = true;
                result.yards_gained = yards_to_endzone;
            }

            // Check for first down
            if (result.yards_gained >= self.game_state.distance) {
                result.is_first_down = true;
            }

            return result;
        }

        /// Process a punt
        fn processPunt(self: *PlayHandler, kick_distance: u8) PlayResult {
            var result = PlayResult{
                .play_type = .punt,
                .yards_gained = 0,
                .out_of_bounds = false,
                .pass_completed = false,
                .is_touchdown = false,
                .is_first_down = false,
                .is_turnover = true, // Punt is change of possession
                .time_consumed = 6,
                .field_position = self.field_position,
            };

            // Add variance to kick distance
            const variance = self.rng.intRangeAtMost(i8, -5, 10);
            const actual_distance = @as(i16, kick_distance) + variance;
    
            // Net yards accounting for return
            const return_yards = self.rng.intRangeAtMost(i16, -5, 15);
            result.yards_gained = actual_distance - return_yards;

            // Check for touchback
            const field_pos = self.getFieldPosition();
            if (@as(i16, field_pos) + result.yards_gained > 100) {
                result.yards_gained = @as(i16, 80) - @as(i16, field_pos); // Ball at 20
            }

            return result;
        }

        /// Process a field goal attempt
        fn processFieldGoal(self: *PlayHandler, distance: u8) PlayResult {
            var result = PlayResult{
                .play_type = .field_goal,
                .yards_gained = 0,
                .out_of_bounds = false,
                .pass_completed = false,
                .is_touchdown = false,
                .is_first_down = false,
                .is_turnover = false,
                .time_consumed = 10,  // Field goal attempt time
                .field_position = self.field_position,
            };

            // Calculate success rate based on distance
            const success_rate: u8 = if (distance <= 30) 95
                else if (distance <= 40) 85
                else if (distance <= 50) 65
                else 40;

            const made = self.rng.intRangeAtMost(u8, 1, 100) <= success_rate;
    
            if (made) {
                // Add 3 points
                if (self.possession_team == .home) {
                    self.game_state.home_score += 3;
                } else {
                    self.game_state.away_score += 3;
                }
            } else {
                // Missed FG - change of possession at spot of kick
                result.is_turnover = true;
            }

            return result;
        }

        /// Process extra point attempt
        fn processExtraPoint(self: *PlayHandler) PlayResult {
            const result = PlayResult{
                .play_type = .extra_point,
                .yards_gained = 0,
                .out_of_bounds = false,
                .pass_completed = false,
                .is_touchdown = false,
                .is_first_down = false,
                .is_turnover = false,
                .time_consumed = 3,
                .field_position = self.field_position,
            };

            // 95% success rate for extra points
            const made = self.rng.intRangeAtMost(u8, 1, 100) <= 95;
    
            if (made) {
                if (self.possession_team == .home) {
                    self.game_state.home_score += 1;
                } else {
                    self.game_state.away_score += 1;
                }
            }

            return result;
        }

        /// Process kickoff
        fn processKickoff(self: *PlayHandler, return_yards: i16) PlayResult {
            var result = PlayResult{
                .play_type = .kickoff,
                .yards_gained = 0,
                .out_of_bounds = false,
                .pass_completed = false,
                .is_touchdown = false,
                .is_first_down = false,
                .is_turnover = true, // Change of possession
                .time_consumed = 6,
                .field_position = self.field_position, // Current position
            };

            // Add variance to return
            const variance = self.rng.intRangeAtMost(i16, -5, 10);
            const actual_return = return_yards + variance;
    
            // Starting field position after return
            result.field_position = @intCast(@min(100, @max(0, 25 + actual_return)));
    
            // Small chance of touchdown return
            if (self.rng.intRangeAtMost(u8, 1, 100) <= 1) {
                result.is_touchdown = true;
                result.field_position = 100;
            }

            return result;
        }

        /// Process kneel down
        fn processKneelDown(self: *PlayHandler) PlayResult {
            return PlayResult{
                .play_type = .kneel_down,
                .yards_gained = -1,
                .out_of_bounds = false,
                .pass_completed = false,
                .is_touchdown = false,
                .is_first_down = false,
                .is_turnover = false,
                .time_consumed = 40, // Full play clock
                .field_position = self.getFieldPosition(),
            };
        }

        /// Process spike to stop clock
        fn processSpike(self: *PlayHandler) PlayResult {
            return PlayResult{
                .play_type = .spike,
                .yards_gained = 0,
                .out_of_bounds = false,
                .pass_completed = false,
                .is_touchdown = false,
                .is_first_down = false,
                .is_turnover = false,
                .time_consumed = 1,
                .field_position = self.getFieldPosition(),
            };
        }

        /// Process turnover
        fn processTurnover(self: *PlayHandler, turnover_type: PlayType, return_yards: i16) PlayResult {
            var result = PlayResult{
                .play_type = turnover_type,
                .yards_gained = return_yards,
                .out_of_bounds = false,
                .pass_completed = false,
                .is_touchdown = false,
                .is_first_down = false,
                .is_turnover = true,
                .time_consumed = 8,
                .field_position = self.getFieldPosition(),
            };

            // Switch possession
            self.possession_team = if (self.possession_team == .home) .away else .home;
            self.game_state.possession = self.possession_team;

            // Check for defensive touchdown
            if (self.rng.intRangeAtMost(u8, 1, 100) <= 5) {
                result.is_touchdown = true;
                if (self.possession_team == .home) {
                    self.game_state.home_score += 6;
                } else {
                    self.game_state.away_score += 6;
                }
            }

            return result;
        }

        /// Get current field position (0-100, 0 = own end zone)
        fn getFieldPosition(self: *const PlayHandler) u8 {
            return self.field_position;
        }

        /// Validate game state.
        ///
        /// Ensures the game state is valid and consistent.
        ///
        /// __Parameters__
        ///
        /// - `self`: Const reference to PlayHandler
        ///
        /// __Return__
        ///
        /// - void on success
        ///
        /// __Errors__
        ///
        /// - `PlayHandlerError.InvalidGameState`: If state is invalid
        pub fn validateGameState(self: *const PlayHandler, state: anytype) PlayHandlerError!void {
            const GameStateType = @TypeOf(self.game_state);
            const game_state = if (@TypeOf(state) == GameStateType) 
                state 
            else if (@TypeOf(state) == *const GameStateType or @TypeOf(state) == *GameStateType)
                state.*
            else 
                self.game_state;
            
            // Validate down
            if (game_state.down < 1 or game_state.down > 4) {
                return PlayHandlerError.InvalidGameState;
            }

            // Validate distance
            if (game_state.distance > 100) {
                return PlayHandlerError.InvalidGameState;
            }

            // Validate quarter
            if (game_state.quarter < 1 or game_state.quarter > 5) {
                return PlayHandlerError.InvalidGameState;
            }

            // Validate time remaining
            const max_time: u32 = if (game_state.quarter == 5) 600 else 900;
            if (game_state.time_remaining > max_time) {
                return PlayHandlerError.InvalidGameState;
            }

            // Validate play clock
            if (game_state.play_clock > 40) {
                return PlayHandlerError.InvalidGameState;
            }

            // Validate scores (basic check for negative scores)
            if (game_state.home_score > 200 or game_state.away_score > 200) {
                return PlayHandlerError.InvalidGameState;
            }
        }

        /// Validate play result.
        ///
        /// Ensures a play result is valid and consistent.
        ///
        /// __Parameters__
        ///
        /// - `self`: Const reference to PlayHandler
        /// - `result`: Play result to validate
        ///
        /// __Return__
        ///
        /// - void on success
        ///
        /// __Errors__
        ///
        /// - Various PlayHandlerError types based on validation failures
        pub fn validatePlayResult(self: *const PlayHandler, result: *const PlayResult) PlayHandlerError!void {
            _ = self;

            // Validate field position
            if (result.field_position > 100) {
                return PlayHandlerError.InvalidPlayResult;
            }

            // Validate yards gained (reasonable range)
            if (result.yards_gained < -50 or result.yards_gained > 100) {
                return PlayHandlerError.InvalidPlayResult;
            }

            // Validate time consumed
            if (result.time_consumed > 40) {
                return PlayHandlerError.InvalidPlayResult;
            }

            // Validate logical consistency
            if (result.is_touchdown and result.is_turnover) {
                return PlayHandlerError.InvalidPlayResult;
            }

            // Pass plays must have pass_completed set correctly
            switch (result.play_type) {
                .pass_short, .pass_medium, .pass_deep, .screen_pass => {
                    // These are pass plays, pass_completed should be meaningful
                },
                .touchdown => {
                    // Touchdown play type must have is_touchdown flag set
                    if (!result.is_touchdown) {
                        return PlayHandlerError.InvalidPlayResult;
                    }
                },
                else => {
                    // Non-pass plays shouldn't have pass_completed true
                    if (result.pass_completed) {
                        return PlayHandlerError.InvalidPlayResult;
                    }
                },
            }
        }

        /// Validate statistics.
        ///
        /// Ensures statistics are within valid ranges.
        ///
        /// __Parameters__
        ///
        /// - `self`: Const reference to PlayHandler
        ///
        /// __Return__
        ///
        /// - void on success
        ///
        /// __Errors__
        ///
        /// - `PlayHandlerError.StatisticsOverflow`: If statistics overflow
        pub fn validateStatistics(self: *const PlayHandler, stats: anytype) PlayHandlerError!void {
            const TeamStatisticsType = @TypeOf(self.home_stats);
            const team_stats = if (@TypeOf(stats) == TeamStatisticsType) 
                stats 
            else if (@TypeOf(stats) == *const TeamStatisticsType or @TypeOf(stats) == *TeamStatisticsType)
                stats.*
            else 
                self.home_stats;
            
            // Check stats
            if (@abs(team_stats.total_yards) > 10000 or
                @abs(team_stats.passing_yards) > 10000 or
                @abs(team_stats.rushing_yards) > 10000) {
                return PlayHandlerError.StatisticsOverflow;
            }

            // Validate third down conversion rates
            if (team_stats.third_down_conversions > team_stats.third_down_attempts) {
                return PlayHandlerError.StatisticsOverflow;
            }

            // Validate play number using self
            if (self.play_number > 500) {
                return PlayHandlerError.PlaySequenceError;
            }
            
            // Additional validations for the specific stats passed in
            // Check for unrealistic values in unsigned fields
            if (team_stats.plays_run > 10000 or
                team_stats.first_downs > 1000 or
                team_stats.turnovers > 100) {
                return PlayHandlerError.StatisticsOverflow;
            }
            
            // Basic integrity checks
            // Passing + rushing should approximately equal total
            const calc_total = team_stats.passing_yards + team_stats.rushing_yards;
            if (@abs(calc_total - team_stats.total_yards) > 100) {
                return PlayHandlerError.InvalidStatistics;
            }
            
            // Turnovers shouldn't exceed plays run
            if (team_stats.turnovers > team_stats.plays_run) {
                return PlayHandlerError.InvalidStatistics;
            }
        }

        /// Recover from play handler error.
        ///
        /// Attempts to recover from a specific error condition.
        ///
        /// __Parameters__
        ///
        /// - `self`: Mutable reference to PlayHandler
        /// - `err`: The error to recover from
        ///
        /// __Return__
        ///
        /// - void
        pub fn recoverFromError(self: *PlayHandler, err: PlayHandlerError) void {
            switch (err) {
                PlayHandlerError.InvalidPlayType => {
                    // Reset to safe play type
                    // No direct action needed as play type is per-play
                },
                PlayHandlerError.InvalidYardage => {
                    // Reset statistics that might be affected
                    self.home_stats.total_yards = 0;
                    self.away_stats.total_yards = 0;
                },
                PlayHandlerError.InvalidFieldPosition => {
                    // Reset to midfield
                    // Field position is typically transient
                },
                PlayHandlerError.InvalidDownAndDistance => {
                    // Reset to first down
                    self.game_state.down = 1;
                    self.game_state.distance = 10;
                },
                PlayHandlerError.InvalidGameState => {
                    // Reset to safe game state
                    self.game_state = .{
                        .down = 1,
                        .distance = 10,
                        .possession = .home,
                        .home_score = 0,
                        .away_score = 0,
                        .quarter = 1,
                        .time_remaining = 900,
                        .play_clock = 40,
                        .clock_running = false,
                    };
                },
                PlayHandlerError.InvalidStatistics => {
                    // Reset statistics to consistent state
                    self.home_stats = std.mem.zeroes(PlayStatistics);
                    self.away_stats = std.mem.zeroes(PlayStatistics);
                },
                PlayHandlerError.StatisticsOverflow => {
                    // Reset statistics
                    self.home_stats = std.mem.zeroes(PlayStatistics);
                    self.away_stats = std.mem.zeroes(PlayStatistics);
                },
                PlayHandlerError.PlaySequenceError => {
                    // Reset play sequence
                    self.play_number = 0;
                },
                PlayHandlerError.InvalidPlayResult => {
                    // Reset to safe game state since play result was invalid
                    self.game_state = .{
                        .down = 1,
                        .distance = 10,
                        .possession = self.possession_team,
                        .home_score = self.game_state.home_score,
                        .away_score = self.game_state.away_score,
                        .quarter = self.game_state.quarter,
                        .time_remaining = self.game_state.time_remaining,
                        .play_clock = 40,
                        .clock_running = false,
                    };
                },
            }
        }
    };


// ╚════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ UTILS ══════════════════════════════════════╗

    /// Calculate expected points for current field position.
    ///
    /// Returns EPA (Expected Points Added) value for field position.
    ///
    /// __Parameters__
    ///
    /// - `field_position`: Field position (0-100, 0 = own end zone)
    ///
    /// __Return__
    ///
    /// - Expected points value
    pub fn getExpectedPoints(field_position: u8) f32 {
        // Simplified expected points model
        // Real NFL EPA is more complex
        const distance_to_endzone = 100 - field_position;

        if (distance_to_endzone <= 5) return 5.5;
        if (distance_to_endzone <= 10) return 4.8;
        if (distance_to_endzone <= 20) return 3.5;
        if (distance_to_endzone <= 30) return 2.4;
        if (distance_to_endzone <= 40) return 1.5;
        if (distance_to_endzone <= 50) return 0.7;
        if (distance_to_endzone <= 60) return 0.0;
        if (distance_to_endzone <= 70) return -0.5;
        if (distance_to_endzone <= 80) return -1.0;
        if (distance_to_endzone <= 90) return -1.5;
        return -2.0;
    }

    /// Simulate time for hurry-up offense.
    ///
    /// Returns typical time consumption for hurry-up plays.
    ///
    /// __Return__
    ///
    /// - Time in seconds for hurry-up play
    pub fn getHurryUpPlayTime() u32 {
        // Hurry-up plays typically take 10-15 seconds of game time
        return 12;
    }

    /// Simulate time for normal play.
    ///
    /// Returns typical time consumption for standard plays.
    ///
    /// __Return__
    ///
    /// - Time in seconds for normal play
    pub fn getNormalPlayTime() u32 {
        // Normal plays typically take 35-40 seconds including huddle
        return 38;
    }



// ╚════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ TEST ═══════════════════════════════════════╗

    test "process pass play" {
        var handler = PlayHandler.init(12345);

        const result = handler.processPlay(.pass_short, .{}, null);
        try std.testing.expect(result.play_type == .pass_short);
        try std.testing.expect(result.time_consumed > 0);
    }

    test "process run play" {
        var handler = PlayHandler.init(12345);

        const result = handler.processPlay(.run_up_middle, .{}, null);
        try std.testing.expect(result.play_type == .run_up_middle);
        try std.testing.expect(result.time_consumed > 0);
    }

    test "field goal processing" {
        var handler = PlayHandler.init(12345);
        const initial_score = handler.game_state.away_score;

        _ = handler.processPlay(.field_goal, .{ .kick_distance = 30 }, null);

        // Score might or might not increase based on random success
        try std.testing.expect(handler.game_state.away_score >= initial_score);
    }

    test "touchdown scoring" {
        var handler = PlayHandler.init(12345);
        handler.game_state.possession = .home;
        handler.possession_team = .home;

        // Simulate a touchdown
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

        handler.updateGameState(&result);
        try std.testing.expectEqual(@as(u16, 6), handler.game_state.home_score);
    }

    test "down and distance progression" {
        var handler = PlayHandler.init(12345);

        // Test normal progression
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
        try std.testing.expectEqual(@as(u8, 2), handler.game_state.down);
        try std.testing.expectEqual(@as(u8, 7), handler.game_state.distance);

        // Test first down
        result.yards_gained = 7;
        result.is_first_down = true;
        handler.updateGameState(&result);
        try std.testing.expectEqual(@as(u8, 1), handler.game_state.down);
        try std.testing.expectEqual(@as(u8, 10), handler.game_state.distance);
    }

// ╚════════════════════════════════════════════════════════════════════════════════════╝