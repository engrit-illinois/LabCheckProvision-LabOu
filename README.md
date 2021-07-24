# Summary
Takes the OU of an EWS computer lab and adds sub-OUs and links existing GPOs to refactor for standardized remote desktop access, and optionally, COVID social distancing protocols.  
Full documentation is at https://wiki.illinois.edu/wiki/display/engritprivate/EWS+remote+access+to+Windows+labs  

# Usage
1. Download `LabCheckProvision-LabOU.psm1` to `$HOME\Documents\WindowsPowerShell\Modules\LabCheckProvision-LabOU\LabCheckProvision-LabOU.psm1`.
    - The module is now already available for use with your regular account, however it needs to modify AD objects which likely only your SU account will have access to.
2. Make the module available as your SU account: see [here](https://github.com/engrit-illinois/how-to-run-custom-powershell-modules-as-another-user).
3. Run it using the provided examples and documentation below.

# Behavior

### Provisioning
WIP

### Deprovisioning
WIP

### Covidizing
WIP

### Uncovidizing
WIP

### Delays
When an operation depends on the preceeding operation (such as linking a GPO to a newly created OU), a delay is implemented between the operations, to allow for the changes to sync across domain controllers and prevent errors. This delay can be configured using the `-Delay` parameter.  

# Examples

### Provision a lab OU
`LabCheckProvision-LabOU "OU=ECEB9999,OU=EWS,OU=Instructional,OU=Desktops,OU=Engineering,OU=Urbana,DC=ad,DC=uillinois,DC=edu"`

### Deprovision a lab OU
WIP

### Covidize a provisioned lab OU
WIP

### Uncovidize a provisioned lab OU
WIP

# Parameters

### -LabOUDN \<string\>
Required string.  
The distinguished name of the OU to "Covidize".  

### -Provision
Optional switch.  
WIP  

### -Deprovision
Optional switch.  
WIP  

### -Covidize
Optional switch.  
WIP  

### -Uncovidize
Optional switch.  
WIP  

### -TestRun
Optional switch.  
WIP  

### -Delay
Optional integer.  
Number of seconds that the script waits between creating an OU and linking GPOs to it.  
This allows time for the changes to sync to the domain controllers, so that the script doesn't end up trying to link a GPO to an OU that doesn't exist.  
Default is `30`.  

# Notes
- Must be run as your SU account.
- By mseng3. See my other projects here: https://github.com/mmseng/code-compendium.
