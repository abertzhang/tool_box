#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""create_users_table.sql 语法自检（离线，不连数据库）。

用途
----
每次改动建表脚本后跑一遍，提前发现「低级的 SQL 语法写错」，
避免把坏 SQL 贴进 Supabase SQL Editor 才发现。

原理
----
1. 去掉整行 `--` 注释（美元引用 $$ 内部的行不处理，plpgsql 里可能有伪装成注释的内容）；
2. 用**状态机**按分号切分语句 —— 不能用 `split(';')`，因为
   plpgsql 函数体（$$ ... $$）内部、字符串字面量里都有分号；
3. 逐句交给 sqlglot 解析（dialect=postgres）。

已知盲区（sqlglot 解析器不支持，但都是 PG 官方标准语法，**不要据此改 SQL**）
------------------------------------------------------------------------------
- `drop trigger if exists <名> on <表>;`     —— sqlglot 报 Invalid expression
- `notify pgrst, 'reload schema';`           —— sqlglot 报 Unexpected token
这两条已做过对照实验（用官方文档里的标准写法同样报错），确认是解析器能力问题。

另外：plpgsql 函数体（`create function ... as $$ ... $$` / `do $$ ... $$`）
不是 SQL，sqlglot 无法解析，本脚本会 SKIP 掉，这类需要人工复核。

依赖
----
sqlglot（装一次即可）：
    pip install -i https://pypi.tuna.tsinghua.edu.cn/simple sqlglot

用法
----
    python3 scripts/check_sql_syntax.py
    python3 scripts/check_sql_syntax.py <其它 .sql 文件路径>
"""

import re
import sys

try:
    import sqlglot
except ImportError:  # pragma: no cover - 环境缺依赖时给出明确指引
    sys.exit('缺少 sqlglot，请先安装：\n'
             '  pip install -i https://pypi.tuna.tsinghua.edu.cn/simple sqlglot')

# 默认校验本工程的建表脚本
DEFAULT_SQL = 'scripts/create_users_table.sql'

# 语句里出现这些标记说明内含 plpgsql 体，跳过解析（sqlglot 不支持 plpgsql）
SKIP_MARKERS = ('$$',)


def strip_line_comments(src: str) -> str:
    """剔除整行注释，但保留 $$ ... $$ 内部的原始内容。

    plpgsql 函数体里可能出现以 -- 开头的行（我们确实在里头写了中文注释），
    这些不能当成 SQL 注释丢掉——虽然丢了也不影响本脚本（函数体整体 SKIP），
    但保留原样能让切分时的 $$ 配对计数保持准确。
    """
    kept: list[str] = []
    in_dollar = False
    for line in src.split('\n'):
        if not in_dollar and line.strip().startswith('--'):
            continue
        kept.append(line)
        # 一行里出现奇数个 $$，说明美元引用状态发生翻转
        if line.count('$$') % 2 == 1:
            in_dollar = not in_dollar
    return '\n'.join(kept)


def split_statements(text: str) -> list[str]:
    """把整段 SQL 切成语句列表：跟踪行注释 / 块注释 / 单引号 / 双引号 / 美元引用。"""
    stmts: list[str] = []
    buf: list[str] = []
    i, n = 0, len(text)

    while i < n:
        ch = text[i]

        # 行注释：一路吃到换行
        if text.startswith('--', i):
            j = text.find('\n', i)
            i = n if j == -1 else j
            continue

        # 块注释 /* ... */
        if text.startswith('/*', i):
            j = text.find('*/', i + 2)
            i = n if j == -1 else j + 2
            continue

        # 美元引用 $tag$ ... $tag$
        dollar = re.match(r'\$[A-Za-z_]*\$', text[i:])
        if dollar:
            tag = dollar.group(0)
            j = text.find(tag, i + len(tag))
            if j == -1:  # 没闭合，把剩下的全当作本语句
                buf.append(text[i:])
                break
            buf.append(text[i:j + len(tag)])
            i = j + len(tag)
            continue

        # 单引号字符串，'' 表示转义的单引号
        if ch == "'":
            j = i + 1
            while j < n:
                if text[j] == "'":
                    if text.startswith("''", j):
                        j += 2
                        continue
                    break
                j += 1
            buf.append(text[i:j + 1])
            i = j + 1
            continue

        # 双引号标识符
        if ch == '"':
            j = text.find('"', i + 1)
            if j == -1:
                buf.append(text[i:])
                break
            buf.append(text[i:j + 1])
            i = j + 1
            continue

        # 语句结束
        if ch == ';':
            stmts.append(''.join(buf).strip())
            buf = []
            i += 1
            continue

        buf.append(ch)
        i += 1

    tail = ''.join(buf).strip()
    if tail:
        stmts.append(tail)
    return [s for s in stmts if s]


def main() -> int:
    path = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_SQL
    src = open(path, encoding='utf-8').read()

    stmts = split_statements(strip_line_comments(src))
    print(f'文件：{path}')
    print(f'切出语句数：{len(stmts)}\n')

    known_fail: list[tuple[int, str, str]] = []
    real_fail: list[tuple[int, str, str]] = []

    for idx, stmt in enumerate(stmts, 1):
        head = stmt[:70].replace('\n', ' ')
        # plpgsql 函数体直接跳过（不是 SQL，解析不了）
        if any(m in stmt for m in SKIP_MARKERS):
            print(f'[{idx:02}] SKIP  {head}')
            continue
        try:
            sqlglot.parse_one(stmt, dialect='postgres')
            print(f'[{idx:02}] OK    {head}')
        except Exception as exc:  # noqa: BLE001 - 只是拿报错文本做展示
            msg = str(exc).splitlines()[0][:160]
            print(f'[{idx:02}] FAIL  {head}\n         -> {exc.__class__.__name__}: {msg}')
            # 归类：已知盲区 vs 真错误
            normalized = ' '.join(stmt.split()).lower()
            if normalized.startswith('drop trigger') or normalized.startswith('notify'):
                known_fail.append((idx, head, msg))
            else:
                real_fail.append((idx, head, msg))

    print()
    print('=' * 62)
    if real_fail:
        print(f'❌ 发现 {len(real_fail)} 句疑似真错误（需要修）：')
        for idx, head, msg in real_fail:
            print(f'  [{idx:02}] {head}\n       {msg}')
        return 1

    if known_fail:
        print(f'✅ 无新增语法错误；{len(known_fail)} 句为 sqlglot 已知盲区'
              '（drop trigger on <表> / notify），属解析器不支持，不是 SQL 写错。')
    else:
        print('✅ 全部语句解析通过（plpgsql 函数体已跳过，需人工复核）')
    print('提示：sqlglot 只能证明「语法能被解析」，不能替代在 SQL Editor 里真跑一遍。')
    return 0


if __name__ == '__main__':
    sys.exit(main())
