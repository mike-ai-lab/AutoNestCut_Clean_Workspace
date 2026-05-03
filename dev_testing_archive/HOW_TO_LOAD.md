# 🪑 Assets Generator Pro - Loading Instructions

## Method 1: Quick Load (RECOMMENDED)

**Copy and paste this ONE LINE into SketchUp Ruby Console:**

```ruby
load 'C:/path/to/your/furniture_generator.rb'; CustomFurnitureGenerator.reload!
```

**Replace `C:/path/to/your/` with the actual path to your file!**

Example:
```ruby
load 'C:/Users/YourName/Documents/furniture_generator.rb'; CustomFurnitureGenerator.reload!
```

---

## Method 2: Step by Step

1. Open SketchUp Ruby Console: `Window → Ruby Console`

2. Type this command (replace with your actual path):
```ruby
load 'C:/Users/YourName/Documents/furniture_generator.rb'
```

3. Press Enter

4. Then type:
```ruby
CustomFurnitureGenerator.reload!
```

5. Press Enter again

---

## Method 3: Use the Loader Script

1. Open SketchUp Ruby Console

2. Type:
```ruby
load 'C:/path/to/your/LOAD_FURNITURE_GENERATOR.rb'
```

3. Press Enter

---

## What You Should See

After loading, you'll see output like:
```
============================================================
🔄 Reloading 🪑 Assets Generator Pro v1.0.0
============================================================
✓ Cleared existing toolbar
✓ Reset menu state
✓ Reloaded script file
✓ Added menu item: 🪑 Assets Generator Pro
✓ Loaded toolbar icons
✓ Toolbar created and shown
============================================================
✅ Reload complete! Menu: Plugins → 🪑 Assets Generator Pro
============================================================
```

---

## Where to Find It

- **Menu**: `Plugins → 🪑 Assets Generator Pro`
- **Toolbar**: Look for a toolbar named "🪑 Assets Generator Pro"

---

## Troubleshooting

### Icons not showing?
Make sure these files exist in the same folder as `furniture_generator.rb`:
- `furniture_icon_16.png`
- `furniture_icon_24.png`

The script will work without icons, just with a default toolbar button.

### Menu item not appearing?
- Make sure you ran the `reload!` command
- Check the Ruby Console for error messages
- Try closing and reopening SketchUp

### Old menu item still there?
- SketchUp doesn't allow removing menu items during runtime
- The old menu will stay until you restart SketchUp
- The new "🪑 Assets Generator Pro" menu should appear alongside it
- After restart, only the new one will appear

---

## Quick Reference

**To reload after making changes:**
```ruby
load 'C:/path/to/furniture_generator.rb'; CustomFurnitureGenerator.reload!
```

**To just run the generator:**
```ruby
CustomFurnitureGenerator.run_generator
```
