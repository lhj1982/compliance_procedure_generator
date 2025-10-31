# Migration Guide: Dynamic Team Questions

## Overview
This migration updates the compliance procedure system to support dynamic questions per team. Each team now has its own set of tailored compliance questions stored in the database.

## Changes Made

### 1. Database Schema Updates
- Added `questions` column (JSONB type) to the `teams` table
- Cleared old team data
- Inserted 6 new teams with team-specific questions:
  1. **IT / Infrastructure / Security** - PCI-focused control questions
  2. **Finance – Cash Management / Treasury** - Cash management and treasury questions
  3. **Finance – Reconciliation / General Ledger** - GL reconciliation questions
  4. **Risk & Compliance / Fraud / AML** - Fraud and AML monitoring questions
  5. **Customer Operations / Claims / Disputes** - Dispute resolution questions
  6. **Legal / Contracts / Regulatory** - Contract and regulatory compliance questions

### 2. Backend API Updates
**File**: `compliance_procedure_generator/backend/server.py`

- Added new endpoint: `GET /api/teams/<team_id>/questions`
  - Returns team-specific questions from the database
  - Response format:
    ```json
    {
      "team_id": 1,
      "team_name": "IT / Infrastructure / Security",
      "questions": [...]
    }
    ```

### 3. Frontend Updates
**File**: `compliance_procedure_generator/frontend/static/app.js`

- Added `currentQuestions` property to store loaded questions
- Modified `handleTeamSelection()` to fetch questions asynchronously
- Added `loadTeamQuestions()` method to fetch team-specific questions from API
- Updated `generateQuestions()` to use dynamic questions instead of hardcoded ones
- Updated form submission to use dynamic questions

## How to Apply the Migration

### Option 1: Using the Migration Script (Recommended)
```bash
cd compliance_procedure_admin
./run_migration.sh
```

### Option 2: Manual PostgreSQL Execution
```bash
cd compliance_procedure_admin
psql -h localhost -p 5432 -U postgres -d compliance_admin -f schema/004_update_teams_structure.sql
```

### Option 3: Using Docker
```bash
docker exec -i compliance_db psql -U postgres -d compliance_admin < compliance_procedure_admin/schema/004_update_teams_structure.sql
```

## Question Structure

Each team's questions are stored as JSON arrays with the following format:

```json
[
  {
    "id": "procedure_name",
    "question": "Procedure name?",
    "type": "text",
    "placeholder": "e.g., Daily Cash Position Reconciliation"
  },
  {
    "id": "performer",
    "question": "Who does it (role/team)?",
    "type": "textarea",
    "placeholder": "Role or team responsible"
  }
]
```

## Team-Specific Questions

### IT / Infrastructure / Security (15 questions)
- Control Name, Owner, Frequency
- Purpose / PCI Risk Mitigation
- Procedure Steps, Tools & Systems
- Access Requirements, Starting Point
- Checks & Criteria, Failure Handling
- Additional Involvement, Approval/Sign-off
- Evidence Storage, Work Location, Dependencies

### Finance – Cash Management / Treasury (14 questions)
- Procedure name, Performer, Frequency
- Risk (theft, shortfall, misallocation)
- Detailed steps, Systems (bank portals, ERP, treasury)
- Access/credentials/signatories
- Process starting point
- Checks/tolerance thresholds/variance rules
- Exception handling, Approval
- Evidence storage, Team involvement, Dependencies

### Finance – Reconciliation / General Ledger (13 questions)
- Procedure name, Performer, Frequency
- Risk of misstatement/errors
- Reconciliation steps (source/target matching)
- Tools (reconciliation modules, Excel, scripts)
- Access/permissions, Starting point
- Checks (tolerances, ageing, unmatched items)
- Exception handling, Approval, Evidence storage, Dependencies

### Risk & Compliance / Fraud / AML (14 questions)
- Procedure name, Executor team/role, Frequency
- Purpose (fraud, regulatory compliance)
- Steps (monitor, flag, review)
- Systems (rules engine, dashboards, alerts)
- Access/credentials, Starting point
- Checks/thresholds/red flags
- Investigation/escalation steps, Team involvement
- Approvals, Evidence/audit log storage, Dependencies

### Customer Operations / Claims / Disputes (14 questions)
- Procedure name, Performer, Frequency
- Purpose (customer satisfaction, compliance)
- Dispute processing steps
- Tools (case system, CRM)
- Access requirements, Starting point
- Eligibility/policy checks
- Exception/appeal handling, Team involvement
- Approval/escalation, Evidence retention, Dependencies

### Legal / Contracts / Regulatory (13 questions)
- Procedure name, Performer, Frequency/trigger
- Risk/legal exposure
- Steps (draft, review, edits, approval)
- Systems (contract management tool)
- Access requirements, Starting point
- Review criteria (clause compliance, regulatory provisions)
- Revision/escalation management
- Approver roles, Contract storage, Dependencies

## Testing the Changes

1. **Start the backend server**:
   ```bash
   cd compliance_procedure_generator/backend
   python server.py
   ```

2. **Open the frontend**:
   - Navigate to `http://localhost:8000` (or your configured port)

3. **Test dynamic questions**:
   - Select different teams from the dropdown
   - Verify that questions change based on the selected team
   - Submit a form and verify document generation works

4. **Check API endpoints**:
   ```bash
   # Get all teams
   curl http://localhost:9090/api/teams

   # Get questions for team ID 1
   curl http://localhost:9090/api/teams/1/questions
   ```

## Rollback Instructions

If you need to rollback this migration:

```sql
-- Remove the questions column
ALTER TABLE teams DROP COLUMN IF EXISTS questions;

-- Restore original teams
DELETE FROM teams_compliance_procedures;
DELETE FROM teams;

INSERT INTO teams (name) VALUES
('Engineering'),
('Legal'),
('HR'),
('Finance'),
('Operations');
```

## Notes

- The frontend includes fallback logic: if questions cannot be loaded from the API, it will use the hardcoded `COMPLIANCE_QUESTIONS` constant
- Questions are cached in the frontend's `currentQuestions` property until a new team is selected
- The INITIAL_PROMPT in the backend has also been updated to handle more generic SOP generation suitable for all team types
