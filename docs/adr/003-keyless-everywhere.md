# ADR-003 · Keyless everywhere

**Status:** accepted · **Date:** 2026-10-14

## Context

Every service in this estate can be called with a key: Foundry has two account keys, AI Search
has admin and query keys, the container registry has an admin user, Log Analytics has a shared
key for ingestion, and the workloads' storage and Cosmos accounts have theirs. A key is a
bearer credential with no identity behind it: it cannot be scoped below the whole service, it
does not expire, it does not appear in Entra sign-in logs, and once it reaches a configuration
file or a build log it is copied. ADR-002 makes identity the security boundary of the platform;
that boundary only holds if there is no second door.

## Options

1. **Keys, stored in Key Vault.** The default of most samples. The vault protects the key at
   rest but every consumer still holds it in memory and every rotation is a coordinated change.
2. **Entra tokens for applications, keys kept for operators and tools.** Hybrid. The key path
   stays enabled "just in case" and is the one that leaks, because nobody monitors it.
3. **Entra tokens only, with local authentication disabled at the service.** No key exists to
   leak; every caller is a principal with a role, and every call is attributable.

## Decision

Option 3, enforced by the resource property rather than by convention:

| Service | Property | Effect |
|---|---|---|
| Foundry account | `disableLocalAuth: true` | key-based calls return 401; the Azure OpenAI and Foundry Tools APIs accept bearer tokens only |
| AI Search | `disableLocalAuth: true`, `authOptions` omitted | the admin and query keys stop working on the data plane; see below |
| Container registry | `adminUserEnabled: false`, anonymous pull off | pushes and pulls authenticate through Entra (`AcrPush`, `AcrPull`); repository-scoped tokens are not created |
| Log Analytics | `features.disableLocalAuth: true` | ingestion and query with the workspace key are refused; diagnostic settings and Application Insights do not use it |
| Workload storage accounts | `allowSharedKeyAccess: false` | declared in the workload templates |
| Workload Cosmos DB accounts | `disableLocalAuth: true` | declared in the workload templates; data access is a SQL role assignment |

Key Vault is therefore absent from this repository and from three of the four workloads. A
vault with nothing in it would suggest a secret exists somewhere; the SaaS platform is the one
workload that holds a real secret, and says so.

### What RBAC-only means for AI Search

Search's RBAC mode is stricter than the other services'. With `disableLocalAuth` set, the control
plane still accepts `listAdminKeys`, but the keys it returns are rejected by every data-plane
request, so a leaked key is inert. The consequences that matter operationally:

- The indexer connects to the workload's storage with the **search service's own identity**, which
  needs `Storage Blob Data Reader` on the container; the integrated embedding skill calls Foundry
  with the same identity and `Cognitive Services OpenAI User`; billable built-in skills are
  charged through `Cognitive Services User`. Those three grants replace three connection strings.
- The operator's account needs `Search Service Contributor` to manage indexes and `Search Index
  Data Contributor` to write documents; subscription ownership grants neither, which is why the
  README lists them as prerequisites.
- The portal's Search explorer and the `az search` data-plane commands only work for principals
  holding a Search role. There is no key to paste.

## Trade-offs

- Local development requires `az login` and the roles above; a sample that expects a key does
  not run until it is rewritten for `DefaultAzureCredential`.
- Role propagation takes up to a few minutes after assignment; a first call that fails with 403
  right after deployment is expected and the README says so.
- Third-party tools that only support key authentication cannot connect. None is in use.

## Revisit when

A tool that cannot present an Entra token has to integrate. The narrowest reopening is
per-service: for Search, `authOptions.aadOrApiKey` with `aadAuthFailureMode: http403` keeps
tokens primary while a key exists for one client, and that client's key gets a rotation owner.
