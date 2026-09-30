# Engineering Control Plane Lab

A tiny clean-room experiment for visualizing software-delivery state across fictional projects.

No private repository data, customer data, production identifiers, credentials, network details, or proprietary implementation are used.

## What it demonstrates

The lab separates:

- work candidates
- dependencies
- verification state
- blocked work
- safe parallel work
- next actions

The sample projects are intentionally fictional:

```text
Project Alpha
Project Beta
Project Gamma
```

## Run locally

Open `index.html` in a browser.

The demo has no backend and sends no data anywhere.

## Why this model is useful

A large project often has many tasks that look sequential in prose but are not true dependencies.

A control-plane view can help distinguish:

```text
must happen before
```

from:

```text
can run in parallel
```

and:

```text
blocked by shared capacity
```

from:

```text
blocked by product dependency
```

This experiment is educational, not a production orchestrator.
