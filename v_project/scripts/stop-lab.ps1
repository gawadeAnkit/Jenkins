# ==============================================================================
# STOP VPROFILE LAB INSTANCES (Halts compute billing - $0.00 compute charges)
# ==============================================================================
Write-Host "Checking for running VProfile EC2 instances..." -ForegroundColor Cyan

$instances = aws ec2 describe-instances `
    --filters "Name=tag:Project,Values=vprofile" "Name=instance-state-name,Values=running,pending" `
    --query "Reservations[*].Instances[*].InstanceId" `
    --output text

if ($instances -and $instances.Trim() -ne "") {
    $idList = $instances.Trim() -split '\s+'
    Write-Host "Found $($idList.Count) running instance(s): $($idList -join ', ')" -ForegroundColor Yellow
    Write-Host "Stopping instances..." -ForegroundColor Yellow
    aws ec2 stop-instances --instance-ids $idList | Out-Null
    Write-Host "`nAll VProfile lab instances have been commanded to STOP." -ForegroundColor Green
    Write-Host "EC2 compute hours are now halted." -ForegroundColor Green
    Write-Host "All your data (Jenkins pipelines, Nexus artifacts, MySQL database) remains safely preserved on disk." -ForegroundColor Green
} else {
    Write-Host "No running VProfile instances found. All instances are already stopped." -ForegroundColor Gray
}
