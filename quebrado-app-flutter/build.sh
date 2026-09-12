#!/bin/bash
set -e

echo "==> Verificando instalación de Flutter SDK..."
if [ ! -d "$HOME/flutter" ]; then
  echo "==> Clonando Flutter stable..."
  git clone --depth 1 -b stable https://github.com/flutter/flutter.git $HOME/flutter
fi

export PATH="$HOME/flutter/bin:$PATH"

flutter config --no-analytics

echo "==> Preparando variables de entorno..."
if [ -n "$SUPABASE_URL" ] && [ -n "$SUPABASE_ANON_KEY" ]; then
  echo "SUPABASE_URL=$SUPABASE_URL" > .env
  echo "SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY" >> .env
  if [ -n "$GEMINI_API_KEY" ]; then
    echo "GEMINI_API_KEY=$GEMINI_API_KEY" >> .env
  fi
elif [ -f ".env.example" ] && [ ! -f ".env" ]; then
  cp .env.example .env
fi

echo "==> Instalando dependencias de Flutter..."
flutter pub get

echo "==> Compilando Flutter Web Release..."
flutter build web --release \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  --dart-define=GEMINI_API_KEY="$GEMINI_API_KEY"

echo "==> Build web finalizado con éxito en build/web."
