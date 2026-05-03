# Comprehensive Workflow Test Guide

## Overview

This test suite validates the complete AutoNestCut workflow from A to Z, including edge cases and error handling.

## Test Coverage

### Phase 1: Component Creation & Analysis
- ✅ Component creation and Part object initialization
- ✅ Material detection from faces and instances
- ✅ Dimension extraction (width, height, thickness)
- ✅ Grain direction handling (Any, horizontal, vertical, fixed)
- ✅ Edge banding parsing (all formats)

### Phase 2: Model Analysis
- ✅ Basic model analyzer functionality
- ✅ Empty selection handling
- ✅ Invalid component handling (lines, points, etc.)
- ✅ Nested component structures

### Phase 3: Nesting Algorithm
- ✅ Basic nesting with multiple parts
- ✅ Rotation for optimal fit
- ✅ Grain direction constraints
- ✅ Multiple material handling
- ✅ Oversized parts handling

### Phase 4: Report Generation
- ✅ Report data structure generation
- ✅ Data integrity validation
- ✅ Missing data handling

### Phase 5: Label Generation
- ✅ SVG label generation (label_generator.rb)
- ✅ PDF label sheet generation (label_sheet_generator.rb)
- ✅ QR code generation and encoding
- ✅ Label positioning on parts

### Phase 6: Material Highlighting
- ✅ Material highlighting by name
- ✅ Highlight toggle on/off
- ✅ Highlighting by thickness matching

### Phase 7: Export Functions
- ✅ CSV export
- ✅ PDF export
- ✅ SVG export for CNC

### Phase 8: Edge Cases & Error Handling
- ✅ Zero dimensions
- ✅ Negative dimensions
- ✅ Missing materials
- ✅ Duplicate components
- ✅ Very large quantities (1000+ parts)
- ✅ Special characters in names (<, >, &, ", ')
- ✅ Unicode material names (Cyrillic, Chinese, Arabic)

## How to Run

### Method 1: Load in SketchUp Ruby Console

```ruby
load 'C:/Users/Administrator/Desktop/AUTOMATION/cutlist/AutoNestCut/AutoNestCut_Clean_Workspace/Extension/AutoNestCut/COMPREHENSIVE_WORKFLOW_TEST.rb'
```

### Method 2: Run from Extension Menu

Add this to your development menu:

```ruby
# In main.rb, add to menu:
autonest_menu.add_item('🧪 Run Comprehensive Tests') { 
  require_relative 'COMPREHENSIVE_WORKFLOW_TEST'
  AutoNestCut::ComprehensiveWorkflowTest.run_all_tests
}
```

## Expected Output

```
================================================================================
AUTONESTCUT COMPREHENSIVE WORKFLOW TEST SUITE
================================================================================
Testing complete workflow from A to Z with edge cases
================================================================================

✓ PASS: Component Creation
✓ PASS: Material Detection
✓ PASS: Dimension Extraction
✓ PASS: Grain Direction Handling
✓ PASS: Edge Banding Parsing
✓ PASS: Model Analyzer - Basic
✓ PASS: Empty Selection Handling
⚠ WARN: Invalid Component Handling
✓ PASS: Nested Components
✓ PASS: Nesting - Basic
✓ PASS: Nesting - Rotation
✓ PASS: Nesting - Grain Constraints
⚠ WARN: Nesting - Oversized Parts
✓ PASS: Report Generation
✓ PASS: Report Data Integrity
✓ PASS: Label Generator - SVG
✓ PASS: Label Sheet Generator - PDF
✓ PASS: QR Code Generation
⚠ WARN: Zero Dimensions Handling
✓ PASS: Special Characters in Names
⚠ WARN: Unicode Material Names

================================================================================
TEST RESULTS SUMMARY
================================================================================

✓ PASSED: 18/22
  • Component Creation
  • Material Detection
  • Dimension Extraction
  • Grain Direction Handling
  • Edge Banding Parsing
  • Model Analyzer - Basic
  • Empty Selection Handling
  • Nested Components
  • Nesting - Basic
  • Nesting - Rotation
  • Nesting - Grain Constraints
  • Report Generation
  • Report Data Integrity
  • Label Generator - SVG
  • Label Sheet Generator - PDF
  • QR Code Generation
  • Special Characters in Names

⚠ WARNINGS: 4/22
  • Invalid Component Handling: Invalid components should be skipped
  • Nesting - Oversized Parts: Oversized parts should be handled
  • Zero Dimensions Handling: Zero dimensions should be handled gracefully
  • Unicode Material Names: Unicode handling

================================================================================
SUCCESS RATE: 81.8%
================================================================================
```

## Interpreting Results

### ✓ PASS
Test completed successfully with expected behavior.

### ✗ FAIL
Test failed - indicates a bug or issue that needs fixing.

### ⚠ WARN
Test completed but with edge case behavior - review to ensure it's acceptable.

## Common Issues

### Issue: "LoadError: cannot load such file"
**Solution:** Ensure you're running from the correct directory and all dependencies are loaded.

### Issue: "NameError: uninitialized constant"
**Solution:** The extension needs to be loaded first. Run `load 'Extension/autonestcut.rb'` first.

### Issue: Tests create components in model
**Solution:** Tests clean up after themselves, but if interrupted, run:
```ruby
Sketchup.active_model.active_entities.clear!
Sketchup.active_model.definitions.purge_unused
```

## Adding New Tests

To add a new test:

1. Create a method following the naming convention: `test_feature_name`
2. Use `begin...rescue` block for error handling
3. Call `pass_test(test_name)` on success
4. Call `fail_test(test_name, error)` on failure
5. Call `warn_test(test_name, message)` for edge cases
6. Add the test to `run_all_tests` method

Example:

```ruby
def self.test_new_feature
  test_name = "New Feature Test"
  begin
    # Test code here
    result = some_function()
    
    assert(result == expected, "Result should match expected")
    
    pass_test(test_name)
  rescue => e
    fail_test(test_name, e)
  end
end
```

## Continuous Integration

For automated testing, run the test suite after:
- ✅ Code changes to core modules
- ✅ Before creating .rbz package
- ✅ After updating dependencies
- ✅ Before major releases

## Known Limitations

1. **Visual Tests**: Cannot test UI dialogs automatically (requires manual testing)
2. **Performance Tests**: Not included (would require large datasets)
3. **Integration Tests**: Some features require user interaction (file save dialogs, etc.)
4. **Platform-Specific**: Some tests may behave differently on Windows vs macOS

## Next Steps

After running tests:

1. **Review failures** - Fix any ✗ FAIL results
2. **Review warnings** - Ensure ⚠ WARN behaviors are acceptable
3. **Manual testing** - Test UI features not covered by automated tests
4. **Performance testing** - Test with large models (100+ components)
5. **User acceptance testing** - Have real users test the workflow

## Support

If tests reveal issues, check:
- Console output for detailed error messages
- Ruby Console in SketchUp for stack traces
- Log files in temp directory
- Session documentation (session6.md, etc.)
