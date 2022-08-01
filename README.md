# Schedule PIM roles activation in a loop
This script was developed to minimize routine process of PIM role activation and to bypass painfull activation scheduling on azure portal one by one for an allowed number of days.

Basically this script allows you to vialoate Just-In-Time control. Don't overuse it ;)

<br>

TODO:<br>
- [x] move from AzureRM to Az module
- [x] Add Check and Install required modules part
- [ ] Add up to 24 hours for scheduled activation option<br>
even if by default you forced to stick to 8 hours or less by setting multiple scheduled activations consecutively
- [ ] Test modules installation
- [ ] Add error handling to CheckInstall-Module (Local Admin requirements to install; AzureAD AzureADPreview conflict)
