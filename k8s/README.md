# Kubernetes manifests for `codebase`

این پوشه یه مجموعه manifest کوبرنتیز برای اپ Next.js پروژه فراهم می‌کنه. طراحی
بر مبنای تصمیمات زیر:

- **تک‌پد، همه‌چیز تو یه container** (Caddy + Next.js + mini-services)
- **SQLite با PVC** و `replicas: 1` (ساده‌ترین حالت)
- **Nginx Ingress Controller**
- **Image registry:** `docker.io/your-org/codebase`

---

## فایل‌ها

| فایل | توضیح |
|------|-------|
| `namespace.yaml` | Namespace `codebase` |
| `configmap.yaml` | Caddyfile + env vars غیرحساس |
| `secret.yaml.example` | Template برای `next-auth` و URL. کپی کن به `secret.yaml` و مقدار واقعی بذار |
| `pvc.yaml` | PVC یک گیگابایتی برای SQLite (ReadWriteOnce) |
| `deployment.yaml` | Deployment اصلی با readiness/liveness probe |
| `service.yaml` | ClusterIP Service که به پورت 81 (Caddy) فوروارد می‌کنه |
| `ingress.yaml` | Nginx Ingress — hostname رو باید عوض کنی |
| `kustomization.yaml` | همهٔ فایل‌های بالا رو با هم load می‌کنه |
| `Dockerfile` | تصویر production (multi-stage، Bun + Caddy) |
| `OWNER.example` | راهنمای جایگزینی `<owner>` با GitHub owner واقعی |

---

## مراحل دیپلوی

### ۱. بیلد و push کردن image

**روش خودکار (توصیه‌شده):** workflow `.github/workflows/docker-publish.yml`
با push به main یا هر tag `v*`، image رو توی `ghcr.io/<owner>/codebase`
می‌سازه و publish می‌کنه. فقط کافیه `<owner>` رو با GitHub org/username واقعی
عوض کنی (راهنمای کامل: `k8s/OWNER.example`).

```bash
cd /home/mohammadreza-mehrabani/projects/codebase
sed -i 's/<owner>/my-org/g' k8s/deployment.yaml
```

**روش دستی (اگه workflow نداری یا تست محلی می‌خوای):**

```bash
cd /home/mohammadreza-mehrabani/projects/codebase
docker build -f k8s/Dockerfile -t ghcr.io/my-org/codebase:latest .
docker push ghcr.io/my-org/codebase:latest
```

### ۲. تنظیم secret

```bash
cp k8s/secret.yaml.example k8s/secret.yaml

# کلید next-auth رو بساز:
openssl rand -base64 32

# فایل رو ویرایش کن و NEXTAUTH_SECRET و NEXTAUTH_URL رو پر کن.
# NEXTAUTH_URL باید با hostname اینگرس یکی باشه.
```

### ۳. تنظیم hostname

تو `k8s/ingress.yaml` خط `host: REPLACE_ME_WITH_PUBLIC_HOSTNAME` رو با دامنهٔ
واقعی عوض کن (مثلاً `app.example.com`).

اگه TLS می‌خوای، cert-manager یا Secret دستی اضافه کن:

```yaml
tls:
  - hosts:
      - app.example.com
    secretName: codebase-tls
```

### ۴. اعمال manifest ها

```bash
cd /home/mohammadreza-mehrabani/projects/codebase/k8s

# اول secret (که توی kustomization نیست):
kubectl apply -f secret.yaml

# بعد بقیه با kustomize:
kubectl apply -k .

# یا مستقیم:
kubectl apply -f namespace.yaml
kubectl apply -f configmap.yaml
kubectl apply -f pvc.yaml
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl apply -f ingress.yaml
```

### ۵. چک کردن وضعیت

```bash
kubectl -n codebase get pods,svc,ingress,pvc
kubectl -n codebase logs -f deploy/codebase
kubectl -n codebase describe ingress codebase
```

---

## نکات مهم

### چرا `replicas: 1` و `strategy: Recreate`؟

`/app/db/custom.db` روی یه PVC با `ReadWriteOnce` mount می‌شه. چند پاد همزمان
نمی‌تونن روی SQLite بنویسن و در نهایت فایل خراب می‌شه. `Recreate` هم تضمین
می‌کنه هنگام آپدیت، پاد قدیمی قبل از پاد جدید کاملاً خاموش بشه.

اگه روزی خواستی HA داشته باشی:
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

اگه این قابلیت‌ها لازم نیست، می‌تونی Caddy رو از image حذف کنی و مستقیم
Next.js (پورت 3000) رو پشت Ingress بذاری. اون وقت:
- `deployment.yaml`: containerPort رو به 3000 عوض کن، probe path هم `/api`
- `service.yaml`: targetPort رو به `nextjs` (3000) بذار
- `configmap.yaml`: دیگه Caddyfile لازم نیست

### probe path

از `/api` استفاده کردم چون `src/app/api/route.ts` یه GET handler ساده
(`{"message":"Hello, world!"}`) داره و وابسته به client-side hydration نیست.
اگه این route رو حذف کردی، یه `/api/health` اضافه کن.

### Python runtime

اگه پروژه از Python استفاده می‌کنه، `.zscripts/python-runtime-build.sh`
رو توی مرحلهٔ build صدا بزن و `/app/python-runtime` رو توی image کپی کن.
الان Dockerfile فرض می‌کنه این مرحله غیرضروریه. اگه لازم شد، مرحلهٔ
`python-runtime-build.sh` رو با همون env vars به builder اضافه کن.

---

## عیب‌یابی

**پاد Pending مونده:**
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

**ImagePullBackOff (cluster نمی‌تونه image رو بکشه):**
```bash
kubectl -n codebase describe pod <pod-name> | grep -A5 Events
# معمولاً یعنی:
# 1. Package توی ghcr.io private هست → ImagePullSecret بساز (مرحلهٔ ۲ رو چک کن)
# 2. image name اشتباهه (owner رو عوض نکردی)
# 3. image هنوز build نشده (workflow اول اجرا نشده)
```

**`<owner>` رو جایگزین نکردی:**
```bash
grep -rn '<owner>' k8s/
# اگه خروجی داد، یعنی هنوز عوض نشده. مراحل OWNER.example رو اجرا کن.
```

**Next.js بالا نمی‌یاد:**
```bash
kubectl -n codebase exec -it <pod-name> -- sh
# cd /app && ls -la .next/standalone/server.js
# cd /app/next-service-dist (یا /.next/standalone) و bun server.js رو دستی اجرا کن
```
