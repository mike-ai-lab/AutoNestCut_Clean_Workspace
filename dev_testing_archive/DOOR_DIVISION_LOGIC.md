# 🚪 Smart Door Division Feature

## Overview
Cupboards automatically divide into multiple doors when the width exceeds 100cm per door.

## Maximum Door Width
- **Max single door width**: 100cm
- **Ensures**: No door exceeds this width for practical use

## Examples

### Example 1: 60cm Cupboard
- **Total Width**: 60cm
- **Doors**: 2 doors
- **Each Door**: 30cm
- **Logic**: Standard 2-door cupboard (under 200cm total)

### Example 2: 150cm Cupboard
- **Total Width**: 150cm
- **Doors**: 2 doors
- **Each Door**: 75cm
- **Logic**: Standard 2-door cupboard (under 200cm total)

### Example 3: 220cm Cupboard
- **Total Width**: 220cm
- **Calculation**: 220 ÷ 100 = 2.2 → ceil = 3 doors
- **Doors**: 4 doors (3 is odd, so +1 for symmetry)
- **Each Door**: 55cm
- **Logic**: Exceeds 200cm, needs more doors

### Example 4: 300cm Cupboard
- **Total Width**: 300cm
- **Calculation**: 300 ÷ 100 = 3 → ceil = 3 doors
- **Doors**: 4 doors (3 is odd, so +1 for symmetry)
- **Each Door**: 75cm
- **Logic**: Divided evenly into 4 doors

### Example 5: 400cm Cupboard
- **Total Width**: 400cm
- **Calculation**: 400 ÷ 100 = 4 → ceil = 4 doors
- **Doors**: 4 doors (already even)
- **Each Door**: 100cm
- **Logic**: Perfect division at max width

### Example 6: 450cm Cupboard
- **Total Width**: 450cm
- **Calculation**: 450 ÷ 100 = 4.5 → ceil = 5 doors
- **Doors**: 6 doors (5 is odd, so +1 for symmetry)
- **Each Door**: 75cm
- **Logic**: Divided evenly into 6 doors

## Algorithm

```ruby
def calculate_door_count(total_width_cm)
  # Standard 2 doors if under 200cm
  return 2 if total_width_cm <= 100 * 2
  
  # Calculate minimum doors needed
  min_doors = (total_width_cm / 100).ceil
  
  # Ensure even number for symmetry
  min_doors += 1 if min_doors.odd?
  
  min_doors
end
```

## Benefits

1. **Practical**: No door exceeds 100cm width
2. **Symmetric**: Always even number of doors
3. **Automatic**: No manual calculation needed
4. **Flexible**: Works for any cupboard width

## Console Output

When generating a cupboard, you'll see:
```
📐 Cupboard width: 220cm → Creating 4 doors (55.0cm each)
```

This confirms the door division calculation.
