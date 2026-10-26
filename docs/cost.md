# Cost model

Every figure in this document is an **estimate from list prices** unless the sentence that
contains it says it was measured. List prices were retrieved on 2026-10-14 from the Azure Retail
Prices API (`https://prices.azure.com/api/retail/prices`, `currencyCode=EUR`,
`armRegionName eq 'swedencentral'` for regional meters). A month is 730 hours or 30.4 days.

## Fixed cost of the shared group, as deployed

| Resource | Meter | Unit price (EUR) | Per day | Per month |
|---|---|---|---|---|
| AI Search Basic, 1 replica, 1 partition | `Basic Unit` | 0.0889 / hour | 2.13 | 64.9 |
| Container Registry Basic | `Basic Registry Unit` | 0.1466 / day | 0.15 | 4.5 |
| Log Analytics, ingestion | `Analytics Logs Data Ingestion` | 2.6311 / GB | depends on volume; diagnostics from three idle services are well under 0.1 GB a day | under 8 |
| Log Analytics, retention | 30 days included | 0 | 0 | 0 |
| Foundry account, project, deployments | none while idle | 0 | 0 | 0 |
| Action group, budget, diagnostic settings | none | 0 | 0 | 0 |
| **Total, estimated** | | | **≈ 2.3** | **≈ 70–77** |

The search service is more than ninety percent of the fixed cost, which is why the budget in
`infra/main.bicep` defaults to 80 a month: it is the shared group's expected bill if the search
service runs all month, and the 40 % and 80 % notifications fire at about 32 and 64.

## Variable cost: model usage

Pay-as-you-go deployments bill tokens only. Prices per million tokens, `GlobalStandard`, from the
same API call (the `DataZoneStandard` figures, ten percent higher, are in ADR-004):

| Deployment | Input | Cached input | Output |
|---|---|---|---|
| `gpt-5-mini` | 0.22 | 0.022 | 1.76 |
| `gpt-5-nano` | 0.044 | 0.0044 | 0.352 |
| `text-embedding-3-small` | not priced by the API in this region; treated as negligible | | |

Worked example, estimated: a regulatory question that plans with `gpt-5-nano` (1,000 tokens in,
200 out), reranks and answers with `gpt-5-mini` (two calls, 8,000 tokens in and 1,000 out in
total) costs about 0.0036 — roughly 3.6 per thousand questions. Indexing a corpus of a few
thousand pages through the embedding deployment adds cents.

## What the posture costs elsewhere

| Posture | Fixed cost per month, estimated | Source |
|---|---|---|
| As deployed: identity boundary, public endpoints | ≈ 70–77 | this document |
| Network-isolated: private endpoints, zones, Premium registry, jump host | ≈ 163 more | ADR-002 |
| Network-isolated with a point-to-site VPN gateway instead of a jump host | ≈ 257 more | ADR-002 |

## How cost is attributed

Every resource carries a `repo` tag, so Cost Management can split the subscription bill by
repository even where a resource is shared. The query that produces the measured figure for this
group, to run after at least one full day of data:

```bash
az rest --method post --only-show-errors -o tsv --query "properties.rows" \
  --url "https://management.azure.com/subscriptions/$(az account show --query id -o tsv)/resourceGroups/rg-aiplatform-shared-swc/providers/Microsoft.CostManagement/query?api-version=2026-08-01" \
  --body '{"type":"ActualCost","timeframe":"Custom","timePeriod":{"from":"2026-10-15T00:00:00Z","to":"2026-10-25T23:59:59Z"},"dataset":{"granularity":"None","aggregation":{"totalCost":{"name":"Cost","function":"Sum"}},"grouping":[{"type":"Dimension","name":"ServiceName"}]}}'
```

Token usage per deployment per day comes from the first query in `monitoring/queries.kql`,
which reads the `AzureOpenAIRequestUsage` log the diagnostic setting routes to the workspace.

## Measured cost

Measured on 2026-10-26 with the query above, over the eleven full days from 15 to 25 October
2026 (the estate was first deployed on 2026-10-14):

| Service | Measured, 11 days (EUR) |
|---|---|
| AI Search | 23.47 |
| Foundry Models, token usage of the three deployments | 8.46 |
| Foundry Tools, Document Intelligence | 6.22 |
| Container Registry | 1.61 |
| Log Analytics, Azure Monitor | 0 |
| **Total** | **39.76** |

A day without model usage cost 2.28 (2.13 search, 0.15 registry), in line with the ≈ 2.3
estimated above; the rest is model and tool usage billed to the shared Foundry account.

## Keeping the bill at zero between demos

`make destroy` runs `azd down --force --purge`, which removes every resource in the group and
purges the soft-deleted Foundry account so the name can be reused. The resource group itself
survives, as the bootstrap intends. Redeploying takes about ten minutes and costs nothing until
the search service's first hour.
