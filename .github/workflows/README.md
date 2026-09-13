# CI: Publish Docker image

این workflow تصویر production پروژه رو می‌سازه و توی **GitHub Container Registry**
(`ghcr.io`) منتشر می‌کنه، تا manifest های `k8s/deployment.yaml` بتونن مستقیم
ازش pull کنن.

---

## Trigger

| رویداد | نتیجه |
|--------|-------|
| push به `main` | tag های `:latest` و `:<7-char-sha>` |
| push به `refs/tags/v*` (مثلاً `v1.2.3`) | tag های `:v1.2.3`, `:latest`, `:<7-char-sha>` |

> شرط `if` عمداً اضافه شده تا اگه یه push هم به main و هم به یه tag بخوره
> (که در عمل پیش نمی‌یاد ولی GitHub اون رو به‌عنوان دو event می‌فرسته)،
> workflow دوبار اجرا نشه.

---

## محل انتشار

image ها توی `ghcr.io/<owner>/<repo>` منتشر می‌شن:

```
ghcr.io/<owner>/codebase:latest
ghcr.io/<owner>/codebase:a1b2c3d
ghcr.io/<owner>/codebase:v1.2.3
```

بعد از اولین انتشار، برو به GitHub:
**Packages → `<repo>` → Package settings → Add repository** و دسترسی public
رو فعال کن (اگه می‌خوای cluster بتونه بدون login بکشه).

---

## استفاده توی k8s

توی `k8s/deployment.yaml` خط image رو عوض کن:

```yaml
image: ghcr.io/<owner>/codebase:latest
```

و اگه cluster داخل GitHub نیست، یه **ImagePullSecret** بساز:

```bash
kubectl create secret docker-registry ghcr-pull \
  --docker-server=ghcr.io \
  --docker-username=<github-user> \
  --docker-password=<github-pat-with-read:packages> \
  --namespace=codebase
```

و توی `deployment.yaml` اضافه کن:

```yaml
spec:
  imagePullSecrets:
    - name: ghcr-pull
  containers: ...
```

---

## ارتقاء بعدی (اگه build کند شد)

اگه image بزرگ شد و build طول کشید، یه cache step اضافه کن:

```yaml
- name: Cache Docker layers
  uses: actions/cache@v4
  with:
    path: /tmp/.buildx-cache
    key: ${{ runner.os }}-buildx-${{ github.sha }}
    restore-keys: ${{ runner.os }}-buildx-

- name: Build and push
  uses: docker/build-push-action@v6
  with:
    cache-from: type=local,src=/tmp/.buildx-cache
    cache-to: type=local,dest=/tmp/.buildx-cache-new,mode=max
    # (سپس در پایان: mv /tmp/.buildx-cache-new /tmp/.buildx-cache)
```
