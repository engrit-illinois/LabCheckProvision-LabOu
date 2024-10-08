# Summary
Takes the OU of an EWS computer lab and adds sub-OUs and links existing GPOs to refactor for standardized remote desktop access,.  
Full documentation is at https://uofi.atlassian.net/wiki/spaces/engritinstruction/pages/36191924/EWS+remote+access+to+Windows+labs  

# Usage
1. Download `LabCheckProvision-LabOU.psm1` to `$HOME\Documents\WindowsPowerShell\Modules\LabCheckProvision-LabOU\LabCheckProvision-LabOU.psm1`.
    - The module is now already available for use with your regular account, however it needs to modify AD objects which likely only your SU account will have access to.
2. Make the module available as your SU account: see [here](https://github.com/engrit-illinois/how-to-run-custom-powershell-modules-as-another-user).
3. Run it using the provided examples and documentation below.

The following actions can be specified via the associated parameter:  
- Provision
- Deprovision

Only one action can be specified at a time. The steps each action takes are documented below.  

# Parameters, behavior, and examples

### -LabOudn \<string\>
Required string.  
The distinguished name of the parent lab OU on which to take action.  

### -Provision
Optional switch.  
Provisions the given parent lab OU for remote access.  

When specifying the `-Provision` parameter:  
1. A `RemoteEnabled` OU is created under the given parent lab OU.
2. A `LocalLoginDisabled` OU is created under the new `RemoteEnabled` OU.
3. The GPO named `ENGR EWS RDU <lab-name>` is linked to the `RemoteEnabled` OU if such a GPO exists. The GPO must be manually created beforehand. `<lab-name>` must exactly mirror the name of the given parent OU.
4. The existing GPO named `ENGR EWS Restrict local login to admins` is linked to the `LocalLoginDisabled` OU.

Example:  
`LabCheckProvision-LabOU -Provision -LabOudn "OU=ECEB-9999,OU=EWS,OU=Instructional,OU=Desktops,OU=Engineering,OU=Urbana,DC=ad,DC=uillinois,DC=edu"`

### -Deprovision
Optional switch.  
Deprovisions the given parent lab OU for remote access.  
The given parent lab OU must be provisioned, and all AD objects (computer, users, groups, OUs, etc.) must be moved out of the `RemoteEnabled` and `LocalLoginDisabled` sub-OUs first.

When specifying the `-Deprovision` parameter:  
1. A check is made to see if any AD objects exist in the `RemoteEnabled` or `LocalLoginDisabled` sub-OUs of the given lab OU. If any objects exist in these OUs, the script simply exits without making any changes. If no objects are found then...
2. The `LocalLoginDisabled` OU is removed (along with all GPO links to it).
3. The `RemoteEnabled` OU is removed (along with all GPO links to it).

Example:  
`LabCheckProvision-LabOU -Deprovision -LabOudn "OU=ECEB-9999,OU=EWS,OU=Instructional,OU=Desktops,OU=Engineering,OU=Urbana,DC=ad,DC=uillinois,DC=edu"`

### -TestRun
Optional switch.  
Runs through the given action as normal, except all changes to AD are skipped.  

Example:  
`LabCheckProvision-LabOU -TestRun -Provision -LabOudn "OU=ECEB-9999,OU=EWS,OU=Instructional,OU=Desktops,OU=Engineering,OU=Urbana,DC=ad,DC=uillinois,DC=edu"`

### -Delay
Optional integer.  
Number of seconds that the script waits between creating an OU and linking GPOs to it.  
This allows time for changes to sync to the domain controllers, so that the script doesn't end up trying to do things like link a GPO to a newly-created OU that hasn't been replicated yet.  
Default is `30`.  

# Notes
- By mseng3. See my other projects here: https://github.com/mmseng/code-compendium.
