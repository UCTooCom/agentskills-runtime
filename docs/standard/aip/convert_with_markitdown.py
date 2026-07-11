# -*- coding: utf-8 -*-
"""直接使用 MarkItDown 源码的 PDF 转换器进行转换"""

import os
import sys
import io

# 将 markitdown 源码目录加入路径
MARKITDOWN_SRC = r"D:\UCT\projects\miniapp\qintong\Delivery\uctoo-admin\apps\markitdown\packages\markitdown\src"
sys.path.insert(0, MARKITDOWN_SRC)

# 直接导入 PDF 转换器相关模块
from markitdown.converters._pdf_converter import PdfConverter, _merge_partial_numbering_lines
from markitdown._base_converter import DocumentConverterResult
from markitdown._stream_info import StreamInfo
import pymupdf


def extract_images_from_pdf(pdf_path, images_dir, pdf_base):
    """提取 PDF 中的图像和流程图页面"""
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


def convert_pdf(pdf_path, output_dir):
    """使用 MarkItDown PdfConverter 转换 PDF"""
    pdf_base = os.path.splitext(os.path.basename(pdf_path))[0]
    md_filename = pdf_base + '.md'
    md_path = os.path.join(output_dir, md_filename)

    print(f"Converting: {os.path.basename(pdf_path)}")

    images_dir = os.path.join(output_dir, "images")
    os.makedirs(images_dir, exist_ok=True)

    converter = PdfConverter()

    with open(pdf_path, 'rb') as f:
        stream_info = StreamInfo(
            filename=os.path.basename(pdf_path),
            extension='.pdf',
            mimetype='application/pdf'
        )
        result = converter.convert(f, stream_info)

    markdown = result.text_content
    title = pdf_base.replace('+', ' ')

    lines = markdown.split('\n')
    new_lines = []
    page_num = 1
    for line in lines:
        # 简单地在每个分页处添加页码标记
        # pdfminer 用 '\f' 分隔页面，这里我们已经是纯文本了
        new_lines.append(line)

    final_content = f"# {title}\n\n{markdown}"

    image_info = extract_images_from_pdf(pdf_path, images_dir, pdf_base)

    if image_info:
        image_pages = {}
        for info in image_info:
            page = info['page']
            if page not in image_pages:
                image_pages[page] = []
            image_pages[page].append(info)

        for page_num, images in sorted(image_pages.items()):
            page_marker = f"<!-- Page {page_num} -->"
            images_sorted = sorted(images, key=lambda x: x['y0'])
            img_markdown = ""
            for img in images_sorted:
                relative_path = os.path.join("images", img['filename'])
                if img['type'] == 'diagram':
                    img_markdown += f"\n![第{page_num}页流程图]({relative_path})\n"
                else:
                    img_markdown += f"\n![图像]({relative_path})\n"

            if page_marker not in final_content:
                final_content = page_marker + "\n" + img_markdown + final_content
            else:
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
            convert_pdf(pdf_path, target_dir)
        except Exception as e:
            print(f"  Error: {e}")
            import traceback
            traceback.print_exc()

    print(f"\nDone!")


if __name__ == '__main__':
    main()
