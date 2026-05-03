const fs = require('fs');
const path = require('path');

const basePath = 'c:\\Users\\Administrator\\Desktop\\AUTOMATION\\cutlist\\AutoNestCut\\AutoNestCut_Clean_Workspace';

const files = [
    'diagrams_report_from_git.js',
    'diagrams_report_working.js',
    'Extension\\AutoNestCut\\ui\\html\\diagrams_report.js',
    'Extension\\AutoNestCut\\ui\\html\\diagrams_report_FIXED.js',
    'Extension\\AutoNestCut\\exporters\\report_generator.rb',
    'Extension\\AutoNestCut\\ui\\dialog_manager_backup.rb',
    'temp_old_report_gen.rb'
];

let totalProcessed = 0;

console.log('Starting corrupted symbol fix...\n');

files.forEach(file => {
    const fullPath = path.join(basePath, file);
    
    if (!fs.existsSync(fullPath)) {
        console.log(`SKIPPED: ${file} (not found)`);
        return;
    }
    
    try {
        let content = fs.readFileSync(fullPath, 'utf8');
        const original = content;
        
        content = content.replace(/m┬▓/g, 'm²');
        content = content.replace(/mm┬▓/g, 'mm²');
        content = content.replace(/cm┬▓/g, 'cm²');
        content = content.replace(/in┬▓/g, 'in²');
        content = content.replace(/ft┬▓/g, 'ft²');
        
        if (content !== original) {
            fs.writeFileSync(fullPath, content, 'utf8');
            console.log(`FIXED: ${file}`);
            totalProcessed++;
        }
    } catch (err) {
        console.log(`ERROR: ${file} - ${err.message}`);
    }
});

console.log(`\nFiles processed: ${totalProcessed}`);
console.log('All corrupted symbols have been fixed!');
