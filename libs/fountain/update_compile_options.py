import os
import re

# 获取所有 f_ 开头的子目录
subdirs = [d for d in os.listdir('.') if os.path.isdir(d) and d.startswith('f_')]

for subdir in subdirs:
    cjpm_path = os.path.join(subdir, 'cjpm.toml')
    if os.path.exists(cjpm_path):
        with open(cjpm_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # 检查是否已经有 -Woff all
        if '-Woff all' not in content:
            # 查找 compile-option 行并更新
            content = re.sub(
                r'compile-option = "([^"]+)"',
                r'compile-option = "-Woff all \1"',
                content
            )
            
            with open(cjpm_path, 'w', encoding='utf-8') as f:
                f.write(content)
            
            print(f'Updated {subdir}/cjpm.toml')
        else:
            print(f'{subdir}/cjpm.toml already has -Woff all')
    else:
        print(f'{subdir}/cjpm.toml not found')

print('Done!')
