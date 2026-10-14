# CLAUDE.md — working agreement

`azure-ai-landing-zone` is the shared Azure platform that four AI workloads run on. It contains
infrastructure as code, monitoring queries and documentation. No application code, ever.

Re-read this file at the start of every phase.

## Process

- Do not stage, commit or push. The author commits at the end of each phase with the message
  printed in the phase summary.
- At the end of each phase stop and print:

  ```
  ── PHASE n COMPLETE ──
  Files: <n>/20   Bicep lines: <n>/400
  Verified: az bicep build ✓  az bicep lint ✓  what-if ✓
  Commit with:
    git add <paths>
    git commit -m "<message>"
  Say "continue" for phase n+1.
  ```

- Before writing any resource, verify its type, current GA API version and property names against
  Microsoft Learn. Never write an API version from memory. If a property is preview-only, say so
  and choose the GA alternative.
- Run `az bicep build`, `az bicep lint` and `az deployment group what-if` before declaring a phase
  complete. A check that was not executed is not a pass.

## Non-negotiable constraints

1. **No identity leakage.** No subscription, tenant, object or principal ids, no email addresses,
   no real endpoint hostnames anywhere, commit messages included. Derive identifiers from
   `subscription()`, `tenant()`, `resourceGroup()` or a module output. Deploy-time values such as
   the alert address arrive through environment variables, never through a committed file.
2. **No secrets.** Managed identity everywhere; `disableLocalAuth: true` wherever the service
   supports it; no key, connection string or SAS anywhere.
3. **Size budget.** At most 20 tracked files outside `docs/` (the portfolio-wide budget
   convention, which excludes documentation), at most 400 lines of Bicep in total, zero Python,
   directory depth 2.
4. **`targetScope = 'resourceGroup'`.** `rg-aiplatform-shared-swc` already exists. Never create
   it, never deploy at subscription scope.
5. **Comments.** `@description` on every parameter and output. At most three inline comments in
   the whole repository, only where a decision is non-obvious.
6. **English** everywhere. No unfinished-work markers, no unused parameter, no module that is never called.

## The estate

Region `swedencentral`, suffix `swc` in every name, one shared `tags` object on every resource
(`workload`, `env`, `owner`, `managedBy`, `repo`).

| Resource | Name | Notes |
|---|---|---|
| Log Analytics | `log-aiplatform-shared-swc` | 30-day retention |
| Foundry account | `fdry-aiplatform-shared-swc` | `AIServices`, S0, `disableLocalAuth`, public access with Entra only |
| Foundry project | `proj-aiplatform-shared` | system-assigned identity |
| Model deployments | `gpt-5-mini`, `gpt-5-nano`, `text-embedding-3-small` | names equal model names; SKU from `modelDeploymentSku` |
| Guardrail | one `raiPolicy` | applied to both chat deployments |
| AI Search | `srch-aiplatform-shared-swc` | RBAC only, system-assigned identity |
| Container Registry | `craiplatformsharedswc` | Basic, admin user disabled |
| Action group | `ag-aiplatform-shared` | email receiver |
| Budget | `budget-aiplatform-monthly` | resource-group scope, 40/80/100 % |
| Diagnostics | Foundry, Search, ACR | all to the workspace |
| Role assignments | Search identity on the Foundry account | integrated vectorisation |

The decision that shapes the repository: **identity is the security boundary; the network is a
cost and operations decision that is documented (ADR-002) rather than deployed.**

## Outputs of `main.bicep`

`foundryEndpoint`, `foundryAccountName`, `foundryResourceId`, `foundryProjectEndpoint`,
`foundryProjectName`, `chatDeploymentName`, `smallChatDeploymentName`,
`embeddingDeploymentName`, `searchEndpoint`, `searchServiceName`, `searchResourceId`,
`searchPrincipalId`, `registryLoginServer`, `registryName`, `logAnalyticsWorkspaceId`,
`actionGroupId`, `sharedResourceGroupName`.

## Phases

| # | Work | Commit message |
|---|---|---|
| 1 | `CLAUDE.md`, layout, `.gitignore`, `LICENSE`, `azure.yaml`, `Makefile`, README skeleton, ADR-001 | `chore: scaffold platform repository` |
| 2 | `monitoring.bicep`, `queries.kql`, `role-assignment.bicep` | `feat(monitoring): workspace, alerting and cost budget` |
| 3 | `foundry.bicep`, ADR-003, ADR-004 | `feat(ai): foundry account, project and model deployments` |
| 4 | `search.bicep`, `registry.bicep`, `main.bicep`, outputs, `main.bicepparam` | `feat(platform): ai search, container registry and orchestration` |
| 5 | Workflows, `architecture.md`, `security.md`, `cost.md`, ADR-002, ADR-005, ADR-006, README | `docs: security posture, cost model and deployment workflows` |

## Definition of done

- `az bicep build` and `az bicep lint` clean on every file
- `az deployment group what-if -g rg-aiplatform-shared-swc` succeeds and creates nothing unexpected
- Every resource carries all five tags
- Foundry and Search both report local authentication disabled
- The three deployment names equal the model names exactly
- All seventeen outputs exist, `searchPrincipalId` included
- Within budget, with actual file and line counts reported
- No email address outside `LICENSE`; no GUID other than the all-zero placeholder
- The Mermaid diagrams are valid
- Anything that could not be verified without deploying is listed
