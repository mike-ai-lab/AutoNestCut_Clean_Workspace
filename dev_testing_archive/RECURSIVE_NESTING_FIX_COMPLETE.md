# Recursive Nesting Fix - Complete

## Problem
When parts are nested **multiple levels deep** (component → component → component), the 3D viewer was only drilling down **one level**, causing the entire outer container to be highlighted instead of the individual deepest part.

## Root Cause
Both backend and frontend were only checking for **one level** of nesting:
```ruby
# OLD: Only checked one level
if inner_entities.length == 1
  actual_part = inner_entities.first  # Stopped here!
end
```

## Solution: Recursive Drilling

### Backend Fix (report_generator.rb)
Changed from single-level check to **recursive loop** that drills down to the **deepest level**:

```ruby
# NEW: Recursively drill down to deepest level
loop do
  inner_entities = if actual_part.is_a?(Sketchup::ComponentInstance)
    actual_part.definition.entities.select { |e| e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance) }
  elsif actual_part.is_a?(Sketchup::Group)
    actual_part.entities.select { |e| e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance) }
  else
    []
  end
  
  # If there's exactly one nested component/group, drill down
  if inner_entities.length == 1
    actual_part = inner_entities.first
    nesting_depth += 1
  else
    # Either no nested components or multiple - stop drilling
    break
  end
end
```

### Frontend Fix (diagrams_report.js)
Changed click handler to **recursively drill down** through the Three.js scene graph:

```javascript
// NEW: Recursively drill down to deepest child
while (true) {
  const childGroups = currentGroup.children.filter(child => 
    child.type === 'Group' && child.userData && child.userData.partName
  );
  
  if (childGroups.length === 1) {
    currentGroup = childGroups[0];
    drillDepth++;
  } else {
    break;  // Stop at deepest level
  }
}
```

## How It Works

### Example: 3-Level Nesting
```
OuterComponent (ID: 1343272)
  └─ MiddleComponent (ID: 1343280)
      └─ InnerPart (ID: 1343284) ← NOW TARGETS THIS!
```

**Before Fix:**
- Backend: Used OuterComponent's ID (1343272)
- Frontend: Highlighted entire OuterComponent
- Result: ❌ Whole assembly highlighted, not individual part

**After Fix:**
- Backend: Drills down 2 levels → Uses InnerPart's ID (1343284)
- Frontend: Drills down 2 levels → Highlights only InnerPart
- Result: ✅ Individual part highlighted correctly

## Logging
Both backend and frontend now log the drilling depth:
- Backend: `🔍 Drilled down 2 level(s) for Part_18 - using deepest part's ID`
- Frontend: `🔍 Drilled down 2 level(s) to deepest part: Part_18`

## Testing
Test with components nested at various depths:
- ✅ Single level (no nesting)
- ✅ 2 levels (component → component)
- ✅ 3+ levels (component → component → component → ...)

## Result
The system now **always targets the deepest individual part**, matching exactly what the extension's nesting algorithm does, regardless of nesting depth!
