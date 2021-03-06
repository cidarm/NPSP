*** Settings ***

Resource        robot/Cumulus/resources/NPSP.robot
Suite Setup     Open Test Browser
Suite Teardown  Delete Records and Close Browser

 
*** Test Cases ***    
Create ASC for Affiliated Contact
    [tags]  unstable
    &{account} =  API Create Organization Account   
    &{contact} =  API Create Contact    Email=skristem@robot.com 
    Go To Record Home    &{contact}[Id]
    Select Tab    Related
    Click Related List Button   Organization Affiliations    New
    Populate Lookup Field    Organization    &{account}[Name]
    Select Value From Dropdown   Related Opportunity Contact Role              Soft Credit
    Click Modal Button        Save
    &{opportunity} =  API Create Opportunity    &{account}[Id]    Donation    Name=&{account}[Name] $500 donation    Amount=500    
    Go To Record Home    &{opportunity}[Id]
    Select Tab    Related
    Select Relatedlist    Contact Roles
    Verify Related List Field Values
    ...                     &{contact}[FirstName] &{contact}[LastName]=Soft Credit
    Go To Record Home    &{contact}[Id]
    Select Tab    Related
    Load Related List    Opportunities
    Check Record Related Item    Opportunities    &{opportunity}[Name]
    Run Donations Batch Process
    Go To Record Home    &{Contact}[Id]
    ${locator}    Get NPSP Locator    detail_page.section_header    Soft Credit Total
    Scroll Element Into View    ${locator}
    Confirm Field Value    Soft Credit This Year    contains    $500.00    
    Confirm Field Value    Soft Credit Total    contains    $500.00    
