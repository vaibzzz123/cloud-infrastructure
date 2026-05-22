kubectl create secret generic netbird-secret \
  --namespace caddy \
  --from-env-file=04-caddy/.env \
  --dry-run=client -o yaml | kubeseal -o yaml > 04-caddy/03-sealedsecret.yml