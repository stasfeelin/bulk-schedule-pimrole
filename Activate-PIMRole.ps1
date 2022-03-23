##
# Do not Forget to install PS modules if you use it for the first time!
# To do so uncomment two string bellow 
##

#Install-Module -Name AzureRM -AllowClobber
#Install-Module AzureADPreview # Note PIM commandlets are currently available only in preview version


$daysNum = 30	# max number of scheduled activations is 30
$Duration = 10	# time in role in hours per activation, max value may vary; you can check it in PIM on azure portal
# Set Start Day on tomorrow at 9AM local time
$startDayTime = (Get-Date).AddDays(1).Date.AddHours(9) 

## Use following way to set startDayTime to have more precise starting point for role activation ###
# $startDayTime = '11/22/2020 9:25AM'

## to vialoate Just-In-Time control not too much you would want to skip weekends ###
$skipWeekends = $TRUE

# Login and fetch some service variables
Login-AzureRmAccount
$currentAzureContext = Get-AzureRmContext
$TenantID = $currentAzureContext.Tenant.Id
$accountId = $currentAzureContext.Account.Id
Connect-AzureAD -TenantId $TenantID -AccountId $accountId

$user = Get-AzureADUser -SearchString $currentAzureContext.Account

# Getting all your eligible roles, writing them in an array, and ask in a terminal which one you want to activate
$rolestable = @(); $roles = @()
$assignments = Get-AzureADMSPrivilegedRoleAssignment -ProviderId "aadRoles" -ResourceId $TenantID -Filter "subjectId eq '$($user.ObjectId)'" | select RoleDefinitionId -Unique
foreach ($each in $assignments) { $roles += Get-AzureADDirectoryRoleTemplate | ? { $_.ObjectID -eq $each.RoleDefinitionId }}
$roles | % {$row = "" | Select Index, Role; $row.Role = $_.DisplayName; $row.Index = $roles.IndexOf($_); $rolestable += $row}
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
		Open-AzureADMSPrivilegedRoleAssignmentRequest`
			-ProviderId 'aadRoles'`
			-ResourceId $TenantID`
			-RoleDefinitionId $role.ObjectId`
			-SubjectId $user.ObjectId`
			-Type 'UserAdd'`
			-AssignmentState'Active'`
			-schedule $schedule`
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
