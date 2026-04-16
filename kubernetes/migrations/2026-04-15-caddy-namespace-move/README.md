# Caddy Namespace Migration

This one-time migration moves the handwritten Caddy stack from the `default`
namespace into the dedicated `caddy` namespace while preserving NetBird state
from `/var/lib/netbird`.

## Files

- `01-cutover.sh`: stages the new namespace resources, copies data, deploys the
  new workload, and switches Ingress
- `02-cleanup.sh`: removes temporary helper Pods and the old `default`
  namespaced resources after verification
- `source-helper.yml`: mounts the existing `default/netbird-pvc`
- `destination-helper.yml`: mounts the new `caddy/netbird-pvc`

## Preconditions

- Your current `kubectl` context points at the target cluster.
- `kubectl` can create resources in both `default` and `caddy`.
- The updated manifests in `kubernetes/caddy/` have already been committed.
- `kubernetes/caddy/03-sealedsecret.yml` is already resealed for namespace
  `caddy`.
- Brief downtime is acceptable during the cutover.

## Cutover

Run the cutover script from anywhere inside the repo:

```bash
./kubernetes/migrations/2026-04-15-caddy-namespace-move/01-cutover.sh
```

What it does:

1. Applies `kubernetes/caddy/00` through `03`
2. Scales the old `default/caddy-deployment` to `0`
3. Starts helper Pods in `default` and `caddy`
4. Copies `/var/lib/netbird` from the old PVC to the new PVC with `tar`
5. Applies `kubernetes/caddy/04` and `05`
6. Waits for the new `caddy` Deployment and secret
7. Deletes the old `default` Ingress and applies `kubernetes/caddy/06`
8. Waits for the new TLS secret in namespace `caddy`

## Verify

Check the new namespace:

```bash
kubectl -n caddy get deploy,po,svc,ingress,pvc,secret
kubectl -n caddy logs deploy/caddy-deployment -c netbird --tail=50
kubectl -n caddy get secret vabkapoor-com-tls
```

Confirm the old Deployment is scaled down:

```bash
kubectl -n default get deploy caddy-deployment
kubectl -n default get pods -l app=caddy
```

## Cleanup

After the new workload is healthy and traffic is flowing through the `caddy`
namespace, remove the temporary helper Pods and old `default` resources:

```bash
./kubernetes/migrations/2026-04-15-caddy-namespace-move/02-cleanup.sh
```

The cleanup script intentionally leaves `default/netbird-pvc` in place as
rollback insurance. Delete that PVC manually only after you are confident the
new workload is stable.

## Rollback

If the cutover fails before the new `caddy` Deployment is serving traffic:

1. Delete the `caddy` Ingress if it was applied.
2. Scale `default/caddy-deployment` back to `1`.
3. Investigate the `caddy` namespace resources without deleting
   `default/netbird-pvc`.

Example:

```bash
kubectl -n caddy delete ingress caddy-ingress --ignore-not-found
kubectl -n default scale deployment caddy-deployment --replicas=1
kubectl -n default rollout status deployment/caddy-deployment --timeout=180s
```
