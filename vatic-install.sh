export MYSQL_PASSWORD=${MYSQL_PASSWORD:-hail_ukraine}
export VAGRANT_INSTALL=${VAGRANT_INSTALL:-0}

set -e

if [[ "$VAGRANT_INSTALL" -eq "1" ]]; then 
    echo "(!) Warning: doing vagrant style install (assuming empty box and being rude in actions)"
fi;

sudo apt-get update

# set some mysql password so we can proceed without interactive prompt for it
sudo debconf-set-selections <<< "mysql-server mysql-server/root_password password $MYSQL_PASSWORD"
sudo debconf-set-selections <<< "mysql-server mysql-server/root_password_again password $MYSQL_PASSWORD"

sudo apt-get -y install mysql-server
sudo apt-get install -y git python-setuptools python-dev libavcodec-dev libavformat-dev libswscale-dev libjpeg62 libjpeg62-dev libfreetype6 libfreetype6-dev apache2 libapache2-mod-wsgi mysql-server mysql-client libmysqlclient-dev gfortran

sudo easy_install -U SQLAlchemy pillow wsgilog mysql-python munkres parsedatetime argparse
sudo easy_install -U numpy

git clone https://github.com/cvondrick/turkic.git
git clone https://github.com/cluePrints/pyvision.git
git clone https://github.com/cluePrints/vatic.git

cd turkic
sudo python setup.py install
cd ..

# without this bit cython pyvision compilation fails
sudo apt-get install -y g++ make
sudo easy_install pip
sudo pip install cython==0.20

cd pyvision
sudo python setup.py install
cd ..

if [[ "$VAGRANT_INSTALL" -eq "1" ]]; then
    sudo cp /etc/apache2/mods-available/headers.load /etc/apache2/mods-enabled
    mysql -u root -p$MYSQL_PASSWORD -e 'create database vatic;'


    sudo cat > /etc/apache2/sites-enabled/000-default <<EOF
    WSGIDaemonProcess www-data
    WSGIProcessGroup www-data

    <VirtualHost *:80>
        ServerName vatic.domain.edu
        DocumentRoot /home/vagrant/vatic/public

        WSGIScriptAlias /server /home/vagrant/vatic/server.py
        CustomLog /var/log/apache2/access.log combined
    </VirtualHost>

EOF

    cp vatic/config.py-example vatic/config.py
    sed -ibak "s/root@localhost/root:$MYSQL_PASSWORD@localhost/g" vatic/config.py

    sudo apache2ctl graceful

    turkic setup --database
    turkic setup --verify

    echo "Sudo we are rather done. Go to localhost:8080 if you're lucky"
else
    echo "*****************************************************"
    echo "*** Please consult README to finish installation. ***"
    echo "*****************************************************"
fi;
