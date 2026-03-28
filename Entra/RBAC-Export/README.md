# Entra-Rbac

PowerShell scripts for Entra ID role assignment export and Unified RBAC migration toward Microsoft Defender XDR.

---

## Scripts

| Script | Description |
|--------|-------------|
| [EntraID-RBAC-Export.ps1](./EntraID-RBAC-Export.ps1) | Exports all Entra ID role assignments (Active + PIM Eligible) to a structured CSV file |

---

## Migration workflow

This folder covers a four-step Unified RBAC migration workflow. Scripts will be added progressively:

```
Step 1 — EntraID-RBAC-Export.ps1          ✓ available
           └─ output: EntraID_RBAC_Export_YYYYMMDD.csv

Step 2 — RBAC-MappingPlan.ps1             (coming soon)
           └─ output: RBAC_MigrationPlan.csv

Step 3 — RBAC-Porting.ps1                 (coming soon)
           └─ output: RBAC_Porting_Log.csv

Step 4 — RBAC-PostPorting-Verify.ps1      (coming soon)
           └─ output: RBAC_PostPorting_Report.csv
```

---

## Prerequisites

### Modules

```powershell
Install-Module Microsoft.Graph.Authentication -Scope CurrentUser
Install-Module Microsoft.Graph.Identity.Governance -Scope CurrentUser
Install-Module Microsoft.Graph.Users -Scope CurrentUser
```

### Tenant permissions

| Role | Notes |
|------|-------|
| **Global Reader** | Recommended — read-only, least privilege |
| **Privileged Role Administrator** | Required if you also manage PIM assignments |
| Security Reader + Privileged Role Reader | Minimum scoped alternative |

### Execution policy

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

---

## References

- [Activate Microsoft Defender XDR Unified RBAC](https://learn.microsoft.com/en-us/defender-xdr/activate-defender-rbac)
- [Microsoft Defender XDR Unified RBAC overview](https://learn.microsoft.com/en-us/defender-xdr/manage-rbac)
- [Microsoft.Graph PowerShell SDK](https://learn.microsoft.com/en-us/powershell/microsoftgraph/overview)
