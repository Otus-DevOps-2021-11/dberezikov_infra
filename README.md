# Подключение по SSH

### Самостоятельное задание

Для организации подключения к удаленным хостам по алиасам необходимо создать файл ~/.ssh/config

```css
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
```    
Ниже указаны варианты подключений, которые предусматривают наличие файла конфигурации ssh по описанному выше шаблону
1. Подключится к приватному хосту someinternalhost через публичный хост bastion в одну строку можно следующей командой: ssh -t bastion ssh someinternalhost
2. **Дополнительное задание**. Подключится к приватному хосту someinternalhost через команду вида ssh someinternalhost можно указав в ~/.ssh/config, в параметрах подключения для этого хоста, опцию с параметрами ProxyCommand ssh bastion -W %h:%p

# Организация VPN сервера на базе Pritunl с сертификатом от Let's Encrypt

Для домена 62.84.124.168.sslip.io выпущен SSL сертификат от Let's Encrypt
На хосте bastion устнановлен nginx с проксированием на pritunl (в конфигурации pritunl изменен порт)

Данные для подключения к bastion и someinternalhost:  
bastion_IP = 62.84.124.168  
someinternalhost_IP = 10.130.0.20

**Сгенерированный сертификат установленный на сервер с Pritunl**
![Valid cerificate](https://s778sas.storage.yandex.net/rdisk/ab239d31b1fa27ee636e5576a205a8b3ed1bb51b2cfb0ca800ab751a19e67198/61c1cfd6/bPwhcfqTVI5uQ2ZjxUcyNTjzFRDxEyRWSa3j9HEVKADnIN4LOtEqZKMeoyRB6R8bGHIY5dOO0deg1m5xNX3Axw==?uid=1328976523&filename=valid_cert.jpg&disposition=inline&hash=&limit=0&content_type=image%2Fjpeg&owner_uid=1328976523&fsize=136698&hid=64e3901076f92da9110c38f23e509217&media_type=image&tknv=v2&etag=dbd65a5219792c7d82d5c206456ae298&rtoken=ICTwcJoqVMEc&force_default=yes&ycrid=na-c0dae8919962ebce8e1a17296fe9df6f-downloader14h&ts=5d3a795932180&s=d20204466d72c6c1ce4e8d8be0a510b3fa7b904e82051eb5e5b27f9c354c8fa8&pb=U2FsdGVkX18_r4qUsM7logfMeQhvNh_LN0cLYvabxVIy0wdf_B3G0e6EB83V6zF2OkrPEePTk-uQexNYSTMmjNDH6E7cloi6Rp5b_tdctd8)
