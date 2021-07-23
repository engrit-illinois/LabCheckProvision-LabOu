# Documentation home: https://github.com/engrit-illinois/Covidize-LabOU
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
	
	function log($msg) {
		Write-Host $msg
	}
	
	function Delay {
		log "    Waiting $Delay seconds for DC sync..."
		Start-Sleep -Seconds $Delay
	}
	
	function Make($name, $parent) {
		$ou = "OU=$name,$parent"
		#log "    Making ou: `"$ou`"..."
		
		if(Test-OUExists $parent) {
			log "    Parent OU exists."
			
			if(Test-OUExists $ou) {
				"    OU already exists."
			}
			else {
				if($TestRun) {
					log "Skipping OU creation because -TestRun was specified."
				}
				else {
					log "Creating OU..."
					New-ADOrganizationalUnit -Name $name -Path $parent | Out-Null
				}
				log "    Done."
				Delay
			}
		}
		else {
			log "    Parent OU doesn't exist: `"$parent`"!"
		}
	}
	
	function Link($name, $ou) {
		if(Test-GPOLinked $name $ou) {
			log "    GPO already linked."
		}
		else {
			if($TestRun) {
				log "Skipping link creation because -TestRun was specified."
			}
			else {
				log "Creating link..."
				New-GPLink -Name $name -Target $ou | Out-Null
			}
			log "    Done."
			#Delay
		}
	}
	
	function Unlink($name, $ou) {
		if(-not (Test-GPOLinked $name $ou)) {
			log "    GPO not linked to begin with."
		}
		else {
			if($TestRun) {
				log "Skipping link deletion because -TestRun was specified."
			}
			else {
				log "Deleting link..."
				New-GPLink -Name $name -Target $ou | Out-Null
			}
			log "    Done."
			#Delay
		}
	}
	
	function Test-OUExists($ou) {
		#log "Testing if ou exists: `"$ou`"..."
		try {
			Get-ADOrganizationalUnit -Identity $ou | Out-Null
			#log "    OU exists."
			$ouExists = $true
		}
		catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
			#log "    OU does not exist."
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
		# RemoteEnabled sub-OU
		log "Creating RemoteEnabled OU..."
		Make "RemoteEnabled" $LabOudn
		
		log "Linking access GPO to RemoteEnabled OU..."
		Link "ENGR EWS $lab RDU" $remoteEnabledOudn
		
		# LocalLoginDisabled (i.e. Remote-Only) sub-OU
		log "Creating LocalLoginDisabled OU..."
		Make "LocalLoginDisabled" $remoteEnabledOudn
		
		log "Linking access GPO to LocalLoginDisabled OU..."
		Link "ENGR EWS Restrict local login to admins" $localDisabledOudn
	}
	
	function Covidize($remoteEnabledOudn, $localDisabledOudn) {
		# Root lab OU
		log "Linking background GPO to root lab OU..."
		Link "ENGR EWS COVID Local-Only Desktop-Lockscreen Background" $LabOudn
		
		log "Linking login message GPO to root lab OU..."
		Link "ENGR EWS COVID Local-Only Login Message" $LabOudn
		
		# RemoteEnabled sub-OU
		log "Linking background GPO to RemoteEnabled OU..."
		Link "ENGR EWS General Lab Desktop-Lockscreen Background" $remoteEnabledOudn
		
		log "Linking login message GPO to RemoteEnabled OU..."
		Link "ENGR EWS COVID Remote-Enabled (i.e. no) Login Message" $remoteEnabledOudn
		
		# LocalLoginDisabled (i.e. Remote-Only) sub-OU
		log "Linking background GPO to LocalLoginDisabled OU..."
		Link "ENGR EWS COVID Remote-Only Desktop-Lockscreen Background" $localDisabledOudn
		
		log "Linking login message GPO to LocalLoginDisabled OU..."
		Link "ENGR EWS COVID Remote-Only Login Message" $localDisabledOudn
	}
	
	function Uncovidize($remoteEnabledOu, $localDisabledOu) {
		# Root lab OU
		log "Unlinking background GPO from root lab OU..."
		Unlink "ENGR EWS COVID Local-Only Desktop-Lockscreen Background" $LabOudn
		
		log "Unlinking login message GPO from root lab OU..."
		Unlink "ENGR EWS COVID Local-Only Login Message" $LabOudn
		
		# RemoteEnabled sub-OU
		log "Unlinking background GPO from RemoteEnabled OU..."
		Unlink "ENGR EWS General Lab Desktop-Lockscreen Background" $remoteEnabledOudn
		
		log "Unlinking login message GPO from RemoteEnabled OU..."
		Unlink "ENGR EWS COVID Remote-Enabled (i.e. no) Login Message" $remoteEnabledOudn
		
		# LocalLoginDisabled (i.e. Remote-Only) sub-OU
		log "Unlinking background GPO from LocalLoginDisabled OU..."
		Unlink "ENGR EWS COVID Remote-Only Desktop-Lockscreen Background" $localDisabledOudn
		
		log "Unlinking login message GPO from LocalLoginDisabled OU..."
		Unlink "ENGR EWS COVID Remote-Only Login Message" $localDisabledOudn
		
	}
	
	function Deprovision($remoteEnabledOu, $localDisabledOu) {
		log "Not implemented yet!"
	}
	
	function Do-Stuff {
		if(Test-OUExists $LabOudn) {
			$labOuParts = $LabOudn.Split(",")
			$lab = $labOuParts[0].Split("=")[1]
			log "Lab OU name: `"$lab`"."
			
			$remoteEnabledOudn = "OU=RemoteEnabled,$LabOudn"
			log "RemoteEnabled OUDN: `"$remoteEnabledOudn`"."
			
			$localDisabledOudn = "OU=LocalLoginDisabled,$remoteEnabledOudn"
			log "LocalLoginDisabled OUDN: `"$localDisabledOudn`"."
	
			if($Provision) { Provision $remoteEnabledOudn, $localDisabledOudn }
			elseif($Covidize) { Covidize $remoteEnabledOudn, $localDisabledOudn }
			elseif($Uncovidize) { Uncovidize $remoteEnabledOudn, $localDisabledOudn }
			elseif($Deprovision) { Deprovision $remoteEnabledOudn, $localDisabledOudn }
			else { log "No action switch was specified!" }
		}
		else {
			log "Given lab OUDN not found!"
		}
	}
	
	Do-Stuff
	
	log "EOF"
}