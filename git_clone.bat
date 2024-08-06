@echo off
@>nul chcp 65001
setlocal enabledelayedexpansion

:: 设置目标路径
set "TARGET_PATH=D:\cvsHome_NR\system"

REM 配置为自己的数据库文件压缩包下载路径
set "ZDOWNLOAD_PATH=D:\zdownload"

REM 配置自己的MySQL账号和密码
set "MYSQL_USER=root"
set "MYSQL_PASSWORD=123456"

echo        __  __                         _____           _       _   
echo       ^|  \/  ^|                       / ____^|         (_)     ^| ^|  
echo       ^| \  / ^| __ _  ___ _ __ ___   ^| (___   ___ _ __ _ _ __ ^| ^|_ 
echo       ^| ^|\/^| ^|/ _` ^|/ __^| '__/ _ \   \___ \ / __^| '__^| ^| '_ \^| __^|
echo       ^| ^|  ^| ^| (_^| ^| (__^| ^| ^| (_) ^|  ____) ^| (__^| ^|  ^| ^| ^|_) ^| ^|_ 
echo       ^|_^|  ^|_^|\__,_^|\___^|_^|  \___/  ^|_____/ \___^|_^|  ^|_^| .__/ \__^|   Auto_Clone v2.7.1
echo                                                        ^|_^|        
echo          ^+---------------------------------------------------^+
echo          ^|                   使 用 说 明                     ^|
echo          ^| 1. 直接输入Git项目的SSH链接进行项目的拉取.        ^|
echo          ^+---------------------------------------------------^+
echo 执行顺序: Ⅰ.增加数据库  Ⅱ.解压数据库文件  Ⅲ.还原数据库  Ⅳ.克隆项目
echo           Ⅴ.检出分支    Ⅵ.增加.env文件    Ⅶ.拉取依赖    Ⅷ.完成

:: 提示用户输入 Git 仓库 URL
set /p REPO_URL="请输入 Git 仓库 URL(ssh): "

:: 确保目标路径存在
if not exist "%TARGET_PATH%" mkdir "%TARGET_PATH%"

:: 从 URL 中提取仓库名称（假设为 URL 的最后一部分，去掉 .git）
for %%I in (%REPO_URL%) do set "REPO_NAME=%%~nI"

:: 检查数据库是否存在
mysql -u %MYSQL_USER% -p%MYSQL_PASSWORD% -e "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = '%REPO_NAME%'" | findstr /i "%REPO_NAME%" > nul
if %errorlevel% equ 0 (
    echo 数据库 %REPO_NAME% 已存在,跳过创建...
) else (
    call mysql -u %MYSQL_USER% -p%MYSQL_PASSWORD% -e "CREATE DATABASE IF NOT EXISTS %REPO_NAME% CHARACTER SET utf8 COLLATE utf8_general_ci;" > nul 2>&1
    echo √数据库创建成功 %REPO_NAME%...
)

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
del /q "%ZDOWNLOAD_PATH%\*.zip"

REM 执行SQL文件
for %%F in ("%ZDOWNLOAD_PATH%\*.sql") do (
    echo 正在还原数据库 %%F...
    mysql -u %MYSQL_USER% -p%MYSQL_PASSWORD% %REPO_NAME% < "%%F" > nul 2>&1
    echo √还原成功...
)

REM 清理sql文件
del /q "%ZDOWNLOAD_PATH%\*.sql"

REM 执行额外的更新SQL
mysql -u %MYSQL_USER% -p%MYSQL_PASSWORD% %REPO_NAME% -e "UPDATE dr_sys_user set password='6f5fc701b7b3cd30fea52c8a12405337', encrypt='drsoft' where id='1'" > nul 2>&1
echo admin密码已重置...

:skip_unzip_restore

:: 切换到目标路径
cd /d "%TARGET_PATH%"

:: 检查项目是否已存在
if exist "%TARGET_PATH%\%REPO_NAME%" (
    echo 警告: 项目 %REPO_NAME% 已存在于 %TARGET_PATH% 目录中,跳过克隆项目...
)else (
    :: 执行 git clone 命令
    echo 正在克隆项目到 %TARGET_PATH% ...
    git clone %REPO_URL% > nul 2>&1
    echo √克隆成功...
)

:: 获取仓库名称（假设为 URL 的最后一部分，去掉 .git）
for %%I in (%REPO_URL%) do set "REPO_NAME=%%~nI"

:: 切换到克隆的仓库目录
cd %REPO_NAME%

echo 正在增加本地^(dev deploy^)分支
:: 检出 dev 分支
REM 正在检出 dev 分支...
git checkout -b dev origin/dev > nul 2>&1
:: 检出 deploy 分支
REM 正在检出 deploy 分支...
git checkout -b deploy origin/deploy > nul 2>&1
REM 切换回 dev 分支
git checkout dev > nul 2>&1
REM 删除本地 master 分支
git branch -d master > nul 2>&1
REM 正在拉取 origin/master 到本地 dev 分支...
git pull origin master > nul 2>&1
git push origin dev > nul 2>&1
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
echo √增加成功

:: 检查是否需要创建 .env 文件
if not exist ".env" (
    echo 正在创建env文件...
    (
    echo APP_DEBUG = true
    echo LOCAL_MODE = true
    echo COMPOSER_PATH =
    echo.
    echo [APP]
    echo APP_NAME =znr
    echo TIMEZONE = Asia/Shanghai
    echo LANG = zh-cn
    echo.
    echo [DATABASE]
    echo TYPE = mysql
    echo HOSTNAME = 127.0.0.1
    echo #Update Name
    echo DATABASE = %REPO_NAME%
    echo USERNAME = %MYSQL_USER%
    echo PASSWORD = %MYSQL_PASSWORD%
    echo HOSTPORT = 3306
    echo.
    echo [REDIS]
    echo HOST = 127.0.0.1
    echo PASSWORD =
    echo PORT = 6379
    echo SELECT = 0
    echo EXPIRE = 86400
    echo.
    echo [COOKIE]
    echo # HTTPONLY = true
    echo # SECURE = false
    echo.
    echo [SESSION]
    echo # NAME = PHPSESSID
    echo TYPE = cache
    echo STORE = redis
    echo EXPIRE = 1440
    ) > .env
    echo √创建成功...
) else (
    echo .env 文件已存在,跳过创建...
)

:: 检查是否需要拉取依赖
if not exist "composer.lock" (
    :: 拉取依赖
    echo 正在通过 Composer 拉取依赖...
    composer install > nul 2>&1 && echo √拉取成功... && pause
) else (
    echo composer.lock 文件已存在,跳过依赖拉取...
    pause
)
