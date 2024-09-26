# -*- coding: utf-8 -*-

*** Settings ***

Library    Process
Library    OperatingSystem
Library    Collections
Library    DiffLibrary

Resource   %{IUM_ROBOTS_DIR}${/}common${/}resources${/}eIUM.resource
Resource   .${/}common.resource

Test teardown    Common teardown

*** Variables ***

# путь до директории с входными данными для коллектора, распростроняется с самим тестом
${TEST_VALUE_DIR}    ${CURDIR}/check/input
# путь до директории с проверочными данными для коллектора, распростроняется с самим тестом
${REFERENCE_VALUE_DIR}    ${CURDIR}/check/output
# путь до директории откуда коллектор берет файл с данными
${PATH_TO_INPUT_DIR}    /opt/SIU/tmp
# путь до директориии где коллектор создает выходные данные
${PATH_TO_OUTPUT_DIR}   /var/opt/SIU/${collector_name}/output

*** Keywords ***

*** Test Cases ***

Checking the correctness of the collector output to file
    # для работы теста, при запуске ему требуеться передать название хоста на котором развернут коллектор и имя коллектора
    Variable should exist    ${host_name}
    Variable should exist    ${collector_name}

    # путь до лог-файла коллектора
    Add to remote interesting files    ${host_name}    /var/opt/SIU/log/${collector_name}.log

    # остановка и очистка коллектора
    Stop collector    ${host_name}    ${collector_name}
    Clean collector   ${host_name}    ${collector_name}

    # очистка директории из которой коллектор берет файл с данными
    OperatingSystem.Remove File    ${PATH_TO_OUTPUT_DIR}/*
    # очистка директории в которой коллектор создает выходные файлые (должна быть уже очищена командой Clean collector)
    OperatingSystem.Remove File    ${PATH_TO_INPUT_DIR}/*

    # создание списка файлов с тестовыми данными для передачи коллектору
    @{input_files}=    OperatingSystem.List Files In Directory    ${TEST_VALUE_DIR}
    # копирование всех файлов с тестовыми данными из директории автотеста в директорию откуда коллектор читает файлы
    FOR    ${file}    IN    @{input_files}
        OperatingSystem.Copy File    ${TEST_VALUE_DIR}/${file}    ${PATH_TO_INPUT_DIR}
    END

    # запуск коллектора
    Start collector   ${host_name}    ${collector_name}

    # ожидание в лог-файле сообщения об успешном запуске коллектора
    Wait for message in remote command output    ${host_name}    cat /var/opt/SIU/log/${collector_name}.log    The Encapsulator is starting to process data

    # ожидание в лог-файле сообщения о выгрузке NME-данных в файл
    Wait for message in remote command output    ${host_name}    cat /var/opt/SIU/log/${collector_name}.log    Wrote NME file:
    # инициирование "ручного" флаша коллектора, для выгрузки всех NME которые могли остаться в памяти коллектора
    OperatingSystem.Run    /opt/SIU/bin/siucontrol -n ${collector_name} -c flushCol

    #-------------------------------------------------------------------------------
    OperatingSystem.Remove File    ${PATH_TO_OUTPUT_DIR}/WebUsage_nmefile
    #-------------------------------------------------------------------------------

    # создание списока файлов с проверочными данными
    @{reference_files}=    OperatingSystem.List Files In Directory    ${REFERENCE_VALUE_DIR}
    # запись размера списка с файлами проверочных данных
    ${number_reference_files}=   Get Length    ${reference_files}
    # создание списока файлов созданных коллектором
    @{collector_files}=    OperatingSystem.List Files In Directory    ${PATH_TO_OUTPUT_DIR}
    # запись размера списка с файлами сданными коллектором
    ${number_collector_file}=   Get Length    ${collector_files}

    # проверяем количество файлов созданных коллектором с количеством проверочных файлов
    Should Be Equal As Integers    ${number_collector_file}    ${number_reference_files}    The number of output files does not match!
    # сортируем по имени список с файлами соданными коллектором
    Sort List    ${collector_files}
    # сортируем по имени список с файлами проверочных данных
    Sort List    ${reference_files}
    # попарно сравниваем файлы из списка проверочных данных с файлами из спика созданных коллектором
    FOR    ${ref_file}    ${col_file}    IN ZIP    ${reference_files}    ${collector_files}
        DiffLibrary.Diff Files    ${REFERENCE_VALUE_DIR}/${ref_file}    ${PATH_TO_OUTPUT_DIR}/${col_file}
    END

    # проверяем лог файл на наличие записей об ошибках
    Check remote log file for errors    ${host_name}    /var/opt/SIU/log/${collector_name}.log

    # останавливаем коллектор
    ${rc}=    Run And Return Rc    /opt/${instance_name}/bin/siucontrol -host ${host_name} -n ${collector_name} -c stopProc 2>&1