## Instructions

**Project:** `autonestcut_clean_workspace`
**Goal:** Replace Ruby-based nesting/optimization with a high-performance C++ external solver while keeping SketchUp Ruby for UI, orchestration, and I/O only.

---

### 1. Architecture Decision (Non-Negotiable)

* Use **external C++ executable**, not Ruby C-extension
* Ruby = controller + UI + file prep + progress + import results
* C++ = all heavy computation:

  * nesting
  * rotations
  * collision checks
  * fitness evaluation
  * board packing
  * optimization loops

Reason:

* Prevent SketchUp freezing
* Zero Ruby GC pressure
* Full OS memory cleanup on process exit
* Crash isolation

---

### 2. What to Extract From Ruby

Identify and REMOVE from Ruby any code that:

* Iterates geometries in optimization loops
* Tests placements
* Rotates parts repeatedly
* Calculates bounds / collisions repeatedly
* Scores layouts

Ruby keeps:

* Reading SketchUp geometry once
* Exporting simplified geometry data
* Progress UI
* Importing results
* View capture / export

---

### 3. Data Interface (Mandatory)

Use **JSON files** for IPC.

#### Ruby → C++ (input)

Export a single JSON file:

```json
{
  "boards": [
    { "id": 1, "width": 2440, "height": 1220 }
  ],
  "parts": [
    {
      "id": "p1",
      "material": "Cabinet_Wood",
      "polygon": [[0,0],[600,0],[600,400],[0,400]],
      "rotations": [0,90,180,270]
    }
  ],
  "settings": {
    "kerf": 3,
    "spacing": 5,
    "timeout_ms": 60000
  }
}
```

Ruby generates this once per run.

---

#### C++ → Ruby (output)

```json
{
  "placements": [
    {
      "part_id": "p1",
      "board_id": 1,
      "x": 120,
      "y": 80,
      "rotation": 90
    }
  ],
  "stats": {
    "time_ms": 412,
    "boards_used": 1
  }
}
```

---

### 4. C++ Responsibilities (Claude must implement)

* Parse input JSON
* Convert polygons to internal structures
* Run nesting algorithm:

  * bottom-left / skyline / guillotine (choose fastest)
  * heuristic or greedy (no brute force)
* Use:

  * `std::vector`
  * stack allocation where possible
  * no heap churn inside loops
* Output JSON result
* Print progress to STDOUT (optional)

---

### 5. Performance Rules (Strict)

* No STL maps inside hot loops
* No dynamic allocation inside nesting loop
* Precompute rotations
* Precompute bounding boxes
* Early rejection before polygon collision
* Terminate early if layout is “good enough”

Target:

* **< 1 second for small cabinets**
* **< 10 seconds for real projects**

---

### 6. Build Output

Claude must generate:

```
/cpp/
 ├─ src/
 │   ├─ main.cpp
 │   ├─ nesting.cpp
 │   └─ geometry.cpp
 ├─ CMakeLists.txt
 └─ build/
     └─ nester.exe
```

Windows first.
Binary name: `nester.exe`

---

### 7. Ruby Integration

Ruby must:

* Write input JSON to temp folder
* Call executable with `system()` or `Open3.popen3`
* Wait for completion
* Parse output JSON
* Apply placements in SketchUp

No Ruby loops for optimization allowed.

---

### 8. Development Rule

* Ruby code can change freely
* C++ recompiles only when algorithm changes
* Binary is bundled inside `.rbz`

---

### 9. Non-Goals (Explicit)

* No multithreading in Ruby
* No Ruby geometry math in loops
* No attempt to “optimize Ruby”
* No native Ruby C-extension

---

### 10. Expected Outcome

* SketchUp never freezes
* Memory usage stays flat
* Nesting time drops from minutes → seconds
* Extension feels professional-grade

---

## Final instruction to Claude

> Implement the C++ solver first, then wire Ruby to it.
> Performance is the priority, not elegance.

---
