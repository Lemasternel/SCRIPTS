$rg_name = "RG_BRS"
$loc_name = "brazilsouth"
$subnet_name = "SNET_BRS_SERVERS"
$vnet_name = "VNET_BRS"
$vm_pub_name = "MicrosoftWindowsServer"
$vm_offer_name = "WindowsServer"
$vm_sku_name = "2016-Datacenter"
$vm_size = "Standard_A1"
$vm_pub_ip = "IPPUB_BRS_WS"
$vm_nsg_name = "NSG_BRS_WS"
$vm_ni_name = "NI_BRS_WS"
$vm_name = "VM_BRS_WS"
$vm_comp_name = "VMBRSWS"
$vm_rdp_rule_name = "ALLOW_RDP"
$vm_http_rule_name = "ALLOW_HTTP"
$vm_usr_name = "adminAdmin"
$vm_pwd_name = "admin!@ADMIN"
$vm_crypt_pwd = ConvertTo-SecureString $vm_pwd_name -AsPlainText -Force

Write-Host ""
Write-Host "Este SCRIPT criará a estrutura inicial de uma plataforma cloud no Azure."
Write-Host "Será criado dentro da localização '${loc_name}'..."
Write-Host ""
Write-Host "Grupo de recurso '${rg_name}'"
Write-Host "Rede virtual '${vnet_name}' contendo a subnet '${subnet_name}'"
Write-Host "Máquina virtual '${vm_name} - ${vm_size}' com '${vm_offer_name} - ${vm_sku_name}', permitindo acesso RDP e HTTP."
Write-Host ""

$continuar = Read-Host "Continuar? (S, N). Padrão S"
if ($continuar -eq "N" -or $continuar -eq "n") {
    Write-Host "Processo abortado!" 
    Return
}

Write-Host "Faça login na sua conta"
$login = Login-AzureRmAccount

if (!$login) { 
    Write-Host "Processo abortado, falha na tentativa de login!" 
    Return
}

Write-Host ""
Write-Host "..INICIANDO CRIAÇÃO DA ESTRUTURA INICIAL DA CLOUD.."
Write-Host ""

Write-Host "Criando grupo de recurso '${rg_name}'. AGUARDE! "
New-AzureRmResourceGroup -ResourceGroupName $rg_name -Location $loc_name

Write-Host "Configurando Subnet '${subnet_name}'. AGUARDE! "
$sbnet_servers = New-AzureRmVirtualNetworkSubnetConfig -Name $subnet_name -AddressPrefix 10.1.0.0/25

Write-Host "Criando rede virtual '${vnet_name}'. AGUARDE! "
$vnet = New-AzureRmVirtualNetwork -Name $vnet_name -ResourceGroupName $rg_name -Location $loc_name -AddressPrefix 10.1.0.0/24 -Subnet $sbnet_servers

Write-Host "Criando ip público para VM '${vm_pub_ip}'. AGUARDE! "
$ippub = New-AzureRmPublicIpAddress -ResourceGroupName $rg_name -Location $loc_name -AllocationMethod Static -IdleTimeoutInMinutes 4 -Name $vm_pub_ip

Write-Host "Configurando acesso RDP para VM '${vm_rdp_rule_name}'. AGUARDE! "
$nsg_rdp_rule = New-AzureRmNetworkSecurityRuleConfig -Name $vm_rdp_rule_name -Protocol Tcp -Direction Inbound -Priority 1000 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 3389 -Access Allow

Write-Host "Configurando acesso HTTP para VM '${vm_http_rule_name}'. AGUARDE! "
$nsg_http_rule = New-AzureRmNetworkSecurityRuleConfig -Name $vm_http_rule_name -Protocol Tcp -Direction Inbound -Priority 1001 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 80 -Access Allow

Write-Host "Criando grupo de segurança da rede '${vm_nsg_name}'. AGUARDE! "
$nsg = New-AzureRmNetworkSecurityGroup -Name $vm_nsg_name -ResourceGroupName $rg_name -Location $loc_name -SecurityRules $nsg_rdp_rule, $nsg_http_rule

Write-Host "Criando placa de rede '${vm_ni_name}'. AGUARDE! "
$subnet = Get-AzureRmVirtualNetwork -Name $vnet_name -ResourceGroupName $rg_name | Get-AzureRmVirtualNetworkSubnetConfig -Name $subnet_name
$ni = New-AzureRmNetworkInterface -Name $vm_ni_name -ResourceGroupName $rg_name -Location $loc_name -SubnetId $subnet.Id -PublicIpAddressId $ippub.Id -NetworkSecurityGroupId $nsg.Id

Write-Host "Configurando VM. AGUARDE! "
$vm_cred = New-Object -TypeName "System.Management.Automation.PSCredential" -ArgumentList $vm_usr_name, $vm_crypt_pwd
$vm_config = New-AzureRmVMConfig -VMName $vm_name -VMSize $vm_size | Set-AzureRmVMOperatingSystem -Windows -ComputerName $vm_comp_name -Credential $vm_cred  | Set-AzureRmVMSourceImage -PublisherName $vm_pub_name -Offer $vm_offer_name -Skus $vm_sku_name -Version "latest" | Add-AzureRmVMNetworkInterface -Id $ni.Id

Write-Host "Criando VM '${vm_name}'. AGUARDE! "
$vm = New-AzureRmVM -ResourceGroupName $rg_name -Location $loc_name -VM $vm_config

Write-Host "..FINALIZADA CRIAÇÃO DA ESTRUTURA INICIAL DA CLOUD.."
Write-Host ""
Write-Host "Credenciais para acesso a VM '${vm_name}': Usuário: ${vm_usr_name} Password: ${vm_pwd_name}"