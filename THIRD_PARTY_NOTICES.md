# Third-Party Notices

This repository contains generated or vendored material from third-party
open-source projects. That material remains copyrighted by its respective
copyright holders and is distributed under the licenses identified below.

The Apache License 2.0 in the repository root applies to original material in
this repository. It does not replace or remove third-party copyright,
attribution, trademark, or license notices.

## Included or Referenced Components

### Sealed Secrets v0.36.1

- Project: Sealed Secrets for Kubernetes
- Source: https://github.com/bitnami-labs/sealed-secrets
- License: Apache-2.0
- Included material: `kubernetes/01-sealed-secrets/00-manifest.yml`
- Form: Generated or vendored Kubernetes controller manifest

### cert-manager v1.20.0

- Project: cert-manager
- Source: https://github.com/cert-manager/cert-manager
- License: Apache-2.0
- Included material: `kubernetes/02-cert-manager/01-manifest.yml`
- Form: Kubernetes manifest rendered from the upstream Helm chart

### Longhorn v1.11.1

- Project: Longhorn
- Source: https://github.com/longhorn/longhorn
- License: Apache-2.0
- Included material: `kubernetes/03-longhorn/01-manifest.yml`
- Form: Kubernetes manifest rendered from the upstream Helm chart

### Argo CD Helm chart 10.2.1 / Argo CD 3.4.5

- Project: Argo Helm
- Source: https://github.com/argoproj/argo-helm
- License: Apache-2.0
- Reference: `kubernetes/00-argocd/Chart.yaml`
- Form: Remote Helm chart dependency; the upstream chart is not vendored in
  this repository

## License Texts and Notices

The full Apache License 2.0 text is provided in the repository-root
`LICENSE` file. Upstream copyright, attribution, and license notices embedded
in generated or vendored files must be retained.

This notice is informational and does not modify the terms of any license.

