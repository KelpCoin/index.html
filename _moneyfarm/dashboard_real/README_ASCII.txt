Automation Toolkit Dashboard (offline).
Files live under C:\BrownEyeCortex\_moneyfarm\dashboard_real.
Run generate_dashboard.ps1 to refresh data.
run_dashboard.ps1 opens report.html.
report.html embeds JSON and works without a server.
Logs: dashboard_real\logs\gen_YYYYMMDD_HHMMSS.log.
Snapshot: dashboard_real\data\snapshot.json.
OPS summary: _moneyfarm\logs\dashboard_ops_summary.log.
Scheduled task refreshes hourly.
ASCII only by design.
