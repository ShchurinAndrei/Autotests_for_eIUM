# -*- coding: utf-8 -*-

*** Settings ***

Library    Process
Library    OperatingSystem
Library    Collections

Resource   %{IUM_ROBOTS_DIR}${/}common${/}resources${/}eIUM.resource
Resource   .${/}common.resource

Test teardown    Common teardown

*** Variables ***

${HOST_NAME}    medappfixpl01
${COLLECTOR_NAME_1}    Dec_Veraz_Test_furf
${COLLECTOR_NAME_2}    Proc_Veraz_Test_furf
${PATH_TO_OUTPUT_DIR}    /data/cdrs/tmp/file_perf_testing/input/L2/Dec_Veraz_Test_furf
${PATH_TO_INPUT_DIR_1}    /data/cdrs/tmp/file_perf_testing/input/L3/Dec_and_Proc_Veraz_Test_furf
${PATH_TO_INPUT_DIR_2}    /data/cdrs/tmp/file_perf_testing/input/L4/NEW
# ${TEST_VALUE_DIR}    /data/cdrs/tmp/file_perf_testing/sources/VERAZ
${TEST_VALUE_DIR}    ${CURDIR}/check/input

*** Keywords ***

*** Test Cases ***

    # путь до лог-файлов обоих коллекторов
    Add to remote interesting files    ${HOST_NAME}    /data/siu/var/log/${COLLECTOR_NAME_1}.log
    Add to remote interesting files    ${HOST_NAME}    /data/siu/var/log/${COLLECTOR_NAME_2}.log

    # остановка и очистка первого коллектора
    Stop collector    ${HOST_NAME}    ${COLLECTOR_NAME_1}
    Clean collector   ${HOST_NAME}    ${COLLECTOR_NAME_1}

    # очистка директории из которой первый коллектор берет файл с данными
    OperatingSystem.Remove File    ${PATH_TO_OUTPUT_DIR}/*
    # очистка директории в которой первый коллектор создает выходные файлые а второй коллектор читае получивиеся файлы
    OperatingSystem.Remove File    ${PATH_TO_INPUT_DIR_1}/*

    # создание списка файлов с тестовыми данными для передачи коллектору
    @{input_files}=    OperatingSystem.List Files In Directory    ${TEST_VALUE_DIR}
    # запись размера списка с файлами проверочных данных
    ${number_input_files}=   Get Length    ${input_files}
    # копирование всех файлов с тестовыми данными из директории автотеста в директорию откуда коллектор читает файлы
    FOR    ${file}    IN    @{input_files}
        OperatingSystem.Copy File    ${TEST_VALUE_DIR}/${file}    ${PATH_TO_OUTPUT_DIR}
    END

    # остановка и очистка второго коллектора
    Stop collector    ${HOST_NAME}    ${COLLECTOR_NAME_2}
    Clean collector   ${HOST_NAME}    ${COLLECTOR_NAME_2}

    # очистка директории в которой второй коллектор создает выходные файлые
    OperatingSystem.Remove File    ${PATH_TO_INPUT_DIR_2}/*

    # запуск первого коллектора
    Start collector   ${HOST_NAME}   ${COLLECTOR_NAME_1}
    # ожидание в лог-файле сообщения об успешном запуске первого коллектора
    Wait for message in remote command output    ${HOST_NAME}    cat /data/siu/var/log/${COLLECTOR_NAME_1}.log    The Encapsulator is starting to process data

    # запуск второго коллектора
    Start collector   ${HOST_NAME}   ${COLLECTOR_NAME_2}
    # ожидание в лог-файле сообщения об успешном запуске второго коллектора
    Wait for message in remote command output    ${HOST_NAME}    cat /data/siu/var/log/${COLLECTOR_NAME_2}.log    The Encapsulator is starting to process data

    # ожидание в лог-файле первого коллектора сообщения о количестве очищенных dataset-ов равным количеству входных файлов
    Wait for message in remote command output    ${HOST_NAME}    cat /data/siu/var/log/${COLLECTOR_NAME_1}.log    Dataset ${number_input_files} has been delivered.
    # создание списка файлов оставшихся во входной директории первого коллектора
    @{remaining_files_1}=    OperatingSystem.List Files In Directory    ${PATH_TO_OUTPUT_DIR}
    # проверка что директория с входными файлами первого коллектора пуста
    Should Be Empty    ${remaining_files_1}    The input directory is not empty!

    # ожидание в лог-файле второго коллектора сообщения о количестве очищенных dataset-ов равным количеству входных файлов
    ${number_input_files_2}=    Evaluate    ${number_input_files} - 1
    Wait for message in remote command output    ${HOST_NAME}    cat /data/siu/var/log/${COLLECTOR_NAME_2}.log    Dataset ${number_input_files_2} has been delivered.
    # создание списка файлов оставшихся во входной директории второго коллектора
    @{remaining_files_2}=    OperatingSystem.List Files In Directory    ${PATH_TO_INPUT_DIR_1}
    # проверка что директория с входными файлами второго коллектора содержит лишь 1 файл
    ${number_remaining_files_2}=   Get Length    ${remaining_files_2}
    Should Be Equal As Integers    ${number_remaining_files_2}    1    The number of files in the output directory is not equal to 1!

    # проверяем лог файл первого коллектора на наличие записей об ошибках
    Check remote log file for errors    ${HOST_NAME}    /data/siu/var/log/${COLLECTOR_NAME_1}.log
    # проверяем лог файл второго коллектора на наличие записей об ошибках
    Check remote log file for errors    ${HOST_NAME}    /data/siu/var/log/${COLLECTOR_NAME_2}.log

    # останавливаем первый коллектор
    ${rc_1}=    Run And Return Rc    /opt/${instance_name}/bin/siucontrol -host ${HOST_NAME} -n ${COLLECTOR_NAME_1} -c stopProc 2>&1
    # останавливаем второй коллектор
    ${rc_2}=    Run And Return Rc    /opt/${instance_name}/bin/siucontrol -host ${HOST_NAME} -n ${COLLECTOR_NAME_2} -c stopProc 2>&1

    # запускаем скрипт вычисления время работы коллектора и записывам результат для первого коллектора (в секундах)
    ${work_time_1}=    Run And Return    ./last-first.sh /data/siu/var/log/${COLLECTOR_NAME_1}.log
    # записываем в лог время работы первого коллектора
    Log    Work time of the first collector: ${work_time_1} seconds

    # запускаем скрипт вычисления время работы коллектора и записывам результат для второго коллектора (в секундах)
    ${work_time_2}=    Run And Return    ./last-first.sh /data/siu/var/log/${COLLECTOR_NAME_2}.log
    # записываем в лог время работы второго коллектора
    Log    Work time of the second collector: ${work_time_2} seconds