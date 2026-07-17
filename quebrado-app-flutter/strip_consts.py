import os
import re

for root, _, files in os.walk('lib'):
    for file in files:
        if not file.endswith('.dart'): continue
        path = os.path.join(root, file)
        with open(path, 'r') as f:
            content = f.read()
        
        # Remove const before class constructors (e.g. const Icon, const EdgeInsets)
        # We need to make sure we don't accidentally match `static const Type` if possible, 
        # but even if we do, it's valid Dart to have `static Type`. 
        # Actually `static const` must be initialized, `static String x = ""` is valid.
        
        content = re.sub(r'\bconst\s+([A-Z])', r'\1', content)
        
        # Remove const before lists, maps, generics
        content = re.sub(r'\bconst\s+\[', r'[', content)
        content = re.sub(r'\bconst\s+\{', r'{', content)
        content = re.sub(r'\bconst\s+\<', r'<', content)
        
        with open(path, 'w') as f:
            f.write(content)
print("Done stripping consts.")
