# Domain: Powershell Design

PowerShell scripting best practices for automation, DevOps, and system administration.
Covers security, cross-platform compatibility (Windows/Linux/macOS), error handling,
and common footguns. Applies to PowerShell 5.1+ and PowerShell 7+.

Version Context (January 2026):
- PowerShell 7.4 LTS: supported until November 2026 (.NET 8)
- PowerShell 7.5.4: current stable, supported until May 2026 (.NET 9)
- Windows PowerShell 5.1: maintenance mode, still ships with Windows
- PowerShell 2.0: Removed from Windows 11 24H2 and Server 2025
- PSScriptAnalyzer 1.24.0: Requires PS 5.1+ or PS 7.4.6+ (won't load on 7.4.5)
- CVE-2025-54100: Invoke-WebRequest DOM parsing vulnerability (December 2025)
- CVE-2025-25004: PowerShell 7.5.3 vulnerability (fixed in 7.5.4)


**Validation:** `powershell.validate.sh` enforces NEVER/MUST rules. SHOULD rules trigger warnings. GUIDANCE is not mechanically checked.

---

## Invariants

### NEVER (validator will reject)

1. **Invoke-Expression with User Input** - Invoke-Expression executes arbitrary strings as code. With any external input,
this creates command injection vulnerabilities. The "iex" alias is equally dangerous.

   ```
   // BAD
   Invoke-Expression $userInput
   // BAD
   iex (Get-Content script.ps1)
   // BAD
   $cmd | iex

   // GOOD
   & $command $args
   // GOOD
   $params = @{ Name = $value }; Get-Process @params
   // GOOD
   & ([scriptblock]::Create($trustedCode))
   ```

2. **Plain Text Passwords in Code** - Never store passwords, API keys, or secrets as plain text in scripts.
Use SecureString, the SecretManagement module, or environment variables.

   ```
   // BAD
   $cred = New-Object PSCredential("user", ("P@ssw0rd" | ConvertTo-SecureString -AsPlainText))
   // BAD
   $password = "MySecret123"

   // GOOD
   $cred = Get-Credential
   // GOOD
   $secret = Get-Secret -Name "MyAPIKey"
   // GOOD
   $password = $env:SERVICE_PASSWORD | ConvertTo-SecureString -AsPlainText -Force
   ```

3. **Invoke-WebRequest Without -UseBasicParsing** - Invoke-WebRequest without -UseBasicParsing uses DOM parsing which can execute
embedded scripts. CVE-2025-54100 exploits this for RCE. Windows PowerShell 5.1
requires -UseBasicParsing explicitly; PowerShell 7+ defaults to basic parsing
but explicit is safer for cross-version scripts.


   > December 2025 CVE-2025-54100 patches added security prompts for unsafe parsing.
Always use -UseBasicParsing for automation scripts that run unattended.

   ```
   // BAD
   $response = Invoke-WebRequest $url
   // BAD
   iwr https://example.com/api

   // GOOD
   $response = Invoke-WebRequest $url -UseBasicParsing
   // GOOD
   Invoke-RestMethod $url  # Doesn't have DOM parsing issue
   ```

4. **ConvertTo-SecureString with -AsPlainText in Source** - Using ConvertTo-SecureString -AsPlainText with a literal string defeats the purpose
of SecureString. The secret is still in plain text in your source code.

   ```
   // BAD
   "MyPassword" | ConvertTo-SecureString -AsPlainText -Force

   // GOOD
   Read-Host -AsSecureString -Prompt "Password"
   // GOOD
   $env:PASSWORD | ConvertTo-SecureString -AsPlainText -Force
   ```

5. **Using Aliases in Scripts** - Aliases like %, ?, foreach, where, ls, cat, curl vary by platform and session.
Scripts using aliases may fail on Linux/macOS or in constrained environments.

   ```
   // BAD
   % { $_.Name }
   // BAD
   ls | ? { $_.Length -gt 1000 }
   // BAD
   curl $url

   // GOOD
   ForEach-Object { $_.Name }
   // GOOD
   Get-ChildItem | Where-Object { $_.Length -gt 1000 }
   // GOOD
   Invoke-WebRequest $url -UseBasicParsing
   ```

6. **Write-Host for Data Output** - Write-Host writes to the console, not the pipeline. Output cannot be captured,
redirected, or used by other commands. Use Write-Output for data.

   ```
   // BAD
   Write-Host "User: $username"  # Can't be captured!
   // BAD
   function Get-Data { Write-Host $result }

   // GOOD
   Write-Output "User: $username"
   // GOOD
   "User: $username"  # Implicit output
   // GOOD
   Write-Verbose "Processing $item"  # For diagnostics
   ```

7. **Positional Parameters in Scripts** - Positional parameters make code harder to read and prone to errors when
cmdlet signatures change. Always use named parameters in scripts.

   ```
   // BAD
   Copy-Item $source $dest
   // BAD
   Set-Content $path $data

   // GOOD
   Copy-Item -Path $source -Destination $dest
   // GOOD
   Set-Content -Path $path -Value $data
   ```

8. **Backtick Line Continuation in Middle of Expressions** - Backticks for line continuation are fragile - trailing whitespace after
the backtick breaks the script silently. Use splatting or natural breaks.


   > Backticks are acceptable after pipeline operators where natural breaks work.
For long parameter lists, use splatting.

   ```
   // BAD
   Get-Process `
     -Name "notepad" `   # Trailing space after backtick = broken!
     -ErrorAction Stop
   

   // GOOD
   $params = @{
       Name = "notepad"
       ErrorAction = "Stop"
   }
   Get-Process @params
   
   // GOOD
   Get-Process |
       Where-Object { $_.CPU -gt 100 } |
       Sort-Object CPU
   
   ```

9. **Hardcoded Paths** - Hardcoded paths like C:\Temp or /tmp break cross-platform scripts.
Use environment variables and Join-Path for portability.

   ```
   // BAD
   $logFile = "C:\Temp\log.txt"
   // BAD
   $config = "/etc/myapp/config.json"

   // GOOD
   $logFile = Join-Path $env:TEMP "log.txt"
   // GOOD
   $logFile = Join-Path ([System.IO.Path]::GetTempPath()) "log.txt"
   ```

10. **Assignment in Conditional (= vs -eq)** - Using = instead of -eq in conditionals performs assignment, not comparison.
This silently succeeds and always evaluates to the assigned value.


   > PowerShell doesn't warn about assignment in conditions. This is a common
mistake that causes subtle bugs.

   ```
   // BAD
   if ($status = "Active") { ... }  # Always true!
   // BAD
   Where-Object { $_.Name = "test" }

   // GOOD
   if ($status -eq "Active") { ... }
   // GOOD
   Where-Object { $_.Name -eq "test" }
   ```

### MUST (validator will reject)

1. **Set-StrictMode Required** - Scripts must enable strict mode to catch undefined variables and other
common mistakes early. Use Set-StrictMode -Version Latest.


   > Strict mode catches: uninitialized variables, non-existent properties,
function calls with wrong syntax, and more. Essential for production scripts.

CAVEAT: -Version Latest is non-deterministic. A script written for PS 5.1
using -Version Latest may fail under PS 7+ due to stricter rules. For maximum
portability, use -Version 3.0 (highest defined level as of Jan 2026).

   ```
   Required:
   Set-StrictMode -Version Latest
   Set-StrictMode -Version 3.0  # Portable across versions
   ```

2. **ErrorActionPreference Stop for Critical Scripts** - Production scripts should set $ErrorActionPreference = 'Stop' or use
-ErrorAction Stop on critical commands to catch failures.


   > PowerShell's default is Continue, which silently proceeds after errors.
For automation, this leads to cascading failures and corrupted state.

   ```
   $ErrorActionPreference = "Stop"
   Get-Content $file -ErrorAction Stop
   ```

3. **Try-Catch for Error Handling** - Scripts performing operations that can fail must use try-catch blocks
with -ErrorAction Stop to properly handle errors.


   > Try-catch only catches terminating errors. Non-terminating errors require
-ErrorAction Stop to be caught. Always include specific exception types
when the recovery action differs.

   ```
   // BAD
   $content = Get-Content $file
   Process-Data $content  # If Get-Content fails, this runs with $null!
   

   // GOOD
   try {
       $content = Get-Content $file -ErrorAction Stop
       Process-Data $content
   }
   catch [System.IO.FileNotFoundException] {
       Write-Error "File not found: $file"
   }
   catch {
       Write-Error "Failed to read file: $_"
   }
   
   ```

4. **CmdletBinding for Advanced Functions** - Functions should use [CmdletBinding()] to enable common parameters like
-Verbose, -Debug, -ErrorAction, and -WhatIf support.

   ```
   // BAD
   function Get-Data {
       param($Path)
       Get-Content $Path
   }
   

   // GOOD
   function Get-Data {
       [CmdletBinding()]
       param(
           [Parameter(Mandatory)]
           [string]$Path
       )
       Get-Content $Path
   }
   
   ```

5. **Approved Verbs for Functions** - Function names must use approved PowerShell verbs (Get, Set, New, Remove, etc.)
to maintain consistency with the PowerShell ecosystem.


   > Run Get-Verb to see the full list of approved verbs. Use the closest match
or consider if your function is doing too much (single responsibility).

   ```
   // BAD
   function Fetch-Data { }
   // BAD
   function Calculate-Sum { }

   // GOOD
   function Get-Data { }
   // GOOD
   function Measure-Sum { }
   ```

6. **Parameter Validation** - Parameters must have type constraints and validation attributes.
Use [Parameter(Mandatory)] for required parameters.

   ```
   // BAD
   param($Path, $Count)
   

   // GOOD
   param(
       [Parameter(Mandatory)]
       [ValidateNotNullOrEmpty()]
       [string]$Path,
       
       [ValidateRange(1, 100)]
       [int]$Count = 10
   )
   
   ```

### SHOULD (validator warns)

1. **Use** - Scripts should declare their requirements with #Requires statements
to fail fast if prerequisites aren't met.

   ```
   #Requires -Version 7.0
   #Requires -Modules ActiveDirectory
   
   # Script code...
   ```

2. **Comment-Based Help** - Functions should include comment-based help with at minimum .SYNOPSIS
and .PARAMETER documentation for discoverability via Get-Help.

   ```
   function Get-UserReport {
       <#
       .SYNOPSIS
           Generates a user activity report.
       
       .DESCRIPTION
           Retrieves user login history and generates a formatted report.
       
       .PARAMETER UserName
           The username to generate a report for.
       
       .EXAMPLE
           Get-UserReport -UserName "jsmith"
       #>
       [CmdletBinding()]
       param([string]$UserName)
       # ...
   }
   ```

3. **ShouldProcess for Destructive Operations** - Functions that modify state (files, registry, AD, etc.) should support
-WhatIf and -Confirm via SupportsShouldProcess.

   ```
   function Remove-UserData {
       [CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
       param([string]$UserName)
       
       if ($PSCmdlet.ShouldProcess($UserName, "Remove all user data")) {
           # Perform deletion
       }
   }
   ```

4. **OutputType Attribute** - Functions should declare their output type with [OutputType()] for
better tooling support and documentation. Run PSScriptAnalyzer for enforcement.

   ```
   function Get-ServerStatus {
       [CmdletBinding()]
       [OutputType([PSCustomObject])]
       param([string]$ServerName)
       
       [PSCustomObject]@{
           Name = $ServerName
           Status = "Online"
       }
   }
   ```

5. **Use PascalCase for Variables** - Use PascalCase for local variables ($UserName) consistent with .NET
conventions. Use SCREAMING_SNAKE_CASE for constants.

   ```
   // BAD
   $user_name = "jsmith"
   // BAD
   $USERNAME = "jsmith"  # Unless constant

   // GOOD
   $UserName = "jsmith"
   // GOOD
   $MaxRetryCount = 3
   // GOOD
   $script:CacheTimeout = 300
   ```

6. **Explicitly Handle $null Comparisons** - Always put $null on the left side of comparisons. When on the right,
arrays are filtered instead of compared.

   ```
   // BAD
   if ($result -eq $null) { }

   // GOOD
   if ($null -eq $result) { }
   // GOOD
   if (-not $result) { }  # For boolean context
   ```

7. **Avoid Global Variables** - Avoid using $global: scope. It pollutes the session and creates hidden
dependencies. Use parameters or script scope instead.

   ```
   // BAD
   $global:Config = Get-Config

   // GOOD
   $script:Config = Get-Config
   // GOOD
   function Get-Data { param($Config) }
   ```

8. **Avoid Empty Catch Blocks** - Empty catch blocks silently swallow errors, making debugging impossible.
At minimum, log the error.

   ```
   // BAD
   try { Do-Thing } catch { }

   // GOOD
   try { Do-Thing } 
   catch { 
       Write-Warning "Operation failed: $_"
   }
   
   ```

9. **Use Single Quotes for Literal Strings** - Use single quotes for strings that don't need variable expansion.
This prevents accidental injection and is slightly faster.

   ```
   $path = 'C:\Users'
   $pattern = '^[a-z]+$'
   ```
   ```
   When Double Quotes:
   $message = "Hello, $UserName"
   $path = "$BasePath\$FileName"
   ```

10. **Specify Encoding for File Operations** - PowerShell 7 defaults to UTF-8 without BOM; Windows PowerShell varies.
Specify -Encoding explicitly for cross-platform and interop scenarios.


   > Windows PowerShell 5.1: varies by cmdlet (often UTF-16 or ASCII)
PowerShell 7+: UTF-8 without BOM
For legacy system interop, use -Encoding UTF8BOM

   ```
   Set-Content -Path $file -Value $data -Encoding UTF8
   Out-File -Path $log -Encoding UTF8 -Append
   Get-Content -Path $file -Encoding UTF8
   ```

11. **Use Join-Path for Path Construction** - Never concatenate paths with string operations. Use Join-Path for
cross-platform compatibility (handles / vs \).

   ```
   // BAD
   $fullPath = $basePath + "\" + $fileName
   // BAD
   $fullPath = "$basePath\$fileName"

   // GOOD
   $fullPath = Join-Path $basePath $fileName
   // GOOD
   $fullPath = [System.IO.Path]::Combine($basePath, $fileName)
   ```

12. **Check $IsWindows/$IsLinux/$IsMacOS for Platform Code** - For platform-specific code, use the automatic variables $IsWindows,
$IsLinux, and $IsMacOS introduced in PowerShell 6+.


   > These variables don't exist in Windows PowerShell 5.1. For scripts
supporting both, check if the variable exists first.

   ```
   if ($IsWindows) {
       $configPath = Join-Path $env:APPDATA "MyApp\config.json"
   } elseif ($IsLinux -or $IsMacOS) {
       $configPath = Join-Path $HOME ".config/myapp/config.json"
   }
   # For 5.1 compatibility
   if (-not (Test-Path variable:IsWindows)) {
       $IsWindows = $true
   }
   ```

13. **Avoid Select-Object -ExpandProperty When Not Needed** - Use member access ($object.Property) instead of Select-Object -ExpandProperty
for single properties. It's clearer and faster.

   ```
   // BAD
   $name = Get-Process | Select-Object -First 1 -ExpandProperty Name

   // GOOD
   $name = (Get-Process | Select-Object -First 1).Name
   // GOOD
   $names = (Get-Process).Name  # Array of all names
   ```

### GUIDANCE (not mechanically checked)

1. **Script Template** - Standard template for production PowerShell scripts.
   ```
   Template:
   #Requires -Version 7.0
   
   <#
   .SYNOPSIS
       Brief description of the script.
   
   .DESCRIPTION
       Detailed description of what the script does.
   
   .PARAMETER Path
       Description of the Path parameter.
   
   .EXAMPLE
       .\Script-Name.ps1 -Path "C:\Data"
   #>
   
   [CmdletBinding()]
   param(
       [Parameter(Mandatory)]
       [ValidateNotNullOrEmpty()]
       [string]$Path
   )
   
   Set-StrictMode -Version Latest
   $ErrorActionPreference = 'Stop'
   
   #region Functions
   function Write-Log {
       [CmdletBinding()]
       param(
           [string]$Message,
           [ValidateSet('Info', 'Warning', 'Error')]
           [string]$Level = 'Info'
       )
       $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
       Write-Verbose "[$timestamp] [$Level] $Message"
   }
   #endregion
   
   #region Main
   try {
       Write-Log "Starting script with Path: $Path"
       
       # Main script logic here
       
       Write-Log "Script completed successfully"
   }
   catch {
       Write-Log "Script failed: $_" -Level Error
       throw
   }
   finally {
       # Cleanup code here
   }
   #endregion
   ```

2. **Module Structure** - Recommended structure for PowerShell modules.
   ```
   Structure:
   MyModule/
   ├── MyModule.psd1          # Module manifest
   ├── MyModule.psm1          # Root module
   ├── Public/                # Exported functions
   │   ├── Get-Something.ps1
   │   └── Set-Something.ps1
   ├── Private/               # Internal functions
   │   └── Helper-Function.ps1
   ├── Classes/               # PowerShell classes
   │   └── MyClass.ps1
   ├── Tests/                 # Pester tests
   │   ├── Get-Something.Tests.ps1
   │   └── Set-Something.Tests.ps1
   └── docs/                  # Documentation
   ```

3. **Splatting for Readability** - Use splatting (@params) for commands with many parameters.
This improves readability and makes parameter changes easier.

   ```
   $mailParams = @{
       To         = $recipients
       From       = $sender
       Subject    = $subject
       Body       = $body
       SmtpServer = $smtpServer
       Priority   = 'High'
   }
   Send-MailMessage @mailParams
   ```

4. **Pipeline vs ForEach** - Use pipeline (|) for streaming large data sets. Use ForEach-Object -Parallel
for CPU-bound operations in PowerShell 7+. Use foreach statement for
small collections when you need break/continue.

   ```
   Pipeline Streaming:
   Get-ChildItem -Recurse | Where-Object { $_.Length -gt 1MB }
   ```
   ```
   Parallel Processing:
   $servers | ForEach-Object -Parallel {
       Test-Connection $_ -Count 1
   } -ThrottleLimit 10
   ```
   ```
   Foreach With Control:
   foreach ($item in $smallCollection) {
       if ($item.Skip) { continue }
       Process-Item $item
   }
   ```

5. **Cross-Platform Considerations** - Key differences when writing cross-platform scripts.
   ```
   Considerations:
   # Environment variables are case-sensitive on Linux
   $env:PATH        # Windows: works
   $env:Path        # Linux: works (PowerShell normalizes)
   $env:path        # Use consistent casing
   
   # Use static .NET methods for platform-independent values
   [Environment]::UserName        # Instead of $env:USERNAME
   [Environment]::MachineName     # Instead of $env:COMPUTERNAME
   [IO.Path]::GetTempPath()       # Instead of $env:TEMP
   [Environment]::NewLine         # Instead of "`r`n" or "`n"
   
   # File system is case-sensitive on Linux
   Get-ChildItem "Config.json"    # Won't find config.json on Linux!
   ```

6. **SecretManagement for Credentials** - Use the SecretManagement module (PowerShell 7+) for storing and
retrieving secrets securely. Supports multiple vault backends.

   ```
   Usage:
   # Install modules (one-time)
   Install-Module Microsoft.PowerShell.SecretManagement
   Install-Module Microsoft.PowerShell.SecretStore
   
   # Register a vault
   Register-SecretVault -Name LocalStore -ModuleName Microsoft.PowerShell.SecretStore
   
   # Store a secret
   Set-Secret -Name "APIKey" -Secret $secureString -Vault LocalStore
   
   # Retrieve a secret
   $apiKey = Get-Secret -Name "APIKey" -AsPlainText
   ```

---

## Anti-Patterns

| Anti-Pattern | Description | Fix |
|--------------|-------------|-----|
| Invoke-Expression with input |  | Use & operator or splatting |
| Plain text passwords |  | Get-Credential, SecretManagement, env vars |
| Write-Host for data |  | Write-Output or implicit output |
| Aliases in scripts |  | Full cmdlet names |
| $var -eq $null |  | $null -eq $var |
| String path concatenation |  | Join-Path |
| No -ErrorAction Stop |  | -ErrorAction Stop or $ErrorActionPreference |
| Empty catch block |  | At minimum, log the error |
| = instead of -eq |  | Use -eq for comparison |
| Global variables |  | Parameters or script scope |
