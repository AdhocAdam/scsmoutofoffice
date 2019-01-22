<#
.SYNOPSIS
Sync Out of Office information from Exchange into Service Manager

.DESCRIPTION
You can use this script to loop through your Exchange environment and sync all mailboxes OOO status
into SCSM having once imported the class extensions (AdhocAdam.System.Domain.User.OOOExtension.mp) to do so. This
leverages the SMletsExchangeConnector's Get-SCSMUserByEmailAddress function to perform the user lookup.
#>

function Get-SCSMUserByEmailAddress ($EmailAddress)
{
    $notificationClass = Get-SCSMClass -name "System.Notification.Endpoint$"
    $userSMTPNotification = Get-SCSMObject -Class $notificationClass -Filter "TargetAddress -eq '$EmailAddress'" | Sort-Object lastmodified -Descending | Select-Object -first 1

    if ($userSMTPNotification) 
    { 
        $user = Get-SCSMObject -id (Get-SCSMRelationshipObject -ByTarget $userSMTPNotification).sourceObject.id
        return $user
    }
    else
    {
        return $null
    }
}

#load mailboxes, loop through to determine their OOO state, set accordingly on SCSM objects
$allMailboxes = Get-Mailbox | Select-Object Identity, PrimarySMTPAddress
foreach ($mailbox in $allMailboxes)
{  
    $mailboxOOO = Get-MailboxAutoReplyConfiguration -Identity $mailbox.identity
    $scsmUser = Get-SCSMUserByEmailAddress -EmailAddress $mailbox.PrimarySMTPAddress
    if ($scsmUser)
    {
        if ($mailboxOOO.AutoReplyState -eq "Disabled") {$isOutOfOffice = $false} else {$isOutOfOffice = $true}
        Set-SCSMObject -SMObject $scsmUser -PropertyHashtable @{"OutOfOffice" = $isOutOfOffice; "OutOfOfficeStartDate" = $mailboxOOO.StartTime.ToUniversalTime(); "OutOfOfficeEndDate" = $mailboxOOO.EndTime.ToUniversalTime(); }
    }
}
