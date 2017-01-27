param
(
  [string]$shims = "netstandard"
)
$genapi = "\\fxcore\tools\others\GenAPI\GenAPI.exe";

if ($shims -eq "netstandard")
{
    $refPath = Resolve-Path "..\..\..\bin\obj\CompatShims\ref\netstandard1.6"
}
elseif ($shims -eq "netfx")
{
    $refPath = "C:\Program Files (x86)\Reference Assemblies\Microsoft\Framework\.NETFramework\v4.6.1"
}

$shimOutput = $shims;
$shimlistFile = "$shims.shimlist.txt";

if (!(Test-Path $shimlistFile))
{
    Write-Error "Shim list doesn't exist $shimList";
    exit;
}
$shimList = gc $shimlistFile;

$projTemplate = gc shim.projtemplate

$netstandardRef = "..\..\..\bin\ref\netstandard\2.0.0.0\netstandard.dll";
$netstandardAPIList = "netstandardAPIList.txt";

& $genapi -writer:DocIds -assembly:$netstandardRef -out:$netstandardAPIList

foreach ($shim in $shimList)
{
    if ($shim[0] -eq '#') { continue; }

    $shimForwards = "$shimOutput\$shim.Forwards.cs";
    $shimProject = "$shimOutput\$shim.csproj";
    $shimContract = "$refPath\$shim.dll";

    if (!(Test-Path $shimContract))
    {
        Write-Host "Assembly $shimContract doesn't exist so skipping."
        continue;
    }

    Write-Host "Generating forwards and project for $shimContract";

    $asmName = [System.Reflection.AssemblyName]::GetAssemblyName($shimContract);
    $asmVersion = $asmName.Version.ToString();

    $asmToken = $asmName.GetPublicKeyToken()[0].ToString("x2");
    if ($asmToken -eq "b0")
    {
        $token = "UseMSFTKey";
    }
    elseif ($asmToken -eq "b7")
    {
        $token = "UseECMAKey";
    }
    elseif ($asmToken -eq "cc")
    {
        $token = "UseOpenKey";
    }
    else
    {
        Write-Error "Don't know which key is token $asmToken";
    }

    & $genapi -writer:TypeForwards -assembly:"$shimContract" -apiList:"$netstandardAPIList" -out:"$shimForwards" -libpath:"$refPath"
    #& $genapi -writer:TypeForwards -assembly:"$shimContract" -out:"$shimForwards" -libpath:"$refPath"
    $projTemplate.Replace("[SHIM]", $shim).Replace("[TOKEN]", $token).Replace("[VERSION]", $asmVersion) | sc "$shimProject"
}