# -*- coding: utf-8 -*-
"""
使用官方 markitdown 库转换 PDF 到 Markdown（增强版）
- 官方 markitdown 核心转换
- pymupdf 提取图像和流程图
- 质量后处理优化
"""

import os
import sys
import re
import pymupdf
from markitdown import MarkItDown


PARTIAL_NUMBERING_PATTERN = re.compile(r"^\.\d+$")


def merge_partial_numbering_lines(text):
    lines = text.split("\n")
    result_lines = []
    i = 0
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()
        if PARTIAL_NUMBERING_PATTERN.match(stripped):
            j = i + 1
            while j < len(lines) and not lines[j].strip():
                j += 1
            if j < len(lines):
                next_line = lines[j].strip()
                result_lines.append(f"{stripped} {next_line}")
                i = j + 1
            else:
                result_lines.append(line)
                i += 1
        else:
            result_lines.append(line)
            i += 1
    return "\n".join(result_lines)


def clean_markdown_tables(md_text):
    """
    清理明显的误判表格。
    策略：如果表格只有 1-2 行数据，且内容看起来像普通文字，就移除表格格式。
    """
    lines = md_text.split('\n')
    result_lines = []
    i = 0
    while i < len(lines):
        line = lines[i]
        # 检测是否是表格行
        if line.strip().startswith('|') and line.strip().endswith('|'):
            # 收集整个表格块
            table_lines = []
            j = i
            while j < len(lines) and lines[j].strip().startswith('|') and lines[j].strip().endswith('|'):
                table_lines.append(lines[j])
                j += 1

            # 检查是否是分隔行
            has_separator = any('---' in line for line in table_lines)

            if has_separator and len(table_lines) <= 4:
                # 小表格（<=3 行数据），检查是否是误判
                # 提取所有单元格文字
                all_text = ' '.join(table_lines).replace('|', ' ').replace('-', ' ').strip()
                # 如果是普通中文句子，很可能是误判
                chinese_chars = sum(1 for c in all_text if '\u4e00' <= c <= '\u9fff')
                total_chars = len(all_text.replace(' ', ''))
                if total_chars > 0 and chinese_chars / total_chars > 0.5 and len(table_lines) <= 3:
                    # 误判，转为普通文字
                    for tl in table_lines:
                        clean = tl.strip().strip('|').strip()
                        if '---' not in clean:
                            result_lines.append(clean.replace('|', ' '))
                    i = j
                    continue

            # 正常表格，保留
            for tl in table_lines:
                result_lines.append(tl)
            i = j
        else:
            result_lines.append(line)
            i += 1

    return '\n'.join(result_lines)


def extract_images_from_pdf(pdf_path, images_dir, pdf_base):
    """提取 PDF 中的图像和流程图页面，按页码正序排列"""
    doc = pymupdf.open(pdf_path)
    image_info_list = []

    for page_num in range(len(doc)):
        page = doc[page_num]
        images = page.get_images(full=True)
        drawings = page.get_drawings()
        has_diagram = len(drawings) > 15

        if has_diagram:
            mat = pymupdf.Matrix(200 / 72, 200 / 72)
            pix = page.get_pixmap(matrix=mat, alpha=False)
            img_filename = f"{pdf_base}_page{page_num + 1}_diagram.png"
            img_path = os.path.join(images_dir, img_filename)
            pix.save(img_path)
            image_info_list.append({
                'page': page_num + 1,
                'filename': img_filename,
                'type': 'diagram',
                'y0': 0
            })

        for img_idx, img in enumerate(images):
            xref = img[0]
            try:
                base_image = doc.extract_image(xref)
                image_bytes = base_image["image"]
                image_ext = base_image["ext"]

                img_filename = f"{pdf_base}_page{page_num + 1}_img{img_idx + 1}.{image_ext}"
                img_path = os.path.join(images_dir, img_filename)
                with open(img_path, "wb") as f:
                    f.write(image_bytes)

                try:
                    image_rects = page.get_image_rects(xref)
                    if image_rects:
                        y0 = min(r.y0 for r in image_rects)
                    else:
                        y0 = 0
                except Exception:
                    y0 = 0

                if not has_diagram:
                    image_info_list.append({
                        'page': page_num + 1,
                        'filename': img_filename,
                        'type': 'image',
                        'y0': y0
                    })
            except Exception:
                pass

    doc.close()
    image_info_list.sort(key=lambda x: (x['page'], x['y0']))
    return image_info_list


def add_page_markers(md_text, pdf_path):
    """
    为 Markdown 文本添加页码标记。
    由于 markitdown 不返回页码，我们用 pdfplumber 辅助估算。
    """
    try:
        import pdfplumber
        import io

        with open(pdf_path, 'rb') as f:
            pdf_bytes = f.read()

        page_texts = []
        with pdfplumber.open(io.BytesIO(pdf_bytes)) as pdf:
            for page in pdf.pages:
                text = page.extract_text() or ""
                page_texts.append(text.strip())
                page.close()

        # 在 markdown 中查找每页的起始特征行，插入页码标记
        md_lines = md_text.split('\n')
        result_lines = []
        current_page = 0

        # 构建每页的特征行（第一行非空行）
        page_features = []
        for idx, pt in enumerate(page_texts):
            lines = [l.strip() for l in pt.split('\n') if l.strip()]
            if lines:
                # 取前几行作为特征
                feature = lines[0][:30] if lines[0] else ""
                page_features.append((idx + 1, feature, lines[:3]))

        for line in md_lines:
            stripped = line.strip()
            # 检查是否匹配下一页的特征
            if current_page < len(page_features):
                page_num, feature, first_lines = page_features[current_page]
                # 简单匹配：行内容相似
                if stripped and feature and stripped[:20] == feature[:20]:
                    result_lines.append(f"\n<!-- Page {page_num} -->\n")
                    current_page += 1
                # 也检查是否是表格行的特征
                elif stripped.startswith('|') and first_lines and first_lines[0].startswith('中'):
                    # 首页表格特殊处理
                    if current_page == 0:
                        result_lines.append(f"\n<!-- Page 1 -->\n")
                        current_page = 1

            result_lines.append(line)

        return '\n'.join(result_lines)
    except Exception:
        return md_text


def insert_images_into_markdown(markdown_text, image_info, pdf_base):
    """将图像按页码插入到 Markdown 中"""
    if not image_info:
        return markdown_text

    image_pages = {}
    for info in image_info:
        page = info['page']
        if page not in image_pages:
            image_pages[page] = []
        image_pages[page].append(info)

    lines = markdown_text.split('\n')
    result_lines = []
    current_page = None

    for line in lines:
        page_match = re.search(r'<!-- Page (\d+) -->', line)
        if page_match:
            current_page = int(page_match.group(1))
            result_lines.append(line)

            if current_page in image_pages:
                images = sorted(image_pages[current_page], key=lambda x: x['y0'])
                for img in images:
                    relative_path = f"images/{img['filename']}"
                    if img['type'] == 'diagram':
                        result_lines.append(f"\n![第{current_page}页流程图]({relative_path})\n")
                    else:
                        result_lines.append(f"\n![图像]({relative_path})\n")
        else:
            result_lines.append(line)

    return '\n'.join(result_lines)


def pdf_to_markdown(pdf_path, output_dir):
    """完整的 PDF 转 Markdown 流程"""
    pdf_base = os.path.splitext(os.path.basename(pdf_path))[0]
    md_filename = pdf_base + '.md'
    md_path = os.path.join(output_dir, md_filename)

    print(f"Converting: {os.path.basename(pdf_path)}")

    images_dir = os.path.join(output_dir, "images")
    os.makedirs(images_dir, exist_ok=True)

    # 1. 使用 markitdown 转换
    md = MarkItDown()
    result = md.convert(pdf_path)
    markdown = result.text_content

    # 2. 质量优化：合并部分编号行
    markdown = merge_partial_numbering_lines(markdown)

    # 3. 质量优化：清理误判的小表格
    markdown = clean_markdown_tables(markdown)

    # 4. 添加页码标记
    markdown = add_page_markers(markdown, pdf_path)

    # 5. 提取图像
    image_info = extract_images_from_pdf(pdf_path, images_dir, pdf_base)

    # 6. 插入图像到对应页码
    markdown = insert_images_into_markdown(markdown, image_info, pdf_base)

    # 7. 添加标题
    title = pdf_base.replace('+', ' ')
    final_content = f"# {title}\n\n{markdown}"

    with open(md_path, 'w', encoding='utf-8') as f:
        f.write(final_content)

    table_count = markdown.count('\n| ') // 3  # 粗略估算表格数
    print(f"  -> Saved: {md_filename}")
    print(f"  -> Images: {len(image_info)} images extracted")
    print(f"  -> Size: {len(final_content)} chars")
    return md_path


def main():
    if len(sys.argv) > 1:
        target_dir = sys.argv[1]
    else:
        target_dir = os.path.dirname(os.path.abspath(__file__))

    pdf_files = sorted([f for f in os.listdir(target_dir) if f.endswith('.pdf')])

    if not pdf_files:
        print("No PDF files found.")
        return

    print(f"Found {len(pdf_files)} PDF files.\n")

    for pdf_file in pdf_files:
        pdf_path = os.path.join(target_dir, pdf_file)
        try:
            pdf_to_markdown(pdf_path, target_dir)
        except Exception as e:
            print(f"  Error: {e}")
            import traceback
            traceback.print_exc()

    print(f"\nDone!")


if __name__ == '__main__':
    main()
