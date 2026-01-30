# C++ Solver Setup Guide

## Step 1: Install a C++ Compiler

You need a C++ compiler to build the nesting solver. Choose ONE of these options:

### Option A: MinGW-w64 (Recommended - Easiest)

1. **Download MinGW-w64:**
   - Go to: https://github.com/niXman/mingw-builds-binaries/releases
   - Download: `x86_64-13.2.0-release-posix-seh-ucrt-rt_v11-rev1.7z`
   - Extract to: `C:\mingw64`

2. **Add to PATH:**
   - Open Windows Settings → Search "Environment Variables"
   - Click "Environment Variables" button
   - Under "System variables", find "Path", click "Edit"
   - Click "New" and add: `C:\mingw64\bin`
   - Click OK on all dialogs
   - **Restart your terminal/command prompt**

3. **Verify installation:**
   ```cmd
   g++ --version
   ```
   Should show: `g++ (MinGW-W64 x86_64-posix-seh...) 13.2.0`

### Option B: Visual Studio Build Tools

1. **Download:**
   - Go to: https://visualstudio.microsoft.com/downloads/
   - Scroll to "Tools for Visual Studio"
   - Download "Build Tools for Visual Studio 2022"

2. **Install:**
   - Run installer
   - Select "Desktop development with C++"
   - Install (requires ~7GB)

3. **Use Developer Command Prompt:**
   - Search for "Developer Command Prompt for VS 2022"
   - Run commands from there

---

## Step 2: Build the Solver

Once you have a compiler installed:

### If using MinGW (Option A):

```cmd
cd Extension\AutoNestCut\cpp
build_mingw.bat
```

### If using Visual Studio (Option B):

```cmd
cd Extension\AutoNestCut\cpp
build.bat
```

---

## Step 3: Test the Solver

After building, test it:

```cmd
nester.exe test_input.json test_output.json
```

You should see output like:
```
Settings: kerf=3mm, allow_rotation=1
Loaded 5 parts across 1 materials
=== Processing material: Plywood_18mm ===
Starting nesting for 5 parts on material: Plywood_18mm
Progress: 5/5 parts placed on 2 boards
Nesting complete: 5/5 parts placed on 2 boards
=== Nesting Complete ===
Total boards: 2
Time: 2ms
Results written to: test_output.json
```

Check `test_output.json` - it should contain placement data.

---

## Troubleshooting

### "g++ is not recognized"
- Make sure you added `C:\mingw64\bin` to PATH
- **Restart your terminal** after changing PATH
- Verify with: `g++ --version`

### "cmake is not recognized"
- You don't need CMake if using `build_mingw.bat`
- MinGW compiles directly without CMake

### Build errors
- Make sure you're in the `Extension/AutoNestCut/cpp` directory
- Check that all `.cpp` and `.h` files exist in `src/` folder
- Try cleaning: delete any `.exe` or `.o` files and rebuild

### Executable crashes
- Run: `nester.exe` (no arguments) - should show usage message
- If it crashes immediately, the build may have failed

---

## What's Next?

Once the executable builds successfully, I'll integrate it with your Ruby extension so it automatically uses the C++ solver instead of the slow Ruby nesting code.

---

## Quick Reference

**Build command (MinGW):**
```cmd
cd Extension\AutoNestCut\cpp
build_mingw.bat
```

**Test command:**
```cmd
nester.exe test_input.json test_output.json
```

**Expected result:**
- `nester.exe` file created in `cpp/` directory
- Test completes in < 100ms
- `test_output.json` contains placement data
