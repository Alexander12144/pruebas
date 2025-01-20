#!/bin/bash

push=$1

# Si se incluye el parámetro "push", imprime mensaje
if [ "$push" != "push" ]; then
    echo -e "\e[33mModo de prueba\e[0m"
fi

# Verificar si existe la carpeta release y si no, crearla
if [ ! -d "./release" ]; then
    mkdir ./release
fi

# Leer el archivo pubspec.yaml
content=$(cat ./pubspec.yaml)

# Buscar la línea que contiene la versión
versionLine=$(echo "$content" | grep "version:")

# Extraer el número de versión
version=$(echo "$versionLine" | sed 's/version: //' | sed 's/"//g')
echo -e "\e[36mVersión: $version\e[0m"

# Split en + para tomar solo la primera parte
version=$(echo "$version" | cut -d'+' -f1)

# Quita los puntos de la versión
version=$(echo "$version" | sed 's/\.//g')

# Construir el nombre del archivo APK
apkName="app_impulsa_v$version.apk"
echo -e "\e[32mNombre del APK: $apkName\e[0m"

# Generar el APK
echo -e "\e[33mIniciando la construcción del APK...\e[0m"
flutter build apk

# Mover y renombrar el APK
mv ./build/app/outputs/flutter-apk/app-release.apk ./release/$apkName

# Mostrar la ruta del APK
echo -e "\e[32mAPK generado exitosamente ./release/$apkName\e[0m"

# Generar versión web
echo -e "\e[33mIniciando la construcción de la versión web...\e[0m"
flutter build web

# Mover y renombrar la carpeta
mv ./build/web ./release/app_impulsa_v${version}_web

# Abrir la carpeta "release"
xdg-open ./release

echo -e "\e[33m=====================================================\e[0m"

if [ "$push" == "push" ]; then
    echo -e "\e[33mActualización de la rama master\e[0m"

    # Checkout a la rama master
    # git checkout master

    # Merge con la rama dev
    # git merge dev

    # Push a la rama master
    # git push origin master

    # Regresar a la rama dev
    # git checkout dev

    echo -e "\e[33m=====================================================\e[0m"
fi
