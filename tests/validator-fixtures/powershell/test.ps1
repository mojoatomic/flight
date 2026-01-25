# PowerShell with violations

# N1: Plain text credentials
$password = "secret123"

# N2: Invoke-Expression
Invoke-Expression $userInput

# M1: No error handling
Get-Content C:\important.txt
