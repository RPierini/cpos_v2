#!/bin/bash

# Parâmetros de simulação de rede (podem ser passados como ENV vars se desejar)
DELAY=${NET_DELAY:-"50ms"}      # Atraso base
JITTER=${NET_JITTER:-"15ms"}    # Variação do atraso
LOSS=${NET_LOSS:-"1%"}          # Perda de pacotes

echo "Configurando simulação de rede: Atraso=$DELAY, Jitter=$JITTER, Perda=$LOSS para eth0"
# Adicionar qdisc base se não existir, senão mudar
tc qdisc show dev eth0 | grep -q "netem"
if [ $? -eq 0 ]; then
    echo "Modificando qdisc netem existente em eth0"
    tc qdisc change dev eth0 root netem delay $DELAY $JITTER loss $LOSS
else
    echo "Adicionando novo qdisc netem em eth0"
    tc qdisc add dev eth0 root netem delay $DELAY $JITTER loss $LOSS
fi

echo "Configuração de rede aplicada."
tc qdisc show dev eth0

echo "starting container..."

# Database related commands
service mariadb start
echo "initializing mempool"
mysql -e "CREATE USER 'CPoS'@localhost IDENTIFIED BY 'CPoSPW';"
mysql -e "GRANT ALL PRIVILEGES ON *.* TO 'CPoS'@'localhost';"
mysql -e "CREATE DATABASE mempool;"
mysql mempool < cpos/db/mempool.sql
echo "initializing local blockchain database"
mysql -e "CREATE DATABASE localBlockchain;"
mysql localBlockchain < cpos/db/localBlockchain.sql

# CPoS related commands
export GENESIS_TIMESTAMP=$(date -d '2024-06-01 00:00:00' +%s)
echo "GENESIS_TIMESTAMP: $GENESIS_TIMESTAMP"
poetry run python demo/main.py --beacon-ip $BEACON_IP --beacon-port $BEACON_PORT -p $PORT --genesis-timestamp $GENESIS_TIMESTAMP --total-rounds $NUMBER_OF_ROUNDS &
pid=$!

send_data() {
    echo "sending data..."
    poetry run python demo/send_data.py
    kill -SIGTERM $pid
    exit
}

trap "send_data" INT TERM

wait $pid
poetry run python demo/send_data.py
echo "exiting!"
