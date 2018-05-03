# wordpress

Allow to install a predefined version of wordpress at build time
and configure it at runtime.

## Content
The image contains the following components pre-installed :
* [wp-cli](http://wp-cli.org/)


## Usage

```
docker run -v [PATH]:/src exoplatform/wordpress
```

The container will look for the following elements based on the ``/src`` directory :
* plugins/* : sources of the plugins to install and **activate**
* themes/* : sources of the themes to install
* plugins.lst : list of official plugins to install
* themes.lst : list of official themes to install
* languages.lst : list of languages to install. (since 1.1.10)

## plugins.lst and themes.lst files format

List of elements under the form :
```
<name>:<version|url>
```

Example :
```
# My plugins
contact-form-7:4.5.1
polylang:2.0.7
myplugin:https://my.public.url/myplugin.zip
```

## Languages

Each line of the ```languages.lst``` file must match a [Wordpress local](https://make.wordpress.org/polyglots/teams/).
If the file is not present, no additional languages will be installed.

Example :
```
en_GB
fr_FR
```

## Environment variables

| Variable Name          | Description
-------------------------|------------------------------------------------------------
WORDPRESS_DB_HOST        | Database host name
WORDPRESS_DB_USER        | Database user name
WORDPRESS_DB_PASSWORD    | Database user password
WORDPRESS_DB_NAME        | Database schema name
WORDPRESS_PUBLIC_URL     | Public url to use Example : http://localhost
WORDPRESS_DOMAIN_NAME    | Wordpress domain Example : localhost
WORDPRESS_ADMIN_USER     | Admin user to initialize Example : admin
WORDPRESS_ADMIN_PASSWORD | Admin user password to initialize Example : adminpassword
FPM_STATUS_ENABLED       | should /status page should be enabled or not (default: true)
FPM_PING_ENABLED         | Should the fpm /ping page should be enabled (default: true)
FPM_PROCESS_MANAGER      | Type of process manager SUpported : dynamic or ondemand default:dynamic
FPM_START_CHILDREN       | Number of children created on startup default=2
FPM_MAX_CHILDREN         | Max number of child process default=5
FPM_MIN_SPARE_SERVERS    | Minimal number of idle processes default=1
FPM_MIN_SPARE_SERVERS    | Maximal number of idel processes default=3
