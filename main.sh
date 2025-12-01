# Terminal
#!/bin/bash

echo "=== SCANNER SSH com Terminal Distribuído ==="

# 1. Descobrir usuário atual
USUARIO=$(whoami)
echo "Usuário local: $USUARIO"

# 2. Verificar chaves SSH
if [ -f "/home/$USUARIO/.ssh/id_rsa" ]; then
    CHAVE="/home/$USUARIO/.ssh/id_rsa"
elif [ -f "/home/$USUARIO/.ssh/id_ed25519" ]; then
    CHAVE="/home/$USUARIO/.ssh/id_ed25519"
else
    echo "❌ Nenhuma chave SSH encontrada em /home/$USUARIO/.ssh/"
    echo "Gere uma chave com: ssh-keygen"
    exit 1
fi

echo "✔️ Chave encontrada: $CHAVE"
echo

# 3. Descobrir rede local
MEU_IP=$(hostname -I | awk '{print $1}')
REDE=$(echo $MEU_IP | cut -d'.' -f1,2,3)

echo "Rede detectada: $REDE.0/24"
echo

# 4. Scannear e conectar
echo "Procurando máquinas com SSH aberto..."

CONEXOES=()

for i in {1..254}; do
    IP="$REDE.$i"
    [ "$IP" = "$MEU_IP" ] && continue

    # Testa porta 22
    (echo >/dev/tcp/$IP/22) >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "SSH aberto em $IP — testando chave..."

        ssh -i "$CHAVE" -o BatchMode=yes -o ConnectTimeout=2 "$USUARIO@$IP" "echo OK" 2>/dev/null

        if [ $? -eq 0 ]; then
            echo "✔️ Conexão aceitou chave: $IP"
            CONEXOES+=("$IP")
        else
            echo "❌ Chave NÃO aceita em $IP"
        fi
    fi
done

echo
echo "Máquinas com SSH acessível:"
printf "%s\n" "${CONEXOES[@]}"
echo

if [ ${#CONEXOES[@]} -eq 0 ]; then
    echo "❌ Nenhuma máquina aceitou a chave SSH."
    exit 1
fi

echo "=== TERMINAL DISTRIBUÍDO ==="
echo "Digite comandos. Para sair, use: exit"
echo

while true; do
    read -p "> " CMD
    [ "$CMD" = "exit" ] && break

    echo "Executando comando em todos os hosts..."
    echo

    for IP in "${CONEXOES[@]}"; do
        echo "--- $IP ---"
        ssh -i "$CHAVE" -o BatchMode=yes -o ConnectTimeout=2 "$USUARIO@$IP" "$CMD"
        echo
    done
done
