# -*- coding: utf-8 -*-
"""
基于 Microsoft MarkItDown PDF 转换逻辑的高质量 PDF 转 Markdown 工具
适配 Python 3.8，核心算法参考 markitdown 的 _pdf_converter.py

功能特性：
1. 使用 pdfplumber 提取表格（智能识别表格结构）
2. 使用 pdfminer 提取纯文本（更好的文本间距）
3. 智能检测表格/表单页面 vs 纯文本页面
4. 自动识别并格式化 Markdown 表格
5. 提取流程图/图像并插入到 Markdown 中
"""

import os
import sys
import io
import re

try:
    import pdfplumber
    import pdfminer
    import pdfminer.high_level
except ImportError as e:
    print(f"Error: Missing dependency - {e}")
    print("Please install: pip install pdfplumber pdfminer.six pymupdf")
    sys.exit(1)

try:
    import pymupdf  # 用于提取图像
except ImportError:
    pymupdf = None


PARTIAL_NUMBERING_PATTERN = re.compile(r"^\.\d+$")


def merge_partial_numbering_lines(text):
    """合并类似 .1 .2 的编号行与下一行文本"""
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


def to_markdown_table(table, include_separator=True):
    """将二维列表转换为对齐的 Markdown 表格"""
    if not table:
        return ""

    table = [[cell if cell is not None else "" for cell in row] for row in table]
    table = [row for row in table if any(cell.strip() for cell in row)]

    if not table:
        return ""

    col_widths = [max(len(str(cell)) for cell in col) for col in zip(*table)]

    def fmt_row(row):
        return "|" + "|".join(str(cell).ljust(width) for cell, width in zip(row, col_widths)) + "|"

    if include_separator:
        header, *rows = table
        md = [fmt_row(header)]
        md.append("|" + "|".join("-" * w for w in col_widths) + "|")
        for row in rows:
            md.append(fmt_row(row))
    else:
        md = [fmt_row(row) for row in table]

    return "\n".join(md)


def extract_form_content_from_words(page):
    """
    从 PDF 页面提取表单/表格内容。
    参考 markitdown 的 _extract_form_content_from_words 函数。
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

        row_info.append({
            "y_key": y_key,
            "words": row_words,
            "text": combined_text,
            "x_groups": x_groups,
            "is_paragraph": is_paragraph,
            "num_columns": len(x_groups),
            "has_partial_numbering": has_partial_numbering,
        })

    all_table_x_positions = []
    for info in row_info:
        if info["num_columns"] >= 3 and not info["is_paragraph"]:
            all_table_x_positions.extend(info["x_groups"])

    if not all_table_x_positions:
        return None

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
        adaptive_tolerance = max(25, min(50, adaptive_tolerance))
    else:
        adaptive_tolerance = 35

    global_columns = []
    for x in all_table_x_positions:
        if not global_columns or x - global_columns[-1] > adaptive_tolerance:
            global_columns.append(x)

    if len(global_columns) > 1:
        content_width = global_columns[-1] - global_columns[0]
        avg_col_width = content_width / len(global_columns)

        if avg_col_width < 30:
            return None

        columns_per_inch = len(global_columns) / (content_width / 72)

        if columns_per_inch > 10:
            return None

        adaptive_max_columns = int(20 * (page_width / 612))
        adaptive_max_columns = max(15, adaptive_max_columns)

        if len(global_columns) > adaptive_max_columns:
            return None
    else:
        return None

    for info in row_info:
        if info["is_paragraph"]:
            info["is_table_row"] = False
            continue

        if info["has_partial_numbering"]:
            info["is_table_row"] = False
            continue

        aligned_columns = set()
        for word in info["words"]:
            word_x = word["x0"]
            for col_idx, col_x in enumerate(global_columns):
                if abs(word_x - col_x) < 40:
                    aligned_columns.add(col_idx)
                    break

        info["is_table_row"] = len(aligned_columns) >= 2

    table_regions = []
    i = 0
    while i < len(row_info):
        if row_info[i]["is_table_row"]:
            start_idx = i
            while i < len(row_info) and row_info[i]["is_table_row"]:
                i += 1
            end_idx = i
            table_regions.append((start_idx, end_idx))
        else:
            i += 1

    total_table_rows = sum(end - start for start, end in table_regions)
    if len(row_info) > 0 and total_table_rows / len(row_info) < 0.2:
        return None

    result_lines = []
    num_cols = len(global_columns)

    def extract_cells(info):
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
        return cells

    idx = 0
    while idx < len(row_info):
        info = row_info[idx]

        table_region = None
        for start, end in table_regions:
            if idx == start:
                table_region = (start, end)
                break

        if table_region:
            start, end = table_region
            table_data = []
            for table_idx in range(start, end):
                cells = extract_cells(row_info[table_idx])
                table_data.append(cells)

            if table_data:
                col_widths = [
                    max(len(row[col]) for row in table_data) for col in range(num_cols)
                ]
                col_widths = [max(w, 3) for w in col_widths]

                header = table_data[0]
                header_str = (
                    "| "
                    + " | ".join(
                        cell.ljust(col_widths[i]) for i, cell in enumerate(header)
                    )
                    + " |"
                )
                result_lines.append(header_str)

                separator = (
                    "| "
                    + " | ".join("-" * col_widths[i] for i in range(num_cols))
                    + " |"
                )
                result_lines.append(separator)

                for row in table_data[1:]:
                    row_str = (
                        "| "
                        + " | ".join(
                            cell.ljust(col_widths[i]) for i, cell in enumerate(row)
                        )
                        + " |"
                    )
                    result_lines.append(row_str)

            idx = end
        else:
            in_table = False
            for start, end in table_regions:
                if start < idx < end:
                    in_table = True
                    break

            if not in_table:
                result_lines.append(info["text"])
            idx += 1

    return "\n".join(result_lines)


def extract_images_from_pdf(pdf_path, images_dir, pdf_base):
    """提取 PDF 中的图像和流程图页面"""
    if pymupdf is None:
        return []

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
    return image_info_list


def pdf_to_markdown(pdf_path, output_dir):
    """将 PDF 转换为高质量 Markdown"""
    pdf_base = os.path.splitext(os.path.basename(pdf_path))[0]
    md_filename = pdf_base + '.md'
    md_path = os.path.join(output_dir, md_filename)

    print(f"Converting: {os.path.basename(pdf_path)}")

    images_dir = os.path.join(output_dir, "images")
    os.makedirs(images_dir, exist_ok=True)

    with open(pdf_path, 'rb') as f:
        pdf_bytes = io.BytesIO(f.read())

    markdown_chunks = []
    form_page_count = 0

    with pdfplumber.open(pdf_bytes) as pdf:
        for page_idx, page in enumerate(pdf.pages):
            page_content = extract_form_content_from_words(page)

            if page_content is not None:
                form_page_count += 1
                if page_content.strip():
                    markdown_chunks.append(f"\n<!-- Page {page_idx + 1} -->\n")
                    markdown_chunks.append(page_content)
            else:
                text = page.extract_text()
                if text and text.strip():
                    markdown_chunks.append(f"\n<!-- Page {page_idx + 1} -->\n")
                    markdown_chunks.append(text.strip())

            page.close()

    if form_page_count == 0:
        pdf_bytes.seek(0)
        markdown = pdfminer.high_level.extract_text(pdf_bytes)
    else:
        markdown = "\n\n".join(markdown_chunks).strip()

    markdown = merge_partial_numbering_lines(markdown)

    image_info = extract_images_from_pdf(pdf_path, images_dir, pdf_base)

    title = pdf_base.replace('+', ' ')
    final_content = f"# {title}\n\n{markdown}"

    if image_info:
        image_pages = {}
        for info in image_info:
            page = info['page']
            if page not in image_pages:
                image_pages[page] = []
            image_pages[page].append(info)

        for page_num, images in sorted(image_pages.items()):
            page_marker = f"<!-- Page {page_num} -->"
            if page_marker in final_content:
                images_sorted = sorted(images, key=lambda x: x['y0'])
                img_markdown = ""
                for img in images_sorted:
                    relative_path = os.path.join("images", img['filename'])
                    if img['type'] == 'diagram':
                        img_markdown += f"\n![第{page_num}页流程图]({relative_path})\n"
                    else:
                        img_markdown += f"\n![图像]({relative_path})\n"

                final_content = final_content.replace(
                    page_marker,
                    page_marker + img_markdown
                )

    with open(md_path, 'w', encoding='utf-8') as f:
        f.write(final_content)

    print(f"  -> Saved: {md_filename}")
    print(f"  -> Images: {len(image_info)} images extracted")
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
