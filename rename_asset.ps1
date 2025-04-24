# Script PowerShell para renomear arquivos de assets do Zumbi para o padrão Tipo_Parte_Angulo.png

# Diretório base do projeto (onde o script está localizado)
$ProjectBaseDir = $PSScriptRoot # Diretório do script
# Diretório base dos assets do zumbi
$ZombieAssetsDir = Join-Path -Path $ProjectBaseDir -ChildPath "assets\enemies\zombie"

# Verifica se o diretório base existe
if (-not (Test-Path -Path $ZombieAssetsDir -PathType Container)) {
    Write-Error "Erro: Diretório $ZombieAssetsDir não encontrado."
    Write-Error "Certifique-se de que o script está na raiz do projeto (Solo-Hero) e que a pasta de assets existe."
    exit 1
}

Write-Host "Iniciando renomeação de assets do Zumbi em $ZombieAssetsDir"
Write-Host "---"

# Função para processar um diretório (walk, die1, die2)
function Process-Directory {
    param(
        [string]$DirPath,
        [string]$OldPrefixPattern, # Padrão do prefixo antigo (ex: "Walk", "Death1")
        [string]$NewPrefix         # Novo prefixo (ex: "Walk", "Die1")
    )

    $fullDirPath = Join-Path -Path $ZombieAssetsDir -ChildPath $DirPath
    if (-not (Test-Path -Path $fullDirPath -PathType Container)) {
        Write-Warning "Aviso: Diretório $fullDirPath não encontrado. Pulando."
        return
    }

    Write-Host "Processando diretório: $fullDirPath"

    # Loop através dos arquivos PNG no diretório especificado
    Get-ChildItem -Path $fullDirPath -Filter *.png | ForEach-Object {
        $file = $_
        $oldName = $file.Name
        $oldPath = $file.FullName

        # Regex para o padrão ANTIGO (com espaços)
        $regexOld = "^($OldPrefixPattern)\s(Body|Shadow)\s(\d{3})\.png$"
        # Regex para o padrão NOVO (com underscores) - para verificar se já foi renomeado
        $regexNew = "^(Walk|Die1|Die2)_(Body|Shadow)_(\d{3})\.png$"

        if ($oldName -match $regexOld) {
            $part = $matches[2]  # Body ou Shadow
            $angle = $matches[3] # 000, 045, etc.

            # Constrói o novo nome
            $newName = "${NewPrefix}_${part}_${angle}.png"

            # Renomeia apenas se o nome for diferente
            if ($oldName -ne $newName) {
                Write-Host "Renomeando '$oldName' para '$newName'" -ForegroundColor Yellow
                # !!! DESCOMENTE A LINHA ABAIXO PARA RENOMEAR DE VERDADE !!!
                Rename-Item -Path $oldPath -NewName $newName -Verbose
            } else {
                Write-Host "Ignorando (já está correto): $oldName" -ForegroundColor Gray
            }
        } elseif ($oldName -match $regexNew) {
            # Informa se o arquivo já parece estar no formato correto
            Write-Host "Ignorando (parece já renomeado): $oldName" -ForegroundColor Green
        } else {
            # Informa sobre arquivos com nomes inesperados
            Write-Host "Ignorando (nome inesperado): $oldName" -ForegroundColor Cyan
        }
    }
    Write-Host "Finalizado: $fullDirPath"
    Write-Host "---"
}

# Processa cada diretório de animação
Process-Directory -DirPath "walk" -OldPrefixPattern "Walk" -NewPrefix "Walk"
Process-Directory -DirPath "die1" -OldPrefixPattern "Death1" -NewPrefix "Die1"
Process-Directory -DirPath "die2" -OldPrefixPattern "Death2" -NewPrefix "Die2"

Write-Host "Processo de renomeação concluído." -ForegroundColor Magenta
Write-Host "Verifique a saída acima. Se tudo estiver correto, descomente a linha 'Rename-Item ...' no script e execute-o novamente." -ForegroundColor Magenta

exit 0