@echo off
@>nul chcp 65001
setlocal enabledelayedexpansion

REM 配置为自己路径(git项目)
set "PROJECT_ROOT=D:\cvsHome_NR\system"

REM 配置为自己的数据库文件压缩包下载路径
set "ZDOWNLOAD_PATH=D:\zdownload"

REM 配置自己的MySQL账号和密码
set "MYSQL_USER=root"
set "MYSQL_PASSWORD=123456"

set "SCRIPT_PATH=%~f0"
set "LAST_CHOICE_FILE=%TEMP%\last_git_choice.txt"
REM 项目根目录: "%PROJECT_ROOT%\"

echo        __  __                         _____           _       _   
echo       ^|  \/  ^|                       / ____^|         (_)     ^| ^|  
echo       ^| \  / ^| __ _  ___ _ __ ___   ^| (___   ___ _ __ _ _ __ ^| ^|_ 
echo       ^| ^|\/^| ^|/ _` ^|/ __^| '__/ _ \   \___ \ / __^| '__^| ^| '_ \^| __^|
echo       ^| ^|  ^| ^| (_^| ^| (__^| ^| ^| (_) ^|  ____) ^| (__^| ^|  ^| ^| ^|_) ^| ^|_ 
echo       ^|_^|  ^|_^|\__,_^|\___^|_^|  \___/  ^|_____/ \___^|_^|  ^|_^| .__/ \__^|   Auto_Git v 2.8.0
echo                                                        ^|_^|        
echo          ^+---------------------------------------------------^+
echo          ^|                   使 用 说 明                     ^|
echo          ^| 1. (有暂存) 提交格式为 [序号-提交信息].           ^|
echo          ^| 2. (有暂存) 输序号,默认提交内容为[调整并优化页面].^|
echo          ^| 3. (无暂存) 输序号, 只更新当前序号的项目.         ^|
echo          ^| 4. (u*序号*) 更新 u 后面序号的项目.               ^|
echo          ^| 5. (ua) 更新全部项目.                             ^|
echo          ^| 6. (m 序号1 序号2 ...) 更新指定的多个项目.        ^|
echo          ^| 7. (sql*序号*) 还原数据库.                        ^|
echo          ^| 8. (s 序号1 序号2 ...) 简单更新指定的多个项目.    ^|
echo          ^| 9. (sa) 简单更新全部项目.                         ^|
echo          ^+---------------------------------------------------^+

set counter=1
set lineCounter=0
set maxWidth=0

REM 首先计算最长项目名称的长度
for /d %%d in ("%PROJECT_ROOT%\*") do (
    set "projectName=!counter!.%%~nxd"
    call :strLen projectName strlen
    if !strlen! gtr !maxWidth! set maxWidth=!strlen!
    set /a counter+=1
)
set /a maxWidth+=0
set counter=1

REM 然后显示对齐的项目列表
for /d %%d in ("%PROJECT_ROOT%\*") do (
    set "projects[!counter!]=%%d"
    set "projectName=!counter!.%%~nxd"
    call :padString "!projectName!" "!maxWidth!" projectDisplay
    <nul set /p ="[!projectDisplay!]  "
    set /a lineCounter+=1
    if !lineCounter! equ 5 (
        echo.
        set lineCounter=0
    )
    set /a counter+=1
)

if !lineCounter! neq 0 (
    echo.
)

if !counter! == 1 (
    echo 没有发现 Git 项目,退出脚本...
    timeout /t 3
    exit
)
echo ------------------------------------------------------------------------------------------------------------------------

:choice
set "last_choice="
if exist "%LAST_CHOICE_FILE%" (
    set /p last_choice=<"%LAST_CHOICE_FILE%"
    echo 直接回车使用上次选择的项目或操作: !last_choice! 
)
set /p choice="请输入要操作的 Git 项目序号或操作："
if "!choice!"=="" if not "!last_choice!"=="" set "choice=!last_choice!"

:execute_choice
set updateOnly=0
if "!choice!"=="ua" (
    echo !choice!>"%LAST_CHOICE_FILE%"
    call :updateAllProjects
    goto end_script
) else if "!choice!"=="sa" (
    echo !choice!>"%LAST_CHOICE_FILE%"
    call :simpleUpdateAllProjects
    goto end_script
) else if "!choice:~0,1!"=="u" (
    set updateOnly=1
    set choiceNumber=!choice:~1!
    echo !choice!>"%LAST_CHOICE_FILE%"
) else if "!choice:~0,1!"=="m" (
    echo !choice!>"%LAST_CHOICE_FILE%"
    call :updateMultipleProjects !choice:~2!
    goto end_script
) else if "!choice:~0,3!"=="sql" (
    set choiceNumber=!choice:~3!
    echo !choice!>"%LAST_CHOICE_FILE%"
    call :restoreDatabase !choiceNumber!
    goto end_script
) else if "!choice:~0,1!"=="s" (
    echo !choice!>"%LAST_CHOICE_FILE%"
    call :simpleUpdateMultipleProjects !choice:~2!
    goto end_script
) else (
    for /f "tokens=1,* delims=-" %%a in ("!choice!") do (
        set choiceNumber=%%a
        set commitMessage=%%b
    )
)
if not defined projects[!choiceNumber!] (
    echo 无效的序号,请重新输入...
    goto choice
)
if not defined commitMessage set commitMessage=调整并优化页面

REM 保存当前选择
echo !choice!>"%LAST_CHOICE_FILE%"

call :updateProject !choiceNumber!
if %updateOnly%==1 goto end_script

set hasChanges=0
pushd "!projects[%choiceNumber%]!"
for /f %%i in ('git diff --cached --name-only') do set hasChanges=1
popd

if %hasChanges% == 0 (
    goto end_script
)

REM 正在提交并推送 dev 分支暂存文件到 origin/dev...
pushd "!projects[%choiceNumber%]!"
REM 检查是否存在dev和deploy分支
git rev-parse --verify dev >nul 2>&1
set dev_exists=%errorlevel%
git rev-parse --verify deploy >nul 2>&1
set deploy_exists=%errorlevel%

if %dev_exists% neq 0 ( 
    if %deploy_exists% neq 0 (
        REM 本地不存在dev和deploy分支，只更新master分支
        git checkout master >nul 2>&1
        git pull origin master >nul 2>&1
        git add . >nul 2>&1
        git commit -m "%commitMessage%" > nul 2>&1
        git push origin master > nul 2>&1
        for /f %%i in ('git diff --name-only HEAD@{1} HEAD ^| find /c /v ""') do set "updatedFiles=%%i"
        echo 提交/推送 !updatedFiles! 个文件到master分支.
        popd
        echo 操作完成!
        goto :end_script
    )
)

git commit -m "%commitMessage%" > nul 2>&1
git push origin dev > nul 2>&1
for /f %%i in ('git diff --name-only HEAD@{1} HEAD ^| find /c /v ""') do set "updatedFiles=%%i"
echo 提交/推送 !updatedFiles! 个文件.
REM 推送当前分支到远程 master 分支...
git push origin dev:master > nul 2>&1

REM 正在切换到 deploy 分支...
git checkout deploy > nul 2>&1

REM 正在从 origin/dev 拉取代码到本地 deploy 分支...
git pull origin dev > nul 2>&1
REM 正在推送到 origin/deploy 分支和 origin/dev 分支...
git push origin deploy dev > nul 2>&1

REM 正在切换回 dev 分支...
git checkout dev > nul 2>&1

REM 正在拉取 origin/master 到本地 dev 分支...
git pull origin master > nul 2>&1

popd
echo 操作完成!

:end_script
timeout /t 1
exit
exit /b

:updateAllProjects
for /l %%i in (1,1,%counter%) do (
    if defined projects[%%i] (
        call :updateProject %%i
    )
)

echo 所有项目更新完成!
goto end_script

:restoreDatabase
set repoPath=!projects[%1]!
for %%I in ("!projects[%1]!") do set projectName=%%~nxI
echo 正在还原数据库: ⌈%projectName%⌋...

:: 检查是否存在ZIP文件
dir /b "%ZDOWNLOAD_PATH%\*.zip" >nul 2>&1
if %errorlevel% neq 0 (
    echo 警告: %ZDOWNLOAD_PATH% 目录中没有找到ZIP文件,跳过解压和数据库还原步骤...
    goto :skip_unzip_restore
)
REM 解压所有ZIP文件
for %%F in ("%ZDOWNLOAD_PATH%\*.zip") do (
    echo 正在解压文件 %%F...
    powershell -command "Expand-Archive -Path '%%F' -DestinationPath '%ZDOWNLOAD_PATH%' -Force"
    echo √解压成功...
)
:skip_unzip_restore

REM 执行SQL文件
for %%F in ("%ZDOWNLOAD_PATH%\*.sql") do (
    echo 正在还原数据库 %%F...
    mysql -u %MYSQL_USER% -p%MYSQL_PASSWORD% %projectName% --force < "%%F" > nul 2>&1
    if !errorlevel! neq 0 (
        echo ×还原失败，请检查错误并重试...
	del /q "%ZDOWNLOAD_PATH%\*.sql"
    ) else (
        echo √还原成功...
	REM 清理sql文件
	del /q "%ZDOWNLOAD_PATH%\*.zip"
	del /q "%ZDOWNLOAD_PATH%\*.sql"
    )
)
REM 执行额外的更新SQL
mysql -u %MYSQL_USER% -p%MYSQL_PASSWORD% %projectName% -e "UPDATE dr_sys_user set password='6f5fc701b7b3cd30fea52c8a12405337', encrypt='drsoft' where id='1'" > nul 2>&1
echo admin密码已重置...
goto end_script

:updateMultipleProjects
REM 正在更新多个项目...
:updateMultipleLoop
if "%1"=="" goto :eof
call :updateProject %1
shift
goto updateMultipleLoop

:updateProject
set repoPath=!projects[%1]!
for %%I in ("!projects[%1]!") do set projectName=%%~nxI
echo 正在更新: ⌈%projectName%⌋...

pushd "%repoPath%"
if not exist .git (
    echo 错误: ⌈%projectName%⌋ 不是一个有效的 Git 仓库。
    echo 请检查该目录是否包含 .git 文件夹，或者是否是一个 Git 仓库的根目录。
    echo 跳过此项目的更新。
    echo.
    popd
    exit /b
)

REM 检查是否存在dev和deploy分支
git rev-parse --verify dev >nul 2>&1
set dev_exists=%errorlevel%
git rev-parse --verify deploy >nul 2>&1
set deploy_exists=%errorlevel%

if %dev_exists% neq 0 ( 
    if %deploy_exists% neq 0 (
        REM 本地不存在dev和deploy分支，只从远程master拉取到本地master
        git checkout master >nul 2>&1
        git pull origin master >nul 2>&1
        popd
        echo ⌈%projectName%⌋ 更新完成
        echo ------------------------------------------------------------------------------------------------------------------------
        exit /b
    )
)

for /f %%i in ('git rev-parse --abbrev-ref HEAD 2^>nul') do set currentBranch=%%i
if /i not "%currentBranch%"=="dev" (
    git checkout dev > nul 2>&1
)

git pull origin dev > nul 2>&1
if %errorlevel% neq 0 (
    echo ⌈dev⌋检测到冲突...
    REM 尝试自动合并
    git merge -s recursive -X theirs origin/dev > nul 2>&1
    REM 检查是否还有冲突
    git diff --name-only --diff-filter=U > conflicts.txt
    if %errorlevel% neq 0 (
        echo 自动合并失败，以下文件仍存在冲突:
        for /f "delims=" %%i in (conflicts.txt) do (
            echo - %%i
        )
        echo.
        set /p choice="如何处理剩余冲突? (1:接受远程版本的更改 / 2:保留冲突标记 / 3:取消操作): "
        if "!choice!"=="1" (
            echo 正在接受远程版本的更改...
            for /f "delims=" %%i in (conflicts.txt) do (
                git checkout --theirs "%%i"
                git add "%%i"
                echo 已接受远程版本: %%i
            )
            git commit -m "Resolved conflicts by accepting remote changes" > nul 2>&1
            echo 冲突已解决，正在继续拉取...
            git pull origin dev
        ) else if "!choice!"=="2" (
            echo 保留冲突标记，请手动解决冲突后再次运行脚本...
            git add .
            del conflicts.txt
            popd
            exit /b
        ) else (
            echo 操作已取消,退出脚本...
            del conflicts.txt
            popd
            exit /b
        )
    ) else (
        echo 自动合并成功，正在提交更改...
        git commit -m "Auto-merged dev branch" > nul 2>&1
    )
    del conflicts.txt
)
git pull origin master > nul 2>&1

REM 计算并显示更新的文件数量
for /f %%i in ('git diff --name-only HEAD@{1} HEAD ^| find /c /v ""') do set "updatedFiles=%%i"
if %updatedFiles% gtr 0 (
    REM git diff --name-only HEAD@{1} HEAD
    echo 更新内容为: 
    git log -1 --pretty=format:"%%s%%n%%n%%b"
    echo 拉取到 !updatedFiles! 个文件...
    git push origin dev > nul 2>&1
)

REM 从master分支拉取
git pull origin master > nul 2>&1
if %errorlevel% neq 0 (
    echo 从⌈origin/master⌋拉取时检测到冲突
    REM 尝试自动合并
    git merge -s recursive -X theirs origin/master > nul 2>&1
    REM 检查是否还有冲突
    git diff --name-only --diff-filter=U > conflicts.txt
    if %errorlevel% neq 0 (
        echo 自动合并失败，以下文件仍存在冲突:
        for /f "delims=" %%i in (conflicts.txt) do (
            echo - %%i
        )
        echo.
        set /p choice="如何处理冲突? (1:接受远程master版本的更改 / 2:保留冲突标记 / 3:取消操作): "
        if "!choice!"=="1" (
            echo 正在接受远程master版本的更改...
            for /f "delims=" %%i in (conflicts.txt) do (
                git checkout --theirs "%%i"
                git add "%%i"
                echo 已接受远程master版本: %%i
            )
            git commit -m "Resolved conflicts by accepting remote master changes" > nul 2>&1
            echo 冲突已解决，正在推送到远程dev分支...
            git push origin dev > nul 2>&1
            if %errorlevel% neq 0 (
                echo 推送到远程dev分支失败，请手动处理
            ) else (
                echo 成功推送到远程dev分支
            )
        ) else if "!choice!"=="2" (
            echo 保留冲突标记，请手动解决冲突后再次运行脚本...
            git add .
            echo 已取消从⌈origin/master⌋的拉取操作，继续执行其他步骤...
        ) else (
            echo 操作已取消，继续执行其他步骤...
        )
    ) else (
        echo 自动合并master成功，正在提交更改...
        git commit -m "Auto-merged master branch" > nul 2>&1
        echo 正在推送到远程dev分支...
        git push origin dev > nul 2>&1
        if %errorlevel% neq 0 (
            echo 推送到远程dev分支失败，请手动处理
        ) else (
            echo 成功推送到远程dev分支
        )
    )
    del conflicts.txt
) else (
    git push origin dev > nul 2>&1
)

REM 正在切换到⌈deploy⌋分支...
git checkout deploy > nul 2>&1
REM 正在拉取 origin/dev 到本地 deploy 分支...
git pull origin dev > nul 2>&1
REM 正在检查是否有需要推送的内容...
git diff --quiet HEAD origin/deploy || git push origin deploy > nul 2>&1
REM 正在切换回⌈dev⌋分支...
git checkout dev > nul 2>&1
REM 正在拉取 origin/deploy 到本地 dev 分支...
git pull origin deploy > nul 2>&1
REM 正在拉取 origin/master 到本地 dev 分支...
git pull origin master > nul 2>&1

popd

echo ⌈%projectName%⌋ 更新完成
echo ------------------------------------------------------------------------------------------------------------------------
exit /b

:simpleUpdateAllProjects
echo 正在简单更新所有项目...
for /l %%i in (1,1,%counter%) do (
    if defined projects[%%i] (
        call :simpleUpdateProject %%i
    )
)
echo 所有项目简单更新完成!
goto end_script

:simpleUpdateMultipleProjects
REM 正在简单更新多个项目...
:simpleUpdateMultipleLoop
if "%1"=="" goto :eof
call :simpleUpdateProject %1
shift
goto simpleUpdateMultipleLoop

:simpleUpdateProject
set repoPath=!projects[%1]!
for %%I in ("!projects[%1]!") do set projectName=%%~nxI
echo 正在简单更新: ⌈%projectName%⌋...

pushd "%repoPath%"
if not exist .git (
    echo 错误: ⌈%projectName%⌋ 不是一个有效的 Git 仓库。
    echo 请检查该目录是否包含 .git 文件夹，或者是否是一个 Git 仓库的根目录。
    echo 跳过此项目的更新。
    echo.
    popd
    exit /b
)

REM 检查是否存在dev和deploy分支
git rev-parse --verify dev >nul 2>&1
set dev_exists=%errorlevel%
git rev-parse --verify deploy >nul 2>&1
set deploy_exists=%errorlevel%

if %dev_exists% neq 0 ( 
    if %deploy_exists% neq 0 (
        REM 本地不存在dev和deploy分支，只从远程master拉取到本地master
        git checkout master >nul 2>&1
        git pull origin master >nul 2>&1
        popd
        echo ⌈%projectName%⌋ 简单更新完成
        echo ------------------------------------------------------------------------------------------------------------------------
        exit /b
    )
)

REM 切换到dev分支并拉取代码
git checkout dev > nul 2>&1
git pull origin dev > nul 2>&1

REM 切换到deploy分支并拉取代码
git checkout deploy > nul 2>&1
git pull origin deploy > nul 2>&1

REM 切换回dev分支
git checkout dev > nul 2>&1

popd

echo ⌈%projectName%⌋ 简单更新完成
echo ------------------------------------------------------------------------------------------------------------------------
exit /b

:strLen
setlocal enabledelayedexpansion
:strLen_Loop
   if not "!%1:~%len%!"=="" set /A len+=1 & goto :strLen_Loop
(endlocal & set %2=%len%)
goto :eof

:padString
setlocal enabledelayedexpansion
set "str=%~1"
set "len=%~2"
set "spaces=                                        "
set "padded=!str!!spaces!"
set "padded=!padded:~0,%len%!"
endlocal & set "%~3=%padded%"
goto :eof