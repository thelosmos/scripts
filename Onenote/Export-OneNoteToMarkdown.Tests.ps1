$scriptPath = Join-Path $PSScriptRoot 'Export-OneNoteToMarkdown.ps1'
. $scriptPath -InputPath 'dummy.one' -OutputPath $env:TEMP

$tempDir = Join-Path $env:TEMP 'onenote-export-test'
if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force }
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

$xml = @'
<one:Page xmlns:one="http://schemas.microsoft.com/office/onenote/2013/onenote">
  <one:Image>
    <one:Data data="AAECAw==" />
  </one:Image>
  <one:InsertedFile>
    <one:Data data="dGVzdA==" />
  </one:InsertedFile>
</one:Page>
'@

$pageDoc = [xml]$xml
$ns = Get-OneNoteNamespaceTable -XmlDoc $pageDoc
$assetsDir = Join-Path $tempDir 'assets'
$imgNode = $pageDoc.SelectSingleNode('//*[local-name()="Image"]')
$attachmentNode = $pageDoc.SelectSingleNode('//*[local-name()="InsertedFile"]')
$payload = Get-OneNoteEmbeddedData -Node $imgNode -Ns $ns
Write-Host "payload from image node: $payload"
$attachmentPayload = Get-OneNoteEmbeddedData -Node $attachmentNode -Ns $ns
Write-Host "payload from attachment node: $attachmentPayload"
$imgCounter = 0
$imgMarkdown = Export-OneNoteImage -ImageNode $imgNode -Ns $ns -AssetsDir $assetsDir -PageTitle 'Test Page' -Counter ([ref]$imgCounter)
$attachmentCounter = 0
$attachmentMarkdown = Export-OneNoteAttachment -AttachmentNode $attachmentNode -Ns $ns -AssetsDir $assetsDir -PageTitle 'Test Page' -Counter ([ref]$attachmentCounter)

if ($imgMarkdown -notmatch '!\[image\]' -or $attachmentMarkdown -notmatch '\[attachment') {
    throw "Expected embedded media to be exported, got: $imgMarkdown | $attachmentMarkdown"
}

if (-not (Test-Path $assetsDir)) {
    throw 'Expected asset directory to be created.'
}

Write-Host 'Regression test passed.'
