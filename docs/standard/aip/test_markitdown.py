import sys
from markitdown import MarkItDown

pdf_path = sys.argv[1]
md = MarkItDown()
result = md.convert(pdf_path)

lines = result.text_content.split('\n')
print(f"总行数: {len(lines)}")
print(f"总字符数: {len(result.text_content)}")
print()
print("=== 前 80 行 ===")
for i, line in enumerate(lines[:80]):
    print(f"{i+1:3d}: {line}")
