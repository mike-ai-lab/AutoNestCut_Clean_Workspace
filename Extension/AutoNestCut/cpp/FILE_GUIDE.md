# File Guide - What Each File Does

## 📖 Documentation (Read These)

| File | Purpose | When to Read |
|------|---------|--------------|
| **START_HERE.txt** | Quick start guide | **READ THIS FIRST** |
| **WHAT_YOU_NEED_TO_DO.md** | Your action items | Right after START_HERE |
| **SETUP_GUIDE.md** | Detailed setup instructions | If you need more details |
| **README.md** | Technical documentation | After everything works |
| **FILE_GUIDE.md** | This file | If you're confused about files |

---

## 🔧 Build Scripts (Run These)

| File | Purpose | When to Run |
|------|---------|-------------|
| **install_mingw.ps1** | Auto-install MinGW compiler | First time setup |
| **build_mingw.bat** | Build the C++ solver | After installing MinGW |
| **build.bat** | Build with Visual Studio | If using VS instead |
| **test.bat** | Test the built executable | After building |

---

## 💻 Source Code (Don't Touch These)

| File | Purpose | Notes |
|------|---------|-------|
| **src/main.cpp** | Entry point, JSON I/O | Handles input/output |
| **src/nesting.cpp** | Core nesting algorithm | Port of your Ruby code |
| **src/nesting.h** | Nesting header | Data structures |
| **src/geometry.cpp** | Rectangle math | Intersection, subtraction |
| **src/geometry.h** | Geometry header | Rectangle struct |

---

## 📦 Configuration (Don't Touch These)

| File | Purpose | Notes |
|------|---------|-------|
| **CMakeLists.txt** | CMake build config | For Visual Studio builds |
| **test_input.json** | Sample test data | Used by test.bat |

---

## 🎯 What You Actually Need to Do:

1. **Read:** `START_HERE.txt`
2. **Run:** `install_mingw.ps1` (right-click → Run with PowerShell)
3. **Run:** `build_mingw.bat` (in Command Prompt)
4. **Run:** `test.bat` (to verify it works)
5. **Tell me:** "It worked!" or paste any error

That's it! I handle the rest.

---

## 📁 Directory Structure:

```
Extension/AutoNestCut/cpp/
│
├── 📖 START_HERE.txt              ← READ THIS FIRST
├── 📖 WHAT_YOU_NEED_TO_DO.md      ← Your action items
├── 📖 SETUP_GUIDE.md              ← Detailed instructions
├── 📖 README.md                   ← Technical docs
├── 📖 FILE_GUIDE.md               ← This file
│
├── 🔧 install_mingw.ps1           ← Run this first
├── 🔧 build_mingw.bat             ← Then run this
├── 🔧 test.bat                    ← Then run this
│
├── 📦 CMakeLists.txt
├── 📦 test_input.json
│
└── src/
    ├── 💻 main.cpp
    ├── 💻 nesting.cpp
    ├── 💻 nesting.h
    ├── 💻 geometry.cpp
    └── 💻 geometry.h
```

---

## 🎯 Success Criteria:

After running the build scripts, you should have:
- ✅ `nester.exe` file in this directory
- ✅ `test_output.json` file (after running test.bat)
- ✅ No error messages

If you see these, you're done! Tell me and I'll integrate it with Ruby.
