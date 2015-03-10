#!/bin/bash

EXPECTED_ARGS=2

#CHECKS IF IT IS ROOT
if [ $EUID != 0 ]; then
    echo "Please run as root"
    exit
#CHECKS IF BOTH ARGUMENTS EXIST
elif [ $# -ne $EXPECTED_ARGS ]; then
    echo "USAGE: sudo $0 USERNAME EMAIL"
        exit
#CHECKS IF USER EXISTS
elif id -u "$1" >/dev/null 2>&1; then
        echo "User already exists"
        exit
fi

#APACHE VIRTUALHOST & USER CREATION & SYMLINK FOR THE HOME DIRECTORY
useradd -m -s /bin/bash $1
mkdir -p /var/www/$1/logs
mkdir -p /home/$1/public_html
ln -s /home/$1/public_html/ /var/www/$1/
chown -R $1 /home/$1/public_html/
touch /var/www/$1/public_html/index.html

#APACHE VHOST CONFIG
cat >/etc/apache2/sites-available/$1.conf <<EOL
<VirtualHost *:80>
     ServerAdmin $2
     ServerName $1.deltanove.biz
     ServerAlias www.$1.deltanove.biz
     DocumentRoot /var/www/$1/public_html/
     ErrorLog /var/www/$1/logs/error.log
     CustomLog /var/www/$1/logs/access.log combined
</VirtualHost>
EOL

#ADDS NEW VHOST TO APACHE & RELOADS IT
a2ensite $1.conf
/etc/init.d/apache2 reload

#RANDOMIZES 2 PASSWORDS - 1 FOR SSH/FTP AND 1 FOR SQL
PASSWDSQL="$(</dev/urandom tr -dc '1234567890qwertyuiopasdfghjklzxcvbnmQWERTYUIOPASDFGHJKLZXCVBNM' | head -c12; echo "")"
PASSWDSSH="$(</dev/urandom tr -dc '1234567890qwertyuiopasdfghjklzxcvbnmQWERTYUIOPASDFGHJKLZXCVBNM' | head -c12; echo "")"

#PASSWD NEW USER
/usr/bin/expect <<EOD
spawn passwd $1
expect "Enter new UNIX password:*" { send "$PASSWDSSH\r" }
expect "Retype new UNIX password:*" { send "$PASSWDSSH\r" }
interact
EOD

#CREATES MYSQL USER & GRANTS PERMISSIONS
mysql -u root -pPASS << EOF
GRANT ALL PRIVILEGES ON  \`$1\_%\` . * TO  '$1'@'%' identified by '$PASSWDSQL';
EOF

#SENDS EMAIL WITH INFORMATION
sendmail $2 <<  EOF
SUBJECT: Dados de acesso ao $1.deltanove.biz
Olá, $1.
Obrigado por te juntares ao webhosting mais instável e com pior relação qualidade/preço do mercado! É com muito gosto que te recebemos e te damos o suporte que mereces.
Em baixo vão os links para poderes ter algum acesso aos teus serviços.
Caso algum deles não funcione ou caso tenhas alguma dificuldade com o funcionamento dos mesmos, é bom que vás para o caralho.


Link de acesso ao teu domínio: http://$1.deltanove.biz

Acesso FTP:
Endereço: sftp://deltanove.biz
User: $1
Pass: $PASSWDSSH
Porta: 16


Acesso phpmyadmin / base dados MySQL:
Endereço: http://deltanove.biz/phpmyadmin/
User: $1
Pass: $PASSWDSQL


Se desejares modificar a password de MySQL, entra pelo phpmyadmin e modifica-a a partir de lá.
Se desejares modificar a password de FTP, faz o seguinte:
- Faz download do Putty, para te acederes por SSH - http://www.chiark.greenend.org.uk/~sgtatham/putty/download.html
- Configura-o para:
-- Host Name: deltanove.biz
-- Port: 16
-- Connection Type: SSH
- Faz login com os teus dados FTP
- Escreve na consola "passwd", e faz enter. O sistema vai-te pedir a nova password.


EOF
