# Kubernetes manifests for `codebase`

این پوشه manifest های کوبرنتیز رو نگه می‌داره به‌صورتی که **کاملاً repo-agnostic**
باشن: اگه چند بار fork بگیری، YAML ها رو **هیچ‌وقت نیازی به ویرایش نداری**.
تنها چیزی که بین fork‌ها عوض می‌شه، env varهای `IMAGE_OWNER` و `HOSTNAME`
هست که موقع `apply` پاس می‌شن.

---

## فایل‌ها

| فایل | توضیح |
|------|-------|
| `namespace.yaml` | Namespace `codebase` |
| `configmap.yaml` | Caddyfile + env vars غیرحساس |
| `secret.yaml.example` | Template — `init` خودش ازش می‌سازه `secret.yaml` |
| `pvc.yaml` | PVC یک گیگابایتی برای SQLite (ReadWriteOnce) |
| `deployment.yaml` | Deployment اصلی (image توسط Kustomize override می‌شه) |
| `service.yaml` | ClusterIP Service که به پورت 81 (Caddy) فوروارد می‌کنه |
| `ingress.yaml` | Nginx Ingress — host هم پارامتری عوض می‌شه |
| `kustomization.yaml` | base + image override از `IMAGE_OWNER` env var |
| `Dockerfile` | تصویر production (multi-stage، Bun + Caddy) |
| `setup.sh` | ⭐ **نقطهٔ ورود واحد برای همهٔ fork‌ها** |
| `README.md` | همین فایل |

---

## 🚀 دیپلوی یه fork جدید (۳ مرحله)

### مرحله ۱: workflow رو push کن تا image بسازه

توی GitHub، Settings → Actions → General → Workflow permissions مطمئن شو
**"Read and write permissions"** فعاله.

بعد:

```bash
# روی main
git push origin main

# یا یه tag
git tag v1.0.0 && git push origin v1.0.0
```

workflow `.github/workflows/docker-publish.yml` فعال می‌شه و image رو توی
`ghcr.io/<owner>/<repo>:latest` منتشر می‌کنه (`<owner>` = نام اکانت شما).

> **نکته:** اگه می‌خوای cluster بتونه بدون credential بکشه، برو
> GitHub → Packages → `<repo>` → Package settings → Change visibility → Public.

### مرحله ۲: secret بساز

```bash
./k8s/setup.sh init
```

این دستور `secret.yaml` رو از `secret.yaml.example` می‌سازه و با `openssl rand`
یه کلید تصادفی می‌ذاره. اگه `NEXTAUTH_SECRET` و `HOSTNAME` رو قبلاً export
کرده باشی، اون‌ها استفاده می‌شن.

### مرحله ۳: deploy

```bash
# مقادیر fork خودت رو بذار و deploy کن
IMAGE_OWNER="my-github-username" \
HOSTNAME="app.example.com" \
NEXTAUTH_SECRET="$(openssl rand -base64 32)" \
./k8s/setup.sh apply
```

تمام. `kubectl -n codebase get pods,svc,ingress` بزن و ببین همه چی بالا اومده.

---

## 📋 دستورات setup.sh

| Command | کار |
|---------|-----|
| `./k8s/setup.sh init` | ساختن `secret.yaml` از template |
| `./k8s/setup.sh render` | چاپ manifest رندر‌شده (برای دیباگ یا gitops) |
| `./k8s/setup.sh apply` | اعمال به کلاستر فعلی kubectl context |
| `./k8s/setup.sh delete` | پاک کردن namespace و secret |

همهٔ دستورات env varهای زیر رو می‌خونن:

| متغیر | پیش‌فرض | توضیح |
|-------|---------|-------|
| `IMAGE_OWNER` | `your-org` | GitHub owner که image رو publish کرده |
| `IMAGE_TAG` | `latest` | tag ایمیج (مثلاً SHA برای reproducibility) |
| `HOSTNAME` | _(خالی)_ | دامنهٔ عمومی برای Ingress |
| `NAMESPACE` | `codebase` | k8s namespace |
| `NEXTAUTH_SECRET` | _(خالی)_ | اگه خالی باشه، `init` خودش می‌سازه |

---

## 🔁 Workflow هر fork

```
┌─────────────────┐
│ GitHub Actions  │   push main / v* tag
│ docker-publish  │ ──────────────────────────┐
└─────────────────┘                           ▼
                                    ┌──────────────────────┐
                                    │ ghcr.io/<owner>/     │
                                    │     codebase:latest  │
                                    └──────────────────────┘
                                                │
                                                ▼
┌──────────────────┐    setup.sh apply    ┌─────────────────┐
│ IMAGE_OWNER=...  │ ───────────────────► │ kustomize builds │
│ HOSTNAME=...     │                      │ with override   │
└──────────────────┘                      └─────────────────┘
                                                       │
                                                       ▼
                                              ┌─────────────────┐
                                              │ cluster pulls   │
                                              │ from ghcr.io    │
                                              └─────────────────┘
```

---

## 🛠️ کار با چندتا fork همزمان

اگه می‌خوای چند تا نمونه از پروژه روی یه کلاستر بالا بیاری (مثلاً `staging` و
`prod` یا چند تا پروژهٔ مشابه):

### گزینهٔ ۱: namespace جدا (ساده)

```bash
# پروژهٔ اول
IMAGE_OWNER=acme   HOSTNAME=app1.example.com   NAMESPACE=acme   ./k8s/setup.sh apply

# پروژهٔ دوم (همون ریپو، fork دیگه)
IMAGE_OWNER=acme   HOSTNAME=app2.example.com   NAMESPACE=acme2  ./k8s/setup.sh apply
```

PVC ها و ingress ها توی هر namespace جدا می‌مونن. هیچ تداخلی نیست.

### گزینهٔ ۲: همون namespace، چندتا hostname

اگه چند تا پروژه روی یه دامنهٔ parent می‌خوای (مثلاً `acme.com/app1` و
`acme.com/app2`)، باید ingress path رو split کنی. این کار رو می‌تونی با
**Kustomize overlays** انجام بدی — یه `overlays/<fork>/kustomization.yaml`
بساز که hostname/path رو override می‌کنه. الگوی base + overlay در آینده
اضافه می‌شه.

---

## 🔐 تنظیم ImagePullSecret (برای repoهای private)

اگه image private هست و cluster بیرون از GitHub هست:

```bash
kubectl create secret docker-registry ghcr-pull \
  --docker-server=ghcr.io \
  --docker-username=<github-user> \
  --docker-password=<github-pat-with-read:packages> \
  --namespace=codebase
```

و توی `deployment.yaml` این خط رو اضافه کن (یا یه patch بنویس):

```yaml
spec:
  imagePullSecrets:
    - name: ghcr-pull
```

---

## 📌 نکات مهم

### چرا `replicas: 1` و `strategy: Recreate`؟

`/app/db/custom.db` روی یه PVC با `ReadWriteOnce` mount می‌شه. چند پاد همزمان
نمی‌تونن روی SQLite بنویسن. `Recreate` تضمین می‌کنه هنگام آپدیت، پاد قدیمی
قبل از پاد جدید کاملاً خاموش بشه.

اگه روزی HA خواستی:
1. `prisma/schema.prisma` رو از `sqlite` به `postgresql` تغییر بده
2. یه PostgreSQL StatefulSet جدا اضافه کن
3. `DATABASE_URL` رو توی ConfigMap عوض کن
4. `replicas: 2` و `strategy: RollingUpdate` بذار

### چرا Caddy نگه داشته شد؟

`Caddyfile` فعلی دو تا قابلیت داره که Nginx Ingress ساده نداره:
1. **Multi-port routing با `XTransformPort`** — اگه `mini-services/*` روی
   پورت‌های مختلف گوش می‌دن، کلاینت می‌تونه با `?XTransformPort=4001` پورت
   مقصد رو عوض کنه.
2. **ریدایرکت خودکار HTTP→HTTPS** — توی Caddy رایگانه.

اگه لازم نیست، می‌تونی Caddy رو از image حذف کنی و مستقیم Next.js (پورت 3000)
رو پشت Ingress بذاری.

### probe path

از `/api` استفاده شده چون `src/app/api/route.ts` یه GET handler ساده
(`{"message":"Hello, world!"}`) داره و وابسته به hydration کلاینت نیست.

---

## 🔧 عیب‌یابی

**پاد Pending:**
```bash
kubectl -n codebase describe pod <pod-name>
# معمولاً PVC نمی‌تونه bind بشه — storage class رو چک کن.
```

**پاد CrashLoopBackOff:**
```bash
kubectl -n codebase logs <pod-name> --previous
# معمولاً Caddyfile یا DATABASE_URL اشتباهه.
```

**Ingress 503:**
```bash
kubectl -n codebase get endpoints codebase
# اگه خالی بود، label selector Service با Pod match نمی‌کنه.
```

**ImagePullBackOff:**
```bash
kubectl -n codebase describe pod <pod-name> | grep -A5 Events
# معمولاً:
# 1. Package توی ghcr.io private هست → ImagePullSecret بساز
# 2. IMAGE_OWNER اشتباهه (یا export نشده)
```

**می‌خوای ببینی چی deploy می‌شه قبل از apply:**
```bash
IMAGE_OWNER=my-org ./k8s/setup.sh render | less
```

---

## 🧹 پاک کردن

```bash
NAMESPACE=codebase ./k8s/setup.sh delete
```

این دستور namespace و secret رو کامل پاک می‌کنه. PVC هم به دلیل
`persistentVolumeClaimReclaimPolicy: Delete` پاک می‌شه (بسته به storage
class تنظیمات cluster ممکنه متفاوت باشه).
