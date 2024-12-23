#!/bin/bash

CONFIG_FILE="deployment_config.json"
SCRIPT_VERSION="v4"

# Check if the configuration file exists
if [ ! -f "$CONFIG_FILE" ]; then
  echo "Configuration file not found. Creating a new one..."

  # Gather user inputs for the first time
  read -p "Enter your GitHub username: " GITHUB_USERNAME
  read -p "Enter the repository name (default: my-pwa): " REPO_NAME
  REPO_NAME=${REPO_NAME:-my-pwa}
  read -p "Enter the PWA name (default: MyPWA): " APP_NAME
  APP_NAME=${APP_NAME:-MyPWA}
  read -p "Enter the PWA description (default: A simple PWA): " DESCRIPTION
  DESCRIPTION=${DESCRIPTION:-A simple PWA}
  read -p "Enter the icon file name (default: icon.png): " ICON_NAME
  ICON_NAME=${ICON_NAME:-icon.png}

  # Create the configuration file
  cat <<EOF > $CONFIG_FILE
{
  "github_username": "$GITHUB_USERNAME",
  "repository_name": "$REPO_NAME",
  "pwa_name": "$APP_NAME",
  "pwa_description": "$DESCRIPTION",
  "start_url": "/$REPO_NAME/",
  "icon_name": "$ICON_NAME"
}
EOF

  echo "Configuration file created: $CONFIG_FILE"
else
  echo "Using existing configuration from $CONFIG_FILE..."
  GITHUB_USERNAME=$(jq -r '.github_username' $CONFIG_FILE)
  REPO_NAME=$(jq -r '.repository_name' $CONFIG_FILE)
  APP_NAME=$(jq -r '.pwa_name' $CONFIG_FILE)
  DESCRIPTION=$(jq -r '.pwa_description' $CONFIG_FILE)
  START_URL=$(jq -r '.start_url' $CONFIG_FILE)
  ICON_NAME=$(jq -r '.icon_name' $CONFIG_FILE)
fi

# Create project folder if not exists
mkdir -p $REPO_NAME
cd $REPO_NAME

# Generate index.html
cat <<EOF > index.html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$APP_NAME</title>
    <link rel="manifest" href="manifest.json">
    <script>
        document.addEventListener('DOMContentLoaded', () => {
            // Explicitly request notification permission
            if (Notification.permission === 'default') {
                Notification.requestPermission().then(permission => {
                    if (permission === 'granted') {
                        console.log('Notification permission granted.');
                    } else {
                        console.log('Notification permission denied.');
                    }
                });
            }

            // Periodic notifications every minute
            setInterval(() => {
                if (Notification.permission === 'granted') {
                    const notification = new Notification('Hello from $APP_NAME!', {
                        body: 'Click here to visit the GitHub homepage.',
                        icon: '$ICON_NAME'
                    });
                    notification.onclick = () => {
                        window.open('https://github.com/$GITHUB_USERNAME/$REPO_NAME', '_blank');
                    };
                }
            }, 60000); // 1 minute
        });
    </script>
</head>
<body>
    <h1>Welcome to $APP_NAME (Version: $SCRIPT_VERSION)!</h1>
    <p>This is a simple Progressive Web App with periodic notifications.</p>
    <p>Visit the <a href="https://github.com/$GITHUB_USERNAME/$REPO_NAME" target="_blank">GitHub Repository</a>.</p>
</body>
</html>
EOF

# Generate manifest.json
cat <<EOF > manifest.json
{
  "name": "$APP_NAME",
  "short_name": "$APP_NAME",
  "start_url": "$START_URL",
  "scope": "$START_URL",
  "display": "standalone",
  "background_color": "#ffffff",
  "description": "$DESCRIPTION",
  "icons": [
    {
      "src": "$START_URL$ICON_NAME",
      "sizes": "192x192",
      "type": "image/png"
    }
  ]
}
EOF

# Generate service-worker.js
cat <<EOF > service-worker.js
self.addEventListener('install', (event) => {
    console.log('[Service Worker] Install');
    event.waitUntil(
        caches.open('pwa-cache').then((cache) => {
            return cache.addAll([
                '$START_URL',
                '$START_URLindex.html',
                '$START_URLmanifest.json',
                '$START_URL$ICON_NAME'
            ]);
        })
    );
});

self.addEventListener('fetch', (event) => {
    event.respondWith(
        caches.match(event.request).then((response) => {
            return response || fetch(event.request);
        })
    );
});
EOF

# Generate placeholder icon if not exists
if [ ! -f "$ICON_NAME" ]; then
  echo -e "\033[33mGenerating a placeholder icon. Replace $ICON_NAME with your own.\033[0m"
  echo "PLACEHOLDER PNG DATA" > $ICON_NAME
fi

# Initialize git repository if not exists
if [ ! -d ".git" ]; then
  git init
  git remote add origin git@github.com:$GITHUB_USERNAME/$REPO_NAME.git
fi

# Ensure changes are committed
git add .
if ! git diff --cached --quiet; then
  git commit -m "Update PWA files for $APP_NAME (Version: $SCRIPT_VERSION)"
  echo "Changes committed."
else
  echo "No changes to commit."
fi

# Ensure main branch exists
if ! git rev-parse --verify main &> /dev/null; then
  echo "Creating main branch..."
  git checkout -b main
fi
git push -u origin main || echo "Main branch already pushed."

# Switch to or create gh-pages branch
if git rev-parse --verify gh-pages &> /dev/null; then
  echo "Switching to existing gh-pages branch..."
  git checkout gh-pages
else
  echo "Creating new gh-pages branch..."
  git checkout -b gh-pages
fi
git push -u origin gh-pages

echo -e "\033[32mDone! Your PWA is deployed on GitHub Pages.\033[0m"
echo -e "Check: https://$GITHUB_USERNAME.github.io/$REPO_NAME/"
