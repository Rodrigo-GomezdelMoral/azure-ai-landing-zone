# Security

What this landing zone enforces, what it leaves to the workload repositories, and the risks it
accepts. Decisions are argued in the [ADRs](adr.md); this page states their consequences.

## Network

| Service | Public network access | Path from a spoke |
|---|---|---|
| Foundry account and projects | Disabled | Hub private endpoint, three `privatelink` zones |
| AI Search | Disabled | Hub private endpoint, `privatelink.search.windows.net` |
| Container Registry | Enabled — Premium needed for private link (ADR-005) | Internet, Entra token required |
| Log Analytics | Enabled — no Azure Monitor Private Link Scope (ADR-004) | Internet, Entra token required |

Two service-to-service paths cross the Foundry account's closed front door:

- **Integrated vectorisation.** AI Search calls the embedding deployment as a trusted Azure service
  (`networkAcls.bypass: AzureServices`), authenticated by its managed identity and authorised by its
  role assignment. The bypass admits only listed Azure services, and only callers with a role on the
  account get past authorisation.
- **Enrichment billing.** AI Search reaches Foundry through a shared private link. It stays
  `Pending` until approved on the Foundry side; `make approve-links` approves only the request whose
  message names this search service, and the deploy workflow runs it after every deployment.

## Egress a network-isolated workload must allow

This landing zone has no firewall (ADR-006). A workload that restricts its own egress must allow the
following on port 443, or it loses observability or image pulls.

| Purpose | Destinations |
|---|---|
| Application Insights telemetry | `dc.applicationinsights.azure.com`, `dc.applicationinsights.microsoft.com`, `dc.services.visualstudio.com`, and the regional `{region}.in.applicationinsights.azure.com` named in the connection string's `IngestionEndpoint` |
| Application Insights Live Metrics | `live.applicationinsights.azure.com`, `rt.applicationinsights.microsoft.com`, `rt.services.visualstudio.com`, `{region}.livediagnostics.monitor.azure.com` |
| Container Registry | `<registry>.azurecr.io` and `*.blob.core.windows.net` |

The registry's data endpoint is the weakest line: Basic has no dedicated data endpoints, so the rule
must allow every blob storage account in Azure, not only the registry's. Diagnostic settings are not
affected by any of this; Azure Monitor delivers them over its own channel.

## Identity

- No shared keys. Local authentication is disabled on Foundry, AI Search and Log Analytics; the
  registry has no admin user and Basic offers no anonymous pull. Every call carries an Entra token.
- Service identities are system-assigned and receive only the roles in the README's
  [identity table](../README.md#identity-and-rbac).
- The deployment identity needs, at subscription scope, **Contributor**, **Resource Policy
  Contributor**, and **Role Based Access Control Administrator** conditioned to assign only
  Cognitive Services OpenAI User and Cognitive Services User. Owner works but grants far more.
- GitHub Actions authenticate with OIDC; there is no client secret. The workflows never enable
  shell tracing or echo identifiers, and every `az` call runs with `--only-show-errors`.

## Governance

| Assignment | Effect | Consequence |
|---|---|---|
| `require-repo-tag` | Deny | Untagged resources are rejected anywhere in the subscription. |
| `deny-public-blob` | Deny | Storage accounts must set `allowBlobPublicAccess: false`. |
| `audit-diagnostic-settings` | AuditIfNotExists | The shared services and the workloads' data stores are flagged until they send logs and metrics. |

The tag rule also denies resources that Azure creates on a workload's behalf without tags. Network
Watcher is the first to meet it: Azure enables `NetworkWatcher_{region}` in `NetworkWatcherRG`
automatically when a virtual network is created. Grant a policy exemption on that resource group,
or on a workload's managed resource group, rather than weakening the assignment. No assignment uses
`DeployIfNotExists` or `Modify`, so none needs a managed identity.

## Data

- Model inference runs inside the EU data zone and data at rest stays in the Sweden geography
  (ADR-002).
- The `guardrail-chat` policy on both chat deployments blocks hate, sexual, self-harm and violence
  content from Medium severity in prompts and completions, runs the jailbreak and indirect-attack
  shields on prompts, blocks protected text and annotates protected code.
- Logs are kept for 30 days in one workspace. The query audit log records who queried it.

## Accepted risks

| Risk | Why it is accepted | Revisit |
|---|---|---|
| Registry reachable from the internet | Images carry code, not data; access needs a registry role | ADR-005 |
| Egress uninspected, registry rule opens all blob storage | A firewall would cost 8.5 times the platform | ADR-006 |
| Application Insights ingestion over public endpoints | A private link scope would rewrite DNS for every workload | ADR-004 |
| One search replica, no SLA | Two replicas are needed for a query SLA, three with indexing | [cost.md](cost.md) |
