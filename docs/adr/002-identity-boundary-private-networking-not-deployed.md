# ADR-002 · Identity is the security boundary; private networking is designed, costed and not deployed

**Status:** accepted · **Date:** 2026-10-14

## Context

Every service in this estate exposes a public endpoint. The conventional reading is that a
public endpoint is a risk, and the conventional remedy is private link: a private endpoint per
service, a private DNS zone per service family, a virtual network that everything joins, and
`publicNetworkAccess: Disabled` to close the public door. An earlier version of this platform
did exactly that — one hub group, fourteen private DNS zones, seven private endpoints — and the
result was an estate the operator could not operate.

The question this record answers is not *"is private link good"*. It is: **what does private
link add on top of a keyless, token-only estate, what does it cost, and what does it break for
an estate run by one engineer from a laptop?**

## What the boundary is today

No service accepts a key (ADR-003). A request to any endpoint in the shared group must carry a
Microsoft Entra token for a principal that holds an explicitly assigned role on that resource;
anything else is rejected at the front door of the service, authenticated or not, before any
data is read. Role assignments are the perimeter, and they are reviewed in the same pull request
as the template. A public endpoint in this estate is therefore not an unauthenticated endpoint.

## What private link would add

Private link does one thing the token does not: it keeps **authenticated** traffic off the
public internet, on the Microsoft backbone, and it lets `publicNetworkAccess` be disabled so that
even a correctly issued token presented from outside the network is refused. That is worth
paying for when an organisation's data classification forbids transit over the public internet,
when a network team already operates a hub with hybrid connectivity, or when exfiltration by a
compromised-but-authorised identity must be bounded by network position as well as by role.

The full design, so that the decision is reversible without a research phase:

| Resource | Private endpoint `groupId` | Private DNS zones required |
|---|---|---|
| Foundry account | `account` | `privatelink.cognitiveservices.azure.com`, `privatelink.openai.azure.com`, `privatelink.services.ai.azure.com` |
| AI Search | `searchService` | `privatelink.search.windows.net` |
| Container Registry (Premium only, ADR-006) | `registry` | `privatelink.azurecr.io`, with the regional data endpoint records in the same zone |
| Log Analytics, through an Azure Monitor Private Link Scope | `azuremonitor` | `privatelink.monitor.azure.com`, `privatelink.oms.opinsights.azure.com`, `privatelink.ods.opinsights.azure.com`, `privatelink.agentsvc.azure-automation.net`, `privatelink.blob.core.windows.net` |
| Each workload's storage account | `blob` | `privatelink.blob.core.windows.net` (shared with the scope above) |
| Each workload's Cosmos DB account | `Sql` | `privatelink.documents.azure.com` |
| Each workload's Container Apps environment | `managedEnvironments` | `privatelink.swedencentral.azurecontainerapps.io` |

Zone names and group ids are from the Azure Private Endpoint DNS reference, retrieved on
2026-10-14. The shared group needs four endpoints and ten zones; the four workloads add roughly
ten endpoints and two zones between them, assuming one environment, one storage account and one
Cosmos account each.

## What it would cost

List prices from the Azure Retail Prices API on 2026-10-14, currency EUR, region Sweden Central
where the meter is regional (`Standard Private Endpoint`, `Private Zone`, `Basic Registry Unit`,
`Premium Registry Unit`, `B2s`, `VpnGw1`); a month is 730 hours.

| Item | Unit price | Quantity | Per month |
|---|---|---|---|
| Private endpoints | 0.0088 / hour | 14 | 90 |
| Private DNS zones | 0.44 / zone / month | 12 | 5 |
| Data processed through the endpoints | 0.0088 / GB | tens of GB | under 1 |
| Container Registry Premium instead of Basic (ADR-006) | 1.4666 − 0.1466 / day | 30.4 days | 40 |
| Jump host: one `B2s` virtual machine, running | 0.038 / hour | 730 hours | 28 |
| **Total with a jump host** | | | **≈ 163** |
| Alternative to the jump host: a `VpnGw1` gateway for point-to-site access | 0.1672 / hour | 730 hours | 122 instead of 28 |

The estate's fixed cost without any of this is about 70 a month (`docs/cost.md`), nearly all of
it the search service. Private networking would more than triple the fixed cost before the first
query, and the jump host or gateway is not optional — it is the operational consequence below.

## The consequence that decides it

With `publicNetworkAccess: Disabled`, **the operator is outside the boundary.** Concretely, from
the laptop that builds this portfolio:

- `ops/index.py` cannot create the index, the skillset or the indexer; the search service refuses
  the connection before authentication.
- `azd deploy` cannot reach the services it configures after provisioning, and local integration
  tests cannot run.
- GitHub-hosted runners are equally outside, so every data-plane step in CI — index creation,
  evaluation runs, smoke tests — needs a self-hosted runner inside the network.
- Even `az search service show` with a `--query` on data-plane state fails.

Everything operational therefore moves to a jump host or a point-to-site VPN: a machine to patch,
a Bastion or a public IP to protect, a VPN client to maintain, and a second place where
credentials live. For an organisation with a network team that cost is absorbed; for one
engineer it is the single largest operational burden in the estate, bought to protect traffic
that is already authenticated, encrypted in transit and authorised by role.

## Options considered

1. **Full private link, public access disabled** — the design above. Rejected for the reason
   above; the design is kept so that the rejection is informed rather than lazy.
2. **Private endpoints for the workloads only, public access kept for the operator** — pays for
   the endpoints without gaining the control, because the public door stays open. Rejected as
   the worst of both.
3. **Network Security Perimeter** — a newer control that groups PaaS resources behind a logical
   perimeter without a virtual network. It closes the same door for the same operator; the
   consequence is identical. Noted as the cheaper first step if the decision reverses.
4. **Identity as the boundary, network documented** — this record.

## Decision

Option 4. Every service keeps a public endpoint with local authentication disabled; no virtual
network, private endpoint or private DNS zone is deployed; this document holds the private
design and its price. The workloads inherit the posture: they state it in one sentence and do
not re-argue it.

## Trade-offs

- Authenticated traffic traverses the public internet. Mitigated by TLS and by tokens bound to
  roles, not eliminated.
- A compromised identity can be used from anywhere; network position does not bound it. The
  mitigation is the narrowness of each role and the failed-authentication query in
  `monitoring/queries.kql`.
- A reviewer who expects private endpoints in every "enterprise" template will ask. That is the
  question this document exists to answer.

## Revisit when

Any one of these holds: a workload processes data whose handling rules forbid public-internet
transit; the estate gains a hub network with hybrid connectivity that the operator already sits
inside, so the jump host is free; or a second team operates the platform and the network control
stops being one person's burden. The first step then is the table above, starting with the
search service and the Foundry account, and the Container Registry SKU change in ADR-006.
