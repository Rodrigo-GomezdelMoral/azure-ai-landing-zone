# Security posture

**Identity is the security boundary.** Every service in the shared group accepts Microsoft Entra
tokens only, so a public endpoint is not an unauthenticated endpoint: a request without a token
carrying an explicitly assigned role is rejected at the service, before any data is touched. The
network is a cost and operations decision, designed and costed in ADR-002 and not deployed.

## Authentication surface

| Service | Local authentication | How it is disabled | Who can call it |
|---|---|---|---|
| Foundry account and project | account keys | `disableLocalAuth: true` | principals with `Cognitive Services OpenAI User`, `Cognitive Services User` or `Foundry User` |
| AI Search | admin and query keys | `disableLocalAuth: true`, no `authOptions` | principals with a Search data-plane role |
| Container Registry | admin user, anonymous pull | `adminUserEnabled: false`; anonymous pull never enabled | principals with `AcrPull` or `AcrPush` |
| Log Analytics | workspace shared key | `features.disableLocalAuth: true` | Azure Monitor pipelines; readers with `Log Analytics Reader` |
| Action group, budget | none | not applicable | Azure Monitor and Cost Management |

ADR-003 records why keys are disabled rather than vaulted, and what RBAC-only means for Search.

## Identities and grants

| Principal | Role | Scope | Reason |
|---|---|---|---|
| AI Search system-assigned identity | Cognitive Services OpenAI User | Foundry account | the embedding skill and vectorizer call `text-embedding-3-small` keylessly |
| AI Search system-assigned identity | Cognitive Services User | Foundry account | keyless billing of built-in skills attached to a skillset |
| GitHub Actions principal of this repository | Contributor, Role Based Access Control Administrator | this resource group | deploy the template, including its two role assignments; no permission outside the group |
| GitHub Actions principal of each workload | Role Based Access Control Administrator | this resource group | grant their own identities roles on Foundry, Search and the registry |
| Operator account | Search Service Contributor, Search Index Data Contributor, Cognitive Services OpenAI User, Foundry User | Search service, Foundry account | create indexes and run local tests from a laptop; subscription ownership does not confer data-plane access |
| Foundry project system-assigned identity | none | — | reserved for project-side connections; no grant is needed for the workloads' use |

Grants to workload identities live in the workload repositories, next to the identity that
receives them, through a module scoped to this group. This repository only exports what those
modules need: resource ids and `searchPrincipalId`.

## Deployment identity

The CI principal authenticates with OpenID Connect; no client secret exists anywhere. Three
federated credentials are required, one per subject GitHub sends: `ref:refs/heads/main`,
`pull_request`, and `environment:production`, because a job that declares an environment sends
the environment subject rather than the branch subject and fails with `AADSTS700213` otherwise.
Each subject is in GitHub's immutable form, `repo:<owner>@<owner id>/<repo>@<repository id>:…`,
which is what repositories created after 15 July 2026 send; it binds the trust to the repository's
identity rather than to its name, so a renamed or re-created repository of the same name cannot
assume the role (README, *Federated credentials*).
The workflows never print `AZURE_CLIENT_ID`, `AZURE_TENANT_ID` or `AZURE_SUBSCRIPTION_ID`, never
enable shell tracing, and pass `--only-show-errors` on every `az` call; the deploy step runs with
`--output none` so deployment outputs, which contain resource ids, never reach a public log.

## Network

No virtual network, private endpoint or private DNS zone exists. Three consequences that a
reviewer should know, rather than discover:

- **Authenticated traffic traverses the public internet** between the workloads, this group and
  the operator's laptop, over TLS. Private link would keep it on the Microsoft backbone; ADR-002
  gives the design, the cost and the operational reason it is not deployed.
- **Application Insights ingestion from the workloads has no private path in this estate.** The
  workloads send telemetry to the public ingestion endpoints of Azure Monitor
  (`*.in.applicationinsights.azure.com`, `*.livediagnostics.monitor.azure.com`); wherever egress is
  restricted, those FQDNs must be allowed. A private ingestion path exists only through an Azure
  Monitor Private Link Scope, which ADR-002 costs together with the other endpoints.
- **Service firewalls are not configured.** `publicNetworkAccess` is `Enabled` with no IP rules,
  because the operator's address changes and the token, not the address, is the control. IP
  allow-lists are the first thing to add if a workload gains a fixed egress address.

## Monitoring as a control

Diagnostic settings on Foundry, Search and the registry send every log category and metric to
the shared workspace. `monitoring/queries.kql` includes a *failed authentications* query that
unions 401 and 403 responses from Foundry and Search with rejected registry logins; it is the
query to run after any suspected credential exposure, and the honest answer it gives is "a token
was presented without a role", because no key exists to be exposed.

## Hygiene rules the repository obeys

- No subscription, tenant, object or principal id and no email address is committed. Deploy-time
  values arrive through `ALERT_EMAIL_ADDRESS`, read from the environment by
  `infra/main.bicepparam`.
- The only GUIDs in the repository are the two built-in role definition ids in
  `infra/modules/search.bicep` (`Cognitive Services OpenAI User`, `Cognitive Services User`).
  They are public Azure constants, identical in every tenant, and a role assignment cannot be
  expressed without them.
- A grep for email addresses matches every Bicep resource declaration, because the
  `type@apiVersion` syntax contains an `@`, and the `uses: owner/action@version` lines of the
  workflows; those are the only matches outside `LICENSE`.
- `.azure/`, `*.parameters.json` and `.env` are ignored; the azd environment that holds the
  subscription id and the alert address never enters git.

## Out of scope

No web application firewall, DDoS plan, Defender for Cloud plan or customer-managed keys. Each
would be a line item without a threat model to justify it at this scale, and ADR-002 states the
condition under which the network controls are revisited.
