
# SQL Server Health Check Automation

## Features:
- Always On AG Health Validation
- SQL Backup Success/Failure Status
- Disk Space Report

## Setup Instructions:

1. **Upload PowerShell Script to GitHub:**
   - Place `full_sql_health_check.ps1` in a public/private GitHub repo.
   - Use the raw GitHub URL in the Ansible playbook.

2. **Update Ansible Inventory:**
   ```ini
   [sql_nodes]
   sqlserver1.domain.com
   sqlserver2.domain.com
   ```

3. **Run the Playbook:**
   ```bash
   ansible-playbook -i inventory.ini ansible/run_health_check.yml
   ```

4. **(Optional) Schedule via Ansible's `win_scheduled_task` for periodic execution.**
