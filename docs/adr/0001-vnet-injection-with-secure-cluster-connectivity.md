# ADR 0001. VNet injection with secure cluster connectivity

## Status

Accepted

## Context

A managed Databricks VNet is the fastest way to start, but it cannot be peered to a hub, cannot reach private data sources, and cannot be locked behind a storage firewall. Retrofitting VNet injection later means recreating the workspace.

## Decision

The workspace is deployed with VNet injection into delegated host and container subnets, with `no_public_ip = true`. Private Link is available as two toggles, back-end and front-end, both off by default. A Terraform precondition refuses a closed front-end with an open back-end.

## Consequences

- Cluster nodes have no public IP and no inbound ports. Outbound traffic to the control plane goes through the secure cluster connectivity relay.
- The storage firewall can default to `Deny` and allow only the delegated subnets and the access connector.
- Subnet size caps cluster capacity. Each node uses one IP in each subnet, so a /24 pair supports about 250 nodes.
- Turning on front-end Private Link requires private DNS and a network path from users and CI to the endpoint.
