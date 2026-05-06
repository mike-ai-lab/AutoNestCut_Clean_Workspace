import { Link } from "wouter";
import Header from "../components/Header";
import { 
  ArrowRight, CheckCircle2, Download, Scissors, 
  Grid3x3, Layers, Settings, Star, ChevronLeft, Zap, Box
} from "lucide-react";
const FEATURES = [
  { icon: Scissors, title: "Automated Cut Lists", description: "Generate detailed cut lists with dimensions, quantities, and material specifications from your SketchUp components" },
  { icon: Grid3x3, title: "Intelligent Nesting", description: "Advanced nesting algorithms optimize sheet layout to minimize waste and reduce material costs by up to 30%" },
  { icon: Layers, title: "Interactive 3D Viewer", description: "Visualize nested parts in 3D with exploded views, highlighting, and assembly diagrams for easy workshop reference" },
  { icon: Settings, title: "Multi-Format Export", description: "Export to PDF, CSV, SVG, and HTML formats. Generate CNC-ready files and professional reports" }
];
const SPECS = [
  { label: "Version", value: "2.6.5" },
  { label: "Compatibility", value: "SketchUp 2020+" },
  { label: "License", value: "Perpetual / 7-Day Trial" },
  { label: "Support", value: "Email: muhamad.shkeir@gmail.com" }
];
export default function AutoNestCutDetail() {
  return (
    <div className="bg-[#050505] min-h-screen text-white font-sans selection:bg-green-600 overflow-x-hidden">
      <Header currentPage="tools" />
      <section className="pt-40 pb-20 px-8 max-w-7xl mx-auto">
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-20 items-center">
          <div className="space-y-8">
            <div className="inline-flex items-center gap-3 px-3 py-1 bg-green-500/10 border border-green-500/20 text-green-500 text-[10px] font-black uppercase tracking-widest rounded">
              <Zap size={12} /> Fabrication Engine
            </div>
            <h1 className="text-[120px] font-black tracking-tighter leading-[0.75] uppercase italic stroke-text">
              AutoNestCut
            </h1>
            <p className="text-2xl font-medium text-white/60 leading-tight">
              Intelligent Cut List & <br/>Nesting Optimizer
            </p>
            <p className="text-white/40 leading-relaxed max-w-lg">
              AutoNestCut transforms your SketchUp workflow by automating cut list generation and material nesting. Reduce waste, save time, and generate production-ready cutting plans with intelligent algorithms designed for woodworkers, fabricators, and construction professionals.
            </p>
            <div className="flex flex-wrap gap-4 pt-4">
              <a href="/downloads/AutoNestCut_v26_5.rbz" download className="bg-green-600 hover:bg-green-500 text-white px-10 py-5 rounded-2xl font-black text-xs tracking-widest uppercase transition-all flex items-center gap-4 active:scale-95 shadow-2xl shadow-green-600/20">
                Download Extension <Download size={18} />
              </a>
              <a href="https://autonestcutserver-moeshks-projects.vercel.app/" target="_blank" rel="noopener noreferrer" className="bg-white/5 hover:bg-white/10 border border-white/10 text-white px-10 py-5 rounded-2xl font-black text-xs tracking-widest uppercase transition-all flex items-center gap-4 active:scale-95">
                <ArrowRight size={18} /> Purchase License
              </a>
            </div>
            <div className="flex items-center gap-6 pt-4 text-[9px] font-bold text-white/20 uppercase tracking-[0.3em]">
              <span className="flex items-center gap-2"><Star size={12} className="text-green-500 fill-green-500" /> 7-Day Trial</span>
              <span className="flex items-center gap-2"><Star size={12} className="text-green-500 fill-green-500" /> No CC Required</span>
              <span className="flex items-center gap-2"><Star size={12} className="text-green-500 fill-green-500" /> $69 Lifetime</span>
            </div>
          </div>
          <div className="relative flex justify-center items-center">
            <div className="w-[500px] h-[500px] bg-[#0c0c0e] border border-white/5 rounded-[60px] flex items-center justify-center relative overflow-hidden group">
               <div className="absolute inset-0 bg-green-600/5 opacity-0 group-hover:opacity-100 transition-opacity"></div>
               <Scissors className="w-48 h-48 text-white/5 group-hover:text-green-500/20 transition-colors duration-700" strokeWidth={0.5} />
               <div className="absolute top-10 left-10 text-[9px] font-mono opacity-20 group-hover:opacity-100 transition-opacity">
                  ID: MOD_ANCT_002<br/>STATUS: READY_FOR_DEPLOY
               </div>
               <div className="absolute bottom-10 right-10 flex gap-1">
                  {[...Array(3)].map((_, i) => (
                    <div key={i} className="w-1 h-1 bg-green-500 rounded-full animate-pulse" style={{ animationDelay: `${i*0.2}s` }}></div>
                  ))}
               </div>
            </div>
          </div>
        </div>
      </section>
      <section className="py-32 px-8 bg-[#08080a]">
        <div className="max-w-7xl mx-auto">
          <div className="mb-20 space-y-4">
            <h2 className="text-4xl font-black uppercase italic tracking-tighter">System Features</h2>
            <div className="w-20 h-1 bg-green-500"></div>
          </div>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
            {FEATURES.map((f, i) => (
              <div key={i} className="bg-[#0c0c0e] border border-white/5 p-10 rounded-[40px] hover:border-green-500/50 transition-colors group">
                <div className="w-16 h-16 bg-green-500/10 rounded-2xl flex items-center justify-center text-green-500 mb-8 group-hover:bg-green-500 group-hover:text-white transition-all">
                  <f.icon size={28} />
                </div>
                <h3 className="text-lg font-black uppercase tracking-tight mb-4 italic">{f.title}</h3>
                <p className="text-sm text-white/40 leading-relaxed font-medium">{f.description}</p>
              </div>
            ))}
          </div>
        </div>
      </section>
      <section className="py-32 px-8 max-w-7xl mx-auto">
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-32">
          <div className="space-y-12">
            <h2 className="text-4xl font-black uppercase italic tracking-tighter">Why AutoNestCut</h2>
            <div className="space-y-8">
              {[
                { t: "Reduce Material Waste by 30%", d: "Advanced nesting algorithms intelligently arrange parts to minimize offcuts and maximize sheet utilization, saving you money on every project." },
                { t: "Workshop-Ready Reports", d: "Generate professional PDF reports with cutting diagrams, QR code labels, material lists, and assembly instructions ready for immediate production use." },
                { t: "Multiple Export Formats", d: "Export to PDF, CSV, SVG for CNC machines, and interactive HTML reports. Supports custom material databases and pricing calculations." }
              ].map((item, i) => (
                <div key={i} className="flex gap-6">
                   <div className="mt-1"><CheckCircle2 className="text-green-500" size={24} /></div>
                   <div>
                      <h4 className="text-lg font-bold uppercase italic tracking-tight">{item.t}</h4>
                      <p className="text-white/40 text-sm leading-relaxed">{item.d}</p>
                   </div>
                </div>
              ))}
            </div>
          </div>
          <div className="bg-[#0c0c0e] border border-white/5 p-12 rounded-[50px]">
            <h3 className="text-2xl font-black uppercase italic tracking-tighter mb-10">Technical Specifications</h3>
            <div className="space-y-6">
              {SPECS.map((s, i) => (
                <div key={i} className="flex justify-between items-center py-4 border-b border-white/5 last:border-0">
                  <span className="text-[10px] font-black uppercase tracking-[0.4em] text-white/30">{s.label}</span>
                  <span className="text-sm font-bold text-green-500 italic uppercase">{s.value}</span>
                </div>
              ))}
            </div>
            <div className="mt-12 pt-12 border-t border-white/5 text-center">
               <Star className="mx-auto mb-4 text-green-500 fill-green-500" size={20} />
               <p className="text-[10px] font-black uppercase tracking-[0.3em] opacity-40 italic">Fabrication Standard</p>
            </div>
          </div>
        </div>
      </section>
      <div className="flex justify-center py-20 px-8">
        <footer className="bg-[#0c0c0e] border border-white/5 rounded-full px-12 py-6 shadow-2xl flex flex-col md:flex-row items-center gap-8">
          <div className="flex items-center gap-6 text-[10px] font-black tracking-[0.4em] text-white/30 uppercase">
            <span>© 2025 Studiø</span>
            <div className="w-1 h-1 bg-white/10 rounded-full"></div>
            <span>Muhamad Shkeir</span>
            <div className="w-1 h-1 bg-white/10 rounded-full"></div>
            <span className="text-green-500">Riyadh, KSA</span>
          </div>
          <div className="flex items-center gap-6 text-[10px] font-black tracking-[0.4em] text-white/30 uppercase">
            <a href="/privacy-policy.html" className="hover:text-green-500 transition-colors">Privacy</a>
            <div className="w-1 h-1 bg-white/10 rounded-full"></div>
            <a href="/terms-of-service.html" className="hover:text-green-500 transition-colors">Terms</a>
          </div>
        </footer>
      </div>
      <style>{`
        .stroke-text {
          -webkit-text-stroke: 1px rgba(255,255,255,0.2);
          color: transparent;
        }
        @media (min-width: 1024px) {
          .stroke-text { -webkit-text-stroke: 2px rgba(255,255,255,0.2); }
        }
      `}</style>
    </div>
  );
}