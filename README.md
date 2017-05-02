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
