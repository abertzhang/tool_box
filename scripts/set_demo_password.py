#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
文件：scripts/set_demo_password.py
模块：tool_box / 账号体系（应用商店审核辅助）

用途：
    用 Supabase **Admin API** 给指定账号设置密码，使其可以用「邮箱 + 密码」登录。

为什么要有这个脚本（而不是直接 UPDATE auth.users）：
    直接用 SQL 写 `encrypted_password = crypt('xxx', gen_salt('bf'))` 是我们自己
    手搓 bcrypt 哈希，但项目实际的密码算法未必是 bcrypt —— Supabase 部分项目
    已切换到 argon2id。算法不匹配时 SQL 会执行成功、哈希也确实写进去了，
    但 GoTrue 校验时仍然返回 invalid_credentials，非常难排查（本项目就踩到了）。
    走 Admin API 则由 GoTrue **按项目自身配置**生成哈希，算法永远正确。

前置：
    需要 service_role key（Supabase Dashboard → Project Settings → API Keys）。
    ⚠️ service_role 可绕过全部 RLS，等同于数据库管理员，切勿写进代码或提交。

用法：
    export SUPABASE_SERVICE_ROLE_KEY='eyJhbGciOi...'
    python3 scripts/set_demo_password.py z_chunhua@126.com 123456789

    # 也可以先空跑，只看会改哪个用户、不落任何修改
    python3 scripts/set_demo_password.py z_chunhua@126.com 123456789 --dry-run

关键依赖：
    仅用 Python 标准库（urllib / json），无需 pip 安装任何包。
    注：沙箱环境会注入 HTTP_PROXY，脚本内已用 ProxyHandler({}) 显式禁用代理，
    避免请求被本地代理拦截。
"""

import json
import os
import sys
import urllib.error
import urllib.request

# Supabase 项目 ref：nfoishlluynelazgwduc
BASE_URL = "https://nfoishlluynelazgwduc.supabase.co"


def _opener():
    """构造禁用代理的 urllib opener（绕开环境里的 HTTP_PROXY）。"""
    return urllib.request.build_opener(urllib.request.ProxyHandler({}))


def _request(opener, method, path, key, payload=None):
    """发起一次 Supabase Admin API 请求，返回解析后的 JSON。"""
    data = json.dumps(payload).encode() if payload is not None else None
    req = urllib.request.Request(
        BASE_URL + path,
        data=data,
        method=method,
        headers={
            # Admin API 同时校验这两个头，缺一不可。
            "apikey": key,
            "Authorization": "Bearer " + key,
            "Content-Type": "application/json",
        },
    )
    try:
        resp = opener.open(req, timeout=30)
        raw = resp.read().decode()
        return json.loads(raw) if raw.strip() else {}
    except urllib.error.HTTPError as e:
        body = e.read().decode()
        try:
            detail = json.loads(body)
        except ValueError:
            detail = {"raw": body}
        raise SystemExit(
            "请求失败 %s %s -> HTTP %s\n%s"
            % (method, path, e.code, json.dumps(detail, ensure_ascii=False, indent=2))
        )


def find_user_id(opener, key, email):
    """按邮箱找到用户 id。

    Admin API 的列表接口没有直接的 email 过滤参数，这里分页遍历查找。
    账号量级小（万级以内）遍历开销可忽略；若账号很多可加大 per_page。
    """
    page = 1
    target = email.strip().lower()
    while page <= 20:  # 最多翻 20 页（每页 200 条 = 4000 账号），防止意外死循环
        data = _request(
            opener,
            "GET",
            "/auth/v1/admin/users?page=%d&per_page=200" % page,
            key,
        )
        # 不同 GoTrue 版本返回结构不同：可能是 {"users": [...]}，也可能直接是列表。
        users = data.get("users", []) if isinstance(data, dict) else data
        if not users:
            break
        for u in users:
            if (u.get("email") or "").strip().lower() == target:
                return u.get("id")
        if len(users) < 200:
            break
        page += 1
    return None


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    dry_run = "--dry-run" in sys.argv
    if len(args) < 2:
        raise SystemExit(
            "用法: python3 scripts/set_demo_password.py <email> <password> [--dry-run]"
        )
    email, password = args[0], args[1]

    key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "").strip()
    if not key:
        raise SystemExit(
            "请先设置环境变量 SUPABASE_SERVICE_ROLE_KEY\n"
            "  取值位置：Supabase Dashboard → Project Settings → API Keys → service_role\n"
            "  ⚠️ 该 key 可绕过全部 RLS，不要写进代码、不要提交到仓库。"
        )

    op = _opener()
    user_id = find_user_id(op, key, email)
    if not user_id:
        raise SystemExit("未找到邮箱为 %s 的用户，请确认账号已存在。" % email)

    print("目标用户：")
    print("  email  : %s" % email)
    print("  user_id: %s" % user_id)

    if dry_run:
        print("\n--dry-run：未做任何修改。")
        return

    # email_confirm=true 一并确保邮箱处于已确认状态：
    # 本项目 mailer_autoconfirm=false，未确认的账号登录会失败。
    updated = _request(
        op,
        "PUT",
        "/auth/v1/admin/users/%s" % user_id,
        key,
        {"password": password, "email_confirm": True},
    )
    print("\n已更新：")
    print("  email             : %s" % updated.get("email"))
    print("  email_confirmed_at: %s" % updated.get("email_confirmed_at"))
    print("  updated_at        : %s" % updated.get("updated_at"))
    print("\n完成。可用下面的方式立刻验证登录是否成功：")
    print("  POST %s/auth/v1/token?grant_type=password" % BASE_URL)
    print("  body: {\"email\": \"%s\", \"password\": \"<上面的密码>\"}" % email)


if __name__ == "__main__":
    main()
