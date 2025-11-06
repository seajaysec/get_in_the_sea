# In C - Streamlined Coding Reference

## Operational Modes

### 1. AUTONOMOUS MODE
- All 8 players are AI agents following the rules below
- Players make independent decisions about advancement, rests, dynamics
- User controls: Start, Stop, Tempo, Pulse toggle

### 2. SEMI-AUTONOMOUS MODE  
- All 8 players advance patterns together when user triggers
- User controls: Next Pattern button (advances all), individual player volumes
- Within each pattern, players still independently decide:
  - Number of repetitions before waiting for user's "next"
  - Octave displacement
  - Rest behavior (but return to current user-set pattern)
  - Dynamic following

### 3. MANUAL MODE
- User controls each player's pattern advancement individually
- User controls: 8 separate "Next Pattern" buttons/keys
- Automated behaviors to ease burden:
  - Automatic Pattern 53 detection and wait protocol
  - Automatic ensemble median calculation and warning if >3 spread
  - Optional auto-advance if player falls >3 patterns behind
  - Suggested advancement indicators based on time in pattern
  - Visual convergence detection alerts
  - Automatic ending protocol once all reach 53

## Pulse Configuration

### The Pulse (Optional 9th Voice)
```
Configuration:
  enabled: boolean (user toggle)
  note: C (two octaves above middle C, traditionally)
  rhythm: continuous eighth notes
  tempo: matches global tempo
  volume: 0.7-0.9 (should be prominent)
  audio_engine: uses current/main audio engine
  
Behavior:
  - Begins 5-10 seconds before first player entry
  - Maintains perfectly steady tempo (no humanization)
  - Continues through entire performance
  - Last voice to fade in ending protocol
  - No rests, no variation, no pattern following
  - Pure metronomic function
```

## Core Constants & Parameters

### Tempo & Duration
- **Tempo Range**: 69-132 BPM (quarter note)
- **Common Range**: 96-120 BPM
- **Target Duration**: 45-90 minutes total
- **Pattern Duration**: 45 seconds to 1.5 minutes per pattern (average)
- **Duration Formula**: At ~1 minute per pattern × 53 patterns ≈ 53 minutes

### Pattern Data
- **Total Patterns**: 53
- **Pattern Lengths**: 1 to 64 eighth notes (Pattern 35 is longest at 60 pulses)
- **Total Written Material**: 521 eighth notes
- **Recurring Patterns**: 
  - Pattern 10 = Pattern 41
  - Pattern 11 = Pattern 36  
  - Pattern 18 = Pattern 28

## Player Agent Rules

### Pattern Navigation
```
HARD RULE: Maximum separation = 3 patterns
- Can play: current_pattern, current_pattern-1, current_pattern-2
- If ensemble_median is at pattern N:
  - Players must be within [N-2, N+3]
  - If too far behind: jump forward
  - If too far ahead: rest and wait
```

### Pattern Repetition Logic
```
For each pattern:
  min_repetitions = tempo_dependent_minimum (ensure 45 sec minimum)
  max_repetitions = tempo_dependent_maximum (cap at ~90 sec)
  
  // Adjust for pattern length to prevent long patterns dominating
  if pattern_length > 30_eighth_notes:
    reduce max_repetitions proportionally
  
  actual_repetitions = random(min, max) with bias toward middle
```

### Entry Protocol
```
Start:
  - Optional pulse begins (if enabled)
  - Wait random(0, 20) seconds
  - Begin Pattern 1
  - Each player enters individually, staggered
```

### Exit Protocol
```
When reaching Pattern 53:
  1. Stay on Pattern 53 until all players arrive
  2. When all_players_on_53:
     - Execute 3-5 crescendo/diminuendo cycles (20-30 sec)
     - Each player fades out individually
     - Pulse (if present) fades last
```

### Rest Behavior
```
rest_probability = 0.1-0.2 per pattern transition
rest_duration = random(1, 3) patterns
// Must maintain minimum ensemble density
if active_players < minimum_threshold:
  override rest
```

## Ensemble Coordination

### Pattern Alignment Detection
```
Check every N seconds:
  if 60% of players on same pattern:
    convergence_mode = true
    extend_current_pattern_duration by 1.5x
    after random(15, 30) seconds:
      resume_normal_progression
```

### Dynamic Following
```
sample ensemble_average_volume every second
if trend detected over 3 seconds:
  follow trend with 70% probability
  maintain current with 20% probability  
  oppose trend with 10% probability (for variety)
```

### Octave Displacement
```
For each pattern entry:
  base_octave = instrument_natural_range
  displacement_probability = 0.3
  if displace:
    direction = weighted_random(up: 0.7, down: 0.3)
    amount = 1 octave (rarely 2)
  
  // Special rules:
  if pattern has long notes && low instrument:
    prefer down octave
  if pattern has fast notes && high instrument:
    prefer up octave
```

## Time Management

### Pattern Duration Normalization
```
// Prevent long patterns from dominating timeline
base_duration = random(45, 90) seconds

normalized_duration = base_duration * (avg_pattern_length / current_pattern_length)
// But never less than minimum
final_duration = max(normalized_duration, 30 seconds)
```

### Global Pacing
```
ensemble_progress_rate = current_median_pattern / elapsed_time
if progress_rate < target_rate:
  bias all players toward shorter repetitions
if progress_rate > target_rate:
  bias toward longer repetitions
```

## Implementation Architecture

### Player Agent State
```javascript
class Player {
  currentPattern: 1-53
  repetitionsRemaining: integer
  isResting: boolean
  restPatternsRemaining: integer
  currentOctave: integer
  volume: 0.0-1.0
  timeSinceLastChange: float
  isWaitingForUser: boolean  // Semi-auto/Manual modes
  autoAdvanceWarning: boolean // Manual mode spread detection
}
```

### Ensemble Manager
```javascript
class Ensemble {
  mode: 'autonomous' | 'semi-autonomous' | 'manual'
  players: Player[]
  globalTempo: BPM
  pulseEnabled: boolean
  pulseVolume: 0.0-1.0
  medianPattern: integer
  convergenceMode: boolean
  dynamicTrend: rising|falling|stable
  elapsedTime: seconds
  userPatternTarget: integer  // Semi-auto mode
}
```

### Pulse Agent
```javascript
class Pulse {
  enabled: boolean
  note: 'C7'  // Two octaves above middle C
  tempo: BPM  // Matches ensemble
  volume: 0.8
  isPlaying: boolean
  startDelay: 5000ms  // Before first player
}
```

### Decision Points (per player per beat)

#### AUTONOMOUS MODE
1. **Should I advance?** Check repetitions complete
2. **Should I rest?** Check rest probability and ensemble density
3. **Should I return?** If resting, check if behind ensemble
4. **Should I jump?** If too far behind median
5. **Should I change octave?** On new pattern entry
6. **Should I adjust dynamics?** Every second, check ensemble trend

#### SEMI-AUTONOMOUS MODE  
1. **Should I keep repeating?** Until user signals next
2. **Should I rest?** Yes, but return to current user-set pattern
3. **Should I change octave?** On pattern entry after user advance
4. **Should I adjust dynamics?** Follow ensemble trends
5. **Am I ready indicator?** Show visual after min repetitions reached

#### MANUAL MODE
1. **Should I auto-advance?** Only if >3 patterns behind median (safety)
2. **Should I warn user?** If approaching 3 pattern spread
3. **Show ready indicator?** After 45-90 seconds in pattern
4. **Pattern 53 auto-wait?** Yes, override manual control
5. **Ending protocol?** Automatic once all reach 53

## Mode-Specific User Interface

### AUTONOMOUS MODE Controls
```
- Start/Stop button
- Tempo slider (69-132 BPM)
- Pulse toggle (on/off)
- Global volume
- Visual: Pattern position graph for all 8 players
```

### SEMI-AUTONOMOUS MODE Controls
```
- Next Pattern button (advances all players)
- Individual player volume sliders (8)
- Tempo slider
- Pulse toggle
- Visual: Current pattern number (large)
- Visual: Time in current pattern
- Visual: "Ready" indicators per player
```

### MANUAL MODE Controls
```
- 8 Next Pattern buttons (keyboard: 1-8 keys)
- Pattern jump shortcuts (shift+1-8: jump to median)
- Auto-catch-up toggle (for lagging players)
- Visual: Pattern spread warning (red if >2)
- Visual: Convergence opportunity alert
- Visual: Individual pattern numbers per player
- Visual: Median pattern tracker
- Visual: Suggested advance indicators (green glow)
- Tempo and Pulse controls
```

## Special Behavioral Rules

### Convergence Events
- **Frequency**: 1-2 times per performance
- **Trigger**: When >60% players naturally align
- **Duration**: 15-30 seconds of synchronized playing
- **Exit**: Staggered, maintaining 2-3 pattern spread

### Listening Simulation
```
Each player maintains awareness of:
  - 2-3 nearest neighbors (for local interactions)
  - Ensemble median (for position checking)
  - Global dynamics (for volume following)
  - Pattern density (for rest decisions)
```

### Human Imperfection
```
timing_offset = gaussian(0, 30ms)
volume_fluctuation = ±5% random walk
pattern_advance_delay = 0-500ms after last note
occasional_skip = 2% chance to skip a pattern entirely
```

## Key Ratios & Probabilities

- **Rest Frequency**: ~10-20% of pattern transitions
- **Octave Change**: ~30% of pattern entries
- **Dynamic Following**: ~70% conformity, 30% independence
- **Pattern Skip**: ~2% (instrument limitation simulation)
- **Convergence**: 1-2 times per 45-90 min performance
- **Entry Spread**: 0-20 seconds at start
- **Exit Spread**: 10-30 seconds at end

## Minimum Viable Implementation

### AUTONOMOUS MODE
```python
# Core loop per player per pattern
while current_pattern <= 53:
    repetitions = calculate_weighted_repetitions(pattern_length, tempo)
    
    for rep in range(repetitions):
        play_pattern(current_pattern, current_octave)
        
        # Check ensemble state
        if too_far_behind(median_pattern):
            break  # Jump forward
            
        if should_rest():
            rest_for_patterns(random(1,3))
            
    current_pattern += 1
    
    # Pattern 53 special handling
    if current_pattern == 53:
        wait_for_all_players()
        perform_ending_protocol()
```

### SEMI-AUTONOMOUS MODE
```python
# Core loop per player
while current_pattern <= 53:
    repetitions = calculate_weighted_repetitions(pattern_length, tempo)
    repetitions_played = 0
    
    while not user_advanced_signal:
        play_pattern(current_pattern, current_octave)
        repetitions_played += 1
        
        if repetitions_played >= repetitions:
            show_ready_indicator()
            # Keep looping but player is "ready"
            
        if should_rest():
            rest_for_patterns(1)  # Shorter rests in semi-auto
    
    # User clicked "Next Pattern"
    current_pattern = user_pattern_target
    clear_ready_indicator()
    
    if current_pattern == 53:
        wait_for_all_players()
        perform_ending_protocol()
```

### MANUAL MODE
```python
# Core loop per player
while current_pattern <= 53:
    time_in_pattern = 0
    
    while current_pattern == player_pattern[player_id]:
        play_pattern(current_pattern, current_octave)
        time_in_pattern += pattern_duration
        
        # Helpers for user
        if time_in_pattern > 45_seconds:
            show_advance_suggestion()
            
        if abs(current_pattern - median_pattern) > 2:
            show_spread_warning()
            
        if abs(current_pattern - median_pattern) > 3:
            if auto_catchup_enabled:
                current_pattern = median_pattern - 1
                flash_auto_advance_notification()
        
        # Check for user input
        if user_pressed_next[player_id]:
            current_pattern += 1
            time_in_pattern = 0
            clear_advance_suggestion()
    
    # Auto-handle ending
    if current_pattern == 53 and all_players_at_53():
        auto_perform_ending_protocol()
```

## Pulse Implementation (All Modes)
```python
class PulseVoice:
    def __init__(self, audio_engine):
        self.audio = audio_engine  # Use main engine
        self.note = 'C7'  # Two octaves above middle C
        self.enabled = False
        
    def start(self, tempo):
        if self.enabled:
            sleep(5)  # 5-10 second delay
            while performance_active:
                self.audio.play_note(self.note, 
                                    duration=60/tempo/2,  # Eighth note
                                    volume=0.8)
                sleep(60/tempo/2)  # Eighth note spacing
                
    def stop_with_fade(self, duration=3):
        # Pulse is last to fade
        for vol in linspace(0.8, 0, duration*10):
            self.volume = vol
            sleep(0.1)
```

## Critical Constraints

1. **Never exceed 3 pattern separation** (breaks if violated)
2. **Always wait at pattern 53** (required for ending)
3. **Maintain minimum active players** (prevents silence)
4. **Respect tempo bounds** (69-132 BPM)
5. **Honor 45-90 minute duration** (performance expectation)

## Mode-Specific Burden Reduction

### MANUAL MODE Assists
To make manual control manageable for 8 players:

1. **Visual Clustering**: Group players by current pattern visually
2. **Batch Operations**: Shift+click to advance multiple selected players
3. **Auto-Alignment**: Double-click to jump player to median
4. **Pattern Memory**: Remember typical repetition counts per player
5. **Predictive Highlighting**: Glow players likely needing advancement
6. **Keyboard Shortcuts**:
   - 1-8: Advance individual players
   - Shift+1-8: Jump to median
   - Space: Advance all ready players
   - A: Select all at same pattern
   - C: Trigger convergence mode for selected

### SEMI-AUTONOMOUS MODE Assists
1. **Ready Consensus**: Show percentage of players ready
2. **Pattern Duration Timer**: Visual countdown/progress bar
3. **Auto-Advance Option**: After all players signal ready
4. **Pattern Preview**: Show next pattern number/notation
5. **Optimal Timing Hints**: Subtle pulse when good to advance

### Visual Feedback (All Modes)
```
Pattern Map: [●●●●●○○○----------] (players 1-5 on pattern 6, 6-8 on 7)
Spread: OK | WARNING | CRITICAL
Convergence: 70% aligned (opportunity!)
Duration: 23:45 / ~50:00
Current Median: Pattern 24
```

## Emergence Goals

The implementation should produce:
- Unpredictable but coherent texture evolution
- Natural crescendos and diminuendos
- Occasional magical alignments
- Continuously shifting timbral combinations
- Self-correcting ensemble cohesion
- No two performances identical
- Meditative/trance-like quality through repetition
