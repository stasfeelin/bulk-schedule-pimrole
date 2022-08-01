function CheckInstall-Module
{
	<#
	.SYNOPSIS
	This Funciton check if you have Module installed and tries to install it if it's not.
	.DESCRIPTION
	ModuleName is a required parameter
	.PARAMETER ModuleName
	Required paramter. ModuleName to check whther this Module is installed.
	#>
	param(
		[Parameter(Mandatory=$true)]
		[string]$ModuleName
	)

	if (-not (Get-Module -ListAvailable $ModuleName).path){
		Write-Host "The $($ModuleName) Module is not installed, we will try to install it now" -ForegroundColor Yellow
		#write-Host "This will only work if you are running this script as Local Administrator" -ForegroundColor Yellow
		Write-Host
		Install-Module -Name $ModuleName
	}
	# TODO: Add Error handler to see if the ModuleName exists and can be found in PSGallery
	# TODO: Add Check for local Admin rights required to install ModuleName

	<#	Local Admin check part in case it required to install some module. TODO: Check if it's required.
	# Check if the script runs in an local Administrator context
    If ($(([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) -eq $True)
        {Install-Module -Name Microsoft.Azure.ActiveDirectory.PIM.PSModule} 
    
    # Exit if PowerShell if not run as admin
    Else
	{
		Write-Host "You are not running the script as Local Admin. The script will exit now" -ForegroundColor Yellow
    	Exit
	}
#>
}
# Checking for modules required
# TODO: Check if AzureAD isntalled - might generate conflict as you can have either AzureAD or AzureADPreview installed accotding to MS docs: https://docs.microsoft.com/en-us/powershell/azure/active-directory/install-adv2?view=azureadps-2.0#installing-the-azure-ad-module
CheckInstall-Module -ModuleName Az.Accounts
CheckInstall-Module -ModuleName AzureADPreview # NOTE: PIM commandlets are currently available only in preview version

$daysNum = 30	# max number of scheduled activations is 30
$Duration = 10	# time in role in hours per activation, max value may vary; you can check it in PIM on azure portal
# Set Start Day on tomorrow at 9AM local time
$startDayTime = (Get-Date).AddDays(1).Date.AddHours(9) 

## Use following way to set startDayTime to have more precise starting point for role activation ###
# $startDayTime = '11/22/2020 9:25AM'

## to vialoate Just-In-Time control not too much you would want to skip weekends ###
$skipWeekends = $TRUE

# Login and fetch some service variables
Import-Module Az
Connect-AzAccount
$currentAzureContext = Get-AzContext
$TenantID = $currentAzureContext.Tenant.Id
$accountId = $currentAzureContext.Account.Id
Connect-AzureAD -TenantId $TenantID -AccountId $accountId

$user = Get-AzureADUser -SearchString $currentAzureContext.Account

# Getting all your eligible roles, writing them in an array, and ask in a terminal which one you want to activate
$rolestable = @(); $roles = @()
$assignments = Get-AzureADMSPrivilegedRoleAssignment -ProviderId "aadRoles" -ResourceId $TenantID -Filter "subjectId eq '$($user.ObjectId)'" | select RoleDefinitionId -Unique
foreach ($each in $assignments) { $roles += Get-AzureADDirectoryRoleTemplate | ? { $_.ObjectID -eq $each.RoleDefinitionId }}
$roles | % {$row = "" | Select Index, Role; $row.Role = $_.DisplayName; $row.Index = $roles.IndexOf($_); $rolestable += $row}

$repeat = "y" # initial repeat flag for first iteration of following while loop
while ($repeat -eq "y"){ # while loop to schedule multiple roles one by one if required
	Write $rolestable

	$selectedRole = [int](Read-Host "Enter Index to select activating Role")

	$role = $roles | ? { $_.DisplayName -eq $rolestable[$selectedRole].Role }

	$reason = Read-Host "Enter reason (max 500 characters)"

	# setting up start date and the last date
	$StartDate = [DateTime](Get-Date -Date $startDayTime -Format "dddd MM/dd/yyyy HH:mm")
	$LastDate = $StartDate.AddDays($daysNum)

	# here's where all the magic happens
	While($StartDate -ne $LastDate)
	{

		$schedule = New-Object Microsoft.Open.MSGraph.Model.AzureADMSPrivilegedSchedule
		$schedule.Type = "Once"
		$schedule.StartDateTime = $StartDate.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ") 
		$schedule.endDateTime = $schedule.StartDateTime.AddHours(10)
		try 
		{
			Open-AzureADMSPrivilegedRoleAssignmentRequest `
				-ProviderId 'aadRoles' `
				-ResourceId $TenantID `
				-RoleDefinitionId $role.ObjectId `
				-SubjectId $user.ObjectId `
				-Type 'UserAdd' `
				-AssignmentState 'Active' `
				-schedule $schedule `
				-reason $reason
		} catch { Write-Warning $_ ; break}

		If ( $skipWeekends -and ( $StartDate.DayOfWeek.value__ -eq 5 ) ) 
		{
			"$StartDate TGIF; Have a nice weekend without PIM roles ;)";
			$StartDate = $StartDate.AddDays(3)
			Continue 
		} else {
			$StartDate = $StartDate.AddDays(1)
		}
	}
	$repeat = Read-Host "Enter `"y`" if you want to schedule another role. To exit hit Enter"
}