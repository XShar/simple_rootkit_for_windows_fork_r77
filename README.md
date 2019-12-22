﻿# User-mode rootkit: Скрытие файлов и процессов от пользователя

Всем привет.

Решил я "поиграться с руткитами", особенно понравились две статьи от уважаемого @Nik Zerof с "Хакера":

https://xakep.ru/2018/01/26/winapi-hooks/

https://xakep.ru/2018/03/14/kmdf-driver/

Но тем не менее с одной стороны вроде всё понятно расписано, но с другой как мне показалось тема "сисек" до конца не раскрыта, в части боевого применения указанных методик.

Поэтому решил я посмотреть какие есть уже наработки и может-быть сделать что-то "свое", в кавычках т.к. многие вещи уже сделаны, иногда может проще сделать модификацию чего-то, чем писать с нуля...)

Итак для начала, небольшей ликбез какие бывают руткиты и для чего они нужны:

Я разделил такого типа программы на два класса:

1)User-mode rootkit (ring 3):

О них пойдет речь в этой статье, также здесь будет форк (Переработанная мной версия руткита r77 (https://bytecode77.com/hacking/payloads/r77-rootkit)), с автоматической установкой и удалением.

Итак User-mode руткиты, предназначены для скрытия сторонних программ непосредственно от пользователя, НО не от защитных решений, т.е. мы можем скрыть программу от диспетчера задач, 
скрыть отображения файла в експлорере, процесс-хакере и т.д.

НО в данном типе руткита мы не можем скрыть процесс от антивирусов, файерволов и т.д. Т.к. они работают в режиме ядра и тут ничего не сделать в юзер-моде.:(

Итак вкратце плюсы таких программ:

1. Относительно легко их писать. С основными техниками мы ознакомимся ниже.

2. Легко устанавливать и внедрять в систему. Нужны только права администратора.

Минусы таких программ:

Как я уже сказал, мы несможем скрыть от защитных решений, которые работают на уровне ядра. 

2)kernel-mode rootkit (ring 1):

Ну тут мы хозяева системы, мы можем скрывать своих зверьков как от пользователя, так и от защитных решений...

Плюсы таких решений:

Ну тут понятно, что можем написать такой руткит, что никто и никогда не найдет вашего зверька, даже если антивирусы добавят его в базы, ведь мы можем удалить процесс из списка процессов, 
удалить отображение файла в файловой системе, управлять выводом и что хочешь делать...

Рекомендую почитать статью: https://xakep.ru/2018/03/14/kmdf-driver/

Минусы таких решений:

1. Нужно понимать, что чем больше сила, тем больше ответственность, "Мы сами себе буратины", чуть ошиблись и синий экран смерти станет вашим другом.)

2. Для инсталяции таких драйверов нужна цифровая подпись, да можно купить, но если заниматься черными делами, то подпись быстро заблокируют, а она стоит 300 баксов. :(

Итак с теорией в этой части всё, идем дальше:

Теперь небольшей ликбез о User-mode руткитах, как они работают:

Не секрет, что программы подключают сторонние библиотеки, для использования как API винды, так и каких-то сторонних функций.

Этим и пользуются взломщики, если сделать инжект в нужный процесс, то можно поставить хук на нужную функцию и подменить результаты работы этой функции, 
более подробней про это можно прочитать здесь (Техника называется сплайсинг функций): https://xakep.ru/2018/01/26/winapi-hooks/

В статье сказано про платные библиотеки сплайсеров функции (Detours и madCodeHook), но не сказано про бесплатные аналоги, в данном решении я решил воспользоваться (https://github.com/TsudaKageyu/minhook) 
да она не бесглючная, но в целом для демонстрации подхода, который будет описан здесь, вполне сгодится.)

Также если глянете исходник MinHook там как мне кажется не плохой "Hacker Disassembler Engine", отличный дизассемблер длин инструкций, можно его использовать для написания своего сплайсера, 
но мне было лень заморачиваться, т.к. хотелось реализовать "свой подход", в кавычках т.к. тема не нова, уже есть разные движки, но было интересно поиграть...)))

Небольшей ликбез по сплайсерам:

Существует несколько библиотек перехвата API. Как правило, они делают следующее:
     
1) Заменяет начальную часть определенного функционального кода нашим собственным кодом (также известным как трамплин). 

2) После выполнения функция переходит к обработчику хука.
     
3) Сохраняет исходную версию замененного кода оригинальной функции. Это необходимо для правильной работы оригинальной функции.

4) Восстанавливает замененную часть оригинальной функции.

Также нужно сказать, что есть два вида хуков функции:

Local hooks: Это хуки для конкретной программы (То-что описано в первой статье от @Nik Zerof).

Global hooks: Это хуки для всех программ, то-что сделаем мы.)

Как я упоминал ранее, при создании наших глобальных хуков мы будем использовать библиотеку Mhook. 

Это бесплатная и простая в использовании библиотека с открытым исходным кодом для перехвата API Windows, поддерживающая архитектуры систем x32 и x64. Его интерфейс не сложен и не требует пояснений.

Теперь перейдем непосредственно к написанию нашего руткита:

Для скрытия процесса и файла в директории нам нужно перехватить как минимум две системные функции:

1)NtQuerySystemInformation - Получает огромный объем различной системной информации, в том числе и о процессах.

Многие функции Win32 в конечном итоге обращаются именно к этой функции для получения информации о процессах (Диспетчер задач, процесс хакер и т.д.).

Поэтому достаточно перехватить эту функцию в приложении и модифицировать структуру списка процессов.) 

2)NtQueryDirectoryFile - Получает список файлов в директории.

Перехватив эту функцию, мы также можем модифицировать структуру списка файла (Будто файла и нет вовсе).

Теперь описание нашего руткита, что он делает и как всё устроено:

Задача, скрыть процессы и отображение файла как минимум в эксплорере винды и диспетчера задача.)

Для этого будет сделано следующее:

1)Написана dll, которая будет загружаться во всех приложениях и устанавливать глобальных хук на указанные выше функции.

2)Написан батник, который будет загружать наш руткит, что конкретно будет делать батник:

Есть ветка в реесте:

HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT \CurrentVersion\Windows

А конкретно интересны следующие параметры:

 AppInit_DLLs — определяет библиотеки, необходимые для совместимости с каким_нибудь оборудованием или программой. 
 
 Все описанные в данном параметре библиотеки будут запускаться перед запуском любой программы.

А также:

RequireSignedAppInit_DLLs - Если единица, то будет процерка цифровой подписи указанных в AppInit_DLLs библиотек (Нам нужно установить в ноль).

LoadAppInit_DLLs - Разрешает загрузку библиотек в глобальные области (Нам нужна единица).

Батник добовляет библиотеки руткита в AppInit_DLLs и устанавливает нужные параметры и перезапускает эксплорер.

Также для беккапа, делает экспорт ветки реестра, есть и батник удаляющий руткит из реестра.

После инсталяции руткит начнет работать и файлы помеченные в названием меткой "HIDE" не будут отображаться в эксплорере и диспетчере задач, а также в процесс-хакере и т.д.

Минусы данного способа:

1) Могут быть затронуты только процессы, подключенные к User32.dll.

2) Могут быть вызваны только функции из Ntdll.dll и Kernel32.dll: причина в том, что перехват DLL происходит в DllMain файла User32.dll, и никакая другая библиотека не инициализируется в этот момент.

3) Нужно модифицировать реестр для инсталяции метода, для этого нужно обладать правами администратора системы.

ИСПОЛЬЗУЕМЫЕ ИСТОЧНИКИ:

1) Это альтернативная версия данного руткита:https://bytecode77.com/hacking/payloads/r77-rootkit

2) Альтернативная статья по скрытию процессов:https://www.apriorit.com/dev-blog/160-apihooks

3) Журнал "Хакер", статьи:

https://xakep.ru/2018/01/26/winapi-hooks/

https://xakep.ru/2018/03/14/kmdf-driver/

Отличие от оригинального руткита:

1)Был написан батник для автоматической инсталяции руткита, способ установки руткита и проверки работоспособности:

- В папке $Build для теста запустить "HIDE-ExampleExecutable_x64.exe" и "HIDE-ExampleExecutable_x86.exe".

- Запустить диспетчер задач и посмотреть, что процессы отображаются в списке процессов.

- Запустить файл "install.bat", ОБЯЗАТЕЛЬНО С ПРАВАМИ АДМИНИСТРАТОРА, перезапутить диспетчер задач и файлов в процессах уже не будет, также произойдет перезапуск explorer 
и файлы перестанут отображаться в папке.)

- Для удаления сделайте следующее:

Батник "install.bat" сделает беккап ветке в файл "uninstall.reg", который появится после запуска батника, можно сделать экспорт этого файла.

Либо есть отдельный скрипт "uninstall.bat", достаточно запутить его.

2)Был убран мусор в коде и добавлен отладочный вывод, что руткит работает сигнализирует файл "С:\\rootkit_debug.txt", если он не появился, значит что-то пошло нетак и руткит незапустился.)

Протестировано на Windows 7 x64 и Windows 10.

Данная статья является первой моей статьей о руткитах для Windows и Linux.

Решил сделать цикл статей.)))