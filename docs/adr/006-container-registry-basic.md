# ADR-006 · Rejection: Container Registry Premium with private link

**Status:** accepted (rejection) · **Date:** 2026-10-14

## Context

Four workloads push container images from CI and pull them into Container Apps and, in one case,
AKS. The registry holds fewer than ten images at a time, each under a gigabyte, rebuilt a few
times a week. Private link for a registry is a Premium-tier feature, so the network decision in
ADR-002 and the SKU decision here are coupled: choosing Premium is only worth discussing if the
private endpoint is going to be deployed.

## Options

List prices from the Azure Retail Prices API on 2026-10-14, currency EUR, Sweden Central, per
registry per day; a month is 30.4 days.

| SKU | Unit price | Per month | Included storage | Private link | Webhooks | Geo-replication |
|---|---|---|---|---|---|---|
| Basic | 0.1466 / day | 4.5 | 10 GiB | no | 2 | no |
| Standard | 0.5866 / day | 17.8 | 100 GiB | no | 10 | no |
| Premium | 1.4666 / day | 44.6 | 500 GiB | yes | 500 | yes |

Premium with a private endpoint adds the endpoint itself (0.0088 an hour, about 6.4 a month) and
the `privatelink.azurecr.io` zone (0.44 a month), so the private registry costs about **51.5 a
month against 4.5** — the difference is close to the entire fixed cost of the rest of the shared
group.

## Decision

Basic. The registry's job is to hold a handful of images for pulls that authenticate with
`AcrPull` through managed identities; the admin user is disabled and anonymous pull is never
enabled, so the public endpoint accepts no request without a token. Ten gibibytes covers the
portfolio's images several times over, and the Basic throughput limits are far above a few
pushes a day.

What Premium would add, and why none of it is bought today:

- **Private link** — the network decision is made in ADR-002, for the whole estate, and this
  registry follows it.
- **Geo-replication** — one region.
- **Content trust and dedicated data endpoints** — no signing pipeline exists yet; the day images
  are signed, Premium is the prerequisite and this record is where that is noted.
- **Retention policies and higher webhook counts** — not needed at this image count.

## Trade-offs

- Image pulls traverse the public internet, authenticated. Same trade-off as ADR-002.
- Basic has the lowest throughput and storage ceilings of the three tiers; a workload that
  starts producing multi-gigabyte images or tens of pushes an hour would hit them. Both would be
  visible in `Storage used` and `Total Push Count` metrics before they hurt.
- Untagged manifests accumulate without a retention policy; `az acr manifest` cleanup is a
  manual task.

## Revisit when

ADR-002 reverses (Premium becomes the prerequisite for the endpoint), image signing is adopted,
storage approaches 10 GiB, or a second region is added. The SKU is a one-line change in
`infra/modules/registry.bicep` and an in-place upgrade on the resource.
