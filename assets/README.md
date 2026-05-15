# Iconos de la aplicación

Coloca tu PNG del logo aquí como `icon.png` (recomendado 1024×1024 píxeles, fondo blanco con el documento en el centro).

Si quieres que se use como icono dentro de la app (en la barra superior y la pantalla de bienvenida), declara el asset en `pubspec.yaml`:

```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/icon.png
```

Luego ejecuta:

```bash
flutter pub get
```

El widget `DocumentLogo` ya está preparado para usar la imagen real cuando el archivo exista; mientras tanto dibuja un icono vectorial monocromo equivalente.

Para reemplazar también el icono del launcher de GNOME/KDE, copia tu PNG a:

```
~/.local/share/icons/hicolor/256x256/apps/notas.png
```

Y crea un `.desktop` apuntando a él.
