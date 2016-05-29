#!/bin/bash -e

#setting default user:1 name
wpuser='adaptadmin'

#reading site variables from config
source site.cfg

mkdir htdocs

cd htdocs

# download the WordPress core files
wp core download

# create the wp-config file with our standard setup

if [[ $dbport == "false" ]]
then
	wp core config --dbname=$dbname --dbuser=$dbuser --dbpass=$dbpass --skip-check --extra-php <<PHP
	define( 'WP_DEBUG', true );
	define( 'DISALLOW_FILE_EDIT', true );
PHP
else
	wp core config --dbname=$dbname --dbuser=$dbuser --dbpass=$dbpass --skip-check --extra-php <<PHP
	define( 'WP_DEBUG', true );
	define( 'DB_PORT, ${dbport}');
	define( 'DISALLOW_FILE_EDIT', true );
PHP
fi


# parse the current directory name
currentdirectory=${PWD##*/}

# generate random 12 character password
password=$(LC_CTYPE=C tr -dc A-Za-z0-9_\!\@\#\$\%\^\&\*\(\)-+= < /dev/urandom | head -c 12)

# copy password to clipboard
echo $password | pbcopy

# create database, and install WordPress
wp db create

wp core install --url="$site_url" --title="$site_name" --admin_user="$wpuser" --admin_password="$password" --admin_email="$site_mail"

# discourage search engines
wp option update blog_public 0

# show only 6 posts on an archive page
wp option update posts_per_page 6

# delete sample page, and create homepage
wp post delete $(wp post list --post_type=page --posts_per_page=1 --post_status=publish --pagename="sample-page" --field=ID --format=ids)
wp post create --post_type=page --post_title=Home --post_status=publish --post_author=$(wp user get $wpuser --field=ID --format=ids)

# set homepage as front page
wp option update show_on_front 'page'

# set homepage to be the new page
wp option update page_on_front $(wp post list --post_type=page --post_status=publish --posts_per_page=1 --pagename=home --field=ID --format=ids)

# create all of the pages
export IFS=","
for page in $allpages; do
	wp post create --post_type=page --post_status=publish --post_author=$(wp user get $wpuser --field=ID --format=ids) --post_title="$(echo $page | sed -e 's/^ *//' -e 's/ *$//')"
done

# set pretty urls
wp rewrite structure '/%postname%/' --hard
wp rewrite flush --hard

# delete akismet and hello dolly
wp plugin delete akismet
wp plugin delete hello



#installs plugins from plugins.info file
while read plugins || [[ -n $plugins ]]; do
	wp plugin install $plugins --activate
done < ../plugins.info

git clone https://github.com/adaptdk/adapt_base_theme wp-content/themes/adapt_base_theme

# install the adapt base theme
wp theme activate adapt_base_theme

# install child theme
wp scaffold child-theme $theme_name --parent_theme=adapt_base_theme --theme_name=$theme_name --author=adaptdk --author_uri=http://adapt.dk --activate

# create a navigation bar
wp menu create "Main Navigation"

# add pages to navigation
export IFS=" "
for pageid in $(wp post list --order="ASC" --orderby="date" --post_type=page --post_status=publish --posts_per_page=-1 --field=ID --format=ids); do
	wp menu item add-post main-navigation $pageid
done

# assign navigaiton to primary location
wp menu location assign main-navigation primary

printf "\033[1;31m=================================================================\033[0m\n"
printf "\033[1;33 Installation is complete. Your username/password is listed below.\033[0m\n"
printf "\033[1;33 \033[0m\n"
printf "\033[1;36mUsername: $wpuser\033[0m\n"
printf "\033[1;36mPassword: $password\033[0m\n"
printf "\033[1;33 \033[0m\n"
printf "\033[0m with the following plugins:\033[0m\n"
printf "\033[1;33 \033[0m\n"
while read plugins
do
    printf "\033[1;33 $plugins \033[0m\n"
done < ../plugins.info

printf "\033[1;31m=================================================================\033[0m\n"
