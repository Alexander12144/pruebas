param(
    [string]$push
)

# si se inclute el parametro test imprime mensaje
if ($push -ne "push") {
    Write-Host "Modo de prueba" -ForegroundColor Yellow
}

# Verificar si existe la carpeta release y si no existe crearla
if (!(Test-Path -Path "./release")) {
    New-Item -Path "./release" -ItemType Directory
}

# Leer el archivo pubspec.yaml
$content = Get-Content -Path ./pubspec.yaml

# Buscar la línea que contiene la versión
$versionLine = $content | Where-Object { $_ -match "version:" }

# Extraer el número de versión
$version = $versionLine -replace "version: ", "" -replace '"', ''
Write-Host "Versión: $version" -ForegroundColor Cyan

# split en + para tomar solo la primera parte
$version = $version.Split('+')[0]

# Quita los puntos de la versión
$version = $version.Replace(".", "")

# Construir el nombre del archivo APK
$apkName = "app_impulsa_v$version.apk"
Write-Host "Nombre del APK: $apkName" -ForegroundColor Green

# Generar el APK
Write-Host "Iniciando la construcción del APK..." -ForegroundColor Yellow
flutter build apk

# Mover y renombrar el APK
Move-Item -Path "./build/app/outputs/flutter-apk/app-release.apk" -Destination "./release/$apkName"

# Mostrar la ruta del APK
Write-Host "APK generado exitosamente ./$apkName" -ForegroundColor Green

# Generar versión web
Write-Host "Iniciando la construcción de la versión web..." -ForegroundColor Yellow
flutter build web

# Mover y renombrar la carpeta
Move-Item -Path "./build/web" -Destination "./release/app_impulsa_v${version}_web"

# Abrir la carpeta "release" y poner en primer plano
explorer.exe .\release

Write-Host "=====================================================" -ForegroundColor Yellow

# TODO pendiente conversar la fusión de las ramas
if ($push -eq "push") {
    # Mensaje de actualización de rama master

    # Write-Host "Actualización de la rama master" -ForegroundColor Yellow

    # Checkout a la rama master
    # git checkout master

    # Merge con la rama dev
    # git merge dev

    # Push a la rama master 
    # git push origin master

    # regresar a la rama dev
    # git checkout dev

    Write-Host "=====================================================" -ForegroundColor Yellow
}
