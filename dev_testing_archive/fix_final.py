import os

os.chdir(r'c:\Users\Administrator\Desktop\AUTOMATION\cutlist\AutoNestCut\AutoNestCut_Clean_Workspace')

files = [
    'diagrams_report_from_git.js',
    'diagrams_report_working.js',
    'temp_old_report_gen.rb'
]

for file in files:
    if not os.path.exists(file):
        print(f'SKIPPED: {file} (not found)')
        continue
    
    try:
        # Try UTF-16 first (with BOM)
        try:
            with open(file, 'r', encoding='utf-16') as f:
                content = f.read()
        except:
            # Fall back to UTF-8
            with open(file, 'r', encoding='utf-8') as f:
                content = f.read()
        
        original = content
        content = content.replace('m┬▓', 'm²')
        content = content.replace('mm┬▓', 'mm²')
        content = content.replace('cm┬▓', 'cm²')
        content = content.replace('in┬▓', 'in²')
        content = content.replace('ft┬▓', 'ft²')
        
        if content != original:
            with open(file, 'w', encoding='utf-8') as f:
                f.write(content)
            print(f'FIXED: {file}')
        else:
            print(f'NO CHANGES: {file}')
    except Exception as e:
        print(f'ERROR: {file} - {str(e)}')

print('\nAll files processed!')
