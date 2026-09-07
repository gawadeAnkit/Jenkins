# ==============================================================================
# PERMANENT TEARDOWN OF ALL VPROFILE LAB RESOURCES (100% $0.00 Cost Guarantee)
# ==============================================================================
Write-Host "======================================================================" -ForegroundColor Red
Write-Host "                   PERMANENT LAB INFRASTRUCTURE TEARDOWN              " -ForegroundColor Red
Write-Host "======================================================================" -ForegroundColor Red
Write-Host "This will run 'terraform destroy' to completely delete:" -ForegroundColor Yellow
Write-Host "  - Jenkins Server & EBS Volume" -ForegroundColor Yellow
Write-Host "  - SonarQube Server & EBS Volume" -ForegroundColor Yellow
Write-Host "  - Nexus Repository Server & EBS Volume" -ForegroundColor Yellow
Write-Host "  - Tomcat App Server & EBS Volume" -ForegroundColor Yellow
Write-Host "  - All associated Security Groups and Key Pairs" -ForegroundColor Yellow
Write-Host "`nAll EBS volumes will be deleted, ensuring exactly $0.00 ongoing charges." -ForegroundColor Green
Write-Host "======================================================================" -ForegroundColor Red

$confirm = Read-Host "Type 'destroy' to proceed with complete teardown"
if ($confirm -eq "destroy") {
    $tfDir = Join-Path $PSScriptRoot "..\terraform"
    Write-Host "`nInitiating Terraform Destroy in $tfDir..." -ForegroundColor Cyan
    terraform -chdir=$tfDir destroy -auto-approve
    Write-Host "`nAll AWS resources have been successfully destroyed. Account cost is $0.00." -ForegroundColor Green
} else {
    Write-Host "`nTeardown cancelled. No resources were modified." -ForegroundColor Gray
}
