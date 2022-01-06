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
![Valid cerificate](https://disk.yandex.ru/i/nBV9JluBn2WLrg)

# ДЗ №4 "Деплой тестового приложения"

testapp_IP = 62.84.114.179  
testapp_port = 9292

Команда для создания инстанса с деплоем тестового приложения через start script

```css
yc compute instance create \
  --name reddit-app \
  --hostname reddit-app \
  --cores 2 \
  --core-fraction 5 \
  --memory=2 \
  --create-boot-disk image-folder-id=standard-images,image-family=ubuntu-1604-lts,size=10GB \
  --network-interface subnet-name=otus-network-ru-central1-a,nat-ip-version=ipv4 \
  --metadata serial-port-enable=1 \
  --metadata-from-file user-data=./startscript.yaml
```

Скрипт startscript.yaml

```css
#cloud-config
users:
  - name: appuser
    groups: sudo
    shell: /bin/bash
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    ssh-authorized-keys:
      - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC5r+a3wgOx1nQ5Gawxw+qpnvOFsdKg5XbhiJtt81N9soTZGiPtxoSbnTBnBDA9UoDWKxm1XAGIqzaASJNBnsDdf6sYXVLvC0QbjgF8205CWrErk9+6o7qy7wffJCAv7ZuIE03dUMYL9Ddv+OgcfyzGWJ+ChbHwwfYPq4QukbrmL70eaw09wr4bEQU/MPSPHcWZqiSz0reWYz9nqh3P6rjyiYyeWoa8Bm871BV/gkxLgxHqqjIqGFbq/reDxxSAdNumhIsHksMERyxnbA1SGh95XTSPy8LAfad/v2/aULYwnwIemEa5KIKgWW5od4QWA4B0dlyVba8NGiEl09VoJGpX appuser
runcmd:
  - apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 0C49F3730359A14518585931BC711F9BA15703C6
  - echo "deb [ arch=amd64,arm64 ] http://repo.mongodb.org/apt/ubuntu xenial/mongodb-org/3.4 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-3.4.list
  - apt update -y
  - apt install -y mongodb-org
  - systemctl start mongod
  - systemctl enable mongod
  - apt install -y ruby-full ruby-bundler build-essential apt-transport-https ca-certificates
  - apt install -y git
  - git clone -b monolith https://github.com/express42/reddit.git
  - cd reddit && bundle install
  - puma -d
```

# ДЗ №5 "Сборка образов VM при помощи Packer"

1. Создаем новую ветку в репозитории 
```css
$ git checkout -b packer-base
```
2. Переносим скрипты из прошлого урока в директорию config-script
```css
$ git mv deploy.sh install_* config-script
```  
3. Устанавливаем Packer
``css
$ curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
$ sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
$ sudo apt-get update && sudo apt-get install packer
```
4. Получаем folder-id и создаем сервисный аккаунт в Yandex.Cloud
``css
$ yc config list | grep folder-id
$ SVC_ACCT="appuser"
$ FOLDER_ID="<полученный folder-id>"
$ yc iam service-account create --name $SVC_ACCT --folder-id $FOLDER_ID
```
5. Выдаем сервисному аккаунту права **editor**
```css
$ ACCT_ID=$(yc iam service-account get $SVC_ACCT | \
grep ^id | \
awk '{print $2}')
$ yc resource-manager folder add-access-binding --id $FOLDER_ID \
--role editor \
--service-account-id $ACCT_ID
```
6. Создаем **IAM** key файл за пределами git репозитория
```css
$ yc iam key create --service-account-id $ACCT_ID --output ~/key/key.json
```
7. В git репозитории создаем каталог **packer**
```css
mkdir packer
```
Создаем файл Packer шаблона ubuntu16.json
```css
touch packer/ubuntu16.json
``` 
8. Описываем в шаблоне ubuntu16.json **Builder** секцию 
```css
    "builders": [
        {
            "type": "yandex",
            "service_account_key_file": "{{user `service_account_key_file_path`}}",
            "folder_id": "{{user `folder_id`}}",
            "source_image_family": "{{user `source_image_family`}}",
            "image_name": "reddit-base-{{timestamp}}",
            "image_family": "reddit-base",
            "ssh_username": "ubuntu",
            "platform_id": "{{user `platform_id`}}",
            "use_ipv4_nat": "true",
            "instance_cores": "{{user `instance_cores`}}",
            "instance_mem_gb": "{{user `instance_mem_gb`}}",
            "instance_name": "{{user `instance_name`}}"
        }
```
9. Добавляем в packer шаблон секцию **Provisioners**
``css
    "provisioners": [
        {
            "type": "shell",
            "script": "scripts/install_ruby.sh",
            "execute_command": "sudo {{.Path}}"
        },
        {
            "type": "shell",
            "script": "scripts/install_mongodb.sh",
            "execute_command": "sudo {{.Path}}"
        }
    ]
```
10. В каталоге **packer** создаем каталог **scripts** и копируем туда скрипты install_ruby.sh и install_mongodb.sh
```css
$ cp config-script/install_* packer/scripts
```
11. Выполняем синтакическую проверку packer шаблона на ошибки
```css
$ packer validate ./ubuntu16.json
```
12. Запускаем сборку образа
```css
$ packer build ./ubuntu16.json
```
13. Для успешности сборки образа необходимо в секцию **Biulders** шаблона ubuntu16.json добавить NAT
```css
"use_ipv4_nat": "true"
```
Так же столкнулся с проблемой _Quota limit vpc.networks.count exceeded_, решается удалением сетевых профилей в YC
Для корректности выполнения скрипта **install_ruby.sh** добавил строку _sleep 30_ после команды **apt_update**

14. Создание ВМ из созданного образа через web Yandex.Cloud

15. Вход в ВМ по ssh
```css
$ ssh -i ~/.ssh/appuser appuser@<публичный IP машины>
```

16. Проверка образа и установка приложения
```css
$ sudo apt-get update
$ sudo apt-get install -y git
$ git clone -b monolith https://github.com/express42/reddit.git
$ cd reddit && bundle install
$ puma -d
```
17. Параметризирование шаблона
Создан файл variables.json с рядом параметров. variables.json добавлен в .gitignore
На основе variables.json создан файл variables.json.examples с вымышленными значениями
```css
{
    "folder_id": "id",
    "source_image_family": "ubuntu-1604-lts",
    "service_account_key_file_path": "/path/to/key.json",
    "platform_id": "standard-v1",
    "instance_cores": "2",
    "instance_mem_gb": "2",
    "instance_name": "reddit-app-instance"
}
```

18. Построение bake-образа (задание со⭐)
На основе шаблона ubuntu16.json создан шаблон immutable.json с добавлением в секцию **provisioners** скрипта на деплой и запуск приложения
```css
{
    "builders": [
        {
            "type": "yandex",
            "service_account_key_file": "{{user `service_account_key_file_path`}}",
            "folder_id": "{{user `folder_id`}}",
            "source_image_family": "{{user `source_image_family`}}",
            "image_name": "reddit-full-{{timestamp}}",
            "image_family": "reddit-full",
            "ssh_username": "ubuntu",
            "platform_id": "{{user `platform_id`}}",
            "use_ipv4_nat": "true",
            "instance_cores": "{{user `instance_cores`}}",
            "instance_mem_gb": "{{user `instance_mem_gb`}}",
            "instance_name": "{{user `instance_name`}}"
        }
    ],
    "provisioners": [
        {
            "type": "shell",
            "script": "scripts/install_ruby.sh",
            "execute_command": "sudo {{.Path}}"
        },
        {
            "type": "shell",
            "script": "scripts/install_mongodb.sh",
            "execute_command": "sudo {{.Path}}"
        },
        {
            "type": "shell",
            "script": "files/deploy.sh",
            "execute_command": "sudo {{.Path}}"
        }
    ]
}
```

19. Описываем скрипт deploy.sh с установкой зависимостей и автозапуском приложения при помощи systemd unit после старта ОС
```css
#!/bin/bash
apt update
apt-get install -y git
mkdir /var/run/my-reddit-app && mkdir /opt/my-reddit-app
git clone -b monolith https://github.com/express42/reddit.git /opt/my-reddit-app
cd /opt/my-reddit-app
bundle install

cat > /etc/systemd/system/reddit-app.service << EOF
[Unit]
Description=My Reddit App
After=network.target
After=mongod.service

[Service]
Type=simple
PIDFile=/var/run/my-reddit-app/my-reddit.pid
WorkingDirectory=/opt/my-reddit-app

ExecStart=/usr/local/bin/puma

[Install]
WantedBy=multi-user.target
EOF

systemctl enable reddit-app.service
systemctl start reddit-app.service
```

20. Автоматизация создания ВМ (задание со⭐)
Создаем скрипт create-reddit-vm.sh для автоматического создани ВМ через Yandex.Cloud CLI с последующим запуском скрипта на установку зависимостей, деплоя приложения и запуска приложения с помощью systemd unit
```css
#!/bin/bash
yc compute instance create \
  --name reddit-full \
  --hostname reddit-full \
  --cores 2 \
  --core-fraction 5 \
  --memory=2 \
  --create-boot-disk image-folder-id=standard-images,image-family=ubuntu-1604-lts,size=10GB \
  --network-interface subnet-name=otus,nat-ip-version=ipv4 \
  --metadata serial-port-enable=1 \
  --metadata-from-file user-data=./install-dependencies-deploy-app.yaml
```
  
Создаем скрипт install-dependencies-deploy-app.yaml с набором комманд для деплоя приложения и запуска приложения через systemd unit
```css
#cloud-config
users:
  - name: appuser
    groups: sudo
    shell: /bin/bash
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    ssh-authorized-keys:
      - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC5r+a3wgOx1nQ5Gawxw+qpnvOFsdKg5XbhiJtt81N9soTZGiPtxoSbnTBnBDA9UoDWKxm1XAGIqzaASJNBnsDdf6sYXVLvC0QbjgF8205CWrErk9+6o7qy7wffJCAv7ZuIE03dUMYL9Ddv+OgcfyzGWJ+ChbHwwfYPq4QukbrmL70eaw09wr4bEQU/MPSPHcWZqiSz0reWYz9nqh3P6rjyiYyeWoa8Bm871BV/gkxLgxHqqjIqGFbq/reDxxSAdNumhIsHksMERyxnbA1SGh95XTSPy8LAfad/v2/aULYwnwIemEa5KIKgWW5od4QWA4B0dlyVba8NGiEl09VoJGpX appuser
runcmd:
  - apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 0C49F3730359A14518585931BC711F9BA15703C6
  - echo "deb [ arch=amd64,arm64 ] http://repo.mongodb.org/apt/ubuntu xenial/mongodb-org/3.4 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-3.4.list
  - apt update
  - apt install -y mongodb-org
  - systemctl start mongod
  - systemctl enable mongod
  - apt install -y ruby-full ruby-bundler build-essential apt-transport-https ca-certificates
  - apt update
  - apt install -y git
  - mkdir /var/run/my-reddit-app && mkdir /opt/my-reddit-app
  - git clone -b monolith https://github.com/express42/reddit.git /opt/my-reddit-app
  - cd /opt/my-reddit-app
  - bundle install
  - echo "[Unit]" >> /etc/systemd/system/reddit-app.service
  - echo "Description=My Reddit App" >> /etc/systemd/system/reddit-app.service
  - echo "After=network.target" >> /etc/systemd/system/reddit-app.service
  - echo "After=mongod.service" >> /etc/systemd/system/reddit-app.service
  - echo "[Service]" >> /etc/systemd/system/reddit-app.service
  - echo "Type=simple" >> /etc/systemd/system/reddit-app.service
  - echo "PIDFile=/var/run/my-reddit-app/my-reddit.pid" >> /etc/systemd/system/reddit-app.service
  - echo "WorkingDirectory=/opt/my-reddit-app" >> /etc/systemd/system/reddit-app.service
  - echo "ExecStart=/usr/local/bin/puma" >> /etc/systemd/system/reddit-app.service
  - echo "[Install]" >> /etc/systemd/system/reddit-app.service
  - echo "WantedBy=multi-user.target" >> /etc/systemd/system/reddit-app.service
  - systemctl enable reddit-app.service
  - systemctl start reddit-app.service
```
