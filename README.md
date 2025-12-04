# Terraform GCP Load Balancing Examples

Terraform examples that show how to build **realistic, multi-tier applications** on Google Cloud with different types of load balancers and instance groups.

The goal of this repository is to answer a practical question:

> “I can click together a Google Cloud load balancer in the console —  
> but **how do I model all those forwarding rules, proxies, backends, and health checks in Terraform** in a clean, reusable way?”

While GCP makes load balancers easy to configure in the Console UI, doing the same in Terraform is significantly more complex. Compared to how many teams typically use AWS or Azure, Google’s load balancers are built from more modular resources — backend services, proxies, URL maps, health checks, forwarding rules, proxy-only subnets, firewall rules, and more. Configuring them correctly often requires wiring together 5–10 separate Terraform resources per load balancer.

Google provides some Terraform modules, but they are limited in scope, opinionated, or focused only on specific products (e.g., classic global HTTP(S) LB). For modern architectures — such as **regional external L7 load balancers** or **internal L4 passthrough load balancers** — engineers frequently end up writing their own modules or reverse-engineering examples.

This repository fills that gap by providing **clear, end-to-end, production-like examples** and **fully reusable Terraform modules** for:  
- Internal L4 regional passthrough load balancers
- Regional external L7 managed-proxy load balancers
- Global external L7 HTTP load balancers

Use them as a starting point for your own infrastructure, or study them to understand how all the pieces fit together.

---

## What’s Included

### Demo Scenarios (Complete Working Examples)

This repository contains **3 full end-to-end scenarios**, each showing a progressively more advanced architecture.
All demos share the same modules but differ in orchestration and load‑balancer topology.

#### Scenario 1 — Unmanaged Instance Groups + Regional Load Balancing  
Folder: `demos/01-unmanaged-ig-regional/`
```txt
                    ┌──────────────────────────────────┐
                    │      Regional External L7 LB     │
                    │   (EXTERNAL_MANAGED, HTTP only)  │
                    └───────────────┬──────────────────┘
                                    │
                                    ▼
                         ┌─────────────────────┐
                         │   Frontend VMs      │
                         │ Unmanaged Instance  │
                         │       Group         │
                         └─────────┬───────────┘
                                   │  HTTP (5500)
                                   │
                     ┌─────────────┴───────────────┐
                     │  Internal L4 TCP ILB        │
                     │   (load_balancing_scheme=   │
                     │          "INTERNAL")        │
                     └─────────────┬───────────────┘
                                   │
                                   ▼
                         ┌─────────────────────┐
                         │    Backend VMs      │
                         │ Unmanaged Instance  │
                         │        Group        │
                         └─────────────────────┘
```

#### Scenario 2 — Managed Instance Groups + Autoscaling + Regional Load Balancing
Folder: `demos/02-managed-ig-regional/`
```txt
                    ┌──────────────────────────────────┐
                    │      Regional External L7 LB     │
                    │   (EXTERNAL_MANAGED, HTTP only)  │
                    └───────────────┬──────────────────┘
                                    │
                                    ▼
                         ┌──────────────────────────────┐
                         │    Frontend MIG (Managed)    │
                         │  - Autohealing (HTTP /health)│
                         │  - Autoscaling (CPU)         │
                         └───────────┬──────────────────┘
                                     │ HTTP (5500)
                                     │
                      ┌──────────────┴───────────────┐
                      │   Internal L4 TCP ILB        │
                      │ (Passthrough, regional)      │
                      └──────────────┬───────────────┘
                                     │
                                     ▼
                         ┌──────────────────────────────┐
                         │     Backend MIG (Managed)    │
                         │  - Autohealing (HTTP/health) │
                         │  - Autoscaling (CPU)         │
                         └──────────────────────────────┘
```
#### Scenario 3 — Global Frontend Load Balancing Across Two Regions 
Folder: `demos/03-managed-ig-global/`
```txt
                           ┌─────────────────────────────────────────┐
                           │    Global External HTTP Load Balancer   │
                           │      (Global EXTERNAL, GFEs, HTTP)      │
                           └─────────────────────┬───────────────────┘
                                                 │
       ┌─────────────────────────────────────────┼─────────────────────────────────────────┐
       │                                         │                                         │
       ▼                                         ▼                                         ▼
┌─────────────────────────┐              ┌─────────────────────────┐                (Client requests
│   Google Front End      │              │   Google Front End      │                 automatically hit
│ (Closest geographic GFE)│              │ (Closest geographic GFE)│                 nearest GFE)
└──────────┬──────────────┘              └──────────┬──────────────┘
           │                                        │
           ▼                                        ▼

        Region A                                   Region B
   (e.g., us-central1)                        (e.g., europe-west1)
───────────────────────────             ───────────────────────────
          │                                        │
          ▼                                        ▼
┌────────────────────────────┐         ┌────────────────────────────┐
│     Frontend MIG (A)       │         │     Frontend MIG (B)       │
└─────────────┬──────────────┘         └─────────────┬──────────────┘
              │ HTTP (5500)                          │ HTTP (5500)
              │                                      │
        ┌─────▼──────────────────┐             ┌─────▼──────────────────┐
        │   Internal TCP ILB (A) │             │   Internal TCP ILB (B) │
        └─────┬──────────────────┘             └─────┬──────────────────┘
              │                                      │
              ▼                                      ▼
┌────────────────────────────┐         ┌────────────────────────────┐
│       Backend MIG (A)      │         │       Backend MIG (B)      │
└────────────────────────────┘         └────────────────────────────┘
```
---

### Load Balancer Types

This project demonstrates **three different GCP load balancer products**, implemented exactly as recommended in Terraform. Each type requires a different set of resources (health checks, backend services, proxies, forwarding rules, subnets, etc.), and the examples show the correct, minimal wiring for each.

#### 1. Internal L4 Regional Passthrough Load Balancer (TCP)

**GCP product name:** *Internal TCP/UDP Load Balancer*  
**Terraform scheme:** `load_balancing_scheme = "INTERNAL"`  
**Proxy mode:** Passthrough (no proxy-only subnet)  
**Used in:** All Scenarios (1, 2, 3)  
**Folder:** `modules/internal_lb/`

This load balancer distributes TCP traffic across backend VMs inside a VPC.  
Packets go directly from client to backend — the LB does **not** proxy traffic.

---

#### 2. Regional External L7 HTTP Application Load Balancer (Proxy-Based)

**GCP product name:** *Regional External Application Load Balancer*  
**Terraform scheme:** `load_balancing_scheme = "EXTERNAL_MANAGED"`  
**Proxy mode:** Google-managed proxy (requires `REGIONAL_MANAGED_PROXY` subnet)  
**Used in:** Scenario 1 & 2  
**Folder:** `modules/external_lb/`

This LB terminates HTTP requests at Google’s proxy layer and forwards them to backend services.  
It is the modern replacement for the legacy “HTTP(S) Load Balancer.”

---

#### 3. Global External L7 HTTP Load Balancer

**GCP product name:** *Global External Application Load Balancer (HTTP(S))*  
**Terraform scheme:** `load_balancing_scheme = "EXTERNAL"`  
**Proxy mode:** Global Google Front Ends (GFEs)  
**Used in:** Scenario 3  
**Folder:** `modules/global_external_lb/`

Traffic is served by GFEs closest to the client, then routed to regional backend services.  
In this demo it runs HTTP on port 80, but supports full HTTPS/mTLS in production.

> **Note:** All examples use **HTTP only** for simplicity. Production systems should terminate HTTPS at the LB.

---

### Architecture Patterns

Each scenario models a realistic, modern multi‑tier setup:

- **VPC & subnet layout**  
  Backend and frontend subnets per region.

- **Private VMs only**  
  Instances have *no external IPs*. Outbound traffic uses **Cloud NAT**.

- **Health checks**  
  Separate LB and instance-group health checks.

- **Managed instance groups**  
  Autohealing + CPU-based autoscaling.

- **Startup scripts (demo only pattern)**  
  Retry logic, logging, repo cloning from GitHub, venv setup, app startup.  
  In production you would typically **bake the app into a custom image or container** instead of cloning the repo on every boot.

The sample app:

- `backend.py` — responds with hostname JSON  
- `frontend.py` — calls backend and returns both hostnames

See `test-app/README.md` for details.

---

## Repository Layout

```
.
├── demos
│   ├── 01-unmanaged-ig-regional
│   ├── 02-managed-ig-regional
│   └── 03-managed-ig-global
│
├── modules
│   ├── vpc
│   ├── regional_network
│   ├── internal_lb
│   ├── external_lb
│   ├── global_external_lb
│   ├── vm_unmanaged_group
│   ├── vm_managed_group
│   ├── regional_service_stack
│   └── debug_firewall
│
├── test-app
├── README.md
└── LICENSE
```

---

## Requirements

- Terraform **≥ 1.5**
- A Google Cloud project with billing enabled
- Ability to create a service account and assign IAM roles

---

## ⚠️ Costs

Resources use small machine types (`e2-micro`) but **are still billable**.  
Run:

```
terraform destroy
```

when done.

---

## Authentication: Using a Service Account for Terraform

Terraform authenticates via:

```
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/gcp-creds.json"
```

### 1. Create a Service Account

Google Cloud Console:

1. IAM & Admin → Service Accounts  
2. Click **Create service account**  
3. Name it `terraform-lb-demo` (or similar)  
4. Click **Create and continue**

Docs:  
- https://cloud.google.com/iam/docs/service-accounts  
- https://cloud.google.com/iam/docs/keys-create-delete  

---

### 2. Assign Least‑Privilege IAM Roles

Required roles:

- `roles/compute.serviceAgent`
- `roles/compute.instanceAdmin.v1`
- `roles/compute.loadBalancerAdmin`
- `roles/compute.networkAdmin`
- `roles/compute.securityAdmin`
- `roles/compute.viewer`

Reference:  
https://cloud.google.com/compute/docs/access/iam#compute.engine.roles

---

### 3. Create & Download the JSON Key

1. Open the service account  
2. Go to **Keys** tab  
3. Add key → Create new key → JSON  
4. Save as e.g. `gcp-creds.json`

Never commit this file.

---

### 4. Export Credentials

```bash
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/gcp-creds.json"
```

Terraform will now authenticate automatically.

---

## Running the Demos

Each example is fully isolated.

```
cd demos/01-unmanaged-ig-regional   # Or 02, or 03
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars and set your project ID
terraform init
terraform plan
terraform apply
terraform destroy     # Cleanup
```

> **⚠️ IMPORTANT — Edit terraform.tfvars**
>
> After copying the example variables, open `terraform.tfvars` and update:
> - `project` — replace `my-project-id` with **your actual GCP project ID**
> - For Scenarios 1 & 2: optionally adjust `region` and `zone`
> - For Scenario 3: set `region_a`, `zone_a`, `region_b`, `zone_b`, and suffixes
>
> If you skip this step, Terraform will fail with a project error.

---

### Scenario 1 — Unmanaged Instance Group

```
cd demos/01-unmanaged-ig-regional
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars and set your project ID
terraform init
terraform plan
terraform apply
```

Outputs:

- `internal_lb_ip`
- `external_lb_ip`

Test:

```
curl http://<external_lb_ip>/info
```

---

### Scenario 2 — Managed Instance Group

```
cd demos/02-managed-ig-regional
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars and set your project ID
terraform init
terraform plan
terraform apply
```

Outputs (same as Scenario 1):

- `internal_lb_ip`
- `external_lb_ip`

---

### Scenario 3 — Multi‑Region Global Load Balancer

```
cd demos/03-managed-ig-global
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars and set your project ID
terraform init
terraform plan
terraform apply
```

Outputs:

- `global_lb_ip`
- `region_a_backend_internal_lb_ip`
- `region_b_backend_internal_lb_ip`

Test:

```
curl http://<global_lb_ip>/info
```

#### Important:
A global external HTTP load balancer routes traffic based on **client proximity** (latency), not round-robin.
- If you run curl from your laptop, you will likely always hit the closest region.
- To test that both regions work, run curl from VMs located in other regions, for example:
```bash
# From a VM in us-central1
curl http://<global_lb_ip>/info

# From a VM in europe-west1
curl http://<global_lb_ip>/info
```
---

## Security & Production Notes

### 🔐 Debug Firewall Module

`modules/debug_firewall` opens:

- SSH (22)
- ICMP

from **0.0.0.0/0**.

Convenient for demos.  
**Never** use in production.

---

### 🔐 HTTP Only

Demos use HTTP for clarity.  
Production should:

- Terminate HTTPS at LB  
- Use TLS certificates  
- Enforce security policies

---

### 🏗️ Zonal Redundancy Simplified

Examples deploy **one zone per region**.  
Production should use:

- multiple zones  
- zonal instance groups  
- regional failover  

---

### ⚠️ Flask Development Server (Demo Only)

VMs run the Flask apps via:

```
python3 backend.py
python3 frontend.py
```

Flask warns:

> *This is a development server. Do not use it in a production deployment.*

Production systems should use a WSGI server such as:

```
gunicorn -b 0.0.0.0:5500 frontend:app
```

---

### 🧱 VM Images vs. “Clone on Boot”

In these demos, each VM:

- clones this GitHub repo on startup,  
- creates a Python virtual environment, and  
- runs the Flask apps directly.

This keeps the Terraform examples small and easy to understand, but it is **not** how you would normally deploy in production.

For a production setup you would typically:

- build a **custom VM image** or **container image** that already contains your app and dependencies, and  
- use **instance templates** + **managed instance groups** (or a container platform like GKE/Cloud Run) to roll out new versions.

See:  
- Custom images: https://cloud.google.com/compute/docs/images  
- Instance templates: https://cloud.google.com/compute/docs/instance-templates

---

### 🔑 IAM Caution

Service account roles are powerful — store the key securely and rotate regularly.

---

## License

MIT — see `LICENSE` for details.
