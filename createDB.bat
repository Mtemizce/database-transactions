:: MYSQL - Create Database
@echo off
setlocal enabledelayedexpansion
:: ==============================
:: KULLANICI AYARLARI (DÜZENLE)
:: ==============================
set MYSQL_CONTAINER=public_mysql
set MYSQL_USER=root
set MYSQL_PASS=rootpassword

set /p dbname=Olusturulacak Veritabani adi: 

docker exec -i %MYSQL_CONTAINER% mysql -u%MYSQL_USER% -p%MYSQL_PASS% -e "CREATE DATABASE IF NOT EXISTS !dbname!;"
echo Veritabani olusturuldu.
timeout /t 2 >nul
exit