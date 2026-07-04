<#
.SYNOPSIS
    Exports local OneNote section files (.one) to Markdown - one .md file per
    section - using OneNote's desktop COM Automation API.

.DESCRIPTION
    No cloud auth, no Graph API, no external modules. Talks directly to a
    locally running (or auto-launched) instance of the classic desktop
    OneNote application over COM.

    IMPORTANT: This requires the CLASSIC desktop OneNote (OneNote 2016 /
    the version bundled with Office, or the standalone "OneNote (desktop)"
    MSI from Microsoft). The free "OneNote for Windows 10" Store app does
    NOT expose this COM object model - if that's your only OneNote, install
    the classic desktop version alongside it.

.PARAMETER InputPath
    Path to a single .one file, or a folder containing multiple .one files
    (a notebook folder on disk is just a directory of .one section files
    plus a .onetoc2 index - this script processes every .one file in it).

.PARAMETER OutputPath
    Directory to write the resulting Markdown files (and an "_assets"
    subfolder per section for any embedded images) into. Created if it
    doesn't exist.

.EXAMPLE
    .\Export-OneNoteToMarkdown.ps1 -InputPath "C:\Notebooks\Work\Projects.one" -OutputPath ".\export"

.EXAMPLE
    .\Export-OneNoteToMarkdown.ps1 -InputPath "C:\Notebooks\Work" -OutputPath ".\export"

.NOTES
    - Page content comes back from OneNote as its own XML schema (not
      HTML). Text runs (<one:T>) contain small embedded HTML fragments for
      formatting (bold/italic/links), which this script converts with a
      lightweight regex-based HTML-to-Markdown pass. Paragraph styles
      (Heading 1-6, citations) are resolved via each page's
      <one:QuickStyleDef> table. Bulleted/numbered lists, nested outline
      indentation, tables, and embedded images (decoded from inline base64
      in the page XML) are reconstructed as best-effort Markdown.
    - Ink drawings and embedded file objects (e.g. a pasted Excel sheet)
      are left as a placeholder note rather than converted.
    - XML queries use the Select-Xml cmdlet with a namespace hashtable
      rather than a manually constructed XmlNamespaceManager object, since
      the latter is prone to a known PowerShell 5.1 overload-binding issue
      when passed into SelectNodes/SelectSingleNode.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$InputPath,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = ".\onenote_export"
)

# --------------------------------------------------------------------------
# OneNote COM enum values (from the OneNote Automation API)
# --------------------------------------------------------------------------
$HS_PAGES       = 4   # HierarchyScope.hsPages   - recurse all the way to pages
$PAGE_INFO_ALL  = 3   # PageInfo.piAll            - include binary image data + file type info
$CFT_NONE       = 0   # CreateFileType.cftNone    - open an existing file, don't create one

# --------------------------------------------------------------------------
# CONNECT
# --------------------------------------------------------------------------
function Connect-OneNote {
    try {
        return New-Object -ComObject OneNote.Application
    } catch {
        Write-Error "Could not connect to OneNote via COM. Make sure the classic desktop OneNote (not the Store/UWP app) is installed. Original error: $_"
        exit 1
    }
}

function Open-Section {
    param($OneNoteApp, [string]$OneFilePath)
    $sectionId = ""
    $OneNoteApp.OpenHierarchy($OneFilePath, "", [ref]$sectionId, $CFT_NONE)
    return $sectionId
}

function Get-HierarchyXml {
    param($OneNoteApp, [string]$NodeId, [int]$Scope)
    $xml = ""
    $OneNoteApp.GetHierarchy($NodeId, $Scope, [ref]$xml)
    return $xml
}

function Get-PageContentXml {
    param($OneNoteApp, [string]$PageId)
    $xml = ""
    $OneNoteApp.GetPageContent($PageId, [ref]$xml, $PAGE_INFO_ALL)
    return $xml
}

function Close-Section {
    param($OneNoteApp, [string]$SectionId)
    try { $OneNoteApp.CloseNotebook($SectionId) } catch { }
}

# --------------------------------------------------------------------------
# XML NAMESPACE + QUERY HELPERS (Select-Xml based - avoids XmlNamespaceManager
# overload-binding issues seen in some PowerShell 5.1 builds)
# --------------------------------------------------------------------------
function Get-OneNoteNamespaceTable {
    param([xml]$XmlDoc)
    return @{ one = $XmlDoc.DocumentElement.NamespaceURI }
}

function Get-XmlNodes {
    <# Returns an array (possibly empty) of nodes matching $XPath under $ContextNode. #>
    param($ContextNode, [string]$XPath, [hashtable]$Ns)
    $results = @(Select-Xml -Xml $ContextNode -XPath $XPath -Namespace $Ns -ErrorAction SilentlyContinue)
    if (-not $results -or $results.Count -eq 0) { return @() }
    return @($results | ForEach-Object { $_.Node })
}

function Get-XmlNode {
    <# Returns the first matching node, or $null if none. #>
    param($ContextNode, [string]$XPath, [hashtable]$Ns)
    $nodes = Get-XmlNodes -ContextNode $ContextNode -XPath $XPath -Ns $Ns
    if ($nodes.Count -gt 0) { return $nodes[0] }
    return $null
}

# --------------------------------------------------------------------------
# FILENAME SANITIZATION
# --------------------------------------------------------------------------
function Get-SafeFileName {
    param([string]$Name)
    if ([string]::IsNullOrWhiteSpace($Name)) { return "untitled" }
    $clean = $Name -replace '[\\/:*?"<>|]', '_'
    return $clean.Trim()
}

# --------------------------------------------------------------------------
# LIGHTWEIGHT HTML -> MARKDOWN (for the small fragments inside <one:T>)
# --------------------------------------------------------------------------
function ConvertFrom-OneNoteInlineHtml {
    param([string]$Html)
    if ([string]::IsNullOrWhiteSpace($Html)) { return "" }

    $text = $Html

    # Links: <a href="url">text</a> -> [text](url)
    $text = [regex]::Replace($text, '<a\s+[^>]*href="([^"]*)"[^>]*>(.*?)</a>', '[$2]($1)', 'IgnoreCase, Singleline')

    # Bold (tag or inline style)
    $text = [regex]::Replace($text, '<(b|strong)[^>]*>(.*?)</\1>', '**$2**', 'IgnoreCase, Singleline')
    $text = [regex]::Replace($text, '<span[^>]*style="[^"]*font-weight:\s*bold[^"]*"[^>]*>(.*?)</span>', '**$1**', 'IgnoreCase, Singleline')

    # Italic
    $text = [regex]::Replace($text, '<(i|em)[^>]*>(.*?)</\1>', '*$2*', 'IgnoreCase, Singleline')
    $text = [regex]::Replace($text, '<span[^>]*style="[^"]*font-style:\s*italic[^"]*"[^>]*>(.*?)</span>', '*$1*', 'IgnoreCase, Singleline')

    # Line breaks
    $text = [regex]::Replace($text, '<br\s*/?>', "`n", 'IgnoreCase')

    # Strip any remaining tags (underline, plain spans, etc. - Markdown has no clean equivalent)
    $text = [regex]::Replace($text, '<[^>]+>', '')

    # Decode common HTML entities
    $text = $text -replace '&amp;', '&' -replace '&lt;', '<' -replace '&gt;', '>' -replace '&quot;', '"' -replace '&#39;', "'"

    return $text.Trim()
}

# --------------------------------------------------------------------------
# QUICK STYLE MAP (maps quickStyleIndex -> style name like 'h1', 'p', 'cite')
# --------------------------------------------------------------------------
function Get-QuickStyleMap {
    param([xml]$PageXmlDoc, [hashtable]$Ns)
    $map = @{}
    $defs = Get-XmlNodes -ContextNode $PageXmlDoc -XPath "//one:QuickStyleDef" -Ns $Ns
    foreach ($def in $defs) {
        $idx = $def.GetAttribute("index")
        $name = $def.GetAttribute("name")
        if ($idx) { $map[$idx] = $name }
    }
    return $map
}

function Get-StyleMarkdownPrefix {
    param([string]$StyleName)
    if ($StyleName -match '^h([1-6])$') {
        $level = [int]$Matches[1]
        $hashes = "#" * [Math]::Min($level + 1, 6)   # +1 so page title stays top-level H1
        return "$hashes "
    }
    if ($StyleName -eq "cite") { return "> " }
    return ""
}

function Get-OneNoteEmbeddedData {
    param($Node, [hashtable]$Ns)
    if (-not $Node) { return $null }

    $nodesToInspect = New-Object System.Collections.Generic.List[object]
    $nodesToInspect.Add($Node)

    try {
        $descendants = $Node.SelectNodes('.//*[local-name()="Data" or local-name()="BinaryData" or local-name()="FileData"]')
        if ($descendants) {
            foreach ($descendant in $descendants) {
                $nodesToInspect.Add($descendant)
            }
        }
    } catch {
        # Fall back to a simple child-walk if the XPath form is unsupported.
    }

    foreach ($candidateNode in $nodesToInspect) {
        if (-not $candidateNode) { continue }

        $candidateValues = @()
        foreach ($attrName in @('data', 'binaryData', 'fileData', 'value', 'content', 'src')) {
            try {
                $attribute = $candidateNode.Attributes[$attrName]
                if ($attribute -and -not [string]::IsNullOrWhiteSpace($attribute.Value)) {
                    $candidateValues += $attribute.Value
                }
            } catch {
                # Ignore attributes that are not present.
            }
        }

        try {
            if (-not [string]::IsNullOrWhiteSpace($candidateNode.InnerText)) {
                $candidateValues += $candidateNode.InnerText
            }
        } catch {
            # Ignore nodes without a usable InnerText value.
        }

        foreach ($candidate in $candidateValues) {
            $trimmed = $candidate.Trim()
            if ([string]::IsNullOrWhiteSpace($trimmed)) { continue }

            $normalized = $trimmed -replace '\s', ''
            if ($normalized -match '^data:[^;]+;base64,(.+)$') {
                $normalized = $Matches[1]
            }

            if ($normalized -match '^[A-Za-z0-9+/=]+$' -and $normalized.Length -ge 4 -and ($normalized.Length % 4) -eq 0) {
                return $normalized
            }
        }
    }

    return $null
}

function Convert-OneNoteBase64Payload {
    param([string]$Payload)
    if ([string]::IsNullOrWhiteSpace($Payload)) { return $null }

    $normalized = ($Payload -replace '\s', '')
    if ($normalized -match '^data:[^;]+;base64,(.+)$') {
        $normalized = $Matches[1]
    }
    return $normalized
}

# --------------------------------------------------------------------------
# IMAGE HANDLING
# --------------------------------------------------------------------------
function Export-OneNoteImage {
    param($ImageNode, [hashtable]$Ns, [string]$AssetsDir, [string]$PageTitle, [ref]$Counter)

    $rawData = Get-OneNoteEmbeddedData -Node $ImageNode -Ns $Ns
    if ([string]::IsNullOrWhiteSpace($rawData)) {
        return "*[image: no embedded data found]*"
    }

    $Counter.Value++
    $fileName = "$(Get-SafeFileName $PageTitle)_$($Counter.Value).png"

    try {
        if (-not (Test-Path $AssetsDir)) { New-Item -ItemType Directory -Path $AssetsDir -Force | Out-Null }
        $normalizedData = Convert-OneNoteBase64Payload -Payload $rawData
        $bytes = [Convert]::FromBase64String($normalizedData)
        [System.IO.File]::WriteAllBytes((Join-Path $AssetsDir $fileName), $bytes)
        $assetsFolderName = Split-Path $AssetsDir -Leaf
        return "![image]($assetsFolderName/$fileName)"
    } catch {
        return "*[image: failed to decode - $_]*"
    }
}

function Export-OneNoteAttachment {
    param($AttachmentNode, [hashtable]$Ns, [string]$AssetsDir, [string]$PageTitle, [ref]$Counter)

    $rawData = Get-OneNoteEmbeddedData -Node $AttachmentNode -Ns $Ns
    if ([string]::IsNullOrWhiteSpace($rawData)) {
        return "*[attachment: no embedded data found]*"
    }

    $Counter.Value++
    $displayName = $AttachmentNode.GetAttribute("name")
    if ([string]::IsNullOrWhiteSpace($displayName)) { $displayName = $AttachmentNode.GetAttribute("filename") }
    if ([string]::IsNullOrWhiteSpace($displayName)) { $displayName = "attachment_$($Counter.Value)" }

    $extension = [System.IO.Path]::GetExtension($displayName)
    if ([string]::IsNullOrWhiteSpace($extension)) {
        $contentType = $AttachmentNode.GetAttribute("type")
        if ($contentType -match "pdf") { $extension = ".pdf" }
        elseif ($contentType -match "excel|spreadsheet") { $extension = ".xlsx" }
        elseif ($contentType -match "word") { $extension = ".docx" }
        elseif ($contentType -match "text") { $extension = ".txt" }
        else { $extension = ".bin" }
    }

    $fileName = "$(Get-SafeFileName $PageTitle)_$($Counter.Value)$extension"

    try {
        if (-not (Test-Path $AssetsDir)) { New-Item -ItemType Directory -Path $AssetsDir -Force | Out-Null }
        $normalizedData = Convert-OneNoteBase64Payload -Payload $rawData
        $bytes = [Convert]::FromBase64String($normalizedData)
        [System.IO.File]::WriteAllBytes((Join-Path $AssetsDir $fileName), $bytes)
        $assetsFolderName = Split-Path $AssetsDir -Leaf
        $displayNameSafe = Get-SafeFileName $displayName
        return "[$displayNameSafe]($assetsFolderName/$fileName)"
    } catch {
        return "*[attachment: failed to decode - $_]*"
    }
}

# --------------------------------------------------------------------------
# TABLE HANDLING
# --------------------------------------------------------------------------
function Convert-OneNoteTable {
    param($TableNode, [hashtable]$Ns, [string]$AssetsDir, [string]$PageTitle, [ref]$Counter)

    $lines = @()
    $rows = Get-XmlNodes -ContextNode $TableNode -XPath "one:Row" -Ns $Ns
    $rowIndex = 0
    foreach ($row in $rows) {
        $cells = Get-XmlNodes -ContextNode $row -XPath "one:Cell" -Ns $Ns
        $cellTexts = @()
        foreach ($cell in $cells) {
            $oeNodes = Get-XmlNodes -ContextNode $cell -XPath ".//one:OE" -Ns $Ns
            $parts = @()
            foreach ($oe in $oeNodes) {
                $parts += Get-OeInlineText -OeNode $oe -Ns $Ns -AssetsDir $AssetsDir -PageTitle $PageTitle -Counter $Counter
            }
            $cellText = ($parts -join " ") -replace '\|', '\|'
            if ([string]::IsNullOrWhiteSpace($cellText)) { $cellText = " " }
            $cellTexts += $cellText.Trim()
        }
        $lines += "| " + ($cellTexts -join " | ") + " |"
        if ($rowIndex -eq 0) {
            $sep = ($cellTexts | ForEach-Object { "---" }) -join " | "
            $lines += "| $sep |"
        }
        $rowIndex++
    }
    return $lines
}

function Get-OeInlineText {
    param($OeNode, [hashtable]$Ns, [string]$AssetsDir, [string]$PageTitle, [ref]$Counter)
    $parts = @()
    foreach ($t in (Get-XmlNodes -ContextNode $OeNode -XPath "one:T" -Ns $Ns)) {
        $md = ConvertFrom-OneNoteInlineHtml -Html $t.InnerText
        if ($md) { $parts += $md }
    }
    foreach ($img in (Get-XmlNodes -ContextNode $OeNode -XPath "one:Image" -Ns $Ns)) {
        $parts += Export-OneNoteImage -ImageNode $img -Ns $Ns -AssetsDir $AssetsDir -PageTitle $PageTitle -Counter $Counter
    }
    foreach ($attachment in (Get-XmlNodes -ContextNode $OeNode -XPath "one:InsertedFile" -Ns $Ns)) {
        $parts += Export-OneNoteAttachment -AttachmentNode $attachment -Ns $Ns -AssetsDir $AssetsDir -PageTitle $PageTitle -Counter $Counter
    }
    return ($parts -join " ")
}

# --------------------------------------------------------------------------
# RECURSIVE OUTLINE (OE) PROCESSING
# --------------------------------------------------------------------------
function Convert-OneNoteOE {
    param(
        $OeNode,
        [hashtable]$Ns,
        [hashtable]$StyleMap,
        [string]$AssetsDir,
        [string]$PageTitle,
        [ref]$Counter,
        [int]$Depth = 0
    )

    $lines = @()
    $indent = "  " * $Depth

    $styleIdx = $OeNode.GetAttribute("quickStyleIndex")
    $styleName = if ($StyleMap.ContainsKey($styleIdx)) { $StyleMap[$styleIdx] } else { "p" }
    $prefix = Get-StyleMarkdownPrefix -StyleName $styleName

    $listNode = Get-XmlNode -ContextNode $OeNode -XPath "one:List" -Ns $Ns
    $isBulleted = $listNode -and (Get-XmlNode -ContextNode $listNode -XPath "one:Bullet" -Ns $Ns)
    $isNumbered = $listNode -and (Get-XmlNode -ContextNode $listNode -XPath "one:Number" -Ns $Ns)

    $textParts = @()
    foreach ($t in (Get-XmlNodes -ContextNode $OeNode -XPath "one:T" -Ns $Ns)) {
        $md = ConvertFrom-OneNoteInlineHtml -Html $t.InnerText
        if ($md) { $textParts += $md }
    }
    $textContent = $textParts -join " "

    foreach ($table in (Get-XmlNodes -ContextNode $OeNode -XPath "one:Table" -Ns $Ns)) {
        $lines += Convert-OneNoteTable -TableNode $table -Ns $Ns -AssetsDir $AssetsDir -PageTitle $PageTitle -Counter $Counter
    }

    foreach ($img in (Get-XmlNodes -ContextNode $OeNode -XPath "one:Image" -Ns $Ns)) {
        $imgMd = Export-OneNoteImage -ImageNode $img -Ns $Ns -AssetsDir $AssetsDir -PageTitle $PageTitle -Counter $Counter
        $textContent = if ($textContent) { "$textContent $imgMd".Trim() } else { $imgMd }
    }

    foreach ($attachment in (Get-XmlNodes -ContextNode $OeNode -XPath "one:InsertedFile" -Ns $Ns)) {
        $attachmentMd = Export-OneNoteAttachment -AttachmentNode $attachment -Ns $Ns -AssetsDir $AssetsDir -PageTitle $PageTitle -Counter $Counter
        $textContent = if ($textContent) { "$textContent $attachmentMd".Trim() } else { $attachmentMd }
    }

    if ($textContent) {
        if ($isBulleted) {
            $lines += "$indent- $prefix$textContent"
        } elseif ($isNumbered) {
            $lines += "$indent1. $prefix$textContent"
        } elseif ($prefix) {
            $lines += "$indent$prefix$textContent"
        } else {
            $lines += "$indent$textContent"
        }
    }

    $childContainer = Get-XmlNode -ContextNode $OeNode -XPath "one:OEChildren" -Ns $Ns
    if ($childContainer) {
        foreach ($childOe in (Get-XmlNodes -ContextNode $childContainer -XPath "one:OE" -Ns $Ns)) {
            $lines += Convert-OneNoteOE -OeNode $childOe -Ns $Ns -StyleMap $StyleMap -AssetsDir $AssetsDir -PageTitle $PageTitle -Counter $Counter -Depth ($Depth + 1)
        }
    }

    return $lines
}

# --------------------------------------------------------------------------
# PAGE -> MARKDOWN
# --------------------------------------------------------------------------
function Convert-OneNotePage {
    param([string]$PageXml, [string]$AssetsDir)

    [xml]$pageDoc = $PageXml
    $ns = Get-OneNoteNamespaceTable -XmlDoc $pageDoc
    $pageRoot = $pageDoc.DocumentElement

    $title = $pageRoot.GetAttribute("name")
    if ([string]::IsNullOrWhiteSpace($title)) { $title = "Untitled Page" }
    $lastModified = $pageRoot.GetAttribute("lastModifiedTime")

    $styleMap = Get-QuickStyleMap -PageXmlDoc $pageDoc -Ns $ns
    $imgCounter = 0

    $lines = @("## $title", "")
    if ($lastModified) {
        $lines += "_Last modified: $lastModified_"
        $lines += ""
    }

    $outlines = Get-XmlNodes -ContextNode $pageDoc -XPath "//one:Outline" -Ns $ns
    foreach ($outline in $outlines) {
        $childContainer = Get-XmlNode -ContextNode $outline -XPath ".//one:OEChildren" -Ns $ns
        if (-not $childContainer) { continue }
        foreach ($oe in (Get-XmlNodes -ContextNode $childContainer -XPath "one:OE" -Ns $ns)) {
            $lines += Convert-OneNoteOE -OeNode $oe -Ns $ns -StyleMap $styleMap -AssetsDir $AssetsDir -PageTitle $title -Counter ([ref]$imgCounter)
        }
        $lines += ""
    }

    $markdown = ($lines -join "`n") -replace '(\r?\n){3,}', "`n`n"
    return $markdown.Trim()
}

# --------------------------------------------------------------------------
# SECTION -> MARKDOWN FILE
# --------------------------------------------------------------------------
function Export-OneNoteSectionFile {
    param($OneNoteApp, [string]$OneFilePath, [string]$OutputRoot)

    Write-Host "Section file: $(Split-Path $OneFilePath -Leaf)"
    $sectionId = Open-Section -OneNoteApp $OneNoteApp -OneFilePath $OneFilePath

    $hierarchyXml = Get-HierarchyXml -OneNoteApp $OneNoteApp -NodeId $sectionId -Scope $HS_PAGES
    [xml]$hierarchyDoc = $hierarchyXml
    $ns = Get-OneNoteNamespaceTable -XmlDoc $hierarchyDoc

    $sectionName = $hierarchyDoc.DocumentElement.GetAttribute("name")
    if ([string]::IsNullOrWhiteSpace($sectionName)) {
        $sectionName = [System.IO.Path]::GetFileNameWithoutExtension($OneFilePath)
    }
    Write-Host "  Section name: $sectionName"

    $pageNodes = Get-XmlNodes -ContextNode $hierarchyDoc -XPath "//one:Page" -Ns $ns
    if ($pageNodes.Count -eq 0) {
        Write-Host "  (no pages found)"
        Close-Section -OneNoteApp $OneNoteApp -SectionId $sectionId
        return
    }

    $assetsDir = Join-Path $OutputRoot "$(Get-SafeFileName $sectionName)_assets"
    $docLines = @("# $sectionName", "")

    foreach ($pageNode in $pageNodes) {
        $pageId = $pageNode.GetAttribute("ID")
        $pageName = $pageNode.GetAttribute("name")
        Write-Host "  Page: $pageName"

        $pageXml = Get-PageContentXml -OneNoteApp $OneNoteApp -PageId $pageId
        $pageMarkdown = Convert-OneNotePage -PageXml $pageXml -AssetsDir $assetsDir

        $docLines += $pageMarkdown
        $docLines += ""
        $docLines += "---"
        $docLines += ""
    }

    if (-not (Test-Path $OutputRoot)) { New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null }
    $outFile = Join-Path $OutputRoot "$(Get-SafeFileName $sectionName).md"
    $docLines -join "`n" | Out-File -FilePath $outFile -Encoding utf8
    Write-Host "  -> wrote $outFile"

    Close-Section -OneNoteApp $OneNoteApp -SectionId $sectionId
}

# --------------------------------------------------------------------------
# MAIN
# --------------------------------------------------------------------------
function Main {
    $resolvedInput = Resolve-Path -Path $InputPath -ErrorAction SilentlyContinue
    if (-not $resolvedInput) {
        Write-Error "Input path does not exist: $InputPath"
        exit 1
    }
    $inputItem = Get-Item $resolvedInput

    $oneFiles = @()
    if ($inputItem.PSIsContainer) {
        $oneFiles = Get-ChildItem -Path $inputItem.FullName -Filter "*.one" | Sort-Object Name
        if ($oneFiles.Count -eq 0) {
            Write-Error "No .one files found in $($inputItem.FullName)"
            exit 1
        }
    } else {
        if ($inputItem.Extension -ne ".one") {
            Write-Error "Input file is not a .one file: $($inputItem.FullName)"
            exit 1
        }
        $oneFiles = @($inputItem)
    }

    $outputRoot = $OutputPath
    if (-not (Test-Path $outputRoot)) { New-Item -ItemType Directory -Path $outputRoot -Force | Out-Null }
    $outputRoot = (Resolve-Path $outputRoot).Path

    $onenote = Connect-OneNote

    foreach ($file in $oneFiles) {
        try {
            Export-OneNoteSectionFile -OneNoteApp $onenote -OneFilePath $file.FullName -OutputRoot $outputRoot
        } catch {
            Write-Warning "  ! Failed to export $($file.Name): $_"
        }
    }

    Write-Host "`nDone. Markdown files written under: $outputRoot"
}

if ($MyInvocation.InvocationName -ne '.') {
    Main
}
