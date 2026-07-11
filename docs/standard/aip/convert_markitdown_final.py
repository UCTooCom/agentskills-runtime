# -*- coding: utf-8 -*-
"""
基于 MarkItDown 算法的高质量 PDF 转 Markdown 工具（最终优化版）
- 先用 pdfplumber 原生表格检测识别有边框表格
- MarkItDown 算法用于无边框表格，增加误判过滤
- 图像按页码正序排列
- 适配 Python 3.8
"""

import os
import sys
import io
import re

import pdfplumber
import pdfminer.high_level
import pymupdf


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


def to_markdown_table(table_rows):
    if not table_rows:
        return ""
    table = [[cell if cell is not None else "" for cell in row] for row in table_rows]
    table = [row for row in table if any(cell.strip() for cell in row)]
    if not table:
        return ""

    col_widths = [max(len(str(row[col])) for row in table) for col in range(len(table[0]))]
    col_widths = [max(w, 3) for w in col_widths]

    def fmt_row(row):
        return "| " + " | ".join(str(cell).strip().ljust(width) for cell, width in zip(row, col_widths)) + " |"

    header = table[0]
    md = [fmt_row(header)]
    md.append("| " + " | ".join("-" * w for w in col_widths) + " |")
    for row in table[1:]:
        md.append(fmt_row(row))
    return "\n".join(md)


def extract_tables_with_pdfplumber(page):
    """使用 pdfplumber 原生表格检测识别有边框表格"""
    try:
        tables = page.find_tables()
        if tables:
            result = []
            for table in tables:
                table_data = table.extract()
                if table_data and len(table_data) >= 2:
                    bbox = table.bbox
                    result.append({
                        'data': table_data,
                        'bbox': bbox,
                        'top': bbox[1],
                        'bottom': bbox[3]
                    })
            return result if result else None
    except Exception:
        pass
    return None


def extract_form_content_from_words(page, page_num=1):
    """
    MarkItDown 风格的无边框表格检测。
    增加多重过滤，减少误判。
    """
    words = page.extract_words(keep_blank_chars=True, x_tolerance=3, y_tolerance=3)
    if not words:
        return None

    y_tolerance = 5
    rows_by_y = {}
    for word in words:
        y_key = round(word["top"] / y_tolerance) * y_tolerance
        if y_key not in rows_by_y:
            rows_by_y[y_key] = []
        rows_by_y[y_key].append(word)

    sorted_y_keys = sorted(rows_by_y.keys())
    page_width = page.width if hasattr(page, "width") else 612

    row_info = []
    for y_key in sorted_y_keys:
        row_words = sorted(rows_by_y[y_key], key=lambda w: w["x0"])
        if not row_words:
            continue
        first_x0 = row_words[0]["x0"]
        last_x1 = row_words[-1]["x1"]
        line_width = last_x1 - first_x0
        combined_text = " ".join(w["text"] for w in row_words)
        x_positions = [w["x0"] for w in row_words]
        x_groups = []
        for x in sorted(x_positions):
            if not x_groups or x - x_groups[-1] > 50:
                x_groups.append(x)
        is_paragraph = line_width > page_width * 0.55 and len(combined_text) > 60
        has_partial_numbering = False
        if row_words:
            first_word = row_words[0]["text"].strip()
            if PARTIAL_NUMBERING_PATTERN.match(first_word):
                has_partial_numbering = True

        # 检查是否是列表项（以 "——" 或 "—" 开头）
        is_list_item = combined_text.strip().startswith("—") or combined_text.strip().startswith("——")

        row_info.append({
            "y_key": y_key,
            "words": row_words,
            "text": combined_text,
            "x_groups": x_groups,
            "is_paragraph": is_paragraph,
            "num_columns": len(x_groups),
            "has_partial_numbering": has_partial_numbering,
            "is_list_item": is_list_item,
        })

    # 收集表格候选行的 x 位置
    all_table_x_positions = []
    for info in row_info:
        if (info["num_columns"] >= 3
                and not info["is_paragraph"]
                and not info["is_list_item"]
                and not info["has_partial_numbering"]):
            all_table_x_positions.extend(info["x_groups"])

    if not all_table_x_positions:
        return None

    # 计算列间距的自适应阈值
    all_table_x_positions.sort()
    gaps = []
    for i in range(len(all_table_x_positions) - 1):
        gap = all_table_x_positions[i + 1] - all_table_x_positions[i]
        if gap > 5:
            gaps.append(gap)

    if gaps and len(gaps) >= 3:
        sorted_gaps = sorted(gaps)
        percentile_70_idx = int(len(sorted_gaps) * 0.70)
        adaptive_tolerance = sorted_gaps[percentile_70_idx]
        adaptive_tolerance = max(30, min(60, adaptive_tolerance))
    else:
        adaptive_tolerance = 40

    # 全局列位置
    global_columns = []
    for x in all_table_x_positions:
        if not global_columns or x - global_columns[-1] > adaptive_tolerance:
            global_columns.append(x)

    # 过滤条件1：列数合理（2-10列）
    num_cols = len(global_columns)
    if num_cols < 2 or num_cols > 10:
        return None

    # 过滤条件2：列间距不能太小
    if num_cols > 1:
        content_width = global_columns[-1] - global_columns[0]
        avg_col_width = content_width / num_cols
        if avg_col_width < 50:
            return None

    # 标记表格行
    for info in row_info:
        if info["is_paragraph"] or info["is_list_item"] or info["has_partial_numbering"]:
            info["is_table_row"] = False
            continue
        aligned_columns = set()
        for word in info["words"]:
            word_x = word["x0"]
            for col_idx, col_x in enumerate(global_columns):
                if abs(word_x - col_x) < 45:
                    aligned_columns.add(col_idx)
                    break
        # 至少 2 列对齐才算表格行
        info["is_table_row"] = len(aligned_columns) >= 2

    # 识别表格区域
    table_regions = []
    i = 0
    while i < len(row_info):
        if row_info[i]["is_table_row"]:
            start_idx = i
            while i < len(row_info) and row_info[i]["is_table_row"]:
                i += 1
            end_idx = i
            region_rows = end_idx - start_idx
            # 表格区域至少 3 行
            if region_rows >= 3:
                table_regions.append((start_idx, end_idx))
        else:
            i += 1

    # 过滤条件3：表格总行数占比不能太低
    total_table_rows = sum(end - start for start, end in table_regions)
    if len(row_info) > 0 and total_table_rows / len(row_info) < 0.15:
        return None

    # 过滤条件4：检查表格区域的"空列"情况，如果大部分列是空的，可能是误判
    valid_regions = []
    for start, end in table_regions:
        region_data = []
        for table_idx in range(start, end):
            info = row_info[table_idx]
            cells = ["" for _ in range(num_cols)]
            for word in info["words"]:
                word_x = word["x0"]
                assigned_col = num_cols - 1
                for col_idx in range(num_cols - 1):
                    col_end = global_columns[col_idx + 1]
                    if word_x < col_end - 20:
                        assigned_col = col_idx
                        break
                if cells[assigned_col]:
                    cells[assigned_col] += " " + word["text"]
                else:
                    cells[assigned_col] = word["text"]
            region_data.append(cells)

        # 计算非空列数（至少有一半行有内容的列）
        non_empty_cols = 0
        for col in range(num_cols):
            col_content = [row[col].strip() for row in region_data]
            non_empty_count = sum(1 for c in col_content if c)
            if non_empty_count >= len(region_data) * 0.3:
                non_empty_cols += 1

        # 至少有 2 列是"有内容的"
        if non_empty_cols >= 2:
            valid_regions.append((start, end, region_data))

    if not valid_regions:
        return None

    # 生成结果
    result_lines = []
    idx = 0
    while idx < len(row_info):
        info = row_info[idx]

        in_region = False
        for start, end, region_data in valid_regions:
            if idx == start:
                # 输出表格
                table_md = to_markdown_table(region_data)
                result_lines.append(table_md)
                idx = end
                in_region = True
                break
            elif start < idx < end:
                idx += 1
                in_region = True
                break

        if not in_region:
            if not info.get("is_table_row", False):
                result_lines.append(info["text"])
            idx += 1

    return "\n".join(result_lines)


def convert_pdf_markitdown(pdf_path):
    """使用复合策略转换 PDF：pdfplumber表格 + MarkItDown无边框表格"""
    with open(pdf_path, 'rb') as f:
        pdf_bytes = io.BytesIO(f.read())

    page_contents = []

    with pdfplumber.open(pdf_bytes) as pdf:
        for page_idx, page in enumerate(pdf.pages):
            page_num = page_idx + 1

            # 前 3 页（封面、目录）直接用纯文本
            if page_num <= 3:
                text = page.extract_text()
                if text and text.strip():
                    page_contents.append({
                        'page': page_num,
                        'content': text.strip(),
                        'has_table': False
                    })
                else:
                    page_contents.append({
                        'page': page_num,
                        'content': '',
                        'has_table': False
                    })
                page.close()
                continue

            page_content = None
            has_table = False

            # 第一步：尝试 pdfplumber 原生表格检测（有边框表格）
            tables = extract_tables_with_pdfplumber(page)
            if tables:
                # 有有边框表格，构建混合内容
                text = page.extract_text()
                lines = text.split('\n') if text else []

                # 简单策略：如果有原生表格，直接在表格位置输出 Markdown 表格
                # 为了简化，我们先获取纯文本，然后尝试从表格位置插入
                table_md_parts = []
                for t in tables:
                    table_md = to_markdown_table(t['data'])
                    table_md_parts.append(table_md)

                # 如果表格行数较少，使用纯文本 + 表格补充
                if len(tables) >= 1 and len(tables[0]['data']) >= 3:
                    # 有明确表格，使用混合策略
                    # 先用纯文本获取非表格部分
                    full_text = page.extract_text() or ""

                    # 获取表格上方和下方的文本
                    # 简化处理：先输出文本，再输出表格
                    # 更精确的做法是按行切割
                    result_parts = []
                    table_texts = []
                    for t in tables:
                        md = to_markdown_table(t['data'])
                        table_texts.append(md)

                    result_parts.append(full_text.strip())
                    result_parts.append("\n\n".join(table_texts))
                    page_content = "\n\n".join(result_parts)
                    has_table = True

            # 第二步：如果没有有边框表格，尝试 MarkItDown 风格的无边框表格检测
            if page_content is None:
                form_content = extract_form_content_from_words(page, page_num)
                if form_content is not None:
                    page_content = form_content
                    has_table = True
                else:
                    text = page.extract_text()
                    if text and text.strip():
                        page_content = text.strip()
                    else:
                        page_content = ''

            page_contents.append({
                'page': page_num,
                'content': page_content,
                'has_table': has_table
            })

            page.close()

    markdown_parts = []
    for pc in page_contents:
        if pc['content']:
            markdown_parts.append(f"\n<!-- Page {pc['page']} -->\n")
            markdown_parts.append(pc['content'])
    markdown = "\n\n".join(markdown_parts)

    markdown = merge_partial_numbering_lines(markdown)
    return markdown, page_contents


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
    """完整的 PDF 转 Markdown"""
    pdf_base = os.path.splitext(os.path.basename(pdf_path))[0]
    md_filename = pdf_base + '.md'
    md_path = os.path.join(output_dir, md_filename)

    print(f"Converting: {os.path.basename(pdf_path)}")

    images_dir = os.path.join(output_dir, "images")
    os.makedirs(images_dir, exist_ok=True)

    markdown, page_contents = convert_pdf_markitdown(pdf_path)

    title = pdf_base.replace('+', ' ')
    final_content = f"# {title}\n\n{markdown}"

    image_info = extract_images_from_pdf(pdf_path, images_dir, pdf_base)
    final_content = insert_images_into_markdown(final_content, image_info, pdf_base)

    with open(md_path, 'w', encoding='utf-8') as f:
        f.write(final_content)

    table_pages = sum(1 for pc in page_contents if pc['has_table'])
    print(f"  -> Saved: {md_filename}")
    print(f"  -> Images: {len(image_info)} images extracted")
    print(f"  -> Tables: {table_pages} pages with tables")
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
