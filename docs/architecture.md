# Architecture

The landing zone is one resource group, `rg-aiplatform-shared-swc`, holding the resources that
are expensive, quota-bound or consumed by more than one workload. Four workload groups consume
it through the deployment outputs; nothing in the shared group knows a workload exists.

## Estate

```mermaid
graph TB
    subgraph shared["rg-aiplatform-shared-swc · Sweden Central"]
        direction TB
        FDRY["fdry-aiplatform-shared-swc<br/>Foundry account · AIServices S0<br/>disableLocalAuth · public endpoint"]
        PROJ["proj-aiplatform-shared<br/>Foundry project · system identity"]
        DEP["gpt-5-mini · gpt-5-nano · text-embedding-3-small<br/>GlobalStandard · NoAutoUpgrade"]
        RAI["guardrail-chat<br/>content filters on the two chat deployments"]
        SRCH["srch-aiplatform-shared-swc<br/>AI Search Basic · RBAC only · system identity"]
        ACR["craiplatformsharedswc<br/>Container Registry Basic · no admin user"]
        LOG["log-aiplatform-shared-swc<br/>Log Analytics · 30 days · no local auth"]
        AG["ag-aiplatform-shared<br/>action group · email"]
        BUD["budget-aiplatform-monthly<br/>40 / 80 / 100 %"]
        FDRY --- PROJ
        FDRY --- DEP
        RAI -.applies to.-> DEP
        SRCH -->|"Cognitive Services OpenAI User<br/>Cognitive Services User"| FDRY
        FDRY -. diagnostics .-> LOG
        SRCH -. diagnostics .-> LOG
        ACR -. diagnostics .-> LOG
        BUD --> AG
    end
    WL["Workload groups<br/>rg-ragplatform · rg-fopcopilot · rg-careintel · rg-aisaas"]
    WL -->|"Foundry User · OpenAI User"| FDRY
    WL -->|"Search Index Data Reader<br/>Search Service Contributor"| SRCH
    WL -->|"AcrPull · AcrPush"| ACR
    WL -. "Application Insights" .-> LOG
    SRCH -->|"Storage Blob Data Reader,<br/>granted in the workload group"| WL
```

## The interface: deployment outputs

A workload never discovers shared resources by name. It receives the seventeen outputs of
`infra/main.bicep` as parameters, declares the shared resources as `existing`, and scopes its
cross-group role assignments to `sharedResourceGroupName`.

| Output | Type | Used for |
|---|---|---|
| `foundryEndpoint` | URL | Azure OpenAI and Foundry Tools calls from application code |
| `foundryProjectEndpoint` | URL | Foundry SDK clients, evaluations and traces |
| `foundryAccountName`, `foundryResourceId`, `foundryProjectName` | names and id | `existing` references and role assignment scopes |
| `chatDeploymentName`, `smallChatDeploymentName`, `embeddingDeploymentName` | names | the only model identifiers application code holds |
| `searchEndpoint`, `searchServiceName`, `searchResourceId` | URL, name, id | search clients and Search data-plane roles |
| `searchPrincipalId` | object id | `Storage Blob Data Reader` for the indexer on each workload's own container |
| `registryLoginServer`, `registryName` | name | image references and `AcrPull` |
| `logAnalyticsWorkspaceId`, `actionGroupId` | ids | workspace-based Application Insights and alert routing |
| `sharedResourceGroupName` | name | the `scope` of modules that grant roles on shared resources |

## Identity flows

Every arrow in the diagram is a role assignment on a managed identity or an operator account;
no arrow is a key. The three flows a reviewer should be able to trace:

1. **Indexing.** A workload's indexer runs inside the shared search service. The search identity
   reads blobs with `Storage Blob Data Reader` (granted in the workload group), calls the
   embedding deployment with `Cognitive Services OpenAI User`, and bills built-in skills with
   `Cognitive Services User` (both granted here, in `infra/modules/search.bicep`).
2. **Inference.** A workload's container identity calls the project endpoint with `Foundry User`
   and the account endpoint with `Cognitive Services OpenAI User`, granted by the workload's own
   template through a module scoped to this group.
3. **Deployment.** The GitHub Actions principal of this repository holds Contributor and Role
   Based Access Control Administrator on this group only, and authenticates with OpenID Connect.

## Deployment flow

```mermaid
sequenceDiagram
    participant Dev as Operator
    participant GH as GitHub Actions
    participant RG as rg-aiplatform-shared-swc
    Dev->>RG: bootstrap once: create the group, grant the CI principal, assign operator data-plane roles
    Dev->>GH: pull request
    GH->>GH: az bicep build · az bicep lint
    GH->>RG: OIDC login · az deployment group what-if
    Dev->>GH: merge, then run deploy (environment: production)
    GH->>RG: OIDC login with the environment subject · az deployment group create
    RG-->>Dev: outputs, exported with azd env get-values to a file outside git
```

Locally the same flow is `make whatif`, `make deploy` and `make outputs`, which wrap
`az deployment group what-if`, `azd provision` and `azd env get-values`.

## What is deliberately absent

| Not deployed | Where the decision is recorded |
|---|---|
| Virtual network, private endpoints, private DNS zones | ADR-002 |
| Key Vault | ADR-003: there is no secret to store |
| Azure Policy assignments | ADR-005 |
| Container Registry Premium and its private link | ADR-006 |
| A second Foundry project per workload | ADR-001 |
| Workbooks or dashboards | `monitoring/queries.kql` holds the five queries as portable text |
