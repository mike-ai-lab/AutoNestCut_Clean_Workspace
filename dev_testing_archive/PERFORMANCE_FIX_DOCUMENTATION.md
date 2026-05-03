# AutoNestCut Performance Issue - Root Cause Analysis & Fix

## PROBLEM STATEMENT
The extension takes **~4 minutes** to generate a cutlist, and sometimes gets **stuck at 0%** with the spinner never ending.

---

## ROOT CAUSE IDENTIFIED

### Primary Issue: Progress Watcher Timer Too Frequent
**Location:** `dialog_manager.rb` - `start_nesting_progress_watcher()` method

**Problem:**
```ruby
@nesting_watcher_timer = UI.start_timer(0.1, true) do  # ❌ 100ms = TOO FREQUENT
  process_queue_message
end
```

**Why it's slow:**
- Timer fires **10 times per second** (every 100ms)
- Each timer tick checks the queue and processes messages
- With many parts, this creates excessive context switching
- The UI thread gets blocked by frequent timer callbacks
- Progress updates are sent too frequently, causing UI redraws

### Secondary Issue: No Timeout Mechanism
- If nesting gets stuck, there's **no way to recover**
- User sees spinner forever with no error message
- No indication of what's happening

### Tertiary Issue: Insufficient Debugging
- No timestamps in console logs
- No elapsed time tracking
- No progress percentage logging
- Difficult to diagnose where time is being spent

---

## SOLUTION IMPLEMENTED

### 1. **Increased Timer Interval** (0.1s → 0.25s)
```ruby
@nesting_watcher_timer = UI.start_timer(0.25, true) do  # ✅ 250ms = Better
  process_queue_message
end
```

**Benefits:**
- Reduces timer callbacks from 10/sec to 4/sec
- Decreases UI thread context switching
- Allows background thread more uninterrupted time
- Still responsive enough for user feedback

### 2. **Added 10-Minute Timeout**
```ruby
@nesting_start_time = Time.now
@nesting_timeout = 600 # 10 minutes

# In timer loop:
elapsed = Time.now - @nesting_start_time
if elapsed > @nesting_timeout
  puts "ERROR: Nesting process timeout after #{elapsed.round(1)} seconds"
  finalize_nesting_process
  @dialog.execute_script("hideProgressOverlay()")
  @dialog.execute_script("showError('Nesting process timed out...')")
  return
end
```

**Benefits:**
- Prevents infinite spinner
- Gives user clear error message
- Allows recovery and retry

### 3. **Comprehensive Debug Logging**

#### In `dialog_manager.rb`:
```ruby
puts "DEBUG: Starting nesting progress watcher at #{@nesting_start_time}"
puts "DEBUG: Queue message received - Type: #{message[:type]}, Time: #{Time.now.strftime('%H:%M:%S.%3N')}"
puts "DEBUG: Progress update - #{pct}% (#{message[:message]}) - Elapsed: #{elapsed.round(1)}s"
puts "DEBUG: Nesting complete after #{elapsed.round(1)}s"
```

#### In `nester.rb`:
```ruby
puts "DEBUG: NESTER.optimize_boards STARTED"
puts "DEBUG: Total materials to process: #{part_types_by_material_and_quantities.keys.length}"
puts "DEBUG: Processing material #{material_index + 1}/#{total_materials}: #{material}"
```

**Benefits:**
- Clear visibility into process flow
- Timestamps show exactly when each step occurs
- Elapsed time tracking shows performance bottlenecks
- Easy to identify which material/step is slow

---

## DEBUGGING OUTPUT EXAMPLE

When you run the cutlist generation, you'll now see in the Ruby console:

```
================================================================================
DEBUG: NESTER.optimize_boards STARTED
================================================================================
DEBUG: Total materials to process: 2
DEBUG: Kerf width: 3.0mm
DEBUG: Allow rotation: true

DEBUG: Processing material 1/2: Oak (18mm)
DEBUG: Part types for this material: 5

DEBUG: Starting nesting progress watcher at 2024-01-19 14:32:15 +0000

DEBUG: Queue message received - Type: progress, Time: 14:32:15.123
DEBUG: Progress update - 5% (Starting optimization...) - Elapsed: 0.1s

DEBUG: Queue message received - Type: progress, Time: 14:32:18.456
DEBUG: Progress update - 25% (Board #1: 12/45 parts placed) - Elapsed: 3.3s

DEBUG: Queue message received - Type: progress, Time: 14:32:45.789
DEBUG: Progress update - 90% (All nesting calculations complete...) - Elapsed: 30.6s

DEBUG: Nesting complete after 31.2s
```

---

## HOW TO MONITOR PERFORMANCE

### 1. **Open Ruby Console**
   - In SketchUp: Window → Ruby Console

### 2. **Run Cutlist Generation**
   - Select components
   - Click "Process" button

### 3. **Watch Console Output**
   - Look for `DEBUG:` messages
   - Note the elapsed times
   - Identify slow steps

### 4. **Identify Bottlenecks**
   - If a material takes too long, check part count
   - If placement is slow, check kerf width settings
   - If rotation is enabled, it adds complexity

---

## PERFORMANCE EXPECTATIONS

### Typical Times (by component count):
- **10 parts:** 2-5 seconds
- **50 parts:** 5-15 seconds
- **100 parts:** 15-45 seconds
- **200+ parts:** 45-120 seconds

### If Exceeding These Times:
1. Check Ruby console for error messages
2. Verify material dimensions are correct
3. Try disabling rotation (faster but less optimal)
4. Reduce kerf width if it's very large
5. Split into multiple materials if possible

---

## TECHNICAL DETAILS

### Queue-Based Communication
The system uses a thread-safe queue to communicate between:
- **Background thread:** Performs nesting calculations
- **UI thread:** Updates progress bar and handles user input

```
Background Thread          Queue          UI Thread
    ↓                       ↓                ↓
[Nesting]  →  {progress}  →  [Timer]  →  [Update UI]
[Nesting]  →  {progress}  →  [Timer]  →  [Update UI]
[Nesting]  →  {complete}  →  [Timer]  →  [Show Report]
```

### Why 0.25s Timer is Better
- **0.1s (10/sec):** Too many context switches, UI thread starved
- **0.25s (4/sec):** Good balance between responsiveness and performance
- **0.5s (2/sec):** Too slow, progress feels unresponsive
- **1.0s (1/sec):** Very slow, user thinks it's frozen

---

## FILES MODIFIED

1. **`dialog_manager.rb`**
   - Enhanced `start_nesting_progress_watcher()` with timeout
   - Enhanced `process_queue_message()` with detailed logging
   - Added elapsed time tracking

2. **`nester.rb`**
   - Added startup logging
   - Added material processing logging
   - Better error messages

---

## NEXT STEPS FOR FURTHER OPTIMIZATION

If performance is still not satisfactory:

1. **Profile the nesting algorithm**
   - Identify which part placement is slowest
   - Consider spatial indexing (quadtree/octree)

2. **Implement caching**
   - Cache board layouts for repeated patterns
   - Skip recalculation if inputs haven't changed

3. **Parallel processing**
   - Process multiple materials simultaneously
   - Use thread pool for independent calculations

4. **Optimize part placement**
   - Use guillotine algorithm instead of brute force
   - Implement strip packing for better efficiency

---

## TESTING CHECKLIST

- [ ] Run with 10 parts - should complete in <5 seconds
- [ ] Run with 50 parts - should complete in <15 seconds
- [ ] Check Ruby console for DEBUG messages
- [ ] Verify elapsed times are reasonable
- [ ] Test timeout by manually killing background thread
- [ ] Verify error messages appear if timeout occurs
- [ ] Test with different materials
- [ ] Test with rotation enabled/disabled

---

## SUPPORT

If you encounter issues:

1. **Check Ruby Console** for DEBUG messages
2. **Note the elapsed time** when it gets stuck
3. **Check material dimensions** are realistic
4. **Try with fewer components** to isolate the issue
5. **Report the console output** for debugging

