param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectRoot,
    [string]$UserFilePath,
    [ValidateSet('Phase0', 'Phase1')]
    [string]$Phase = 'Phase1',
    [ValidateSet('On', 'Off')]
    [string]$ShadowMode = 'On',
    [ValidateSet('ControlFlow', 'ThreadBoundary')]
    [string]$DebugMode = 'ThreadBoundary'
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'DebugProfileSupport.ps1')

$root = [IO.Path]::GetFullPath($ProjectRoot)
if ([string]::IsNullOrWhiteSpace($UserFilePath)) {
    $UserFilePath = Join-Path $root `
        'Intermediate\ProjectFiles\RenderPipelineLab.vcxproj.user'
}
$userFile = [IO.Path]::GetFullPath($UserFilePath)
if (-not (Test-Path -LiteralPath $userFile -PathType Leaf)) {
    throw "VS user file is missing; regenerate project files first: $userFile"
}

$logName = "CookedSandbox-$Phase-$ShadowMode.log"
$arguments = @(Get-RenderPipelineDebugArguments `
    -Phase $Phase -ShadowMode $ShadowMode -DebugMode $DebugMode `
    -LogName $logName)
$argumentText = $arguments -join ' '

[xml]$document = Get-Content -Raw -LiteralPath $userFile
$namespaceUri = $document.Project.NamespaceURI
$namespace = New-Object System.Xml.XmlNamespaceManager($document.NameTable)
$namespace.AddNamespace('msb', $namespaceUri)
$condition = "'`$(Configuration)|`$(Platform)'=='Debug|x64'"
$propertyGroup = $document.SelectNodes(
    '/msb:Project/msb:PropertyGroup', $namespace) |
    Where-Object { $_.Condition -eq $condition } |
    Select-Object -First 1

if (-not $propertyGroup) {
    $propertyGroup = $document.CreateElement('PropertyGroup', $namespaceUri)
    $propertyGroup.SetAttribute('Condition', $condition)
    [void]$document.Project.AppendChild($propertyGroup)
}

$argumentNode = $propertyGroup.SelectSingleNode(
    'msb:LocalDebuggerCommandArguments', $namespace)
if (-not $argumentNode) {
    $argumentNode = $document.CreateElement(
        'LocalDebuggerCommandArguments', $namespaceUri)
    [void]$propertyGroup.AppendChild($argumentNode)
}
$argumentNode.InnerText = $argumentText

$settings = New-Object System.Xml.XmlWriterSettings
$settings.Encoding = New-Object System.Text.UTF8Encoding($false)
$settings.Indent = $true
$settings.NewLineChars = [Environment]::NewLine
$writer = [System.Xml.XmlWriter]::Create($userFile, $settings)
try {
    $document.Save($writer)
}
finally {
    $writer.Dispose()
}

Write-Output "VsUserFile=$userFile"
Write-Output "DebugMode=$DebugMode"
Write-Output "Arguments=$argumentText"
Write-Output 'Reload the RenderPipelineLab project or reopen the solution if Visual Studio is already running.'
