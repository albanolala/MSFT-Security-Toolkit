<#
.SYNOPSIS
    Exports all Entra ID role assignments (Active + PIM Eligible) to a CSV file
    for Unified RBAC migration planning in Microsoft Defender XDR.

.DESCRIPTION
    This script connects to Microsoft Graph and exports a complete snapshot of
    Entra ID role assignments, including both active assignments and PIM Eligible
    schedules. It is designed to support the As-Is analysis phase of a migration
    from legacy Entra ID RBAC to Microsoft Defender XDR Unified RBAC.

    Typical use cases:
      - Baseline inventory before a Unified RBAC activation
      - Input for an automatic As-Is to To-Be role mapping script
      - Rollback reference document before any migration activity
      - Compliance audit of current role assignments

    This script is READ-ONLY. It makes no changes to the tenant.

    PREREQUISITES
    ──────────────────────────────────────────────────────────────────────────────
    1. PowerShell version
       Compatible with Windows PowerShell 5.1 and PowerShell 7+.
       No null-coalescing operators (??) are used -- safe on all versions.

    2. Required modules
       Install once from an elevated PowerShell session:

         Install-Module Microsoft.Graph.Authentication -Scope CurrentUser
         Install-Module Microsoft.Graph.Identity.Governance -Scope CurrentUser
         Install-Module Microsoft.Graph.Users -Scope CurrentUser

    3. Required permissions on the Entra ID tenant
       The account running this script must have ONE of the following roles:
         - Global Reader                   (recommended -- least privilege)
         - Privileged Role Administrator   (if you also manage PIM assignments)
         - Security Reader + Privileged Role Reader  (minimum scoped alternative)

       Without the correct permissions, the PIM Eligible export will fail with:
         "403 Forbidden - Insufficient privileges to complete the operation"

    4. Execution policy
       If scripts are blocked on the machine, run once:
         Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

    OUTPUT FORMAT
    ──────────────────────────────────────────────────────────────────────────────
    Semicolon-delimited CSV for European locale Excel (IT, FR, DE, ES).
    Change -Delimiter ";" to "," for US/UK environments.

    Columns:
      AssignmentId    Unique assignment GUID
      PrincipalId     Entra ID Object ID of the user / group / service principal
      PrincipalUPN    UPN, SP name, or PrincipalId as fallback
      PrincipalType   user / group / servicePrincipal
      DisplayName     Display name from Entra ID
      RoleId          Role definition GUID
      RoleName        Role name, or "Unknown Role [GUID]" if orphaned
      AssignmentType  Active or Eligible
      StartDateTime   Assignment start (Eligible only)
      EndDateTime     Assignment expiry -- empty means no expiry configured
      Scope           Directory scope (/, admin unit, etc.)
      IsEXT           True if UPN matches external pattern (#EXT# or _ext_)
      ExportDate      Timestamp of the export run

.PARAMETER OutputPath
    Full path for the output CSV file.
    Defaults to .\EntraID_RBAC_Export_YYYYMMDD.csv in the current directory.

.PARAMETER IncludePIM
    When $true (default), exports both Active and PIM Eligible assignments.
    Set to $false to export Active assignments only.

.PARAMETER WhatIf
    Performs a connection and role cache test only. No file is written to disk.

.EXAMPLE
    .\EntraID-RBAC-Export.ps1
    Connects to the tenant and exports all assignments to the current directory.

.EXAMPLE
    .\EntraID-RBAC-Export.ps1 -IncludePIM:$false
    Exports Active assignments only.

.EXAMPLE
    .\EntraID-RBAC-Export.ps1 -OutputPath "C:\Exports\rbac_snapshot.csv"
    Exports to a custom path.

.EXAMPLE
    .\EntraID-RBAC-Export.ps1 -WhatIf
    Tests connectivity and role cache without writing any file.

.NOTES
    Version : 1.2.0
    Requires: Microsoft.Graph modules >= 2.0, PowerShell 5.1+

.LINK
    https://learn.microsoft.com/en-us/graph/api/rbacapplication-list-roleassignments
    https://learn.microsoft.com/en-us/graph/api/rbacapplication-list-roleeligibilityschedulerequests
    https://learn.microsoft.com/en-us/defender-xdr/activate-defender-rbac
#>

#Requires -Modules Microsoft.Graph.Authentication, Microsoft.Graph.Identity.Governance, Microsoft.Graph.Users

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$OutputPath = ".\EntraID_RBAC_Export_$(Get-Date -Format 'yyyyMMdd').csv",
    [switch]$IncludePIM = $true
)

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 1 — Connection
# ─────────────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "================================================================" -ForegroundColor DarkBlue
Write-Host "  Entra ID RBAC Export  v1.2.0                                 " -ForegroundColor DarkBlue
Write-Host "  Read-only  |  PS 5.1 + PS 7 compatible                       " -ForegroundColor DarkBlue
Write-Host "================================================================" -ForegroundColor DarkBlue
Write-Host ""

Connect-MgGraph -Scopes @(
    'RoleManagement.Read.All',
    'User.Read.All',
    'Directory.Read.All',
    'PrivilegedEligibilitySchedule.Read.AzureADGroup'
) -NoWelcome

$context = Get-MgContext
Write-Host "Connected as : $($context.Account)" -ForegroundColor Green
Write-Host "Tenant ID    : $($context.TenantId)" -ForegroundColor Green
Write-Host ""

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 2 — Role definition cache
#
# All role definitions are downloaded ONCE and stored in a hashtable keyed by Id.
# This eliminates one Graph API call per assignment, which is critical for
# tenants with hundreds or thousands of role assignments.
# ─────────────────────────────────────────────────────────────────────────────
Write-Host "Caching role definitions..." -ForegroundColor Gray
$roleDefinitions = Get-MgRoleManagementDirectoryRoleDefinition -All |
    Group-Object -Property Id -AsHashTable

Write-Host "  Cached $($roleDefinitions.Count) role definitions." -ForegroundColor Gray
Write-Host ""

# Early exit for -WhatIf: connection and cache test only, no file written
if ($WhatIfPreference) {
    Write-Host "[WhatIf] Connection OK. Role cache loaded. No export will be written." -ForegroundColor Yellow
    Disconnect-MgGraph | Out-Null
    return
}

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 3 — Output list and shared timestamp
# ─────────────────────────────────────────────────────────────────────────────
$output = [System.Collections.Generic.List[PSCustomObject]]::new()
$now    = Get-Date -Format 'yyyy-MM-dd HH:mm'

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 4 — Mapping function
#
# Processes one assignment object (Active or Eligible) and appends a
# normalised row to $output.
#
# Identity resolution priority (PS 5.1 compatible -- no ?? operator):
#   1. userPrincipalName        -- standard user accounts
#   2. servicePrincipalNames[0] -- service principals / app registrations
#   3. PrincipalId (GUID)       -- fallback for managed identities / unknown types
#
# Orphan guard:
#   Role IDs not present in the cache (deleted or recently created custom roles)
#   produce "Unknown Role [<GUID>]" instead of throwing an exception.
# ─────────────────────────────────────────────────────────────────────────────
function Add-ToOutput {
    param(
        [Parameter(Mandatory)][object]$Assignment,
        [Parameter(Mandatory)][ValidateSet('Active','Eligible')][string]$Type
    )

    $props = $Assignment.Principal.AdditionalProperties

    # Identity resolution
    $upn = if ($props['userPrincipalName']) {
               $props['userPrincipalName']
           } elseif ($props['servicePrincipalNames']) {
               $props['servicePrincipalNames'][0]
           } else {
               $Assignment.PrincipalId
           }

    # Orphan guard
    $roleName = if ($roleDefinitions.ContainsKey($Assignment.RoleDefinitionId)) {
                    $roleDefinitions[$Assignment.RoleDefinitionId].DisplayName
                } else {
                    "Unknown Role [$($Assignment.RoleDefinitionId)]"
                }

    $output.Add([PSCustomObject]@{
        AssignmentId   = $Assignment.Id
        PrincipalId    = $Assignment.PrincipalId
        PrincipalUPN   = $upn
        PrincipalType  = ($props['@odata.type'] -replace '#microsoft.graph.', '')
        DisplayName    = $props['displayName']
        RoleId         = $Assignment.RoleDefinitionId
        RoleName       = $roleName
        AssignmentType = $Type
        StartDateTime  = if ($Type -eq 'Eligible') { $Assignment.ScheduleInfo.StartDateTime } else { '' }
        EndDateTime    = if ($Type -eq 'Eligible') { $Assignment.ScheduleInfo.Expiration.EndDateTime } else { '' }
        Scope          = $Assignment.DirectoryScopeId
        IsEXT          = ($upn -match '#EXT#|_ext_')
        ExportDate     = $now
    })
}

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 5 — Export Active assignments
#
# Pipeline + ForEach-Object for memory efficiency: Graph API objects are
# processed one at a time as they stream in, avoiding a full in-memory load
# before iteration. Recommended for large tenants.
# ─────────────────────────────────────────────────────────────────────────────
Write-Host "[1/3] Exporting ACTIVE role assignments..." -ForegroundColor Cyan
Get-MgRoleManagementDirectoryRoleAssignment -All -ExpandProperty Principal |
    ForEach-Object { Add-ToOutput -Assignment $_ -Type 'Active' }

Write-Host "      Active assignments exported: $($output.Count)" -ForegroundColor Gray

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 6 — Export PIM Eligible assignments (optional)
#
# Requires the PrivilegedEligibilitySchedule.Read.AzureADGroup scope.
# Use -IncludePIM:$false if the running account lacks PIM read permissions.
# ─────────────────────────────────────────────────────────────────────────────
if ($IncludePIM) {
    $countBefore = $output.Count
    Write-Host "[2/3] Exporting PIM ELIGIBLE assignments..." -ForegroundColor Cyan
    Get-MgRoleManagementDirectoryRoleEligibilitySchedule -All -ExpandProperty Principal |
        ForEach-Object { Add-ToOutput -Assignment $_ -Type 'Eligible' }

    Write-Host "      PIM Eligible assignments exported: $($output.Count - $countBefore)" -ForegroundColor Gray
} else {
    Write-Host "[2/3] PIM Eligible export skipped (-IncludePIM:`$false)." -ForegroundColor DarkGray
}

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 7 — Save to CSV
#
# Semicolon delimiter for European locale Excel (IT, FR, DE, ES).
# Change to -Delimiter "," for US/UK environments.
# ─────────────────────────────────────────────────────────────────────────────
Write-Host "[3/3] Saving to $OutputPath..." -ForegroundColor Cyan
$output | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8 -Delimiter ";"

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 8 — Summary
# ─────────────────────────────────────────────────────────────────────────────
$unknownRoles = ($output | Where-Object { $_.RoleName -like 'Unknown Role*' }).Count
$extAccounts  = ($output | Where-Object { $_.IsEXT -eq $true }).Count

Write-Host ""
Write-Host "================================================================" -ForegroundColor DarkBlue
Write-Host " Export complete" -ForegroundColor Green
Write-Host "----------------------------------------------------------------" -ForegroundColor DarkBlue
Write-Host " Total records      : $($output.Count)"
Write-Host " EXT accounts       : $extAccounts"
Write-Host " Orphaned roles     : $unknownRoles"
Write-Host " Output file        : $OutputPath"
Write-Host "================================================================" -ForegroundColor DarkBlue
Write-Host ""

if ($unknownRoles -gt 0) {
    Write-Warning "$unknownRoles assignment(s) reference role IDs not found in the cache."
    Write-Warning "These are exported as 'Unknown Role [GUID]' -- verify in Entra ID."
}

Disconnect-MgGraph | Out-Null
Write-Host "Disconnected from Microsoft Graph." -ForegroundColor Gray
