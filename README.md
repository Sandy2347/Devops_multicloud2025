
# SQL Server Health Check Automation

This package helps you monitor:
- Always On Availability Group (AG) Health
- SQL Backup Status
- Disk Space on SQL Servers

## Contents

- `scripts/full_sql_health_check.ps1`: PowerShell health check script
- `ansible/run_health_check.yml`: Ansible playbook to execute the script from GitHub
- `README.md`: This instruction file

## Setup Guide

### 1. Upload Script to GitHub

- Upload `scripts/full_sql_health_check.ps1` to a GitHub repo.
- Use the raw URL (e.g. `https://raw.githubusercontent.com/your-org/sql-monitoring/main/full_sql_health_check.ps1`).

### 2. Update Ansible Inventory

Make sure your `inventory.yml` includes a `[sql_nodes]` group with the target Windows SQL servers.

### 3. Run the Playbook

```bash
ansible-playbook -i inventory.yml ansible/run_health_check.yml
```

### 4. Optional: Schedule the Check

Use `win_scheduled_task` module in Ansible to run it regularly (e.g. every 6 hours).

Let me know if you'd like that template included too.
