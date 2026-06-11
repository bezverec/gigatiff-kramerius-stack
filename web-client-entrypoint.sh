#!/bin/sh
set -eu

echo "Generating runtime environment file..."

cat <<EOF > /usr/share/nginx/html/assets/env.json
{
  "devMode": ${APP_DEV_MODE:-false},
  "environmentName": "${APP_ENV_NAME:-docker runtime}",
  "environmentCode": "${APP_ENV_CODE:-docker}",
  "krameriusId": "${APP_KRAMERIUS_ID:-gigatiff}"
}
EOF

# Local GigaTIFF deployment should be driven by APP_KRAMERIUS_ID/env.json.
# The upstream beta client gives localStorage dev overrides higher priority,
# which can keep loading MZK/CDK after earlier testing in the same browser.
find /usr/share/nginx/html -type f -name '*.js' -exec sed -i \
  -e 's/localStorage\.getItem("CDK_DEV_BASE_URL")/null/g' \
  -e 's/localStorage\.getItem("CDK_DEV_KRAMERIUS_ID")/null/g' \
  -e 's/localStorage\.setItem("CDK_DEV_KRAMERIUS_ID","mzk")/localStorage.removeItem("CDK_DEV_KRAMERIUS_ID")/g' \
  -e 's#getKrameriusId(){return null||this.get("krameriusId")||"mzk"}#getKrameriusId(){return"gigatiff"}#g' \
  -e 's#o="https://api.kramerius.mzk.cz"#o=window.location.origin#g' \
  -e 's#img/logo/mzk-logo.png#/favicon.svg#g' \
  {} +

sed -i 's#<head>#<head><script>try{localStorage.removeItem("CDK_DEV_BASE_URL");localStorage.removeItem("CDK_DEV_KRAMERIUS_ID");for(var i=localStorage.length-1;i>=0;i--){var k=localStorage.key(i);if(k?k.indexOf("cdk-cache:")===0:false)localStorage.removeItem(k);}}catch(e){console.warn("GigaTIFF localStorage cleanup failed",e);}</script>#' /usr/share/nginx/html/index.html
sed -i 's#<link rel="icon" type="image/x-icon" href="/img/favicon/favicon.png">#<link rel="icon" type="image/svg+xml" href="/favicon.svg"><link rel="shortcut icon" href="/favicon.svg">#' /usr/share/nginx/html/index.html
sed -i 's#</head>#<link rel="stylesheet" href="/gigatiff-square.css?v=13"></head>#' /usr/share/nginx/html/index.html
sed -i 's#</body>#<script src="/gigatiff-login-shortcut.js?v=4"></script></body>#' /usr/share/nginx/html/index.html

exec nginx -g "daemon off;"
