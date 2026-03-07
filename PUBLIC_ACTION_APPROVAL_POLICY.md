# PUBLIC ACTION APPROVAL POLICY

## Scope
Any action visible to customers, partners, platforms, or public audiences.

## Mandatory gate
No public action executes without explicit approval record stored on disk.

## Approval record minimum
- approver name
- approval timestamp
- action summary
- scope and channels
- expiration time
- rollback path

## Enforcement
Automation must check for approval record before public execution.
If absent or expired, action is blocked.

## Examples requiring approval
- publishing posts, pages, offers, ads, emails
- changing checkout or pricing
- external partner outreach
- public release notes
