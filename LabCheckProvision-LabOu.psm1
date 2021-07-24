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
	
	function Delay {
		log "Waiting $Delay seconds for DC sync..." -L 2
		Start-Sleep -Seconds $Delay
	}
	
	function Create-OU($name, $parent) {
		log "Creating OU `"$name`" in parent `"$parent`"..." -L 1
		
		$ou = "OU=$name,$parent"
				
		if(Test-OUExists $parent) {
			log "Parent OU exists." -L 2
			
			if(Test-OUExists $ou) {
				"OU already exists." -L 2
			}
			else {
				if($TestRun) {
					log "Skipping OU creation because -TestRun was specified." -L 2
				}
				else {
					log "Creating OU..." -L 2
					New-ADOrganizationalUnit -Name $name -Path $parent | Out-Null
				}
				log "Done." -L 2
				Delay
			}
		}
		else {
			log "Parent OU doesn't exist: `"$parent`"!" -L 2
		}
	}
	
	function Link($name, $ou) {
		log "Linking GPO `"$name`" to OU `"$ou`"..." -L 1
		
		if(Test-GPOLinked $name $ou) {
			log "GPO already linked." -L 2
		}
		else {
			if($TestRun) {
				log "Skipping link creation because -TestRun was specified." -L 2
			}
			else {
				log "Creating link..." -L 2
				New-GPLink -Name $name -Target $ou | Out-Null
			}
			log "Done." -L 2
			#Delay
		}
	}
	
	function Unlink($name, $ou) {
		log "Unlinking GPO `"$name`" from OU `"$ou`"..." -L 1
		
		if(-not (Test-GPOLinked $name $ou)) {
			log "Link not found." -L 2
		}
		else {
			if($TestRun) {
				log "Skipping link deletion because -TestRun was specified." -L 2
			}
			else {
				log "Deleting link..." -L 2
				Remove-GPLink -Name $name -Target $ou | Out-Null
			}
			log "Done." -L 2
			#Delay
		}
	}
	
	function Test-OUExists($ou) {
		#log "Testing if ou exists: `"$ou`"..."
		try {
			Get-ADOrganizationalUnit -Identity $ou | Out-Null
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
		Make "RemoteEnabled" $LabOudn
		Link "ENGR EWS $lab RDU" $remoteEnabledOudn
		
		# LocalLoginDisabled (i.e. Remote-Only) sub-OU
		Make "LocalLoginDisabled" $remoteEnabledOudn
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
	
	function Uncovidize($remoteEnabledOu, $localDisabledOu) {
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
	
	function Deprovision($remoteEnabledOu, $localDisabledOu) {
		log "Deprovisioning..."
		log "Not implemented yet!" -L 1
	}
	
	function Do-Stuff {
		if(Test-OUExists $LabOudn) {
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