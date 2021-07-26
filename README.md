# Summary
Takes the OU of an EWS computer lab and adds sub-OUs and links existing GPOs to refactor for standardized remote desktop access, and optionally, COVID social distancing protocols.  
Full documentation is at https://wiki.illinois.edu/wiki/display/engritprivate/EWS+remote+access+to+Windows+labs  

# Usage
1. Download `LabCheckProvision-LabOU.psm1` to `$HOME\Documents\WindowsPowerShell\Modules\LabCheckProvision-LabOU\LabCheckProvision-LabOU.psm1`.
    - The module is now already available for use with your regular account, however it needs to modify AD objects which likely only your SU account will have access to.
2. Make the module available as your SU account: see [here](https://github.com/engrit-illinois/how-to-run-custom-powershell-modules-as-another-user).
3. Run it using the provided examples and documentation below.

# Behavior
The following 4 actions can be specified via the associated parameter:  
- Provision
- Covidize
- Uncovidize
- Deprovision

Only one action can be specified at a time. The steps each action takes are documented below.  

# Parameters, behavior, and examples

### -LabOUDN \<string\>
Required string.  
The distinguished name of the parent lab OU on which to take action.  

### -Provision
Optional switch.  
Provisions the given parent lab OU for remote access.  

When specifying the `-Provision` parameter:  
1. A `RemoteEnabled` OU is created under the given parent lab OU.
2. A `LocalLoginDisabled` OU is created under the new `RemoteEnabled` OU.
3. A GPO named `ENGR EWS <lab name> RDU` is linked to the `RemoteEnabled` OU if such a GPO exists. The GPO must be created manually.
4. A GPO named `ENGR EWS Restrict local login to admins` is linked to the `LocalLoginDisabled` OU.

Example: `LabCheckProvision-LabOU -Provision "OU=ECEB9999,OU=EWS,OU=Instructional,OU=Desktops,OU=Engineering,OU=Urbana,DC=ad,DC=uillinois,DC=edu"`.  

### -Covidize
Optional switch.  
"Covidizes" the given parent lab OU.  

The given parent lab OU must be provisioned first.  

When specifying the `-Covidize` parameter:  
1. The following GPOs are linked to the given parent lab OU:
  - `ENGR EWS COVID Local-Only Desktop-Lockscreen Background`
  - `ENGR EWS COVID Local-Only Login Message`
2. The following GPOs are linked to the RemoteEnabled OU:
  - `ENGR EWS General Lab Desktop-Lockscreen Background`
  - `ENGR EWS COVID Remote-Enabled (i.e. no) Login Message`
3. The following GPOs are linked to the LocalLoginDisabled OU:
  - `ENGR EWS COVID Remote-Only Desktop-Lockscreen Background`
  - `ENGR EWS COVID Remote-Only Login Message`

Example: `LabCheckProvision-LabOU -Covidize "OU=ECEB9999,OU=EWS,OU=Instructional,OU=Desktops,OU=Engineering,OU=Urbana,DC=ad,DC=uillinois,DC=edu"`.  

### -Uncovidize
Optional switch.  
"Uncovidizes" the given parent lab OU.  

The given parent lab OU must be provisioned first.  

When specifying the `-Uncovidize` parameter:  
1. All of the GPOs noted above under the `-Covidize` parameter are unlinked from their respective OUs.

Example: `LabCheckProvision-LabOU -Uncovidize "OU=ECEB9999,OU=EWS,OU=Instructional,OU=Desktops,OU=Engineering,OU=Urbana,DC=ad,DC=uillinois,DC=edu"`.  

### -Deprovision
Optional switch.  
Deprovisions the given parent lab OU for both remote access and "covidization".  

The given parent lab OU must be provisioned, and all AD objects (computer, users, groups, OUs, etc.) must be moved out of the `RemoteEnabled` and `LocalLoginDisabled` sub-OUs first.

When specifying the `-Deprovision` parameter:  
1. A check is made to see if any AD objects exist in the `RemoteEnabled` or `LocalLoginDisabled` sub-OUs of the given lab OU. If any objects exist in these OUs, the script simply exits without making any changes. If no objects are found then...
2. The `LocalLoginDisabled` OU is removed (along with all GPO links to it).
3. The `RemoteEnabled` OU is removed (along with all GPO links to it).
4. If the two "COVID" GPOs are linked to the parent lab OU (see above), those links are removed.

Example: `LabCheckProvision-LabOU -Derovision "OU=ECEB9999,OU=EWS,OU=Instructional,OU=Desktops,OU=Engineering,OU=Urbana,DC=ad,DC=uillinois,DC=edu"`.  

### -TestRun
Optional switch.  
Runs through the given action as normal, except all changes to AD are skipped.  

Example: `LabCheckProvision-LabOU -TestRun -Provision "OU=ECEB9999,OU=EWS,OU=Instructional,OU=Desktops,OU=Engineering,OU=Urbana,DC=ad,DC=uillinois,DC=edu"`.  

### -Delay
Optional integer.  
Number of seconds that the script waits between creating an OU and linking GPOs to it.  
This allows time for changes to sync to the domain controllers, so that the script doesn't end up trying to do things like link a GPO to a newly-created OU that hasn't been replicated yet.  
Default is `30`.  

# Notes
- By mseng3. See my other projects here: https://github.com/mmseng/code-compendium.
