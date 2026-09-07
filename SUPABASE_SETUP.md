# Supabase 接入说明

1. 在 Supabase 项目的 **SQL Editor** 中执行 [`supabase/schema.sql`](supabase/schema.sql)。
2. 从 **Project Settings → API** 复制 Project URL 和 anon public key。
3. 打开 `index.html`，替换 `SUPABASE_URL` 与 `SUPABASE_ANON_KEY` 两个占位值。anon key 可以公开，绝不要填写 `service_role` key。
4. 部署后，在 Supabase **Table Editor → garden_completions** 查看、筛选或删除异常成绩。

网页无账号机制，因此成绩仅做基本的数据库输入校验；异常成绩应在 Dashboard 中手动删除。
