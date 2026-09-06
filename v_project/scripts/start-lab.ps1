# ==============================================================================
# START VPROFILE LAB INSTANCES & DISPLAY SERVICE URLS
# ==============================================================================
Write-Host "Checking for stopped VProfile EC2 instances..." -ForegroundColor Cyan

$instances = aws ec2 describe-instances `
    --filters "Name=tag:Project,Values=vprofile" "Name=instance-state-name,Values=stopped" `
    --query "Reservations[*].Instances[*].InstanceId" `
    --output text

if ($instances -and $instances.Trim() -ne "") {
    $idList = $instances.Trim() -split '\s+'
    Write-Host "Starting $($idList.Count) instance(s): $($idList -join ', ')" -ForegroundColor Yellow
    aws ec2 start-instances --instance-ids $idList | Out-Null
    
    Write-Host "Waiting 30 seconds for instances to initialize and obtain new public IPs..." -ForegroundColor Cyan
    Start-Sleep -Seconds 30
} else {
    Write-Host "All instances are already started or running." -ForegroundColor Gray
}

Write-Host "`n========================================================" -ForegroundColor Green
Write-Host "          CURRENT VPROFILE LAB SERVICES STATUS         " -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green

aws ec2 describe-instances `
    --filters "Name=tag:Project,Values=vprofile" "Name=instance-state-name,Values=running,pending" `
    --query "Reservations[*].Instances[*].[Tags[?Key=='Name'].Value | [0], State.Name, PublicIpAddress]" `
    --output table

$rawJson = aws ec2 describe-instances `
    --filters "Name=tag:Project,Values=vprofile" "Name=instance-state-name,Values=running" `
    --query "Reservations[].Instances[].[Tags[?Key=='Name'].Value | [0], PublicIpAddress]" `
    --output json

$dict = @{}
if ($rawJson) {
    $arr = $rawJson | ConvertFrom-Json
    foreach ($item in $arr) {
        if ($item.Count -ge 2 -and $item[0]) {
            $dict[$item[0]] = $item[1]
        }
    }
}

$jenkinsIp = $dict['Jenkins server']
$appIp     = $dict['App server']
$nexusIp   = $dict['Nexus server']
$sonarIp   = $dict['SonarQube server']

Write-Host "`nLive Dashboard URLs:" -ForegroundColor Cyan
if ($jenkinsIp) { Write-Host "  - Jenkins:    http://${jenkinsIp}:8080" -ForegroundColor Green }
if ($appIp)     { Write-Host "  - App Server: http://${appIp}:8080" -ForegroundColor Green }
if ($nexusIp)   { Write-Host "  - Nexus:      http://${nexusIp}:8081" -ForegroundColor Green }
if ($sonarIp)   { Write-Host "  - SonarQube:  http://${sonarIp}:9000" -ForegroundColor Green }

if ($jenkinsIp) {
    Write-Host "`nGitHub Webhook URL (update in GitHub Settings -> Webhooks):" -ForegroundColor Yellow
    Write-Host "  http://${jenkinsIp}:8080/github-webhook/" -ForegroundColor White
}

