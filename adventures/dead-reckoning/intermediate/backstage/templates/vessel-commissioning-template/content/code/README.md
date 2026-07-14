# ${{ values.name }}

A vessel in the Grand Fleet, commissioned through the fleet's commission office.

This repository was scaffolded by the **vessel commissioning template** in Backstage.
It contains a minimal service that reports the vessel's status, and a
`catalog-info.yaml` that registers the vessel in the fleet registry (the Backstage catalog).

Deployment manifests for this vessel live in the separate `${{ values.name }}-deploy`
repository; the delivery pipeline builds this repo's image and bumps the tag over there.

## Run locally

```bash
go run .
# then visit http://localhost:8080
```
