$confirm = $False
$count = 0

 

$UserName = Read-Host "Enter Username to change or EXIT to cancel"
if($UserName.ToUpper() -eq "EXIT")
{
    Write-Host "User canceled script." -ForegroundColor Red
    Exit
}

 

$OldPassword = Read-Host "Enter OLD Password" -AsSecureString

 

while ($confirm -eq $false)
{
    $NewPassword = Read-Host "Enter NEW Password" -AsSecureString
    $NewPasswordConfirm = Read-Host "Confirm NEW Password: " -AsSecureString
    $plainNewPwd = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($NewPassword))
    $plainNewPwdConf = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($NewPasswordConfirm))
    
    if($plainNewPwd -eq $plainNewPwd)
    {
        $confirm = $true
    }
    else
    {
        Write-Host "Unable to confirm try again." -ForegroundColor Red
        $count++
        if($count -eq 3)
        {
            Write-Host "Unable to confirm password exiting script." -ForegroundColor Red
            Exit
        }
    }
}

 

$DomainController = Read-Host "Enter Domain"

 

$plainOldPwd = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($OldPassword))
$plainNewPwd = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($NewPassword))

 

$DllImport = @'
[DllImport("netapi32.dll", CharSet = CharSet.Unicode)]
public static extern bool NetUserChangePassword(string domain, string username, string oldpassword, string newpassword);
'@

 

$NetApi32 = Add-Type -MemberDefinition $DllImport -Name 'NetApi32' -Namespace 'Win32' -PassThru

 

if ($result = $NetApi32::NetUserChangePassword($DomainController, $UserName, $plainOldPwd, $plainNewPwd))
{
    Write-Host "Password change failed. Please try again." -ForegroundColor Red
}
else 
{
    Write-Host "Password change succeeded." -BackgroundColor Green -ForegroundColor White
}

 

$plainOldPwd = $null
$plainNewPwd = $null