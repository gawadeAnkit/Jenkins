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

Write-Host "`nService Web Dashboard Port Reference:" -ForegroundColor Cyan
Write-Host "  - Jenkins:    http://<Jenkins_Public_IP>:8080" -ForegroundColor White
Write-Host "  - App Server: http://<AppServer_Public_IP>:8080" -ForegroundColor White
Write-Host "  - Nexus:      http://<Nexus_Public_IP>:8081" -ForegroundColor White
Write-Host "  - SonarQube:  http://<SonarQube_Public_IP>:9000" -ForegroundColor White
