#!/bin/bash -eu

WP_CMD="sudo -u www-data wp --path=/var/www/html"

SRC_DIRECTORY=/src
WP_CONTENT_DIRECTORY=${SRC_DIRECTORY}/wp-content

PLUGIN_DIRECTORY=${WP_CONTENT_DIRECTORY}/plugins
PLUGIN_LIST=${SRC_DIRECTORY}/plugins.lst
THEME_DIRECTORY=${WP_CONTENT_DIRECTORY}/themes
THEME_LIST=${SRC_DIRECTORY}/themes.lst

set +u
DEPLOY_MODE=${DEPLOY_MODE:dev}
set -u

function installRemotePlugins() {
  if [ -e "${PLUGIN_LIST}" ]; then
    echo Install plugins from repositories...

    for plugin in $(cat "${PLUGIN_LIST}" | grep -v "^#")
    do
      local name=$(echo $plugin | cut -f1 -d":")
      local version=$(echo $plugin | cut -f2- -d":")

      case $version in
        http*)
          $WP_CMD plugin install ${version}
        ;;
        *)
          local params=""
          if [ ! -z "$version" ]; then
            params="${params} --version=${version}"
          fi

          $WP_CMD plugin install ${name} ${params}
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
      local name=$(echo $theme | cut -f1 -d":")
      local version=$(echo $theme | cut -f2- -d":")

      case $version in
        http*)
          $WP_CMD theme install ${version}
        ;;
        *)
          local params=""
          if [ ! -z "$version" ]; then
            params="${params} --version=${version}"
          fi

          $WP_CMD theme install ${name} ${params}
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
      DEST="/var/www/html/wp-content/plugins/${plugin}"
      if [ -h "${DEST}" ]; then
        echo "WARNING : plugin directory for ${plugin} already exists, ignoring"
      else
        if [ "${DEPLOY_MODE}" == "dev" ]; then
          ln -s ${PLUGIN_DIRECTORY}/${plugin} /var/www/html/wp-content/plugins
        else
          sudo -u www-data cp -rf ${PLUGIN_DIRECTORY}/${plugin} /var/www/html/wp-content/plugins
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
      DEST="/var/www/html/wp-content/themes/${theme}"
      if [ -h "${DEST}" ]; then
        echo "WARNING : plugin theme for ${theme} already exists, ignoring"
      else
        if [ "${DEPLOY_MODE}" == "dev" ]; then
            ln -s ${THEME_DIRECTORY}/${theme} /var/www/html/wp-content/themes
        else
          sudo -u www-data cp -rf ${THEME_DIRECTORY}/${theme} /var/www/html/wp-content/themes
        fi
      fi
    done
  fi
}

function waitForDatabase() {
  local count=0
  local ret=1
  local max_try=30

  echo Waiting for database availability

  while [ ${count} -lt ${max_try} -a ${ret} != 0 ]
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

waitForDatabase

set +e
${WP_CMD} core is-installed
RET=$?
set -e
if [ ${RET} -ne 0 ]; then
  echo Initializing ....
  ${WP_CMD} core config --dbname=${WORDPRESS_DB_NAME} --dbuser=${WORDPRESS_DB_USER} --dbpass=${WORDPRESS_DB_PASSWORD} --dbhost=db
  ${WP_CMD} core install --url=${WORDPRESS_DOMAIN_NAME} --title="Change my title!!" --admin_user=${WORDPRESS_ADMIN_USER} --admin_password=${WORDPRESS_ADMIN_PASSWORD} --admin_email=admin@test.com --skip-email
fi

${WP_CMD} core update-db
setOption siteurl "${WORDPRESS_PUBLIC_URL}"
setOption home "${WORDPRESS_PUBLIC_URL}"
echo Update admin password
set +e
## email is failing
$WP_CMD user update ${WORDPRESS_ADMIN_USER} --user_pass=${WORDPRESS_ADMIN_PASSWORD} 2>/dev/null
set -e

installPluginsFromSources
installRemotePlugins
installThemesFromSources
installRemoteThemes

echo Wordpress installed
echo Starting php-fpm

# Call the default wordpress entrypoint
php-fpm
