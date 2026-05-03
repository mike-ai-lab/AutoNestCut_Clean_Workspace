const fs = require('fs');

const files = [
    'diagrams_report_from_git.js',
    'diagrams_report_working.js',
    'temp_old_report_gen.rb'
];

files.forEach(file => {
    try {
        let content = fs.readFileSync(file, 'utf8');
        const original = content;
        
        content = content.replace(/m┬▓/g, 'm²');
        content = content.replace(/mm┬▓/g, 'mm²');
        content = content.replace(/cm┬▓/g, 'cm²');
        content = content.replace(/in┬▓/g, 'in²');
        content = content.replace(/ft┬▓/g, 'ft²');
        
        if (content !== original) {
            fs.writeFileSync(file, content, 'utf8');
            console.log('FIXED: ' + file);
        }
    } catch (err) {
        console.log('ERROR: ' + file + ' - ' + err.message);
    }
});

console.log('Done!');
