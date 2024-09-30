#!/bin/bash

# Nome do arquivo para salvar redes Wi-Fi
ARQUIVO_REDES="$HOME/redes_wifi.txt"

# Nome do próprio script (ajustar se necessário)
SCRIPT_REDE="$0"

# Variável para armazenar a última rede
ULTIMA_REDE=""

# Função para exibir ajuda
mostrar_ajuda() {
    echo "Equipe: Caio Cavalcante Araújo"
    echo ""
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
    echo "  - As informações da rede e senha (se exibida) são salvas no arquivo: $ARQUIVO_REDES."
    echo "  - Para sair do terminal após executar o arquivo, pressione Ctrl + C ou Esc."
    exit 0
}

# Função para gravar no arquivo (sobrescrevendo)
gravar_no_arquivo() {
    echo "-----------------------------------" > "$ARQUIVO_REDES"
    echo "Rede: $1" >> "$ARQUIVO_REDES"
    if [ -n "$2" ]; then
        echo "Senha: $2" >> "$ARQUIVO_REDES"
    else
        echo "Senha: (não exibida ou rede aberta)" >> "$ARQUIVO_REDES"
    fi
    echo "-----------------------------------" >> "$ARQUIVO_REDES"
    echo "" >> "$ARQUIVO_REDES"
}

# Função para adicionar permissões sudoers sem senha para o script
adicionar_sudoers() {
    # Converte o caminho do script para um caminho absoluto
    SCRIPT_REDE_ABS=$(realpath "$SCRIPT_REDE")
    echo "Caminho absoluto do script: $SCRIPT_REDE_ABS"
    SUDOERS_ENTRY="$USER ALL=(ALL) NOPASSWD: $SCRIPT_REDE_ABS"

    # Verifica se a entrada já existe no arquivo sudoers
    if ! sudo grep -Fxq "$SUDOERS_ENTRY" /etc/sudoers; then
        echo "Adicionando permissões sudo para o script $SCRIPT_REDE..."
        echo "$SUDOERS_ENTRY" | sudo tee -a /etc/sudoers > /dev/null
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

# Função para verificar tecla ESC
verificar_esc() {
    read -rsn1 INPUT
    if [[ "$INPUT" == $'\e' ]]; then
        echo "ESC pressionado. Encerrando o script."
        exit 0
    fi
}

# Inicia o loop de verificação contínua
while true; do
    # Verifica se a tecla ESC foi pressionada
    verificar_esc &

    # Obtém a rede atual (SSID)
    REDE_ATUAL=$(nmcli -t -f active,ssid dev wifi | grep '^yes' | cut -d':' -f2)

    echo "Você está conectado à rede: $REDE_ATUAL"

    # Verifica se a rede mudou
    if [ "$REDE_ATUAL" != "$ULTIMA_REDE" ]; then
        echo "Você se conectou a uma nova rede: $REDE_ATUAL"

        # Faz o escape do nome da rede para evitar problemas com caracteres especiais
        REDE_ESCAPADA=$(printf '%q' "$REDE_ATUAL")

        # Verifica se o arquivo de configuração da rede existe (tratando espaços e caracteres especiais no nome)
        CONFIG_PATH=$(find /etc/NetworkManager/system-connections/ -name "$REDE_ESCAPADA*" | head -n 1)

        if [ -n "$CONFIG_PATH" ]; then
            # Pergunta ao usuário se deseja exibir a senha
            while true; do
                # Read sem -r propositalmente, caso a senha tenha "\"
                read -p "Deseja ver a senha da rede $REDE_ATUAL? (s/n): " EXIBIR_SENHA
                if [[ "$EXIBIR_SENHA" =~ ^[sn]$ ]]; then
                    break
                else
                    echo "Por favor, insira 's' para sim ou 'n' para não."
                fi
            done

            if [ "$EXIBIR_SENHA" == "s" ]; then
                # Verifica se a rede tem uma senha configurada
                SENHA=$(sudo grep psk= "$CONFIG_PATH" | cut -d'=' -f2)

                if [ -n "$SENHA" ]; then
                    echo "A senha da rede $REDE_ATUAL é: $SENHA"
                    gravar_no_arquivo "$REDE_ATUAL" "$SENHA"  # Grava rede e senha no arquivo (sobrescrevendo)
                else
                    echo "Esta rede não possui senha (rede aberta ou senha não encontrada)."
                    gravar_no_arquivo "$REDE_ATUAL"  # Grava rede sem senha no arquivo (sobrescrevendo)
                fi
            else
                echo "Senha não exibida conforme solicitado."
                gravar_no_arquivo "$REDE_ATUAL"  # Grava rede sem senha no arquivo (sobrescrevendo)
            fi
        else
            echo "Arquivo de configuração da rede $REDE_ATUAL não encontrado."
        fi

        # Atualiza a última rede conectada
        ULTIMA_REDE="$REDE_ATUAL"

    else
        # Mostra a rede atual caso não haja mudança
        echo "Você ainda está conectado na mesma rede."
    fi

    # Espera um tempo antes de checar novamente
    sleep 10
done