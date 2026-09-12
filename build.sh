#!/bin/bash
set -e

# Permitir que git opere como superusuario en entornos de compilación de CI/Vercel
git config --global --add safe.directory "*" || true

FLUTTER_VERSION="3.38.3"
echo "==> Verificando instalación de Flutter SDK ($FLUTTER_VERSION)..."
NEED_CLONE=false
if [ ! -d "$HOME/flutter" ] || [ ! -f "$HOME/flutter/bin/flutter" ]; then
  NEED_CLONE=true
else
  CURRENT_VERSION=$("$HOME/flutter/bin/flutter" --version 2>/dev/null | head -n 1 || echo "")
  if [[ "$CURRENT_VERSION" != *"$FLUTTER_VERSION"* ]]; then
    echo "==> Versión instalada ($CURRENT_VERSION) no coincide con $FLUTTER_VERSION. Reinstalando..."
    rm -rf "$HOME/flutter"
    NEED_CLONE=true
  fi
fi

if [ "$NEED_CLONE" = true ]; then
  echo "==> Clonando Flutter $FLUTTER_VERSION..."
  git clone --depth 1 -b $FLUTTER_VERSION https://github.com/flutter/flutter.git "$HOME/flutter"
fi

export PATH="$HOME/flutter/bin:$PATH"

flutter config --no-analytics || true
flutter precache --web || true

if [ -d "quebrado-app-flutter" ]; then
  echo "==> Entrando en directorio quebrado-app-flutter..."
  cd quebrado-app-flutter
fi

echo "==> Preparando variables de entorno..."
if [ -n "$SUPABASE_URL" ] && [ -n "$SUPABASE_ANON_KEY" ]; then
  echo "SUPABASE_URL=$SUPABASE_URL" > .env
  echo "SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY" >> .env
  if [ -n "$GEMINI_API_KEY" ]; then
    echo "GEMINI_API_KEY=$GEMINI_API_KEY" >> .env
  fi
  if [ -n "$GEMINI_MODEL" ]; then
    echo "GEMINI_MODEL=$GEMINI_MODEL" >> .env
  fi
elif [ -f ".env.example" ] && [ ! -f ".env" ]; then
  cp .env.example .env
fi

echo "==> Instalando dependencias de Flutter..."
flutter pub get

echo "==> Compilando Flutter Web Release..."
flutter build web --release \
  --no-tree-shake-icons \
  --no-wasm-dry-run \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  --dart-define=GEMINI_API_KEY="$GEMINI_API_KEY" \
  --dart-define=GEMINI_MODEL="$GEMINI_MODEL"

# Asegurar compatibilidad de outputDirectory para Vercel
if [ -d "build/web" ]; then
  mkdir -p ../quebrado-app-flutter/build/web 2>/dev/null || true
  cp -r build/web/* ../quebrado-app-flutter/build/web/ 2>/dev/null || true
fi

echo "==> Build web finalizado con éxito."
