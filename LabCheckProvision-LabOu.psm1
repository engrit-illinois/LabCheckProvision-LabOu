# Documentation home: https://github.com/engrit-illinois/LabCheckProvision-LabOu
# By mseng3

function LabCheckProvision-LabOu {

	param(
		[Parameter(Position=0,Mandatory=$true)]
		[string]$LabOudn,
		
		[Parameter(ParameterSetName="Provision")]
		[switch]$Provision,
		
		[Parameter(ParameterSetName="Covidize")]
		[switch]$Covidize,
		
		[Parameter(ParameterSetName="Uncovidize")]
		[switch]$Uncovidize,
		
		[Parameter(ParameterSetName="Deprovision")]
		[switch]$Deprovision,
		
		[int]$Delay=30,
		
		[switch]$TestRun
	)

	function log {
		param (
			[Parameter(Position=0)]
			[string]$Msg = "",

			[int]$L = 0
		)

		for($i = 0; $i -lt $L; $i += 1) {
			$Msg = "    $Msg"
		}

		$ts = Get-Date -Format "HH:mm:ss"
		$Msg = "[$ts] $Msg"

		Write-Host $Msg
	}
	
	function Log-Object {
		param(
			[PSObject]$Object,
			[string]$Format = "Table",
			[int]$L = 0
		)
		
		switch($Format) {
			"List" { $string = ($object | Format-List | Out-String) }
			Default { $string = ($object | Format-Table -AutoSize | Out-String) }
		}
		$string = $string.Trim()
		$lines = $string -split "`n"

		$params = @{
			L = $L
		}

		foreach($line in $lines) {
			$params["Msg"] = $line
			log @params
		}
	}
	
	function Delay($L) {
		log "Waiting $Delay seconds for DC sync..." -L $L
		Start-Sleep -Seconds $Delay
	}
	
	function Create-Ou($name, $parent) {
		log "Creating OU `"$name`" in parent `"$parent`"..." -L 1
		
		$oudn = "OU=$name,$parent"
				
		if(Test-OuExists $parent) {
			log "Parent OU exists." -L 2
			
			if(Test-OuExists $oudn) {
				log "OU already exists." -L 2
			}
			else {
				if($TestRun) {
					log "Skipping OU creation because -TestRun was specified." -L 2
				}
				else {
					log "Creating OU..." -L 2
					New-ADOrganizationalUnit -Name $name -Path $parent | Out-Null
					Delay -L 2
				}
				
			}
		}
		else {
			log "Parent OU doesn't exist: `"$parent`"!" -L 2
		}
	}
	
	function Link($name, $oudn) {
		log "Linking GPO `"$name`" to OU `"$oudn`"..." -L 1
		
		if(Test-GPOLinked $name $oudn) {
			log "GPO already linked." -L 2
		}
		else {
			if($TestRun) {
				log "Skipping link creation because -TestRun was specified." -L 2
			}
			else {
				log "Creating link..." -L 2
				New-GPLink -Name $name -Target $oudn | Out-Null
				#Delay
			}
		}
	}
	
	function Unlink($name, $oudn, $L=1) {
		log "Unlinking GPO `"$name`" from OU `"$oudn`"..." -L $L
		
		if(-not (Test-GPOLinked $name $oudn)) {
			log "Link not found." -L ($L + 1)
		}
		else {
			if($TestRun) {
				log "Skipping link deletion because -TestRun was specified." -L ($L + 1)
			}
			else {
				log "Deleting link..." -L ($L + 1)
				Remove-GPLink -Name $name -Target $oudn | Out-Null
				#Delay
			}
		}
	}
	
	function Delete-Ou($oudn) {
		log "Removing OU `"$oudn`"..." -L 2
		
		if(Test-OuExists $oudn) {
			if($TestRun) {
				log "Skipping OU deletion because -TestRun was specified." -L 3
			}
			else {
				log "Removing `"Prevent object from accidental deletion`" setting from OU `"$oudn`"..." -L 3
				Set-ADObject -ProtectedFromAccidentalDeletion $false -Identity $oudn | Out-Null
				Delay -L 3
				log "Removing OU..." -L 3
				Remove-ADOrganizationalUnit -Identity $oudn -Confirm:$false | Out-Null
				Delay -L 3
			}
		}
		else {
			log "OU `"$oudn`" not found!" -L 3
		}
	}
	
	function Test-OuExists($oudn) {
		#log "Testing if ou exists: `"$oudn`"..."
		try {
			Get-ADOrganizationalUnit -Identity $oudn | Out-Null
			#log "OU exists."
			$ouExists = $true
		}
		catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
			#log "OU does not exist."
			$ouExists = $false
		}
		$ouExists
	}
	
	function Test-GPOLinked($gpo, $ou) {
		# https://community.spiceworks.com/topic/2197327-powershell-script-to-get-gpo-linked-to-ou-and-its-child-ou
		$links = Get-ADOrganizationalUnit $ou | Select -ExpandProperty LinkedGroupPolicyObjects
		$guids = $links | ForEach-Object { $_.Substring(4,36) }
		$names = ($guids | ForEach-Object { Get-GPO -Guid $_ | Select DisplayName }).DisplayName
		$result = $names -contains $gpo
		$result
	}
	
	function Provision($remoteEnabledOudn, $localDisabledOudn) {
		log "Provisioning..."
		
		# RemoteEnabled sub-OU
		Create-Ou "RemoteEnabled" $LabOudn
		Link "ENGR EWS RDU $lab" $remoteEnabledOudn
		
		# LocalLoginDisabled (i.e. Remote-Only) sub-OU
		Create-Ou "LocalLoginDisabled" $remoteEnabledOudn
		Link "ENGR EWS Restrict local login to admins" $localDisabledOudn
	}
	
	function Covidize($remoteEnabledOudn, $localDisabledOudn) {
		log "Covidizing..."
		
		# Root lab OU
		Link "ENGR EWS COVID Local-Only Desktop-Lockscreen Background" $LabOudn
		Link "ENGR EWS COVID Local-Only Login Message" $LabOudn
		
		# RemoteEnabled sub-OU
		Link "ENGR EWS General Lab Desktop-Lockscreen Background" $remoteEnabledOudn
		Link "ENGR EWS COVID Remote-Enabled (i.e. no) Login Message" $remoteEnabledOudn
		
		# LocalLoginDisabled (i.e. Remote-Only) sub-OU
		Link "ENGR EWS COVID Remote-Only Desktop-Lockscreen Background" $localDisabledOudn
		Link "ENGR EWS COVID Remote-Only Login Message" $localDisabledOudn
	}
		
	function Uncovidize($remoteEnabledOudn, $localDisabledOudn) {
		log "Uncovidizing..."
		
		# Root lab OU
		Unlink "ENGR EWS COVID Local-Only Desktop-Lockscreen Background" $LabOudn
		Unlink "ENGR EWS COVID Local-Only Login Message" $LabOudn
		
		# RemoteEnabled sub-OU
		Unlink "ENGR EWS General Lab Desktop-Lockscreen Background" $remoteEnabledOudn
		Unlink "ENGR EWS COVID Remote-Enabled (i.e. no) Login Message" $remoteEnabledOudn
		
		# LocalLoginDisabled (i.e. Remote-Only) sub-OU
		Unlink "ENGR EWS COVID Remote-Only Desktop-Lockscreen Background" $localDisabledOudn
		Unlink "ENGR EWS COVID Remote-Only Login Message" $localDisabledOudn
	}
	
	function Deprovision($remoteEnabledOudn, $localDisabledOudn) {
		log "Deprovisioning..."
		
		if(Test-OuExists $remoteEnabledOudn) {
			# Check for objects in RemoteEnabled and LocalLoginDisabled OUs
			log "Checking for child objects in the RemoteEnabled OU..." -L 1
			
			$objects = Get-ADObject -Filter "*" -SearchBase $remoteEnabledOudn
			$objects = $objects | Where { ($_.DistinguishedName -ne $remoteEnabledOudn) -and ($_.DistinguishedName -ne $localDisabledOudn) }
			log "Found $(@($objects).count) child objects (excluding the RemoteEnabled OU itself and the LocalLoginDisabled OU)." -L 2
			
			if(@($objects).count -gt 0) {
				$objectsOutput = $objects | Select ObjectClass,Name,@{Name="DistinguishedName";Expression={$_.DistinguishedName -replace "OU=Desktops,OU=Engineering,OU=Urbana,DC=ad,DC=uillinois,DC=edu","..."}} | Sort ObjectClass,Name
				Log-Object $objectsOutput -L 3
				log ""
				log "This script is currently too dumb to move these objects. Please move them outside of the RemoteEnabled OU and try again." -L 2
			}
			else {
				log "Removing RemoteEnabled and LocalLoginDisabled OUs..." -L 1
				Delete-Ou $localDisabledOudn
				Delete-Ou $remoteEnabledOudn
				
				log "Unlinking any remaining Covid GPOs from the root lab OU, if they exist..." -L 1
				Unlink "ENGR EWS COVID Local-Only Desktop-Lockscreen Background" $LabOudn 2
				Unlink "ENGR EWS COVID Local-Only Login Message" $LabOudn 2
			}
		}
		else {
			log "RemoteEnabled OU not found!" -L 1
		}
	}
	
	function Do-Stuff {
		if(Test-OuExists $LabOudn) {
			log "OUs:"
			$labOuParts = $LabOudn.Split(",")
			$lab = $labOuParts[0].Split("=")[1]
			log "Lab OU name: `"$lab`"." -L 1
			log "Lab OUDN: `"$LabOudn`"." -L 1
			
			$remoteEnabledOudn = "OU=RemoteEnabled,$LabOudn"
			log "RemoteEnabled OUDN: `"$remoteEnabledOudn`"." -L 1
			
			$localDisabledOudn = "OU=LocalLoginDisabled,$remoteEnabledOudn"
			log "LocalLoginDisabled OUDN: `"$localDisabledOudn`"." -L 1
	
			if($Provision) { Provision $remoteEnabledOudn $localDisabledOudn }
			elseif($Covidize) { Covidize $remoteEnabledOudn $localDisabledOudn }
			elseif($Uncovidize) { Uncovidize $remoteEnabledOudn $localDisabledOudn }
			elseif($Deprovision) { Deprovision $remoteEnabledOudn $localDisabledOudn }
			else { log "No action switch was specified!" }
		}
		else {
			log "Given lab OUDN not found!"
		}
	}
	
	Do-Stuff
	
	log "EOF"
}