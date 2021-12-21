Подключение по SSH
Самостоятельное задание

Для организации подключения к удаленным хостам по алиасам необходимо создать файл ~/.ssh/config

##############
Host bastion
    HostName <публичный ip хоста>
    Port 22
    User appuser
    IdentityFile ~/.ssh/id_rsa
    ForwardAgent yes

Host someinternalhost
    HostName <приватный ip хоста>
    Port 22
    User appuser
    ProxyCommand ssh bastion -W %h:%p
    ForwardAgent yes
##############

Ниже указаны варианты подключений, которые предусматривают наличие файла конфигурации ssh по описанному выше шаблону
1. Подключится к приватному хосту someinternalhost через публичный хост bastion в одну строку можно следующей командой: ssh -t bastion ssh someinternalhost
2. Дополнительное задание. Подключится к приватному хосту someinternalhost через команду вида ssh someinternalhost можно указав в ~/.ssh/config, в параметрах подключения для этого хоста, опцию с параметрами ProxyCommnad ssh bastion -W %h:%p

Организация VPN сервера на базе Pritunl с сертификатом от Let's Encrypt

Для домена 62.84.124.168.sslip.io выпущен SSL сертификат от Let's Encrypt
На хосте bastion устнановлен nginx с проксированием на pritunl (в конфигурации pritunl изменен порт)

Данные для подключения к bastion и someinternalhost

bastion_IP = 62.84.124.168
someinternalhost_IP = 10.130.0.20
