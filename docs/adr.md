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
