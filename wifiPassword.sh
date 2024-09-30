#!/bin/bash

# Nome do arquivo para salvar redes Wi-Fi
arquivo_redes="$HOME/redes_wifi.txt"

# Nome do próprio script (ajustar se necessário)
script_rede="$0"

# Variável para armazenar a última rede
ultima_rede=""

# Função para exibir ajuda
mostrar_ajuda() {
    echo "Uso: $0 [opções]"
    echo ""
    echo "Este script monitora a conexão a novas redes Wi-Fi, exibe o nome da rede e, se solicitado,"
    echo "mostra a senha. Também salva essas informações em um arquivo."
    echo ""
    echo "Opções:"
    echo "  -h, --help        Exibe esta mensagem de ajuda"
    echo ""
    echo "Como funciona:"
    echo "  - Após tornar o script executável com ''chmod +x'' e executá-lo com ./script, ele vai:  "
    echo "  - Detectar mudanças na rede Wi-Fi e, quando conectado a uma nova rede, pergunta se"
    echo "    você deseja exibir a senha dessa rede."
    echo "  - As informações da rede e senha (se exibida) são salvas no arquivo: $arquivo_redes"
    exit 0
}

# Função para gravar no arquivo (sobrescrevendo)
gravar_no_arquivo() {
    echo "-----------------------------------" > "$arquivo_redes"
    echo "Rede: $1" >> "$arquivo_redes"
    if [ -n "$2" ]; then
        echo "Senha: $2" >> "$arquivo_redes"
    else
        echo "Senha: (não exibida ou rede aberta)" >> "$arquivo_redes"
    fi
    echo "-----------------------------------" >> "$arquivo_redes"
    echo "" >> "$arquivo_redes"
}

# Função para adicionar permissões sudoers sem senha para o script
adicionar_sudoers() {
    # Converte o caminho do script para um caminho absoluto
    script_rede_abs=$(realpath "$script_rede")
    echo "Caminho absoluto do script: $script_rede_abs"
    sudoers_entry="$USER ALL=(ALL) NOPASSWD: $script_rede_abs"

    # Verifica se a entrada já existe no arquivo sudoers
    if ! sudo grep -Fxq "$sudoers_entry" /etc/sudoers; then
        echo "Adicionando permissões sudo para o script $script_rede..."
        echo "$sudoers_entry" | sudo tee -a /etc/sudoers > /dev/null
        echo "Permissões sudo adicionadas com sucesso."
    else
        echo "Permissões sudo já estão configuradas."
    fi
}

# Verifica se o NetworkManager está instalado
if ! dpkg-query -W -f='${Status}' network-manager 2>/dev/null | grep -q "install ok installed"; then
    echo "NetworkManager não está instalado. Instalando agora..."
    sudo apt update
    sudo apt install -y network-manager
else
    echo "NetworkManager já está instalado."
fi

# Adicionar permissões sudo ao próprio script
adicionar_sudoers

# Verifica se o parâmetro -h ou --help foi fornecido
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mostrar_ajuda
fi

# Inicia o loop de verificação contínua
while true; do
    # Obtém a rede atual (SSID)
    rede_atual=$(nmcli -t -f active,ssid dev wifi | grep '^yes' | cut -d':' -f2)

    # Verifica se a rede mudou
    if [ "$rede_atual" != "$ultima_rede" ]; then
        echo "Você se conectou a uma nova rede: $rede_atual"

        # Faz o escape do nome da rede para evitar problemas com caracteres especiais
        rede_escapada=$(printf '%q' "$rede_atual")

        # Verifica se o arquivo de configuração da rede existe (tratando espaços e caracteres especiais no nome)
        config_path=$(find /etc/NetworkManager/system-connections/ -name "$rede_escapada*" | head -n 1)

        if [ -n "$config_path" ]; then
            # Pergunta ao usuário se deseja exibir a senha
            while true; do
                read -p "Deseja ver a senha da rede $rede_atual? (s/n): " exibir_senha
                if [[ "$exibir_senha" =~ ^[sn]$ ]]; then
                    break
                else
                    echo "Por favor, insira 's' para sim ou 'n' para não."
                fi
            done

            if [ "$exibir_senha" == "s" ]; then
                # Verifica se a rede tem uma senha configurada
                senha=$(sudo grep psk= "$config_path" | cut -d'=' -f2)

                if [ -n "$senha" ]; then
                    echo "A senha da rede $rede_atual é: $senha"
                    gravar_no_arquivo "$rede_atual" "$senha"  # Grava rede e senha no arquivo (sobrescrevendo)
                else
                    echo "Esta rede não possui senha (rede aberta ou senha não encontrada)."
                    gravar_no_arquivo "$rede_atual"  # Grava rede sem senha no arquivo (sobrescrevendo)
                fi
            else
                echo "Senha não exibida conforme solicitado."
                gravar_no_arquivo "$rede_atual"  # Grava rede sem senha no arquivo (sobrescrevendo)
            fi
        else
            echo "Arquivo de configuração da rede $rede_atual não encontrado."
        fi

        # Atualiza a última rede conectada
        ultima_rede="$rede_atual"

    else
        # Mostra a rede atual caso não haja mudança
        echo "Você já está conectado à rede: $rede_atual"
    fi

    # Espera um tempo antes de checar novamente
    sleep 10
done