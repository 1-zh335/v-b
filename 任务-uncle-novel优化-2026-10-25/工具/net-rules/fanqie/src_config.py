# -*- coding: utf-8 -*-
"""全局配置：CDP 端口、站点、路径、私用区码位范围。"""
import os

# CDP 远程调试端口（用户指定 9333）
CDP_PORT = 9333
CDP_URL = f'http://localhost:{CDP_PORT}'

# 站点
FANQIE_HOST = 'fanqienovel.com'
FANQIE_URL = f'https://{FANQIE_HOST}'

# 路径
SRC_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_DIR = os.path.dirname(SRC_DIR)
DATA_DIR = os.path.join(PROJECT_DIR, 'data')
OUTPUT_DIR = os.path.join(PROJECT_DIR, 'output')
CHARSET_PATH = os.path.join(SRC_DIR, 'charset.json')

# 番茄正文的私用区(PUA)码位范围，两套字体映射
CODE = [[58344, 58715], [58345, 58716]]

# 反爬友好：每章之间的随机延迟(秒)区间
# 调小可提速，但风控命中率上升；撞验证码时会自动暂停等人工过码。
# 极限档：几乎不延迟，最快；若频繁撞码可调大。
DELAY_RANGE = (0.0, 0.3)

# 专用 Chrome 配置目录（与日常浏览器隔离）
CHROME_PROFILE_DIR = os.path.join(DATA_DIR, 'chrome-profile')

for _d in (DATA_DIR, OUTPUT_DIR):
    os.makedirs(_d, exist_ok=True)
