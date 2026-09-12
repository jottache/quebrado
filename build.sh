#!/bin/bash
set -e

echo "==> Verificando instalación de Flutter SDK..."
if [ ! -d "$HOME/flutter" ]; then
  echo "==> Clonando Flutter stable..."
  git clone --depth 1 -b stable https://github.com/flutter/flutter.git $HOME/flutter
fi

export PATH="$HOME/flutter/bin:$PATH"

flutter config --no-analytics

echo "==> Entrando en directorio quebrado-app-flutter..."
cd quebrado-app-flutter

echo "==> Preparando variables de entorno..."
if [ -n "$SUPABASE_URL" ] && [ -n "$SUPABASE_ANON_KEY" ]; then
  echo "SUPABASE_URL=$SUPABASE_URL" > .env
  echo "SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY" >> .env
elif [ -f ".env.example" ] && [ ! -f ".env" ]; then
  cp .env.example .env
fi

echo "==> Instalando dependencias de Flutter..."
flutter pub get

echo "==> Compilando Flutter Web Release..."
flutter build web --release \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"

echo "==> Build web finalizado con éxito en quebrado-app-flutter/build/web."
