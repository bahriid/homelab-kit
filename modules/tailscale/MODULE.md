---
name: tailscale
summary: Reach the server over SSH from anywhere, with no SSH port open to the internet.
requires: [base]
asks:
  - Nothing. The login is a human step.
---

# tailscale

## What you get

Tailscale on the server, used only as a private path. SSH stays plain OpenSSH with keys (from the
`base` module). Tailscale SSH, subnet routing, exit node, Serve and Funnel stay off.

## Install

```bash
bash modules/tailscale/install.sh
```

**Human step:** the script prints a login URL (`tailscale up`). The person opens it and approves
the machine. Then on the laptop, add a second SSH host for when they are away from home:

```
Host home
  HostName 192.168.1.50      # LAN IP
  User <deploy-user>

Host home-ts
  HostName 100.x.y.z         # tailscale ip -4 on the server
  User <deploy-user>
```

## Verify

```bash
bash modules/tailscale/check.sh
```

From the laptop on another network (phone hotspot): `ssh home-ts true`.

## Rollback

`sudo tailscale down && sudo apt purge tailscale`

## Notes

- On a laptop that switches between several tailnets, set `tailscale set --accept-dns=false`.
  A half-finished switch can leave system DNS stuck on `100.100.100.100` and kill all internet
  even after `tailscale down`.
- At home, use the LAN host. Tailscale is for when you are out.
