# Test App for Load Balancing Examples

This folder contains two simple Flask applications used in the load balancing demos:

- `backend.py` — runs on backend VMs behind an internal load balancer
- `frontend.py` — runs on frontend VMs that call the backend through the internal LB

Both services expose:

- `/health` — returns `ok` (used by load balancers)
- `/info`
  - Backend: returns its hostname as JSON
  - Frontend: returns its own hostname and the backend hostname


## Running the Apps Manually

### 1. Install Python and venv

```bash
sudo apt update
sudo apt install -y python3 python3-venv python3-pip
```

### 2. Clone the repository

```bash
git clone https://github.com/alandyshev/terraform-gcp-load-balancing-examples.git
cd terraform-gcp-load-balancing-examples/test-app
```

### 3. Create and activate a virtual environment

```bash
python3 -m venv .venv
source .venv/bin/activate
```

### 4. Install dependencies

```bash
pip install -r requirements.txt
```

### 5. Run the backend

```bash
HOST=0.0.0.0 PORT=5501 python backend.py
```

### 6. Run the frontend

```bash
HOST=0.0.0.0 PORT=5500 BACKEND_URL="http://localhost:5501/info" python frontend.py
```
The services will be available on ports **5501** (backend) and **5500** (frontend).


## How Terraform Uses These Apps

Terraform startup scripts:

- clone this repository
- create a virtual environment
- install dependencies
- and run either backend.py or frontend.py depending on the VM role.
