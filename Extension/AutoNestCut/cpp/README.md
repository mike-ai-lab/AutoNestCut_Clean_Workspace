# AutoNestCut C++ Nesting Solver

High-performance nesting engine for AutoNestCut SketchUp extension.

## Building

### Windows

Requirements:
- Visual Studio 2019 or later (with C++ tools)
- CMake 3.15+

```bash
cd Extension/AutoNestCut/cpp
build.bat
```

This creates `nester.exe` in the cpp directory.

### Manual Build

```bash
mkdir build
cd build
cmake .. -G "Visual Studio 17 2022" -A x64
cmake --build . --config Release
```

## Usage

```bash
nester.exe input.json output.json
```

### Input JSON Format

```json
{
  "boards": [
    {
      "material": "Plywood_18mm",
      "width": 2440,
      "height": 1220
    }
  ],
  "parts": [
    {
      "id": "part_1",
      "material": "Plywood_18mm",
      "width": 600,
      "height": 400,
      "grain_direction": "any"
    }
  ],
  "settings": {
    "kerf": 3.0,
    "allow_rotation": true,
    "timeout_ms": 60000
  }
}
```

### Output JSON Format

```json
{
  "placements": [
    {
      "part_id": "part_1",
      "board_id": 1,
      "x": 0,
      "y": 0,
      "rotation": 0
    }
  ],
  "boards": [
    {
      "id": 1,
      "material": "Plywood_18mm",
      "width": 2440,
      "height": 1220,
      "parts_count": 1,
      "used_area": 240000,
      "waste_percentage": 8.5
    }
  ],
  "stats": {
    "time_ms": 42,
    "boards_used": 1
  }
}
```

## Algorithm

- **Maximal Rectangles** bin packing with free rectangle tracking
- **Bottom-left** placement heuristic
- **Largest-first** part sorting
- **Greedy** approach (no backtracking)

## Performance

Target performance:
- Small projects (10-50 parts): < 100ms
- Medium projects (100-200 parts): < 1s
- Large projects (500+ parts): < 10s

## Integration with Ruby

The Ruby extension calls this executable via `system()` or `Open3.popen3`:

```ruby
require 'json'
require 'open3'

# Prepare input
input_data = {
  boards: [...],
  parts: [...],
  settings: {...}
}

# Write input JSON
File.write(temp_input, input_data.to_json)

# Call C++ solver
exe_path = File.join(__dir__, 'cpp', 'nester.exe')
system("#{exe_path} #{temp_input} #{temp_output}")

# Read results
result = JSON.parse(File.read(temp_output))
```
