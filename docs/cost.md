# Cost

Sweden Central retail prices in EUR from the Azure retail prices API, retrieved on 29 September
2026, before tax and without reservations or discounts. A month is 730 hours.

## Today

Fixed charges accrue whether or not a workload sends a request.

| Resource | Unit price | Per month |
|---|---|---|
| AI Search Basic, one replica | €0.0867 per hour | €63.29 |
| Private endpoints: Foundry, Search, and Search's billing link | €0.0086 per hour each | €18.83 |
| Private DNS zones, fourteen | €0.4293 per zone | €6.01 |
| Container Registry Basic | €0.1431 per day | €4.35 |
| **Fixed total** | | **€92.49** |

Everything else is usage-based and near zero when idle: private endpoint traffic at €0.0086 per GB
in each direction, DNS queries at €0.3435 per million, Log Analytics ingestion at €2.5674 per GB
after the first 5 GB each month, and email notifications. The Foundry account, its projects, its
guardrail and the hub network have no fixed charge.

Tokens are billed per deployment on DataZone Standard (per million tokens):

| Model | Input | Output | Example month | Cost |
|---|---|---|---|---|
| `gpt-5-mini` | €0.2361 | €1.8891 | 20 M in, 4 M out | €12.28 |
| `gpt-5-nano` | €0.0472 | €0.3778 | 50 M in, 10 M out | €6.14 |
| `text-embedding-3-small` | below €0.0001 per 1 K | — | indexing and queries | negligible |

The example month costs €18.42 in tokens, €1.67 more than on Global Standard (ADR-002).

## Budget

`budget-aiplatform-monthly` is 300 in the subscription's billing currency — euros are assumed here
— and covers the whole subscription, workload spokes included. At the example volumes the platform
costs €110.90, so the
40 % alert (€120) marks the first spend that is not the platform itself, 80 % (€240) a workload
growing faster than planned, and 100 % (€300) the point to stop and review. The amount is a
parameter in `infra/main.bicepparam`; the start date is fixed at the first deployment.

## Scaled posture

What the same design costs with every rejection reversed and production availability.

| Change | Per month |
|---|---|
| AI Search S1 with three replicas — the SLA for queries and indexing | €631.81 |
| Container Registry Premium with a private endpoint (ADR-005) | €49.81 |
| Azure Firewall Standard with forced tunnelling (ADR-006) | €783.51 |
| DNS Private Resolver inbound endpoint for on-premises resolution (ADR-004) | €154.56 |
| Private endpoints and DNS zones, unchanged | €24.84 |
| Log Analytics at 50 GB a month | €115.53 |
| **Fixed total** | **€1,760.06** |

Ten times today's token volume adds €184.16. The firewall alone costs more than the rest of the
platform combined, which is why ADR-006 waits for a requirement that needs it.

## Attribution

Every taggable resource carries `repo`, and the Deny policy keeps it that way, so Cost Management can group
spend by repository. Shared services carry `repo: azure-ai-landing-zone`: model tokens bill to the
shared Foundry account, not to the workload that sent them. To attribute tokens per workload, give
a workload its own deployment — DataZone Standard deployments cost nothing while idle — and read
the token metrics per deployment in the workbook.
