# -*- coding: utf-8 -*-
"""把三份交付文档转成内嵌关键截图的 HTML（再用 Edge 无头打印为 PDF）。"""
import os
import io
import markdown

TASK = r'C:\Users\31384\Documents\trae_projects\v b\任务-Uncle小说离线低配版-2026-10-30'
OUT_HTML = os.path.join(TASK, '测试', 'pdf-src')
OUT_PDF = os.path.join(TASK, '文档', 'PDF')
os.makedirs(OUT_HTML, exist_ok=True)
os.makedirs(OUT_PDF, exist_ok=True)

DOCS = [
    ('目标设备适配报告.md', '目标设备适配报告（DTPC953）'),
    ('离线使用说明书.md', 'Uncle小说 离线低配版 使用说明书'),
    ('离线部署指南.md', 'Uncle小说 离线低配版 离线部署指南'),
]

SHOTS = [
    (r'截图\离线模式\完整版\离线主页与提示框-1410x990.png',
     '完整版离线标题：窗口标题显示「Uncle小说（离线）」'),
    (r'截图\离线模式\完整版\离线主页与提示框-712x411.png',
     '离线拦截弹窗：标题「离线模式」，正文说明可继续使用本地功能，按钮「重试联网 / 继续离线」'),
    (r'截图\音频与恢复\快速阅读与音频提示-1680x1140.png',
     '本地TXT快速阅读：阅读器标题尾部显示「· 离线」，字号 22 / 窗口 1120×760'),
    (r'截图\音频与恢复\快速阅读与音频提示-652x284.png',
     '无声卡提示：「音频不可用 | 「朗读」需要音频设备」'),
    (r'截图\离线模式\完整版\03-老板键恢复后.png',
     '老板键 Alt+U：隐藏全部窗口后再按一次恢复（完整版与快速阅读均支持）'),
    (r'截图\音频与恢复\联网前-1410x990.png',
     '间歇联网模拟：网络未连通时的离线状态（标题含「离线」）'),
    (r'截图\音频与恢复\联网恢复后-1410x990.png',
     '网络恢复后：软件自动切回在线状态，标题恢复为「Uncle小说」，无需重启'),
]

CSS = """
@page { size: A4; margin: 16mm 14mm; }
body { font-family: 'Microsoft YaHei', 'Segoe UI', sans-serif; font-size: 10.5pt;
       color: #222; line-height: 1.55; }
h1 { font-size: 20pt; color: #1f3a2e; border-bottom: 2px solid #6aa47f; padding-bottom: 6px; }
h2 { font-size: 14pt; color: #24503a; margin-top: 18px; border-left: 4px solid #6aa47f; padding-left: 8px; }
h3 { font-size: 12pt; color: #2f5d43; margin-top: 14px; }
code { font-family: Consolas, monospace; background: #f2f5f2; padding: 1px 4px; border-radius: 3px; font-size: 9.5pt; }
pre { background: #f6f8f6; border: 1px solid #dbe4dc; padding: 8px; white-space: pre-wrap; word-break: break-all; font-size: 9pt; }
table { border-collapse: collapse; width: 100%; margin: 8px 0; font-size: 9.5pt; page-break-inside: avoid; }
th, td { border: 1px solid #cfd8d0; padding: 5px 7px; text-align: left; vertical-align: top; }
th { background: #e6efe8; }
blockquote { border-left: 3px solid #b7cbbd; margin: 8px 0; padding: 4px 10px; color: #38513f; background: #f4f8f4; }
figure { margin: 14px 0; page-break-inside: avoid; text-align: center; }
figure img { max-width: 100%; max-height: 155mm; border: 1px solid #b9c9bd; border-radius: 3px; }
figcaption { font-size: 9.5pt; color: #4a6453; margin-top: 4px; }
.gallery-title { page-break-before: always; }
"""

gallery_parts = [
    '<div class="gallery-title"><h1>附：关键验收截图（内嵌）</h1>',
    '<blockquote>以下截图均由本机模拟目标档参数实测生成（Windows 11 开发机，i5-1135G7/16GB；'
    '目标机 DTPC953 为 Celeron J4005/4GB，界面同样按此逻辑显示）。</blockquote>',
]
for rel, caption in SHOTS:
    path = os.path.join(TASK, rel)
    if not os.path.exists(path):
        print('[WARN] missing screenshot:', path)
        continue
    uri = 'file:///' + path.replace('\\', '/')
    gallery_parts.append('<figure><img src="%s"/><figcaption>%s</figcaption></figure>' % (uri, caption))
gallery_parts.append('</div>')
gallery = '\n'.join(gallery_parts)

for md_name, title in DOCS:
    md_path = os.path.join(TASK, '文档', md_name)
    with io.open(md_path, 'r', encoding='utf-8') as f:
        text = f.read()
    body = markdown.markdown(text, extensions=['tables', 'fenced_code', 'sane_lists'])
    html = (
        '<!doctype html><html lang="zh-CN"><head><meta charset="utf-8">'
        '<title>%s</title><style>%s</style></head><body>%s%s</body></html>'
        % (title, CSS, body, gallery)
    )
    base = os.path.splitext(md_name)[0]
    html_path = os.path.join(OUT_HTML, base + '.html')
    with io.open(html_path, 'w', encoding='utf-8') as f:
        f.write(html)
    print('[OK] HTML:', html_path)
print('[OK] done')
