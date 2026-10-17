import os, re

files_to_check = []
for root_dir in ["autoload", "scenes", "systems", "graphics"]:
    for r, d, fs in os.walk(root_dir):
        for f in sorted(fs):
            if f.endswith(".gd"):
                files_to_check.append(os.path.join(r, f))

errors_found = 0

for filepath in files_to_check:
    if not os.path.exists(filepath):
        print(f"[ERROR] File not found: {filepath}")
        errors_found += 1
        continue
        
    with open(filepath, "r", encoding="utf-8") as f:
        lines = f.readlines()
        
    stack = []
    has_mixed_indent = False
    
    for line_idx, line in enumerate(lines, 1):
        # Check indentation consistency
        if line.startswith(" ") and "\t" in line.lstrip():
            print(f"[WARNING] {filepath}:{line_idx} Mixed tabs and spaces")
            
        # Strip strings first, then comments for bracket checking
        code_part = re.sub(r'\"[^\"]*\"', '""', line)
        code_part = re.sub(r'\'[^\']*\'', "''", code_part)
        code_part = re.sub(r'#.*', '', code_part)
        
        for ch in code_part:
            if ch in '([{':
                stack.append((ch, line_idx))
            elif ch in ')]}':
                if not stack:
                    print(f"[ERROR] {filepath}:{line_idx} Unmatched closing bracket '{ch}'")
                    errors_found += 1
                else:
                    top_ch, top_line = stack.pop()
                    matching = {'(': ')', '[': ']', '{': '}'}
                    if matching[top_ch] != ch:
                        print(f"[ERROR] {filepath}:{line_idx} Mismatched bracket '{top_ch}' at line {top_line} closed with '{ch}'")
                        errors_found += 1

    if stack:
        for unclosed_ch, unclosed_line in stack:
            print(f"[ERROR] {filepath}:{unclosed_line} Unclosed bracket '{unclosed_ch}'")
            errors_found += 1

if errors_found == 0:
    print("SUCCESS: All checked GDScript files passed basic syntax & bracket pairing checks!")
else:
    print(f"FAILED: Found {errors_found} syntax errors!")
