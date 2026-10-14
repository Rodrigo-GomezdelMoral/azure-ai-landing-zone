# ADR-005 · Rejection: no Azure Policy assignments at this scale

**Status:** accepted (rejection) · **Date:** 2026-10-14

## Context

The controls this platform relies on are properties of resources: local authentication disabled,
RBAC-only search, no admin user on the registry, five tags on everything. Azure Policy can
enforce the same properties as guardrails — deny a Cognitive Services account that accepts keys,
append missing tags, audit search services that still accept API keys. An earlier version of
this repository assigned three built-in policies for exactly that purpose, and the assignments
were the first thing to break: definition ids that differ by cloud, scope rules that a
subscription-level template needed and a resource-group template does not, and a compliance
evaluation that lagged the deployment by half an hour.

## Options

1. **Assign built-in policies at the subscription**: *Cognitive Services accounts should have
   local authentication methods disabled*, *Azure AI Search services should have local
   authentication methods disabled*, *Container registries should have the admin account
   disabled*, plus a tag policy with the `modify` effect.
2. **Assign the same policies at the shared resource group only**, so the template keeps its
   group scope and the CI principal needs `Resource Policy Contributor` on the group.
3. **Assign nothing.** Enforce the properties in the template and prove them with `what-if` and
   a post-deployment check; record the policy design so it exists when there is an organisation
   to apply it to.

## Decision

Option 3. Policy is a governance instrument: it exists to constrain **other people's**
templates, across subscriptions a platform team does not author. In this estate one person
writes every template, every template is reviewed in a pull request that runs `what-if`, and the
properties a policy would check are literally the lines of Bicep under review. A policy
assignment here would check the author's work against the author's own rule, add a third
principal permission, and produce compliance data nobody reads — governance theatre, with a
real maintenance cost (a definition id is a GUID that changes between clouds, and the hygiene
rule of this portfolio forbids committing GUIDs that are not public constants).

What is kept from the idea:

- The **invariants are still enforced**, by the resource definitions themselves, and verified by
  the definition-of-done checks in the README (local authentication disabled on Foundry and
  Search, admin user disabled, tags present).
- The **policy design is written down** here so the day it is needed it is a half-hour task:
  the three built-in definitions above with `Deny`, a tag initiative with `Modify` for the five
  tags, assigned at the subscription by a platform team identity, with the four workload groups
  as the scope and the CI principals untouched.

## Trade-offs

- A template change that re-enables a key would pass `what-if` unremarked. The pull request
  review is the control, and it depends on the reviewer reading the diff.
- Nothing stops a resource created by hand in the portal from violating the posture. Nothing is
  created by hand in this estate; the moment that stops being true is a revisit condition.
- The portfolio does not demonstrate Azure Policy authoring. That gap is stated rather than
  filled with a token assignment.

## Revisit when

A second person or team can create resources in the subscription, or the workloads move to
subscriptions the author does not own. Policy becomes the right tool exactly when the template
review stops being the only path to a resource.
