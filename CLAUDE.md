# CLAUDE.md

Working agreement for AI-assisted changes. Re-read this file at the start of every phase.

## Repository

Shared Azure foundation for four AI workloads: P01 rag-platform, P02 field-operations-copilot,
P03 care-intelligence-platform, P04 ai-saas-platform. Infrastructure as code, monitoring assets
and documentation only — no application code. Readers judge it on correctness and restraint.

## Rules of engagement

- **Never run a git command** (`add`, `commit`, `branch`, `push`, `tag`, anything). The author commits.
- `az`, `azd` and shell tooling are allowed.
- Verify every resource type, API version and property name against Microsoft Learn and
  `az provider show` before writing it. Never write an API version or property from memory.
- Private DNS zone names come only from the Learn page *Azure Private Endpoint private DNS zone
  values*. A changed name is used as documented and noted in the README.
- At the end of each phase print the block below exactly, then wait for "continue".

```
── PHASE n COMPLETE ──
Files: <n>/24   Bicep lines: <n>/750
Verified: az bicep build ✓  az bicep lint ✓
Commit with:
  git add <paths>
  git commit -m "<message>"
Say "continue" for phase n+1.
```

## Non-negotiable constraints

1. **No identity leakage.** No subscription, tenant, object or principal IDs, email addresses, real
   endpoint hostnames or account names. Placeholders: `00000000-0000-0000-0000-000000000000`,
   `<SUBSCRIPTION_ID>`. Derive identifiers from `subscription()`, `tenant()`, `resourceGroup()` or
   module outputs. The alert email arrives at deploy time through `ALERT_EMAIL_ADDRESS`.
2. **No secrets.** Managed identity everywhere; `disableLocalAuth: true` wherever supported.
3. **Budget.** ≤ 24 tracked files, ≤ 750 lines of Bicep (`.bicep` + `.bicepparam`), zero Python,
   directory depth ≤ 2. If a change would exceed a limit, remove something and say what.
4. **Comments.** `@description` on every parameter and output. Inline comments only for
   non-obvious decisions, one line maximum, never restating code.
5. **Loops over repetition.** The fourteen DNS zones and their VNet links are one `for` each.
6. **English only. Nothing unfinished** — no TODO, unused parameter or uncalled module.

## File plan — 23 files

```
README.md  LICENSE  .gitignore  CLAUDE.md  azure.yaml  Makefile
infra/main.bicep  infra/main.bicepparam
infra/modules/{network,dns,monitoring,foundry,search,registry,governance,private-endpoint}.bicep
monitoring/queries.kql  monitoring/workbook.json
docs/{adr,cost,security}.md
.github/workflows/{validate,deploy}.yml
```

Deviations from the requested 32-file layout, made to fit the 24-file budget:

- `docs/adr/001..008-*.md` → `docs/adr.md`, one section per ADR, same numbering.
- `infra/modules/role-assignment.bicep` removed. Role assignments are resource-scoped, which Bicep
  expresses only through a typed resource reference; a generic module would widen scope to the
  resource group. Grants live next to the resource they target.
- `docs/architecture.md` removed. The README is the architecture document; a copy would drift.

## Verification

- `make build lint` must pass. `--only-show-errors` hides linter warnings and `az bicep lint`
  exits 0 on warnings, so the lint gate fails on any `ruleId` in the SARIF output.
- `make what-if` against the target subscription before a phase touching `main.bicep` closes.
- Grep checks from the definition of done are run from the repo root with `--exclude-dir=.git`.

## Naming, region and tags

Region `swedencentral`, abbreviation `swc` in every regional name including resource groups.
Global resources (action group, budget, DNS zones, policy assignments) have no region and no suffix.

| Resource | Name |
|---|---|
| Resource groups | `rg-aiplatform-hub-swc`, `rg-aiplatform-shared-swc` |
| Hub VNet / subnet | `vnet-aiplatform-hub-swc` 10.0.0.0/16 / `snet-privatelink` 10.0.1.0/24 |
| Log Analytics | `log-aiplatform-shared-swc` (30-day retention) |
| Foundry account / projects | `fdry-aiplatform-shared-swc` / `proj-ragplatform`, `proj-fopcopilot` |
| AI Search | `srch-aiplatform-shared-swc` (Basic, 1 replica, 1 partition) |
| Container Registry | `craiplatformsharedswc` (Basic, admin user disabled) |
| Action group / budget | `ag-aiplatform-shared` / `budget-aiplatform-monthly` (40/80/100 %) |

Tags on every resource: `workload`, `env`, `owner: 'portfolio'`, `managedBy: 'bicep'`,
`repo: 'azure-ai-landing-zone'`.

## Fixed design decisions

- Hub-and-spoke. The hub owns all fourteen private DNS zones; spokes link to them, never create
  their own. Only the hub VNet is created; spoke address plans are documented.
- Foundry: kind `AIServices`, S0, custom subdomain, public network access disabled, local auth
  disabled, project management enabled. `gpt-5-mini` and `gpt-5-nano` on DataZone Standard (EU),
  `text-embedding-3-small` per current availability, guardrail on chat deployments.
- Projects only for agent workloads: P01 `proj-ragplatform`, P02 `proj-fopcopilot`. Each workload
  repo grants its own identity **Azure AI User** on its own project (ADR-008).
- Search: public network access disabled, RBAC-only, system-assigned identity with
  **Cognitive Services OpenAI User** on the Foundry account; Foundry is the billable enrichment resource.
- Private endpoints for Foundry and Search live in the hub RG, in `snet-privatelink`.
- Diagnostic settings to the shared workspace: Foundry `Audit`, `RequestResponse`, `Trace`;
  Search `OperationLogs`; ACR `ContainerRegistryRepositoryEvents`, `ContainerRegistryLoginEvents`;
  all metrics everywhere.
- ACR Basic with public endpoint (Premium for private link ≈ 10× cost; pull is `AcrPull`-bound).
- Application Insights ingestion has no private link path here; egress FQDNs go in `docs/security.md`.
- Policy assignments (subscription scope): require `repo` tag, deny public blob, audit missing
  diagnostic settings. Effects `Audit`/`Deny`/`AuditIfNotExists` only — no policy identity.
- Budget at subscription scope in `governance.bicep`, notifying the action group. Its start date
  is immutable after creation, so it is a fixed parameter, never `utcNow()`. Budgets take no tags.
- Monitoring data: diagnostic settings export metrics without dimensions, and Cognitive Services
  is not supported by DCR metrics export. `queries.kql` uses documented Log Analytics columns only
  (checked with the Kusto analyzer); per-model splits live in `workbook.json` via Azure Monitor
  metrics. Foundry projects need their own diagnostic setting (`Audit`, `Trace`) for
  `RequestsByProject`.
- Open: built-in policy definitions are GUID-named, so the GUID grep will list three public
  built-in IDs. Default: reference built-ins, declared once and named. Role definitions resolve by
  name with `roleDefinitions()` if what-if accepts it.

## `main.bicep` outputs

`hubVnetId`, `hubVnetName`, `privateLinkSubnetId`, `dnsZoneIds` (keyed by zone name),
`foundryEndpoint`, `foundryAccountName`, `foundryResourceId`, `foundryProjectEndpoints` and
`foundryProjectResourceIds` (keys `ragplatform`, `fopcopilot`), `searchEndpoint`,
`searchServiceName`, `searchResourceId`, `registryLoginServer`, `registryName`,
`logAnalyticsWorkspaceId`, `actionGroupId`, `sharedResourceGroupName`, `hubResourceGroupName`.

## Phases

| # | Work | Commit message |
|---|---|---|
| 1 | CLAUDE.md, layout, .gitignore, LICENSE, azure.yaml, Makefile, README skeleton | `chore: scaffold landing zone repository` |
| 2 | network, dns (one loop), private-endpoint, address plan, ADR-001, ADR-004 | `feat(network): hub vnet, centralised private dns and reusable modules` |
| 3 | monitoring, queries.kql, workbook, budget | `feat(monitoring): log analytics, alerting and cost budget` |
| 4 | foundry: account, deployments, guardrail, projects, PE, diagnostics, ADR-002/003/008 | `feat(ai): foundry account, eu data zone deployments and workload projects` |
| 5 | search with role grant and enrichment attachment, registry, ADR-005 | `feat(platform): ai search and container registry` |
| 6 | governance, main.bicep wiring, outputs, main.bicepparam | `feat(governance): policy assignments and deployment orchestration` |
| 7 | workflows, security.md, cost.md, remaining ADRs, final README | `docs: security, cost and deployment documentation` |

## Definition of done

Build and lint clean on every file · what-if succeeds on an empty subscription · five tags on
every resource · Foundry and Search public access disabled and local auth disabled · fourteen
zones from one loop, each linked to the hub · both project endpoints in outputs · within budget
with actual counts · email grep and GUID grep reported · Mermaid valid · no git command run.
