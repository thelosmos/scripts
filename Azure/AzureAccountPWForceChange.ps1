# Connect first
Connect-MgGraph -Scopes "User.Read.All","User.ReadWrite.All"

$context = Get-MgContext

Write-Host "`n===== GRAPH SESSION =====" -ForegroundColor Cyan
Write-Host "Account: $($context.Account)"
Write-Host "Tenant : $($context.TenantId)"
Write-Host "=========================`n"

# Tenant Confirmation
Write-Host ""
$confirm = Read-Host "Is this information correct? (Y/N)"

if ($confirm -ne "Y") {
    Write-Host "Operation cancelled." -ForegroundColor Cyan
    return
}

# Users to evaluate
$users = @(
"user1",
"user2
)

# 12-hour cutoff
$cutoff = (Get-Date).AddHours(-20)

# Lists
$resetList = @()
$skipList = @()

foreach ($u in $users) {
    try {
        $user = Get-MgUser -UserId $u -Property Id,UserPrincipalName,LastPasswordChangeDateTime

        $lastChangeString = "UNKNOWN"

        if ($null -ne $user.LastPasswordChangeDateTime) {
            $lastChange = [datetime]$user.LastPasswordChangeDateTime
            $lastChangeString = $lastChange.ToString("yyyy-MM-dd HH:mm:ss")

            if ($lastChange -lt $cutoff) {
                $resetList += [PSCustomObject]@{
                    UserPrincipalName = $user.UserPrincipalName
                    LastChange        = $lastChangeString
                    Id                = $user.Id
                }
            }
            else {
                $skipList += [PSCustomObject]@{
                    UserPrincipalName = $user.UserPrincipalName
                    LastChange        = $lastChangeString
                    Id                = $user.Id
                }
            }
        }
        else {
            # No timestamp = force reset
            $resetList += [PSCustomObject]@{
                UserPrincipalName = $user.UserPrincipalName
                LastChange        = "UNKNOWN"
                Id                = $user.Id
            }
        }
    }
    catch {
        Write-Host "Error evaluating $u : $($_.Exception.Message)" -ForegroundColor Red
    }
}

# ✅ Preview
Write-Host ""
Write-Host "===== PREVIEW =====" -ForegroundColor Cyan

Write-Host "`nAccounts that WILL be forced to change password:" -ForegroundColor Yellow
$resetList | ForEach-Object {
    Write-Host (" - {0} (Last change: {1})" -f $_.UserPrincipalName, $_.LastChange)
}

Write-Host "`nAccounts that will be skipped (recent password change):" -ForegroundColor Green
$skipList | ForEach-Object {
    Write-Host (" - {0} (Last change: {1})" -f $_.UserPrincipalName, $_.LastChange)
}

# ✅ Confirmation
Write-Host ""
$confirm = Read-Host "Proceed with password reset + session revoke? (Y/N)"

if ($confirm -ne "Y") {
    Write-Host "Operation cancelled." -ForegroundColor Cyan
    return
}

# ✅ Execute resets
foreach ($user in $resetList) {
    try {
        Write-Host "Forcing reset for $($user.UserPrincipalName)" -ForegroundColor Red

        Update-MgUser -UserId $user.Id -PasswordProfile @{
            ForceChangePasswordNextSignIn = $true
        }

        Revoke-MgUserSignInSession -UserId $user.Id
    }
    catch {
        Write-Host "Error processing $($user.UserPrincipalName) : $($_.Exception.Message)" -ForegroundColor Red
    }
}

# ✅ Revoke sessions for skipped users (recommended)
foreach ($user in $skipList) {
    try {
        Write-Host "Revoking session for $($user.UserPrincipalName)" -ForegroundColor DarkYellow
        Revoke-MgUserSignInSession -UserId $user.Id
    }
    catch {
        Write-Host "Error revoking session for $($user.UserPrincipalName)" -ForegroundColor Red
    }
}

Write-Host "`n✅ Completed." -ForegroundColor Cyan