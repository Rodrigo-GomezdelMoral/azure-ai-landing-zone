# Azure AI landing zone

One hub network, one private DNS authority, one EU-bound model endpoint and one governance
baseline in Sweden Central, so each of four AI workload repositories deploys only its own spoke.

## Architecture

## Address plan

Only the hub is created here; each workload repository creates its own spoke. The whole plan is
fixed now because peered ranges must never overlap, a subnet can be resized only while it is empty,
and every address-space change on a peered network needs a peering sync on both sides.

| Network | Address space | Subnets |
|---|---|---|
| Hub | `10.0.0.0/16` | `snet-privatelink` `10.0.1.0/24` |
| P01 rag-platform | `10.20.0.0/16` | `snet-apps` `10.20.0.0/23` · `snet-privatelink` `10.20.2.0/24` |
| P02 field-operations-copilot | `10.21.0.0/16` | `snet-apps` `10.21.0.0/23` · `snet-privatelink` `10.21.2.0/24` |
| P03 care-intelligence-platform | `10.22.0.0/16` | `snet-apps` `10.22.0.0/23` · `snet-privatelink` `10.22.2.0/24` · `snet-aml` `10.22.4.0/24` |
| P04 ai-saas-platform | `10.23.0.0/16` | `snet-apps` `10.23.0.0/23` · `snet-privatelink` `10.23.2.0/24` · `snet-aks` `10.23.4.0/22` · `snet-func` `10.23.8.0/24` |

The rest of the hub range is held for a gateway, firewall or DNS resolver subnet if ADR-004 or
ADR-006 is revisited.

## Private DNS zones

The hub owns every zone the portfolio needs, links each one to the hub network and exports the IDs
as `dnsZoneIds`. Spokes link the zones they use and never create their own (ADR-004). Names match
the Learn page *Azure Private Endpoint private DNS zone values*, revision of August 2026.

| Zone | Used by |
|---|---|
| `privatelink.cognitiveservices.azure.com` | Foundry account, Content Understanding, Azure Language |
| `privatelink.openai.azure.com` | Foundry model endpoints |
| `privatelink.services.ai.azure.com` | Foundry project endpoints — without it, `FoundryChatClient` calls from a spoke resolve to the public IP and fail |
| `privatelink.search.windows.net` | AI Search |
| `privatelink.blob.core.windows.net` | Storage (P01, P02, P03) |
| `privatelink.file.core.windows.net` | Azure ML workspace storage (P03) |
| `privatelink.documents.azure.com` | Cosmos DB (P01, P02, P04) |
| `privatelink.vaultcore.azure.net` | Key Vault (P03, P04) |
| `privatelink.api.azureml.ms` | Azure ML workspace (P03) |
| `privatelink.notebooks.azure.net` | Azure ML workspace (P03) |
| `privatelink.postgres.database.azure.com` | PostgreSQL Flexible Server (P03) |
| `privatelink.redis.azure.net` | Azure Managed Redis (P04) |
| `privatelink.servicebus.windows.net` | Service Bus (P04) |
| `privatelink.eventgrid.azure.net` | Event Grid topics (P02, P04) |

The Foundry private endpoint (sub-resource `account`) registers records in the first three zones.

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

| ADR | Decision |
|---|---|
| [001](docs/adr.md#adr-001-hub-and-spoke-network) | Hub-and-spoke network |
| [002](docs/adr.md#adr-002-datazone-standard-in-the-eu-zone-not-global-standard) | DataZone Standard in the EU zone, not Global Standard |
| [003](docs/adr.md#adr-003-managed-identity-instead-of-keys) | Managed identity instead of keys |
| [004](docs/adr.md#adr-004-private-endpoints-with-dns-owned-by-the-hub) | Private endpoints with DNS owned by the hub, and the Application Insights exception |
| [005](docs/adr.md#adr-005-rejected-a-premium-registry-behind-a-private-endpoint) | Rejected: a Premium registry behind a private endpoint |
| [008](docs/adr.md#adr-008-one-foundry-project-per-agent-workload) | One Foundry project per agent workload |

## Scope and simplifications
