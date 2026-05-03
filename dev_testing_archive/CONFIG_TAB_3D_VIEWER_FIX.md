# Configuration Tab 3D Viewer Fix - Implementation Plan

## Problem
The Configuration tab's 3D viewer currently:
1. Highlights parts as groups (all instances together) instead of individual instances
2. Has no consistent ID system like the Report tab
3. Lacks bidirectional highlighting (clicking 3D part doesn't highlight table row)
4. Doesn't use the same reliable matching system as the Report tab

## Solution
Replicate the Report tab's unique ID system for the Configuration tab:

### Backend Changes (Ruby)
**File**: `Extension/AutoNestCut/ui/dialog_manager.rb` or wherever config data is sent

1. Add unique instance IDs to parts when s