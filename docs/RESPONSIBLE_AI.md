# Responsible AI impact assessment

Azure AI Landing Zone's impact assessment follows the sections of the Responsible AI Impact
Assessment Template and the goals of the
[Microsoft Responsible AI Standard](https://www.microsoft.com/ai/principles-and-approach),
together with the responsible AI guidance of the
[Azure Well-Architected Framework](https://learn.microsoft.com/azure/well-architected/) for
[AI workloads](https://learn.microsoft.com/azure/well-architected/ai/responsible-ai). This
repository deploys models and platform services and no application, so the assessment covers
what the platform enforces for the workloads above it and what it leaves to them.

## 1. System information

- **What it is:** one resource group, `rg-aiplatform-shared-swc`, declared in `infra/`: a
  Microsoft Foundry account and project, three model deployments, one guardrail, Azure AI
  Search, a container registry, Log Analytics, an action group and a budget
  ([architecture.md](architecture.md)).
- **Layer of the AI stack:** the platform layer, models and platform services, with no
  application code, prompt, user interface or end user. It decides which models and versions
  exist and which content filters run on them; prompts, grounding, evaluation and the user
  experience belong to the workloads.
- **Who builds on it:** four independent AI workloads, a regulatory RAG platform, a
  field-operations copilot, a patient-risk MLOps platform and a multi-tenant SaaS, each in its
  own resource group with its own deployment identity (ADR-001). They receive the seventeen
  outputs of `infra/main.bicep` as parameters, and never a key.
- **Who operates it:** one platform owner, who approves each deployment in the `production`
  environment and receives the budget notifications (README, *Delivery and DORA*).

## 2. Intended uses

- **Intended use:** give the four workloads model inference, search, an image registry and one
  place for logs, reached with Entra identities and explicitly assigned roles.
- **Stakeholders:** the platform owner; the four workloads; the people who use the workloads,
  whom this layer reaches only through the models and the filters it provides.

**Goals of the Responsible AI Standard that apply:**

- *Impact assessment (A1):* this document, for the platform layer. The use each workload makes
  of the models is outside it.
- *Fit for purpose (A3):* each model has a stated task in `infra/main.bicep`: `gpt-5-mini` for
  answering, reranking and agents, `gpt-5-nano` for query planning and classification,
  `text-embedding-3-small` for vectorisation; SKU availability was verified first (ADR-004).
- *Data governance and management (A4):* access to every service by role only (ADR-003); logs
  kept 30 days; where prompts and completions are processed is one parameter,
  `modelDeploymentSku` (ADR-004); section 4 lists the data held.
- *Human oversight and control (A5):* `deploy.yml` runs by hand and waits for an approval, and
  model versions never upgrade by themselves (`versionUpgradeOption: 'NoAutoUpgrade'`).
- *Communication to stakeholders (T2):* the README, [architecture.md](architecture.md),
  [security.md](security.md), [cost.md](cost.md) and six ADRs state what is deployed, what is
  deliberately absent and each accepted limitation.
- *Failures and remediations (RS2):* `what-if` shows a change before it is applied, the template
  redeploys idempotently, and the *failed authentications* query is the one to run after a
  suspected credential exposure ([security.md](security.md)).
- *Ongoing monitoring, feedback and evaluation (RS3):* Foundry, Search and the registry send
  every log and metric to one workspace; `monitoring/queries.kql` holds five queries (tokens per
  model, requests by application, failed authentications, indexer outcomes, slow operations);
  a monthly budget notifies at 40, 80 and 100 %.

System intelligibility for decision making (T1), disclosure of AI interaction (T3) and quality
of service (F1) need a model output and a person reading it: they belong to each workload.

## 3. Adverse impact

- **Unsupported uses:** direct use by end users; workloads that need private networking, which
  is designed and not deployed (ADR-002); EU-only processing while the SKU stays at its default
  (ADR-004).
- **Known limitations:**
  - The guardrail covers the two chat deployments with one set of thresholds for every
    workload. The embedding deployment is left out of it (`guarded: false`), and the template
    declares no filter for indirect prompt injection and no groundedness detection.
  - `GlobalStandard` is the default SKU, so prompts and completions may be processed outside the
    EU; ADR-004 calls it the wrong default for a regulated customer, by design.
  - Endpoints are public and the token is the only control (ADR-002). No Azure Policy keeps the
    settings in place (ADR-005), and no alert rule watches the logs: only the budget notifies.
  - Capacity and the Foundry project are shared: a burst in one workload throttles the others,
    and evaluation runs of different workloads land in one history (ADR-001).
  - Model versions are pinned and age. The retirement date recorded for the `gpt-5` family
    version in use is 2027-02-09, and the upgrade before it is a manual change (ADR-004).
- **Misuse:** a principal that holds a role can call the models for any purpose, and the
  platform does not know the use case. Roles are assigned explicitly, the guardrail blocks the
  harm categories and jailbreak attempts, and token consumption per model is one query away.
  Each workload's deployment identity holds Role Based Access Control Administrator on the group
  ([security.md](security.md)) and can grant more than it needs; this template does not
  constrain that.

## 4. Data requirements

- **No training or fine-tuning.** The models are deployed as published, with pinned versions;
  the repository holds no dataset: only Bicep, workflows, queries and documentation.
- **In transit:** prompts and completions from the workloads, over TLS on public endpoints. With
  `GlobalStandard` inference may run in any Azure region while data at rest stays in the
  resource's region; with `DataZoneStandard` it stays inside the EU data zone (ADR-004).
- **At rest in the shared group:** the indexes the workloads create in the search service, their
  container images, the evaluation runs and traces of the shared Foundry project (ADR-001), and
  logs and metrics for 30 days. Their content is decided by each workload, not here.
- **Personal data in the repository:** none. The alert address arrives through
  `ALERT_EMAIL_ADDRESS` at deploy time and is never committed ([security.md](security.md)).

## 5. Summary of impact

| Harm | Mitigation | Evidence |
|---|---|---|
| Harmful content accepted or generated by a chat model, jailbreaks included | Hate, sexual, violence and self-harm blocked at medium severity on prompts and completions; jailbreak filter on prompts; protected material filters on completions | `harmFilters`, `shieldFilters` and `guardrail-chat` in `infra/modules/foundry.bicep` |
| A leaked key used against the models, the indexes or the registry | No key exists: local authentication is disabled on every service | ADR-003; [security.md](security.md); the verify commands in the README |
| A model that changes behaviour without notice | Versions pinned with `NoAutoUpgrade` | `infra/main.bicep`, `infra/modules/foundry.bicep`, ADR-004 |
| Prompts processed outside the EU against a workload's obligations | `modelDeploymentSku` set to `DataZoneStandard`, which is not the default | ADR-004, `infra/main.bicepparam` |
| An unreviewed change to a model or a filter | Pull request with `what-if`, then a manual deployment with approval | `.github/workflows/`; README, *Delivery and DORA* |
| Runaway model spend | Monthly budget with notifications at 40, 80 and 100 %; token consumption query; `repo` tag | `infra/modules/monitoring.bicep`, `monitoring/queries.kql`, [cost.md](cost.md) |
| One workload starving the others of capacity | None deployed; a deployment per workload is the documented way out | ADR-001, ADR-004 |
