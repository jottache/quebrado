import os
import re

targets = ['AppColors.primary', 'AppColors.secondary', 'AppColors.accent', 'AppColors.mainTabActiveBg', 'AppColors.nestedTabActiveBg']

for root, _, files in os.walk('lib'):
    for file in files:
        if not file.endswith('.dart'): continue
        path = os.path.join(root, file)
        with open(path, 'r') as f:
            lines = f.readlines()
        
        changed = False
        for i in range(len(lines)):
            line = lines[i]
            if 'const ' in line and any(t in line for t in targets):
                # Replace the innermost const if possible, or all consts on the line
                # It's safest to just replace all 'const ' with '' on that line
                # because if one parameter uses a non-const AppColors, the whole thing can't be const.
                lines[i] = line.replace('const ', '')
                changed = True
        
        if changed:
            with open(path, 'w') as f:
                f.writelines(lines)
            print(f"Fixed {path}")

