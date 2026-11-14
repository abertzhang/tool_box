#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import json
import re
from collections import OrderedDict
from pathlib import Path

# ---- 路径配置 ----
ROOT = Path(__file__).resolve().parent.parent          # tool_box/
SRC_L10N = ROOT.parent / "knot_phone" / "lib" / "l10n"  # 源 ARB 所在目录
DST_L10N = ROOT / "lib" / "l10n"                        # 目标 ARB 所在目录
LIB_DIR = ROOT / "lib"                                  # 待扫描的源码根目录

# 强制保留的 key：底部导航 Tab 文案等，即使当前扫描不到也必须存在。
EXTRA_KEYS = {"tools", "profile", "appTitle"}


def collect_source_text() -> str:
    """把 lib 下所有 Dart 源码拼成一个大字符串，供后续正则匹配引用情况。

    跳过 l10n 目录自身（生成代码里包含全部 key，会让过滤失效）。
    """
    chunks = []
    for path in LIB_DIR.rglob("*.dart"):
        if "l10n" in path.parts:
            continue
        chunks.append(path.read_text(encoding="utf-8"))
    return "\n".join(chunks)


def used_keys(all_keys, source: str) -> set:
    """返回在源码中被真实引用的 key 集合。"""
    hit = set()
    for key in all_keys:
        # 成员访问形式：l10n.xxx / localizations.xxx / AppLocalizations.of(c)!.xxx
        if re.search(r"\.%s\b" % re.escape(key), source):
            hit.add(key)
    return hit


def filter_arb(src_file: Path, dst_file: Path, keep: set) -> int:
    """按 keep 集合裁剪单个 ARB 文件并写出，返回保留的文案条数。"""
    data = json.loads(src_file.read_text(encoding="utf-8"), object_pairs_hook=OrderedDict)
    out = OrderedDict()
    # @@locale 等全局元数据必须保留在最前面。
    for k, v in data.items():
        if k.startswith("@@"):
            out[k] = v
    count = 0
    for k, v in data.items():
        if k.startswith("@@") or k.startswith("@"):
            continue
        if k in keep:
            out[k] = v
            # 同步搬运该 key 的描述性 metadata（@key），保证占位符定义不丢。
            meta = data.get("@" + k)
            if meta is not None:
                out["@" + k] = meta
            count += 1
    dst_file.write_text(
        json.dumps(out, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    return count


def main() -> None:
    en_src = SRC_L10N / "app_en.arb"
    zh_src = SRC_L10N / "app_zh.arb"
    en_data = json.loads(en_src.read_text(encoding="utf-8"))
    zh_data = json.loads(zh_src.read_text(encoding="utf-8"))

    # 以英文母版的 key 为全集（zh 是它的翻译）。
    all_keys = [k for k in en_data if not k.startswith("@")]
    source = collect_source_text()
    keep = used_keys(all_keys, source) | EXTRA_KEYS
    # 只保留两份 ARB 都存在的 key，避免生成时出现「缺翻译」告警。
    keep = {k for k in keep if k in en_data and k in zh_data}

    n_en = filter_arb(en_src, DST_L10N / "app_en.arb", keep)
    n_zh = filter_arb(zh_src, DST_L10N / "app_zh.arb", keep)
    print(f"保留文案：en={n_en} 条，zh={n_zh} 条（源文件 en={len(all_keys)} 条）")

    missing = sorted(k for k in EXTRA_KEYS if k not in keep)
    if missing:
        print(f"警告：以下强制保留 key 在源 ARB 中不存在 -> {missing}")


if __name__ == "__main__":
    main()
