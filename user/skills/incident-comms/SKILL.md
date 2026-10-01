---
name: incident-comms
description: Help during and after production incidents. Drafts internal and customer-facing status updates, builds a timeline from pasted notes, chat or alert text, and writes a blameless postmortem with action items. Use when the user mentions an incident, outage, SEV/P1, on-call page, status update, RCA, or postmortem.
argument-hint: "[update | timeline | postmortem] + pasted notes"
disable-model-invocation: true
---

# Incident comms and postmortems

Ground rules:
- Use only facts the user gave you. Never invent timestamps, metrics, customer counts or causes; write `TODO(confirm)` instead.
- Blameless wording: describe systems, signals and decisions, not people.
- Times in UTC, `YYYY-MM-DD HH:MM`.

## `update`: status update during the incident
Internal, at most 6 lines: Status (Investigating / Identified / Monitoring / Resolved) · Impact (who/what, since when) · What we're doing now · Next update at.
Customer-facing variant: same structure, no internal hostnames or service names, no speculation about cause, no blame on vendors.

## `timeline`
Turn the pasted notes into `| UTC | Event | Source |`, sorted, with detection, escalation, mitigation and resolution clearly marked.
Compute time-to-detect / time-to-mitigate / time-to-resolve only when the needed timestamps are present.

## `postmortem`
Fill in [the template](./assets/postmortem-template.md). Take the root cause through "5 whys" down to a systemic cause (missing guardrail, alert, test, or runbook).
Action items: few and concrete ("alert when 5xx rate > 2% for 5 min on service X"), each typed prevent / detect / mitigate, with priority and an owner placeholder.
