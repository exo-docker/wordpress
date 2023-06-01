#!/bin/bash -eu

WP_BASE=$(pwd)

echo #####################
echo "Using : ${WP_BASE} as wordpress base directory"
echo #####################

WP_CMD="sudo -u www-data wp --path=${WP_BASE}"

SRC_DIRECTORY=/src
WP_CONTENT_DIRECTORY=${SRC_DIRECTORY}/wp-content
# STATIC_DIRECTORY=/static

PLUGIN_DIRECTORY=${WP_CONTENT_DIRECTORY}/plugins
PLUGIN_LIST=${SRC_DIRECTORY}/plugins.lst
THEME_DIRECTORY=${WP_CONTENT_DIRECTORY}/themes
THEME_LIST=${SRC_DIRECTORY}/themes.lst
LANGUAGE_LIST=${SRC_DIRECTORY}/languages.lst

set +u
DEPLOY_MODE=${DEPLOY_MODE:dev}
set -u

function moveDirectory {
  local source=$1
  local dest=$2

  if [ ! -e $source ]; then
    echo ${source} does not exist
    exit 1
  fi

  if [ ! -e $dest ]; then
    echo ${dest} does not exist
    exit 1
  fi

  for f in $source/*; do
    name=$(basename $f $source)
    if [ -d $name ]; then
      if [ -d ${dest}/$name ]; then
        moveDirectory $f $dest/$name
        rm -rf $f
      else
        mv $f $dest
      fi
    else
      mv $f $dest
    fi

  done
}

function installLanguages() {
  echo "Languages installation..."
  if [ -e "${LANGUAGE_LIST}" ]; then
    while read language; do
      ${WP_CMD} core language install ${language}
    done < ${LANGUAGE_LIST}
  else
    echo ""
    echo "[INFO] No language to install found (${LANGUAGE_LIST} file not present})"
    echo ""
  fi
  echo "Languages installation done..."
  echo
}

function installRemotePlugins() {
  if [ -e "${PLUGIN_LIST}" ]; then
    echo Install plugins from repositories...

    for plugin in $(cat "${PLUGIN_LIST}" | grep -v "^#")
    do
      local name version
      name=$(echo $plugin | cut -f1 -d":")
      version=$(echo $plugin | cut -f2- -d":")

      echo
      echo -n Deploying plugin
      case $version in
        http*)
          echo " ${name} from ${version}"
          $WP_CMD plugin install --force ${version}
        ;;
        *)
          echo " ${name}:${version}"
          local params=""
          if [ ! -z "$version" ]; then
            params="${params} --version=${version}"
          fi

          $WP_CMD plugin install --force ${name} ${params}
        ;;
      esac

      $WP_CMD plugin activate ${name}

    done
  else
    echo Plugin list not found, Skipping remote plugin installation.
  fi
}

function installRemoteThemes() {
  if [ -e "${THEME_LIST}" ]; then
    echo Install themes from repositories...

    for theme in $(cat "${THEME_LIST}" | grep -v "^#")
    do
      local name version
      name=$(echo $theme | cut -f1 -d":")
      version=$(echo $theme | cut -f2- -d":")

      echo
      echo -n "Deploying theme "
      case $version in
        http*)
          echo "${name} from ${version}"
          $WP_CMD theme install --force ${version}
        ;;
        *)
          local params=""
          if [ ! -z "$version" ]; then
            params="${params} --version=${version}"
          fi
          echo "${name}:${version}"
          $WP_CMD theme install --force ${name} ${params}
        ;;
      esac

    done
  else
    echo Theme list not found, Skipping remote theme installation.
  fi
}


function installPluginsFromSources() {
  if [ ! -d $PLUGIN_DIRECTORY ]; then
    echo Plugin directory $PLUGIN_DIRECTORY not found, skipping plugins installation from sources.
  else
    echo Installing plugins from sources....
    cd ${PLUGIN_DIRECTORY}
    for plugin in $(find . -maxdepth 1 -type d | grep -v "^\.$")
    do
      echo Installing plugin ${plugin} from sources
      DEST="${WP_BASE}/wp-content/plugins/${plugin}"
      if [ -h "${DEST}" ]; then
        echo "WARNING : plugin directory for ${plugin} already exists, ignoring"
      else
        if [ "${DEPLOY_MODE}" == "dev" ]; then
          ln -s ${PLUGIN_DIRECTORY}/${plugin} ${WP_BASE}/wp-content/plugins
        else
          sudo -u www-data cp -rf ${PLUGIN_DIRECTORY}/${plugin} ${WP_BASE}/wp-content/plugins
        fi
      fi
    done
  fi
}

function installThemesFromSources() {
  if [ ! -d $THEME_DIRECTORY ]; then
    echo Theme directory ${THEME_DIRECTORY} not found, skipping themes installation from sources.
  else
    echo Install themes from sources....
    cd $THEME_DIRECTORY
    for theme in $(find . -maxdepth 1 -type d | grep -v "^\.$")
    do
      echo Installing theme ${theme} from sources
      DEST="${WP_BASE}/wp-content/themes/${theme}"
      if [ -h "${DEST}" ]; then
        echo "WARNING : plugin theme for ${theme} already exists, ignoring"
      else
        if [ "${DEPLOY_MODE}" == "dev" ]; then
            ln -s ${THEME_DIRECTORY}/${theme} ${WP_BASE}/wp-content/themes
        else
          sudo -u www-data cp -rf ${THEME_DIRECTORY}/${theme} ${WP_BASE}/wp-content/themes
        fi
      fi
    done
  fi
}

function manageWPCron() {
  echo 'control WP cron status' 
  [ ! -z "${WORDPRESS_DISABLE_CRON:-}" ] && {
    if [ $WORDPRESS_DISABLE_CRON == true ]; then
        $WP_CMD config set DISABLE_WP_CRON true;
        echo 'WP cron disabled'
    fi
  }

}

function manageWPMemLimit() {
  echo 'control Wordpress Mem limit' 
  [ ! -z "${WORDPRESS_MEMORY_LIMIT:-}" ] && {
    $WP_CMD config set WP_MEMORY_LIMIT ${WORDPRESS_MEMORY_LIMIT};
    echo "WP Mem limit set to ${WORDPRESS_MEMORY_LIMIT}"    
  }

}

function waitForDatabase() {
  local count=0
  local ret=1
  local max_try=60

  echo Waiting for database availability

  while [ ${count} -lt ${max_try} ] && [ ${ret} != 0 ]
  do
    set +e
    mysql -h db -u ${WORDPRESS_DB_USER} -p${WORDPRESS_DB_PASSWORD} -e 'select version()' &> /dev/null
    ret=$?
    set -e
    count=$(($count + 1))
    echo -n .
    sleep 1
  done
  echo

  if [ ${count} -ge ${max_try} ]; then
    echo ERROR database not available after ${max_try}s.
    exit 1
  fi
}

function setOption() {
  local KEY=$1
  local NEWVALUE=$2

  OLDVALUE=$(sudo -u www-data wp option get siteurl)
  if [ -z "${OLDVALUE}" ]; then
    echo Set ${KEY} to ${NEWVALUE}
    ${WP_CMD} option add ${KEY} ${NEWVALUE}
  else
    echo Change ${KEY} from ${OLDVALUE} to ${NEWVALUE}
    ${WP_CMD} option update ${KEY} ${NEWVALUE}
  fi
}

function configureStatusPage() {
  echo INFO FPM status page enabled : ${FPM_STATUS_ENABLED}
  if ${FPM_STATUS_ENABLED}; then
    cp /usr/local/etc/php-fpm.d/www.conf /tmp/www.conf
    sed -i 's/^;pm.status_path/pm.status_path/g' /usr/local/etc/php-fpm.d/www.conf
  fi
}

function configurePingPage() {
  echo INFO FPM ping page enabled : ${FPM_PING_ENABLED}
  if ${FPM_PING_ENABLED}; then
    cp /usr/local/etc/php-fpm.d/www.conf /tmp/www.conf
    sed -i 's/^;ping.path/ping.path/g' /usr/local/etc/php-fpm.d/www.conf
    sed -i 's/^;ping.response/ping.response/g' /usr/local/etc/php-fpm.d/www.conf
  fi
}

function configureProcessManager() {
  echo INFO FPM process manager configuration
  # Comment default configuration
  sed -i 's/^pm /;pm /g' /usr/local/etc/php-fpm.d/www.conf
  sed -i 's/^pm.max_children /;pm.max_children /g' /usr/local/etc/php-fpm.d/www.conf
  sed -i 's/^pm.start_servers /;pm.start_servers /g' /usr/local/etc/php-fpm.d/www.conf
  sed -i 's/^pm.min_spare_servers /;pm.min_spare_servers /g' /usr/local/etc/php-fpm.d/www.conf
  sed -i 's/^pm.max_spare_servers /;pm.max_spare_servers /g' /usr/local/etc/php-fpm.d/www.conf
  echo "[www] 
pm = ${FPM_PROCESS_MANAGER}
pm.max_children = ${FPM_MAX_CHILDREN}
pm.start_servers = ${FPM_START_CHILDREN}
pm.min_spare_servers = ${FPM_MIN_SPARE_SERVERS}
pm.max_spare_servers = ${FPM_MAX_SPARE_SERVERS}
" > /usr/local/etc/php-fpm.d/process_manager.conf
  cat /usr/local/etc/php-fpm.d/process_manager.conf
}

function printFPMConfChanges() {
  set +e
  diff -U3 /usr/local/etc/php-fpm.d/www.conf.default /usr/local/etc/php-fpm.d/www.conf
  set -e
}

# FPM configuration
configureProcessManager
configureStatusPage
configurePingPage
printFPMConfChanges

waitForDatabase

set +e
${WP_CMD} core is-installed
RET=$?
set -e
if [ ${RET} -ne 0 ]; then
  if [ "${WP_BASE}" != "/var/www/html" ]; then
    chown -R www-data:www-data ${WP_BASE}
    echo "Moving Wordpress from '/var/www/html to '${WP_BASE}'...'"
    set +e
    moveDirectory /var/www/html ${WP_BASE}
    set -e
  fi

  echo Initializing ....  
  ${WP_CMD} core config --dbname=${WORDPRESS_DB_NAME} --dbuser=${WORDPRESS_DB_USER} --dbpass=${WORDPRESS_DB_PASSWORD} --dbhost=db
  ${WP_CMD} core install --url=${WORDPRESS_DOMAIN_NAME} --title="Change my title!!" --admin_user=${WORDPRESS_ADMIN_USER} --admin_password=${WORDPRESS_ADMIN_PASSWORD} --admin_email=admin@test.com --skip-email

  ${WP_CMD} core update-db
  manageWPCron
  manageWPMemLimit

  OLD_URL=$(${WP_CMD} option get siteurl)
  # Sanitize site url
  NEW_URL=$(echo ${WORDPRESS_PUBLIC_URL} | tr -d '"')

  setOption siteurl "${NEW_URL}"
  setOption home "${NEW_URL}"
  echo Update admin password
  set +e
  ## email is failing
  $WP_CMD user update ${WORDPRESS_ADMIN_USER} --user_pass=${WORDPRESS_ADMIN_PASSWORD} 2>/dev/null
  set -e

  echo Updating base url... updated
  if [ "${NEW_URL}" != "${OLD_URL}" ]; then
    echo Migrate from ${OLD_URL} to ${NEW_URL}
    ${WP_CMD} search-replace ${OLD_URL} ${NEW_URL}
  else
    echo "No url updates needed, keeping ${OLD_URL}"
  fi

  installLanguages
  installPluginsFromSources
  installRemotePlugins
  installThemesFromSources
  installRemoteThemes

  echo Wordpress installed
else
  echo Wordpress already installed.
fi

echo Starting php-fpm

# Call the default wordpress entrypoint
php-fpm
