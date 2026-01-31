# AutoNestCut - SketchUp Extension

**Automated nesting and cut list generation for sheet goods**

AutoNestCut is a professional SketchUp extension that optimizes material usage for woodworking, fabrication, and construction projects. It automatically arranges parts on sheet goods to minimize waste and generates production-ready cut lists, diagrams, and CNC-compatible exports.

---

## 🎯 Key Features

### Core Functionality
- **Intelligent Nesting Algorithm** - Automatically arranges parts on sheet goods to minimize waste
- **Multi-Material Support** - Handles different materials and thicknesses in a single project
- **Material Database Manager** - Comprehensive database with pricing, dimensions, and properties
- **Interactive 3D Viewer** - Visualize assemblies with part highlighting and exploded views
- **Flexible Export Formats** - PDF, CSV, SVG, and interactive HTML reports

### Advanced Capabilities
- **SVG/CNC Export** - Flatten 3D components to 2D vector files for CNC machines
- **Assembly Export** - Generate 3D assembly views with texture mapping
- **Facade Calculator** - Specialized tool for calculating facade materials and patterns
- **Smart Material Matching** - Automatic material detection with thickness-aware validation
- **Component Caching** - Fast re-analysis of previously processed selections
- **Scheduled Exports** - Automate report generation on a schedule

---

## 📋 Requirements

- **SketchUp 2020 or later** (Windows or macOS)
- **Internet connection** for license validation (trial or full license)
- **Node.js** (for license server deployment only)

---

## 🚀 Installation

### For Users

1. Download the latest `.rbz` file from releases
2. In SketchUp, go to **Window > Extension Manager**
3. Click **Install Extension** and select the `.rbz` file
4. Restart SketchUp
5. Find **AutoNestCut** in the **Extensions** menu

### For Developers

1. Clone this repository
2. Copy the `Extension/` folder contents to your SketchUp Plugins directory:
   - **Windows**: `C:\Users\<YourUser>\AppData\Roaming\SketchUp\SketchUp 202x\SketchUp\Plugins`
   - **macOS**: `~/Library/Application Support/SketchUp 202x/SketchUp/Plugins`
3. Restart SketchUp or reload via Ruby Console

---

## 📖 How It Works

### Workflow Overview

```
1. Select Components → 2. Analyze Geometry → 3. Validate Materials → 4. Configure Settings → 5. Generate Reports
```

### Detailed Process

#### 1. **Component Selection**
- Select components or groups in your SketchUp model
- Supports nested components and assemblies
- Handles both individual parts and complete assemblies

#### 2. **Geometry Analysis**
- Extracts dimensions (width, height, thickness) from each component
- Identifies material assignments from SketchUp materials
- Builds component hierarchy for assembly tracking
- Caches results for faster subsequent runs

#### 3. **Material Validation**
- Checks if materials exist in the database
- Detects thickness mismatches automatically
- Offers three resolution options for missing materials:
  - **Remap** to existing material
  - **Create standard sheet** material
  - **Create custom part** material (exact dimensions)

#### 4. **Nesting Optimization**
- Sorts parts by area (largest first) for optimal placement
- Uses guillotine bin-packing algorithm
- Respects kerf width (saw blade thickness)
- Supports rotation for better fit
- Generates multiple boards as needed

#### 5. **Report Generation**
- **Cut List** - Detailed list with dimensions, quantities, and materials
- **Nesting Diagrams** - Visual layout of parts on sheets
- **Cost Estimation** - Material costs based on database pricing
- **Waste Analysis** - Efficiency metrics and offcut tracking
- **Assembly Views** - 3D visualization with part highlighting

---

## 🎨 Features In-Depth

### Material Database Manager

Access via **Extensions > AutoNestCut > Material Stock**

- **Pre-loaded Materials** - Common sheet goods (plywood, MDF, melamine, etc.)
- **Custom Materials** - Add your own materials with custom dimensions
- **Pricing Management** - Set prices per sheet in any currency
- **Multi-Thickness Support** - Store multiple thicknesses per material
- **Import/Export** - Share material databases across projects
- **Search & Filter** - Quickly find materials by name or properties

### 3D Assembly Viewer

- **Interactive Highlighting** - Click parts in the list to highlight in 3D
- **Exploded View** - Visualize assembly with adjustable explosion distance
- **Texture Mapping** - Accurate material textures on 3D models
- **Part Identification** - Color-coded parts with labels
- **Export Options** - Save assembly views as images or 3D files

### SVG/CNC Export

Access via **Extensions > AutoNestCut > 🎯 Flatten for CNC (SVG Export)**

- **2D Flattening** - Converts 3D components to 2D vector outlines
- **Face Selection** - Choose which faces to export (front, back, sides)
- **Dimension Preservation** - Maintains accurate measurements
- **Layer Organization** - Separates cut lines, engrave lines, and labels
- **CNC-Ready** - Compatible with laser cutters, CNC routers, and plasma cutters

### Interactive HTML Reports

- **Responsive Design** - Works on desktop, tablet, and mobile
- **Interactive Tables** - Sort, filter, and search parts
- **3D Viewer** - Embedded 3D assembly visualization
- **Nesting Diagrams** - Zoomable SVG diagrams
- **Print-Friendly** - Optimized for printing or PDF export
- **Offline Capable** - Self-contained HTML file with embedded assets

---

## 🛠️ Configuration Options

### Nesting Settings

| Setting | Description | Default |
|---------|-------------|---------|
| **Kerf Width** | Saw blade thickness (mm) | 3.0 mm |
| **Allow Rotation** | Rotate parts for better fit | Enabled |
| **Edge Banding** | Add edge banding to parts | Disabled |
| **Grain Direction** | Respect wood grain orientation | Disabled |

### Display Settings

| Setting | Description | Default |
|---------|-------------|---------|
| **Units** | Measurement units (mm, cm, in, ft) | mm |
| **Precision** | Decimal places for dimensions | 1 |
| **Currency** | Currency for pricing | USD |
| **Area Units** | Area measurement (m², ft²) | m² |

### Export Settings

| Setting | Description | Default |
|---------|-------------|---------|
| **Include 3D Viewer** | Embed 3D assembly viewer | Enabled |
| **Include Diagrams** | Include nesting diagrams | Enabled |
| **Include Cost** | Show cost estimation | Enabled |
| **Include Waste** | Show waste analysis | Enabled |

---

## 📊 Export Formats

### PDF Export
- Professional layout with company branding
- Multi-page support for large projects
- Embedded diagrams and tables
- Print-ready quality

### CSV Export
- Compatible with Excel, Google Sheets
- Includes all part data and quantities
- Material costs and totals
- Easy integration with ERP systems

### SVG Export
- Vector format for CNC machines
- Scalable without quality loss
- Layer-based organization
- Compatible with CAM software

### HTML Export
- Interactive web-based report
- Embedded 3D viewer
- Responsive design
- Shareable via email or web

---

## 🔐 Licensing

AutoNestCut uses a trial + purchase licensing model:

### Trial License
- **14-day free trial** from first use
- Full feature access during trial
- No credit card required
- Automatic trial countdown

### Full License
- **One-time purchase** per user
- Lifetime updates and support
- Multiple machine activation
- Commercial use allowed

### License Management
- **Purchase**: Extensions > AutoNestCut > Purchase License
- **Check Status**: Extensions > AutoNestCut > License Info
- **Trial Status**: Extensions > AutoNestCut > Trial Status

---

## 🏗️ Architecture

### Extension Structure

```
Extension/
├── AutoNestCut/
│   ├── main.rb                    # Entry point & UI setup
│   ├── config.rb                  # Configuration management
│   ├── materials_database.rb     # Material data management
│   │
│   ├── models/                    # Data models
│   │   ├── part.rb               # Part representation
│   │   ├── board.rb              # Sheet goods representation
│   │   └── facade_surface.rb    # Facade surface model
│   │
│   ├── processors/                # Core business logic
│   │   ├── model_analyzer.rb     # SketchUp model analysis
│   │   ├── nester.rb             # Nesting algorithm
│   │   ├── component_cache.rb    # Caching layer
│   │   └── component_validator.rb # Material validation
│   │
│   ├── exporters/                 # Export handlers
│   │   ├── report_generator.rb   # Report data generation
│   │   ├── pdf_generator.rb      # PDF export
│   │   ├── svg_vector_exporter.rb # SVG/CNC export
│   │   └── assembly_exporter.rb  # 3D assembly export
│   │
│   └── ui/                        # User interface
│       ├── dialog_manager.rb     # Main dialog orchestration
│       ├── material_database_ui.rb # Material manager UI
│       └── html/                  # HTML dialog templates
│           ├── main.html         # Main configuration dialog
│           ├── material_database.html # Material manager
│           └── documentation.html # Help documentation
│
└── lib/
    └── LicenseManager/            # Licensing system
        ├── license_manager.rb    # License validation
        └── trial_manager.rb      # Trial management
```

### License Server

```
Served/
├── server.mjs                     # Express.js server
├── package.json                   # Node.js dependencies
└── vercel.json                    # Vercel deployment config
```

---

## 🔧 Development

### Prerequisites

- Ruby 2.7+ (included with SketchUp)
- Node.js 18+ (for license server)
- SketchUp 2020+ SDK

### Setup Development Environment

1. Clone the repository
2. Install license server dependencies:
   ```bash
   cd Served
   npm install
   ```
3. Create `.env` file in `Served/` with:
   ```
   SUPABASE_URL=your_supabase_url
   SUPABASE_SERVICE_ROLE_KEY=your_service_key
   RSA_PRIVATE_KEY=your_private_key
   RESEND_API_KEY=your_resend_key
   ```
4. Start license server:
   ```bash
   npm start
   ```

### Testing in SketchUp

1. Load extension via Ruby Console:
   ```ruby
   load 'C:/path/to/Extension/autonestcut.rb'
   ```
2. Make changes to Ruby files
3. Reload extension:
   ```ruby
   Sketchup.send_action("showRubyPanel:")
   load 'C:/path/to/Extension/AutoNestCut/main.rb'
   ```

### Building .rbz Package

1. Zip the `Extension/` folder contents
2. Rename `.zip` to `.rbz`
3. Test installation in clean SketchUp instance

---

## 🤝 Contributing

Contributions are welcome! Please follow these guidelines:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Code Style

- Follow Ruby style guide
- Use 2-space indentation
- Add comments for complex logic
- Write descriptive commit messages

---

## 📝 License

Copyright © 2025 Muhamad Shkeir

This software is proprietary and requires a valid license for use.

---

## 🐛 Bug Reports & Feature Requests

Please open an issue on GitHub with:
- SketchUp version
- Operating system
- Steps to reproduce
- Expected vs actual behavior
- Screenshots (if applicable)

---

## 📧 Support

- **Documentation**: Extensions > AutoNestCut > Documentation
- **Email**: support@autonestcut.com
- **Website**: https://autonestcutserver-moeshks-projects.vercel.app

---

## 🙏 Acknowledgments

- Built with SketchUp Ruby API
- Uses Prawn for PDF generation
- Powered by Supabase for licensing
- Deployed on Vercel

---

## 📈 Changelog

### Version 1.0.0 (2025-01-19)
- Initial release
- Core nesting algorithm
- Material database manager
- PDF/CSV/SVG/HTML export
- 3D assembly viewer
- Trial + purchase licensing
- Interactive HTML reports
- SVG/CNC export feature

---

**Made with ❤️ for woodworkers, fabricators, and makers**
