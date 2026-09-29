# Architecture decision records

One section per decision: context, options, decision, trade-offs, revisit when. Numbers are stable.

## ADR-001 Hub-and-spoke network

**Context.** Four workloads in separate repositories share one Foundry account and one AI Search
service, and each brings private data services of its own. P03 processes health data and P04 is
multi-tenant, so a compromise in one workload must not give network reach into another. Everything
runs in one subscription in Sweden Central.

**Options.**
1. One shared virtual network with a subnet per workload.
2. One isolated virtual network per workload, each with its own private endpoints to the shared
   services and its own private DNS zones.
3. Hub-and-spoke with virtual network peering: shared private endpoints and DNS in the hub, one
   spoke per workload.
4. Azure Virtual WAN with a managed virtual hub.

**Decision.** Option 3. This repository owns the hub, `10.0.0.0/16`, which holds the private
endpoints of the shared services and every private DNS zone. Each workload repository owns a `/16`
spoke from the address plan and peers it to the hub.

**Trade-offs.** Peering is not transitive, so spokes cannot reach each other: the isolation P03 and
P04 need, with no firewall rule to maintain. A spoke creates both halves of its peering, so its
deployment identity needs write access to the hub network. With no gateway or firewall in the hub
there is no central egress inspection (ADR-006). Option 1 ties four release cadences to one
resource and reduces isolation to NSG discipline. Option 2 duplicates endpoints and zones per
workload, which is where split DNS starts (ADR-004). Option 4 adds an hourly hub charge for
routing features that four spokes without transit traffic do not use.

**Revisit when.** Spokes need to talk to each other, on-premises or cross-region connectivity
arrives, or the number of spokes makes hand-managed peering error-prone — then Azure Virtual
Network Manager or Virtual WAN.

## ADR-002 DataZone Standard in the EU zone, not Global Standard

**Context.** The workloads send EU regulatory and health content to the models. For every Foundry
deployment type, data at rest stays in the resource's geography; what differs is where inference
runs. Global types may process a request in any Azure region, Data Zone types only within the
Microsoft-specified zone of the resource (EU for Sweden Central), and regional Standard within the
Azure geography.

**Options.**
1. Global Standard — highest default quota, first access to new models.
2. DataZone Standard — pay-per-token, inference confined to the EU data zone.
3. Regional Standard — not offered for `gpt-5-mini`, `gpt-5-nano` or `text-embedding-3-small`
   in Sweden Central.
4. DataZone Provisioned — reserved throughput, billed whether or not it is used.

**Decision.** Option 2 for all three deployments. Embeddings follow the chat models: chunks of the
same documents are sent to them, so the same boundary applies. Deployments pin their model version
and upgrade only when it expires (`OnceCurrentVersionExpired`), which keeps evaluation baselines
comparable until retirement instead of failing on it.

**Trade-offs.** New models reach Global first, then Data Zone. Quota is separate and smaller: the
target subscription started with 500 K tokens per minute of Global Standard quota for `gpt-5-mini`
and none of DataZone Standard for either chat model, so the first deployment waited on a quota
request — ARM preflight rejects any deployment above quota. Option 1 would have skipped that wait
and offers no control over where a prompt is processed.

**Revisit when.** Demand outgrows DataZone quota (option 4), a workload needs a model that has no
Data Zone offer, or a contract requires processing within Sweden rather than within the EU.

## ADR-003 Managed identity instead of keys

**Context.** Four workloads call shared services. An API key is a shared secret with full data-plane
power: it cannot say who called, it cannot be scoped to one project or index, and every copy must
be rotated when one leaks.

**Options.**
1. Keys, stored in each workload's Key Vault and rotated on a schedule.
2. Entra ID only: managed identities with role assignments, local authentication disabled.
3. Entra ID for workloads, keys for service-to-service calls.

**Decision.** Option 2. Foundry and Log Analytics run with `disableLocalAuth: true`, Search accepts
only RBAC, and the registry's admin user is disabled. Service-to-service calls use system-assigned
identities — Search reaches the Foundry embedding deployment with its own identity. Each workload
repository grants its own identities the roles it needs on its own scope: Foundry User on its
project, index roles on Search, `AcrPull` on the registry.

**Trade-offs.** Every caller, including a developer's workstation, needs a role assignment before
the first call, and new assignments take a few minutes to propagate. Callers are attributable in
the logs, and removing one role assignment revokes one caller without touching the others. There is
no break-glass key; re-enabling local authentication is a reviewed change to this repository.

**Revisit when.** A required integration accepts only keys — give it a dedicated resource rather than
enabling local authentication on a shared one.

## ADR-004 Private endpoints with DNS owned by the hub

**Context.** The workloads handle EU regulatory and health content, so data-plane traffic to Azure
services must stay off public endpoints. A private endpoint works only if clients resolve the
service's public name to the endpoint's private IP, which Azure does through `privatelink.*`
private DNS zones. When two teams create the same zone, each copy holds only its own records, and a
client linked to the wrong copy resolves to the public IP — which fails once public access is
disabled. Split zone ownership is the most common cause of private endpoint resolution failures in
hub-and-spoke designs.

**Options.**
1. Service endpoints and service firewalls instead of private endpoints.
2. Private endpoints, with each workload creating the zones it needs.
3. Private endpoints, with every zone owned by the hub and linked into each spoke.
4. Option 3 plus Azure DNS Private Resolver in the hub, used by the spokes as their DNS server.

**Decision.** Option 3. The hub creates the fourteen zones the portfolio needs and exports their
IDs. A spoke links each zone it uses to its own virtual network and points its private endpoints'
DNS zone groups at the hub's zone IDs; it never creates a `privatelink.*` zone. Shared services set
`publicNetworkAccess: Disabled`, so the private endpoint is their only data-plane path.

**Application Insights exception.** Azure Monitor's private path is an Azure Monitor Private Link
Scope (AMPLS), and this landing zone deploys none. An AMPLS rewrites DNS for Azure Monitor endpoints
in every network that shares the DNS, a network can connect to only one AMPLS, and its Private Only
mode blocks every Application Insights resource outside the scope — for all four workloads at once.
Workloads therefore send telemetry to public ingestion endpoints with Entra ID authentication, and a
workload that restricts egress must allow those FQDNs or lose observability
([security.md](security.md)). Diagnostic settings are unaffected: Azure Monitor delivers them to
Log Analytics over its own private channel.

**Trade-offs.** Spokes need write access to the hub's zones to create their links. A new service
type needs its zone added here before any workload can use it. Option 1 keeps services on public IP
addresses and does not exist for AI Search, PostgreSQL, Redis, Event Grid or Azure Machine Learning.
Option 4 adds a resolver that is only needed when clients outside Azure must resolve these zones.

**Revisit when.** On-premises or partner networks must resolve the zones (option 4); telemetry must
stay private, or egress is forced through a firewall that cannot allow the ingestion FQDNs (one
AMPLS, owned by the hub); a workload adopts a service type with no zone here (add it).

## ADR-005 Rejected: a Premium registry behind a private endpoint

**Context.** The four workloads push and pull images from one shared registry. Every other shared
service is reachable only through a private endpoint (ADR-004), but Container Registry offers
private endpoints only on the Premium tier.

**Options.**
1. Basic with a public endpoint, the admin user disabled and pulls authorised by `AcrPull`.
2. Premium with a private endpoint and public network access disabled.
3. One Basic registry per workload.

**Decision.** Option 1. Premium is rejected at this scale.

| Sweden Central retail, September 2026 | Unit price | Per month |
|---|---|---|
| Basic registry | €0.1431 per day | €4.35 |
| Premium registry | €1.431 per day | €43.53 |
| Private endpoint | €0.0086 per hour | €6.28 |

Private access would cost €49.81 a month instead of €4.35 — ten times Basic for the registry alone,
eleven with its endpoint — to shield a registry whose images carry code, not customer data.

**Trade-offs.** The registry answers on the internet, so anyone can attempt to authenticate; the
attempts are logged in `ContainerRegistryLoginEvents`, surfaced by the `FailedAuthentications`
query, and succeed only with an Entra token for an identity holding a registry role — there is no
admin user or anonymous pull. Basic has no geo-replication, dedicated data endpoints, customer-managed
keys or retention of untagged manifests, and includes 10 GiB of storage. A spoke that restricts
egress must allow the registry's login server and data endpoint ([security.md](security.md)).
Option 3 buys repository isolation that repository-scoped permissions give inside one registry.

**Revisit when.** A workload must pull with no internet egress at all, images outgrow 10 GiB, or
workloads must be confined to their own repositories — which means switching the registry to
repository-scoped (ABAC) permissions, where `AcrPull` is no longer honoured and repository roles
replace it.

## ADR-008 One Foundry project per agent workload

**Context.** P01 and P02 build agents with Microsoft Agent Framework's `FoundryChatClient`, which
targets a project endpoint, and publish their evaluation runs to that project. P03 and P04 call
models but run no agents. A project is a child of the Foundry account: it shares the account's model
deployments and private endpoint, and has its own identity, access boundary and evaluation history.

**Options.**
1. One project shared by every workload.
2. One project per workload, four in total.
3. One project per agent workload: `proj-ragplatform` for P01, `proj-fopcopilot` for P02.
4. One Foundry account per workload.

**Decision.** Option 3. Each agent workload repository grants its own identity the Foundry User role
(formerly Azure AI User) on its own project and nothing on the other. P03 and P04 call the account's
deployments with Cognitive Services OpenAI User and get no project.

**Trade-offs.** Option 1 mixes two evaluation histories and makes a grant on the project a grant on
both workloads' agents. Option 2 adds two empty projects, each with an identity, diagnostic setting
and role assignments to review, for workloads with nothing to put in them. Option 4 duplicates the
private endpoint, guardrail and deployments without adding capacity: model quota is per subscription,
region and model, so separate accounts split it rather than grow it. Grants on the account cover all
of its deployments; there is no per-deployment role scope.

**Revisit when.** P03 or P04 adopts agents or evaluation runs — add one entry to the project map in
`foundry.bicep` — or a workload needs capacity isolated from the others.
