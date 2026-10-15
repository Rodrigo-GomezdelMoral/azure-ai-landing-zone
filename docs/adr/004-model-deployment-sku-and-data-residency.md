# ADR-004 · Model deployment SKU, and EU data residency as a one-parameter change

**Status:** accepted · **Date:** 2026-10-14

## Context

Three models are deployed once and shared: `gpt-5-mini` for answering and agents, `gpt-5-nano`
for query planning and cheap classification, `text-embedding-3-small` for vectorisation. A
pay-as-you-go deployment has a SKU that decides **where inference runs**, not how much it can
run: `Standard` stays in the resource's region, `DataZoneStandard` stays inside a data zone (the
EU or the US), `GlobalStandard` may route to any Azure region with capacity. Availability differs
by model and region and changes without notice, so the SKU is a decision to verify, not to assume.

Verified on 2026-10-14 with `az cognitiveservices model list --location swedencentral`:

| Model · version | Standard | DataZoneStandard | GlobalStandard |
|---|---|---|---|
| `gpt-5-mini` · 2025-08-07 | not offered | yes | yes |
| `gpt-5-nano` · 2025-08-07 | not offered | yes | yes |
| `text-embedding-3-small` · 1 | not offered | yes | yes |

Default quota for the subscription in this region, from `az cognitiveservices usage list`
(thousands of tokens per minute): `gpt-5-mini` 1,000 global and 300 data zone; `gpt-5-nano`
5,000 global and 2,000 data zone; `text-embedding-3-small` 1,000 for both.

## Options

1. **`GlobalStandard`.** Highest quota and the lowest price; prompts and completions may be
   processed outside the EU, with data at rest staying in the resource's region.
2. **`DataZoneStandard`.** Inference stays inside the EU data zone. Same models, lower quota,
   a 10 % price premium.
3. **`Standard` (regional).** Not offered for any of the three models in Sweden Central, so not
   available to choose.

Prices retrieved on 2026-10-14 from the Azure Retail Prices API
(`armRegionName eq 'swedencentral' and serviceName eq 'Foundry Models'`, currency EUR, per
million tokens):

| Meter | GlobalStandard | DataZoneStandard |
|---|---|---|
| `gpt-5-mini` input / cached input / output | 0.22 / 0.022 / 1.76 | 0.242 / 0.0242 / 1.94 |
| `gpt-5-nano` input / cached input / output | 0.044 / 0.0044 / 0.352 | 0.0484 / 0.00484 / 0.387 |

The embedding meters are listed without a price by the API in this region and are treated as
negligible in the cost model.

## Decision

A single parameter, `modelDeploymentSku`, applied to all three deployments, defaulting to
`GlobalStandard`. A workload whose customers require EU processing sets the parameter to
`DataZoneStandard`, pays the 10 % premium, and lives within the lower data-zone quota; nothing
else in the estate changes, which is the point of making it a parameter rather than a redeploy.

Two related choices travel with it:

- **Deployment names equal model names**, with no suffix. Application code receives the
  deployment name through the landing zone outputs and passes it to the SDK; a suffix would be
  one more string to keep in sync across four repositories.
- **`versionUpgradeOption: NoAutoUpgrade`.** The workloads publish evaluation numbers. A model
  version that upgrades itself silently invalidates every published metric without a commit to
  explain it. The model list reports the inference retirement date for version 2025-08-07 of the
  `gpt-5` family as 2027-02-09; the upgrade is a deliberate change before then.

## Trade-offs

- `GlobalStandard` is the wrong default for a regulated customer, by design: the platform makes
  residency a cheap switch rather than pre-paying the premium for workloads that do not need it.
- Capacity is shared between the four workloads. One deployment per model keeps the account
  simple; a noisy workload throttles the others before the quota is raised or a second deployment
  is added.
- Pinned versions age. Someone has to own the upgrade before the retirement date.

## Revisit when

A workload handles data whose processing must stay in the EU (switch the parameter), a model
loses `GlobalStandard` availability in Sweden Central (re-run the availability check and
change the default), or the retirement date approaches.
