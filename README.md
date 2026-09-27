# Azure AI landing zone

One hub network, one private DNS authority, one EU-bound model endpoint and one governance
baseline in Sweden Central, so each of four AI workload repositories deploys only its own spoke.

## Architecture

## Address plan

## Private DNS zones

## Naming convention

`{type}-{workload}-{scope}-{region}` — for example `rg-aiplatform-hub-swc` or
`srch-aiplatform-shared-swc`. `workload` is `aiplatform`, `scope` is `hub` or `shared`, and
`region` is `swc` for Sweden Central in every regional name, resource groups included.

- `{type}` is the Cloud Adoption Framework abbreviation, except the Foundry account, which uses
  `fdry` rather than CAF's `aif`.
- Container Registry names allow only alphanumerics: `craiplatformsharedswc`.
- Child resources are named for their purpose: `snet-privatelink`, `proj-ragplatform`.
- Global resources have no region and no suffix: `ag-aiplatform-shared`,
  `budget-aiplatform-monthly`. Private DNS zone names are fixed by Azure.
- The Foundry subdomain, Search service and registry names are globally unique. A second
  deployment changes `workload` in `infra/main.bicepparam`.

## Identity and RBAC

## Consuming the landing zone

## Deploy

## GitHub Actions federated credentials

## Cost

## Decisions

## Scope and simplifications
