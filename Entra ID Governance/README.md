# Entra ID Governance

PowerShell scripts for Microsoft Entra ID Governance — access reviews, lifecycle workflows, entitlement management and privileged identity management reporting.

---

## Scripts

| Script | Description |
|--------|-------------|
| *(coming soon)* | |

---

## Planned scripts

| Script | Description |
|--------|-------------|
| `Get-AccessReviewReport.ps1` | Exports all active and completed access reviews with reviewer decisions and outcomes |
| `Get-StaleGuestAccounts.ps1` | Identifies guest accounts with no activity in the last N days, with export to CSV |
| `Get-LifecycleWorkflowStatus.ps1` | Reports on Lifecycle Workflow runs — joiner, mover, leaver — with per-user task outcomes |
| `Get-EntitlementManagementReport.ps1` | Exports access packages, policies, assignments and pending requests from Entitlement Management |
| `Get-PIMAssignmentReport.ps1` | Full report of PIM Eligible and Active assignments with expiry dates and last activation timestamps |
| `Get-OrphanedObjects.ps1` | Detects orphaned users, groups and service principals with no owner and no recent activity |

---

## Prerequisites

### Modules

```powershell
Install-Module Microsoft.Graph.Authentication -Scope CurrentUser
Install-Module Microsoft.Graph.Identity.Governance -Scope CurrentUser
Install-Module Microsoft.Graph.Users -Scope CurrentUser
Install-Module Microsoft.Graph.Groups -Scope CurrentUser
```

### Tenant permissions

| Role | Notes |
|------|-------|
| **Global Reader** | Recommended for all read-only export scripts |
| **Identity Governance Administrator** | Required for Entitlement Management and Lifecycle Workflows |
| **Privileged Role Administrator** | Required for PIM assignment reports |

---

## References

- [Microsoft Entra ID Governance documentation](https://learn.microsoft.com/en-us/entra/id-governance/identity-governance-overview)
- [Access reviews](https://learn.microsoft.com/en-us/entra/id-governance/access-reviews-overview)
- [Lifecycle workflows](https://learn.microsoft.com/en-us/entra/id-governance/what-are-lifecycle-workflows)
- [Entitlement management](https://learn.microsoft.com/en-us/entra/id-governance/entitlement-management-overview)
- [Microsoft.Graph PowerShell SDK](https://learn.microsoft.com/en-us/powershell/microsoftgraph/overview)
