@echo off
setlocal enabledelayedexpansion

:: ==============================
:: KULLANICI AYARLARI (DÜZENLE)
:: ==============================
set MYSQL_CONTAINER=public_mysql
set MYSQL_USER=root
set MYSQL_PASS=rootpassword

:: ==============================
:: backups klasörü yoksa oluþtur
:: ==============================
if not exist backups (
    mkdir backups
)

:: Log dosyasý
set log_file=backups\backup.log

:: ==============================
:: Sýkýþtýrma tercihi
:: ==============================
echo Yedekleri zip olarak almak ister misiniz? (E/H)
set /p compress=Sikistirma secimi (E = Evet, H = Hayir): 

if /i not "%compress%"=="E" if /i not "%compress%"=="H" (
    echo Gecersiz secim, islem iptal edildi.
    echo [%date% %time%] Gecersiz sikistirma secimi. >> %log_file%
    goto :son
)

:: ==============================
:: Veritabaný listesini al
:: ==============================
docker exec %MYSQL_CONTAINER% mysql -u%MYSQL_USER% -p%MYSQL_PASS% -e "SHOW DATABASES;" > dblist.txt

:: Sistem veritabanlarýný filtrele
set /a count=0
echo Mevcut Veritabanlari:
for /f "skip=1 tokens=*" %%a in (dblist.txt) do (
    set "db=%%a"
    if /i not "!db!"=="information_schema" if /i not "!db!"=="mysql" if /i not "!db!"=="performance_schema" if /i not "!db!"=="sys" (
        set /a count+=1
        set "db!count!=!db!"
        echo [!count!] !db!
    )
)

:: Ek seçenekler
echo [0] Tumunu Yedekle
echo [X] Iptal
echo.

:: ==============================
:: Kullanýcý seçimi
:: ==============================
set /p secim=Yedeklemek istediginiz veritabani numaralari (boslukla ayir, 0 = Tum, X = Iptal): 

if not defined secim (
    echo Hicbir secim yapilmadi, iptal edildi.
    echo [%date% %time%] Hicbir secim yapilmadi, islem iptal edildi. >> %log_file%
    goto :son
)

if /i "%secim%"=="X" (
    echo Islem iptal edildi.
    echo [%date% %time%] Islem kullanici tarafindan iptal edildi. >> %log_file%
    goto :son
)

:: ==============================
:: Tarih-saat oluþtur
:: ==============================
for /f "tokens=2-4 delims=. " %%a in ("%date%") do (
    set gun=%%a
    set ay=%%b
    set yil=%%c
)
for /f "tokens=1-3 delims=:," %%a in ("%time: =0%") do (
    set saat=%%a
    set dakika=%%b
    set saniye=%%c
)
set timestamp=!gun!!ay!!yil!_!saat!!dakika!!saniye!

:: ==============================
:: Geçici .sql dosya listesi
:: ==============================
set filelist=backups\_sql_files_!timestamp!.txt
break > "!filelist!"

:: ==============================
:: Yedekleme iþlemi
:: ==============================
if "%secim%"=="0" (
    for /L %%i in (1,1,!count!) do (
        set "dbname=!db%%i!"
        set "sqlfile=backups\!dbname!_!timestamp!.sql"
        docker exec %MYSQL_CONTAINER% sh -c "exec mysqldump -u%MYSQL_USER% -p%MYSQL_PASS% --databases !dbname!" > "!sqlfile!" 2>> %log_file%
        if exist "!sqlfile!" (
            echo [%date% %time%] SQL yedek alindi: !sqlfile! >> %log_file%
            echo !sqlfile!>> "!filelist!"
        ) else (
            echo [%date% %time%] HATA: !dbname! yedeklenemedi. >> %log_file%
        )
    )
) else (
    for %%s in (%secim%) do (
        set "dbname=!db%%s!"
        if defined dbname (
            set "sqlfile=backups\!dbname!_!timestamp!.sql"
            docker exec %MYSQL_CONTAINER% sh -c "exec mysqldump -u%MYSQL_USER% -p%MYSQL_PASS% --databases !dbname!" > "!sqlfile!" 2>> %log_file%
            if exist "!sqlfile!" (
                echo [%date% %time%] SQL yedek alindi: !sqlfile! >> %log_file%
                echo !sqlfile!>> "!filelist!"
            ) else (
                echo [%date% %time%] HATA: !dbname! yedeklenemedi. >> %log_file%
            )
        ) else (
            echo [%date% %time%] Hatali secim yapildi: %%s >> %log_file%
        )
    )
)

:: ==============================
:: ZIP oluþtur
:: ==============================
if /i "%compress%"=="E" (
    set "zipname=backups\backup_!timestamp!.zip"
    powershell -Command "Compress-Archive -Path (Get-Content '!filelist!') -DestinationPath '!zipname!'" >> %log_file% 2>&1
    if exist "!zipname!" (
        for /f %%f in ('type "!filelist!"') do del "%%f"
        echo [%date% %time%] ZIP olusturuldu: !zipname! >> %log_file%
    ) else (
        echo [%date% %time%] HATA: ZIP olusturulamadi. >> %log_file%
    )
)

:: ==============================
:: Temizlik
:: ==============================
del dblist.txt >nul 2>&1
del "!filelist!" >nul 2>&1
exit
