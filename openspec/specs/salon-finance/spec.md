# Spec: Salon Finance Management

## ADDED Requirements

### Requirement: Income registration

The system SHALL record income movements with: date/time (automatic, editable), amount,
service (from a configurable catalog with optional saved price), optional client
(selectable or created inline), optional employee (free text with suggestions),
payment method (efectivo, transferencia, tarjeta, otro) and optional note.

#### Scenario: Quick income entry via FAB

- **WHEN** the user taps the floating "+" button and chooses "Ingreso"
- **THEN** the income form opens with current date/time pre-filled
- **AND** selecting a service with a saved price auto-fills the amount

#### Scenario: Income persisted offline

- **WHEN** the user saves a valid income (amount > 0, service selected)
- **THEN** the movement is stored in the local SQLite database immediately
- **AND** appears in dashboard, movements list and reports without connectivity

### Requirement: Expense registration

The system SHALL record expense movements with: date, amount, category (from a
configurable catalog), optional supplier, payment method and optional note.

#### Scenario: Expense persisted offline

- **WHEN** the user saves a valid expense (amount > 0, category selected)
- **THEN** the movement is stored locally and reflected in all balances

#### Scenario: Configurable expense categories

- **WHEN** the user adds, edits or deactivates an expense category
- **THEN** the catalog updates and existing movements keep their category

### Requirement: Dashboard

The system SHALL show a dashboard with: balance for day/week/month/year; a pastel pie
chart (mint = earnings, coral = expenses) with net balance; a secondary pie of expenses
by category; a line chart of monthly income vs. expense trend; the last 5 movements;
monthly goal progress; and a cash-close action.

#### Scenario: Net balance calculation

- **WHEN** the dashboard renders for a selected period
- **THEN** net balance equals total income minus total expenses for that period
- **AND** the pie sections are proportional to income and expense totals

#### Scenario: Empty state

- **WHEN** a period has no movements
- **THEN** charts show a friendly empty state instead of crashing

### Requirement: Clients

The system SHALL manage clients (name, phone, notes), searchable by name, each with a
visit history derived from their income movements.

#### Scenario: Client visit history

- **WHEN** the user opens a client detail
- **THEN** all income movements linked to that client are listed newest-first
- **AND** the total spent by the client is shown

### Requirement: Reports and export

The system SHALL provide reports filterable by date range, category, employee and type
(income/expense), showing totals (income, expenses, net), exportable to PDF
(with title, period, chart and table) and to CSV (Excel-compatible).

#### Scenario: Filtered report totals

- **WHEN** the user applies filters
- **THEN** totals and the movement list reflect only matching movements

#### Scenario: PDF export

- **WHEN** the user exports to PDF
- **THEN** a PDF is generated locally with period, totals, pie chart image and table
- **AND** is shared/saved through the OS share sheet (no network)

#### Scenario: CSV export

- **WHEN** the user exports to CSV
- **THEN** a UTF-8 CSV with headers is generated locally and shared via the OS

### Requirement: Daily cash close

The system SHALL allow closing a day: it computes the day summary (income, expenses, net)
and marks the day as closed. Closed days are listed in a history.

#### Scenario: Close current day

- **WHEN** the user confirms the cash close for today
- **THEN** a snapshot (date, totals, net, timestamp) is stored
- **AND** closing the same day again updates the snapshot instead of duplicating

### Requirement: Monthly goals

The system SHALL let the user set a monthly income goal and show progress on the dashboard.

#### Scenario: Goal progress

- **WHEN** a goal exists for the current month
- **THEN** the dashboard shows income-to-goal progress as percentage and bar

### Requirement: Backup and restore

The system SHALL export all data to a single JSON backup file and restore from it,
fully offline.

#### Scenario: Backup round-trip

- **WHEN** the user exports a backup and later restores it
- **THEN** clients, services, categories, movements, cash closes and goals are
  restored exactly (ids preserved)

#### Scenario: Restore validation

- **WHEN** the selected file is not a valid backup (bad JSON, wrong format/version)
- **THEN** the restore is aborted with a clear error and existing data is untouched

### Requirement: 100% offline operation

The system SHALL perform every feature without network access. The release build
SHALL NOT declare the INTERNET permission.

#### Scenario: Airplane mode full flow

- **WHEN** the device is in airplane mode
- **THEN** registration, dashboard, reports, export, cash close and backup all work
