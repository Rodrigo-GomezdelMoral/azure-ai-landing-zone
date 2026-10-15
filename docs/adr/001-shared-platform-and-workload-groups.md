# ADR-001 · One shared platform group, one group per workload

**Status:** accepted · **Date:** 2026-10-14

## Context

Four AI workloads — a regulatory RAG platform, a field-operations copilot, a care-intelligence
MLOps pipeline and a multi-tenant SaaS gateway — need model deployments, a vector index, a
container registry and monitoring. Each is a separate public repository with its own deployment
identity, its own lifecycle and its own `azd down` at the end of a demo cycle.

The question is where the expensive, slow-to-recreate or quota-bound resources live, and what
each repository is allowed to touch.

## Options

1. **Everything per workload.** Each repository provisions its own Foundry account, search service
   and registry. Simplest ownership; four AI Search services at roughly €70 a month each, four
   sets of model quota, four registries, and no way to compare workloads on one bill.
2. **One group for the whole portfolio.** Everything in `rg-aiplatform-swc`. Cheapest and
   simplest, but `azd down` in one repository would destroy the index of another, and the CI
   principal of every repository would need write access to every resource.
3. **One shared group plus one group per workload.** The shared group holds what is expensive,
   quota-bound or consumed by more than one workload. Each workload group holds what that
   workload owns and may destroy freely.

## Decision

Option 3. Five resource groups, created once by a bootstrap script and never by a template:

| Group | Holds | Owned by |
|---|---|---|
| `rg-aiplatform-shared-swc` | Log Analytics, Foundry account and project, model deployments, AI Search, Container Registry, action group, budget | this repository |
| `rg-ragplatform-prod-swc` | storage, Cosmos DB, Container Apps, identities, workload role assignments | `azure-rag-platform` |
| `rg-fopcopilot-prod-swc` | the same shape plus Event Grid | `azure-field-operations-copilot` |
| `rg-careintel-prod-swc` | Azure ML workspace, PostgreSQL, API | `azure-care-intelligence-platform` |
| `rg-aisaas-prod-swc` | AKS, Redis, Cosmos DB, Service Bus, Functions, Key Vault | `azure-ai-saas-platform` |

The rule for placement: **a resource lives in the shared group if destroying it would break a
workload other than the one that created it, or if it carries a quota or a fixed cost that should
be paid once.** Everything else lives with its workload.

Consequences that follow from the rule:

- Every template targets `resourceGroup` scope. No template creates groups, so no deployment
  identity needs subscription-level rights; each CI principal is Contributor on its own group
  and Role Based Access Control Administrator on the shared group, which is the narrowest grant
  that still lets a workload assign roles on the shared Foundry and Search resources.
- Role assignments that cross groups live with the **grantee's** workload, not here. The search
  service's read access to a workload's storage account is declared in that workload's template,
  which is why this repository exports `searchPrincipalId`.
- Cost attribution does not depend on groups. Every resource carries a `repo` tag, so Cost
  Management can split the bill by repository even where resources are shared.

## Trade-offs

- A workload cannot be deployed into an empty subscription on its own; the shared group must
  exist first. The dependency is explicit and one-directional.
- One Foundry project is shared. Evaluation runs from different workloads land in one history;
  the day that becomes confusing, a project per workload is a ten-line change and one extra role
  assignment each.
- Shared quota. A runaway workload can consume the model deployment's tokens-per-minute for the
  others. Acceptable at portfolio scale; in production each workload would get its own deployment
  on the same account.

## Revisit when

A second team owns one of the workloads, or any workload needs a model, a search tier or a
region the others do not. At that point the shared group splits along team lines, and this
document records why it was single until then.
