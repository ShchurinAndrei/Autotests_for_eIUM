#!/bin/bash

# Проверка, что были переданы два аргумента
if [ $# -ne 2 ]; then
    echo "Для работы скрипта $0 требуеться передать два аргумента: host_name и collector_name"
    exit 1
fi

# Присвоение аргументов переменным
host_name=$1
collector_name=$2

# Переход к директории в которой находиться файл iumix_setup.yml
cd ../../..

# Запуск виртуальной среды и подгрузка доп данных для работы автотеста
. iumix/rf/bin/init.sh

# Запуск автотеста
robot -V iumix_setup.yml   -v host_name:$host_name -v collector_name:$collector_name ${IUM_RF_DIR}/robots/collector/simple_data.robot