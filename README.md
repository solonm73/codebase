# `codebase` — Next.js 16 production starter

این ریپو یه قالب Next.js 16 + Tailwind 4 + Prisma + SQLite هست که با
**مانیفست کوبرنتیز** و **CI/CD** کامل برای دیپلوی توی کلاستر آماده‌ست.
طراحی‌شده برای فورک زدن: هر بار که یه پروژهٔ جدید می‌خوای، fork می‌گیری و با
**یه دستور** بالا میاری، بدون ویرایش هیچ YAML.

---

## 🚀 شروع سریع (برای یه fork جدید)

```bash
# ۱. این ریپو رو fork کن و clone کن
git clone https://github.com/<you>/codebase.git my-new-project
cd my-new-project

# ۲. Settings → Actions → General → Workflow permissions: Read and write

# ۳. یه push بده تا image بسازه
git push origin main

# ۴. منتشر بمون تا workflow تموم بشه، بعد:
cd k8s
./setup.sh init
IMAGE_OWNER=<your-github-username> \
HOSTNAME=app.example.com \
NEXTAUTH_SECRET=$(openssl rand -base64 32) \
./setup.sh apply

# ۵. چک کن
kubectl -n codebase get pods,svc,ingress
```

> **نکته:** `<your-github-username>` همون owner ریپوی fork‌شده‌ست. image
> توسط workflow توی `ghcr.io/<your-github-username>/codebase:latest`
> منتشر می‌شه.

---

## 📁 ساختار

```
.
├── src/                    # Next.js app (App Router)
├── prisma/                 # Prisma schema (SQLite by default)
├── k8s/                    # ⭐ Manifest های کوبرنتیز — repo-agnostic
│   ├── setup.sh            # نقطهٔ ورود واحد برای همهٔ fork‌ها
│   ├── README.md           # راهنمای کامل k8s
│   ├── deployment.yaml     # Deployment اصلی
│   └── ...
├── .github/workflows/
│   └── docker-publish.yml  # CI: image → ghcr.io
├── components.json         # shadcn/ui config
├── next.config.ts          # output: "standalone" (k8s-ready)
├── Caddyfile               # Reverse proxy config (mounted in k8s)
└── package.json
```

---

## 🎯 ویژگی‌ها

- **Next.js 16** با App Router، `output: "standalone"` (آمادهٔ دیپلوی توی کانتینر)
- **shadcn/ui + Radix + Tailwind 4** برای UI
- **Prisma + SQLite** (قابل migration به Postgres)
- **next-intl** برای i18n
- **next-auth** برای authentication
- **Zustand** + **TanStack Query** + **React Hook Form** + **Zod** برای state و forms
- **Caddy** به‌عنوان reverse proxy با multi-port routing (`XTransformPort`)

---

## 🐳 دیپلوی محلی (بدون k8s)

```bash
bun install
bun run db:push
bun run dev
```

اپ روی `http://localhost:3000` بالا میاد. Caddy روی پورت 81 reverse-proxy
می‌کنه (برای استفاده از قابلیت `XTransformPort`).

---

## ☸️ دیپلوی کوبرنتیز

برای راهنمای کامل: [`k8s/README.md`](./k8s/README.md)

خلاصه:

```bash
# همه چی پارامتری — هیچ YAML نیاز به ویرایش نداره
IMAGE_OWNER=<owner> \
HOSTNAME=<hostname> \
NAMESPACE=<namespace> \
./k8s/setup.sh apply
```

---

## 🔄 Workflow فورک کردن

```
┌──────────────────────────────────────────────────────────────┐
│  1. این ریپو رو fork کن (GitHub UI)                           │
│                           ↓                                  │
│  2. Clone کن، یه push بده (main یا tag v*)                   │
│                           ↓                                  │
│  3. workflow image رو توی ghcr.io/<you>/codebase می‌ذاره     │
│                           ↓                                  │
│  4. IMAGE_OWNER=<you> HOSTNAME=... ./k8s/setup.sh apply       │
│                           ↓                                  │
│  5. هر بار پروژهٔ بعدی → مرحلهٔ ۱                           │
└──────────────────────────────────────────────────────────────┘
```

نکته: حتی می‌تونی **یه ریپوی fork‌شده رو دوباره fork کنی** — workflow
از `${{ github.repository }}` می‌خونه، پس owner همیشه درست resolve می‌شه.

---

## 🧪 توسعهٔ محلی

```bash
# dev server
bun install
bun run dev

# Prisma
bun run db:push        # sync schema to SQLite
bun run db:generate    # generate Prisma client
bun run db:reset       # ⚠️  nukes the database

# build & test
bun run build
bun run lint
```

---

## 📝 License

MIT — هر طور دوست داری استفاده کن.
