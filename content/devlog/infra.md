+++
title = "Kubernetes: how to prevent our pipelines from failing"
date = "2024-01-26"
[taxonomies]
tags=["work", "infrastructure"]
+++

The CI/CD pipeline of my team has been pretty unstable lately. It seems that when our end-to-end (E2E) tests run, the infrastructure needed to keep the UI running and serve requests is often temporarily unavailable. It's pretty annoying if an API vanishes for 10s and you need to re-run your 15min pipeline. Our response so far has been: turn it off and on again. Yeah. But it's clear that we need to take this more seriously, so I started monitoring pipeline runs with a mixture of refreshing the Jenkins UI and re-running `kubectl`.

It seems to me that pod eviction because of node drain is at least to blame for some of the outages, and that's definitely a solvable problem. It's easy enough to add a Pod Disruption Budget (PDB) to the infrastructure my team controls, but our pipeline also deploys infrastructure controlled by other teams. Meaning, our pipeline triggers other pipelines. How do we add a PDB to these components though?

- make a PR in the other team's repo
- somehow dynamically find the correct selector label and add a PDB for that
- allow configuring the PDB through parameters passed to the other pipeline

Option 2 sounds so whacky that I wouldn't even consider it further. Another option entirely is to have the E2E tests retry. We use a tool that already includes a fair amount of retrying, but you could imagine something like Kube's backoff limit for the entire test suite. This could lead to unnecessary infrastructure costs in case we re-run the same test suite 5x when the underlying infrastructure is regularly down for the entire duration of those 5 runs. This is particularly true for the database we deploy into pull-request environments.

It's a frustrating problem to have to be honest. Adding a PDB means we need to have >1 replica of all required components. If components are slow to start then adding a PDB means cluster maintenance becomes harder since it takes longer for pods to evict.

I think a combination of not specifying a PDB for infrastructure components that are quick to restart on a new node, and a PDB for slower infrastructure (pull request databases) is my preferred solution right now.

