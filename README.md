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
![Valid cerificate](https://raw.githubusercontent.com/Otus-DevOps-2021-11/dberezikov_infra/packer-base/VPN/valid_cert.png)
rk_interface {
    subnet_id = var.subnet_id
    nat       = true
  }

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
```css
$ curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
$ sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
$ sudo apt-get update && sudo apt-get install packer
```
4. Получаем folder-id и создаем сервисный аккаунт в Yandex.Cloud
```css
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
$ mkdir packer
```
Создаем файл Packer шаблона ubuntu16.json
```css
$ touch packer/ubuntu16.json
``` 
8. Описываем в шаблоне ubuntu16.json секцию **Builder**  
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
```css
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
Для корректности выполнения скрипта **install_ruby.sh** добавил строку _sleep 30_ после команды **apt update**

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
Создан файл variables.json с рядом параметров, variables.json добавлен в .gitignore  
На основе variables.json создан файл variables.json.example с вымышленными значениями
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

18. Построение bake-образа (задание с⭐)  
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

# ДЗ №6 "Практика IaC с использованием Terraform"

1. Создаем новую ветку в репозитории
```css
$ git checkout -b terraform-1
``` 

2. Скачиваем бинарный файл terraform версии 0.12.8, распаковываем архив и помещаем бинарный файл terraform в директорию из переменной $PATH, проверяем версию terraform
```css
$ wget https://releases.hashicorp.com/terraform/0.12.8/terraform_0.12.8_linux_386.zip
$ unzip terraform_0.12.8_linux_386.zip -d terraform_0.12.8
$ cp terraform_0.12.8/terraform /usr/local/bin
$ terraform -v
``` 

3. Создаем директорию **terraform** в проекте, внутри нее создаем главный конфигурационный файл **main.tf**
```css
$ mkdir terraform
$ touch terraform/main.tf
```


4. Узнаем значения token, cloud-id и folder-id через команду **yc config list** и записываем их в **main.tf**
```css
provider "yandex" {
  token     = "token"
  cloud_id  = "cloud-id"
  folder_id = "folder-id"
  zone      = "ru-central1-a"
} 
```

5. Создаем через web интерфейс новый сервисный аккаунт с названием terraform и даем ему роль editor

6. Экспортируем ключ сервисного аккаунта и устанавливаем его по умолчанию для использования
```css
$ yc iam key create --service-account-name terraform --output ~/terraform_key.json
$ yc config set service-account-key ~/terraform_key.json
```

7. Для загрузки модуля провайдера Yandex в директории terraform выполняем команду
```css
$ terraform init
```

8. Добавляем в **main.tf** ресурс по созданию инстанса
image_id берем из вывода команды 
```css
yc compute image list
```
subnet_id из вывода команды 
```css
yc vpc network --id <id сети> list-subnets
```

```css
resource "yandex_compute_instance" "app" {
  name = "reddit-app"

  resources {
    cores  = 1
    memory = 2
  }

  boot_disk {
    initialize_params {
      # Указать id образа созданного в предыдущем домашем задании
      image_id = "***"
    }
  }

  network_interface {
    # Указан id подсети default-ru-central1-a
    subnet_id = "***"
    nat       = true
  }
}
```

9. Для возможности поделючения к ВМ по ssh добавляем в **main.tf** информацию о публичном ключе
```css
resource "yandex_compute_instance" "app" {
...
  metadata = {
  ssh-keys = "ubuntu:${file("~/.ssh/appuser.pub")}"
  }
...
}
```

10. Смотрим план изменений перед создание ресурса
```css
$ terraform plan
```

11. Запускаем инстанс ВМ
```css
$ terraform apply
```

12. Для выходных переменных создаем в директории **terraform** отделный файл **outputs.tf**
```css
$ touch outputs.tf
```

с следующим содержимым:
```css
output "external_ip_address_app" {
value = yandex_compute_instance.app.network_interface.0.nat_ip_address
}
```

13. В основной конфиг **main.tf** добавляем секцию с provisioner для копирования с локальной машины на ВМ Unit файла
```css
provisioner "file" {
  source = "files/puma.service"
  destination = "/tmp/puma.service"
}
```

14. Создаем директорию files
```css
$ mkdir files
```

В ней создаем Unit файл
```css
$ touch puma.service
```

Заполняем файл следующим содержимым
```css
[Unit]
Description=Puma HTTP Server
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu/reddit
ExecStart=/bin/bash -lc 'puma'
Restart=always

[Install]
WantedBy=multi-user.target
```

13. В основной конфиг **main.tf** добавляем секцию с provisioner для деплоя приложения
```css
provisioner "remote-exec" {
  script = "files/deploy.sh"
}
```

14. В директории **files** создаем скрипт **deploy.sh**
```css
$ touch files/deploy.sh
```
с следующим содержимым
```css
#!/bin/bash
set -e
APP_DIR=${1:-$HOME}
sudo apt update
sleep 30
sudo apt-get install -y git
git clone -b monolith https://github.com/express42/reddit.git $APP_DIR/reddit
cd $APP_DIR/reddit
bundle install
sudo mv /tmp/puma.service /etc/systemd/system/puma.service
sudo systemctl start puma
sudo systemctl enable puma
```

15. В основной конфиг **main.tf**, перед определения провижинеров, добавляем параметры подключения провиженеров к ВМ 
```css
connection {
  type = "ssh"
  host = yandex_compute_instance.app.network_interface.0.nat_ip_address
  user = "ubuntu"
  agent = false
  # путь до приватного ключа
  private_key = file("~/.ssh/appuser")
  }
```

16. Через команду __terraform taint__ помечаем ВМ для его дальнейшего пересоздания
```css
$ terraform taint yandex_compute_instance.app
```

17. Проверяем план изменений
```css
$ terraform plan
```

и запускаем пересборку ВМ
```css
$ terraform apply
```

18. Для определения входных переменных создадим в директории **terraform** файл **variables.tf** с следующим содержимым:
```css
variable cloud_id{
  description = "Cloud"
}
variable folder_id {
  description = "Folder"
}
variable zone {
  description = "Zone"
  # Значение по умолчанию
  default = "ru-central1-a"
}
variable public_key_path {
  # Описание переменной
  description = "Path to the public key used for ssh access"
}
variable image_id {
  description = "Disk image"
}
variable subnet_id{
  description = "Subnet"
}
variable service_account_key_file{
  description = "key .json"
}
```

19. В **maint.tf** переопределим параметры через input переменные
```css
provider "yandex" {
  service_account_key_file = var.service_account_key_file
  cloud_id  = var.cloud_id
  folder_id = var.folder_id
  zone      = var.zone
}

  boot_disk {
    initialize_params {
      # Указать id образа созданного в предыдущем домашем задании
      image_id = var.image_id
    }
  }

  network_interface {
    # Указан id подсети default-ru-central1-a
    subnet_id = var.subnet_id
    nat       = true
  }

  metadata = {
  ssh-keys = "ubuntu:${file(var.public_key_path)}"
  }
```

20. Для определения самих переменных создадим файл **terraform.tfvars**
```css
$ touch terraform.tfvars
```

с следующим содержимым (реальные значения скрыты звездочками) и с указанием переменных для публичного и приватного ключа   
```css
cloud_id                 = "***"
folder_id                = "***"
zone                     = "ru-central1-a"
image_id                 = "***"
public_key_path          = "~/.ssh/appuser.pub"
private_key_path         = "~/.ssh/appuser"
subnet_id                = "***"
service_account_key_file = "~/key/terraform_key.json"       
```

21. Удалим предыдущий созданный инстанс и создадим новый
```css
$ terraform destroy
$ terraform plan
$ terraform apply
```

22. После сборки инстанса проверяем через браузер, введя в строке браузера значение полученное в external_ip_address_app после сборки интанса с указанием порта 9292

23. Добавим в **.gitignore** следующие исключения
```css
*.tfstate
*.tfstate.*.backup
*.tfstate.backup
*.tfvars
.terraform/
.terraform/files/appuser.pub
```

## Самостоятельное задание
1. Определяем input переменную для приватного ключа в **terraform.tfvars**
```css
private_key_path         = "~/.ssh/appuser"
```
   Определяем input переменную для приватного ключа в **variables.tf**
```css
variable private_key_path {
  # Описание переменной
  description = "Path to the private key used for ssh access"
}
```
   Вносим переменную приватного ключа в блок conenction файла **main.tf**
```css
private_key = file(var.private_key_path)
```
2. Определяем input переменную для задания зоны ресурса "yandex_compute_instance" "app"
```css
resource "yandex_compute_instance" "app" {
  name = "reddit-app"
  zone = var.zone

  resources {
    cores  = 2
    memory = 2
  }
```

3. Форматируем все конфиги terraform через команду
```css
$ terraform fmt
```

4. Ввиду добавления файла terraform.tfvars в .gitignore, делаем копию файла с переменными с другим именем и заменяем реальные значения на звездочки
```css
$ cp terraform.tfvars terraform.tfvars.example
```

новое содержимое файла
```css
cloud_id                 = "***"
folder_id                = "***"
zone                     = "ru-central1-a"
image_id                 = "***"
public_key_path          = "/path/to/key.pub"
private_key_path         = "/path/to/key"
subnet_id                = "***"
service_account_key_file = "/path/to/key.json"
```

## Задания с ⭐
Создание HTTP балансировщика

1. Создаем файл **lb.tf** в котором опишем HTTP балансировщик
```css
$ touch lb.tr
```
2. Создадим целевую группу, в которую балансировщик будет распределять нагрузку  
В группу добавляем ip хоста создаваемый в конфиге **main.tf** через переменную __yandex_compute_instance.app.network_interface.0.ip_address__
```css
resource "yandex_lb_target_group" "my-target-group" {
  name      = "my-target-group"
  region_id = var.region

  target {
    subnet_id = var.subnet_id
    address   = "${yandex_compute_instance.app.network_interface.0.ip_address}"
  }
}
```
3. Создаем сам балансировщик с указанием на целевую группу, добавляем обработчик (listener) с указанием на каком порту слушать соединение (80) и куда в целевую группу передавать (9292) 
```css
resource "yandex_lb_network_load_balancer" "my-external-lb" {
  name = "my-network-lb"

  listener {
    name = "my-listener"
    port = 80
    target_port = 9292
    external_address_spec {
      ip_version = "ipv4"
    }
  }

  attached_target_group {
    target_group_id = "${yandex_lb_target_group.my-target-group.id}"

    healthcheck {
      name = "http"
      http_options {
        port = 9292
        path = "/"
      }
    }
  }
}
```

4. В output переменные (outputs.tf) добавляем вывод внешнего адреса балансировщика
```css
output "external_ip_address_lb" {
  value = yandex_lb_network_load_balancer.my-external-lb.listener.*.external_address_spec[0].*.address
}
```

5. Проверяем список изменений и запускаем деплой балансировщика
```css
$ terraform plan
$ terraform apply
```

6. Проверяем работу балансировщика введя в cтроке адреса web браузера **<полученный ip балансировщика>:80**


## Задания с ⭐
Организация второго инстанса с приложением

1. В основном шаблоне **main.tf** добавляем создание второго инстанса app2 с именем reddit-app2 и деплоем приложения
```css
resource "yandex_compute_instance" "app2" {
  name = "reddit-app2"
  zone = var.zone

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      # Указать id образа созданного в предыдущем домашем задании
      image_id = var.image_id
    }
  }

  network_interface {
    # Указан id подсети default-ru-central1-a
    subnet_id = var.subnet_id
    nat       = true
  }

  metadata = {
    ssh-keys = "ubuntu:${file(var.public_key_path)}"
  }

  connection {
    type  = "ssh"
    host  = yandex_compute_instance.app2.network_interface.0.nat_ip_address
    user  = "ubuntu"
    agent = false
    # путь до приватного ключа
    private_key = file(var.private_key_path)
  }

  provisioner "file" {
    source      = "files/puma.service"
    destination = "/tmp/puma.service"
  }

  provisioner "remote-exec" {
    script = "files/deploy.sh"
  }
}
```

2. В шаблоне **lb.tf** в таргет группу добавляем запись о втором хосте назначения
```css
  target {
    subnet_id = var.subnet_id
    address   = "${yandex_compute_instance.app2.network_interface.0.ip_address}"
  }
```

3. В выходные переменные **outputs.tf** добавляем вывод ip второго хоста
```css
output "external_ip_address_app2" {
  value = yandex_compute_instance.app2.network_interface.0.nat_ip_address
}
```

4. Вопрос из ДЗ: 
>Какие проблемы вы видите в такой конфигурации приложения?
  
Ответ: В данной схеме все инстансы с приложением, включая и балансировщик находятся в одном регионе. В случае падения сети в этом регионе теряем всю схему отказоустойчивости. Целесообразнее инстансы с приложением размещать в разных регионах.

## Задания с ⭐
Организация второго инстанса через переменные

1. В **variables.tf** добавляем описание переменной для количества инстансов
```css
variable instances_count {
  description = "Count of instances"
  default     = 1
}
```

2. В **terraform.tfvars** добавлем значение переменной по условию задачи
```css
instances_count          = "2"
```

3. Удалаяем блок с кодом о втором инстансе из **main.tf** и добавялем переменную count, редактируем переменную name
```css
resource "yandex_compute_instance" "app" {
  count = var.instances_count
  name = "reddit-app${count.index}"
  zone = var.zone
...
}
```

в блоке conenction правим значение host
```css
host  = self.network_interface.0.nat_ip_address
```

4. В **lb.tf** правим блок target делая его dynamic
```css
  dynamic "target" {
    for_each  = "${yandex_compute_instance.app.*.network_interface.0.ip_address}"
    content {
      subnet_id = var.subnet_id
      address   = target.value
    }
  }
```

5. Проверка получившейся конфигурации на ошибки, просмотр плана изменений и запуск
```css
$ terraform plan
$ terraform apply
```
# ДЗ №7 "Принципы организации инфраструктурного кода и работа над инфраструктурой в команде на примере Terraform"

1. Создаем новую ветку
```css
$ git checkout -b terraform-2
```

2. Устанавливаем в **variables.tf** количество инстансов app равным 1
```css
variable instances_count {
  description = "Count of instances"
  default     = 1
}
```

3. Переносим файл **lb.tf** в **terraform/files**
```css
$ mv lb.tf terraform/files
```

4. В **main.tf** определяем ресурсы yandex_vpc_network и yandex_vpc_subnet
```css
resource "yandex_vpc_network" "app-network" {
  name = "reddit-app-network"
}

resource "yandex_vpc_subnet" "app-subnet" {
  name           = "reddit-app-subnet"
  zone           = "ru-central1-a"
  network_id     = "${yandex_vpc_network.app-network.id}"
  v4_cidr_blocks = ["192.168.10.0/24"]
}
```

5. Применим изменения
```css
$ terraform apply
```

6. В файле **main.tf** в конфигурации vm ссылаемся на атрибуты ресурса который создает IP
```css
network_interface {
  subnet_id = yandex_vpc_subnet.app-subnet.id
  nat = true
}
```

7. Пересоздаем инстанс, что бы увидеть очередность создания ресурсов зависимых друг от друга
```css
$ terraform destroy
$ terraform plan
$ terraform apply
```

8. Вынесение БД и APP на отдельный инстанс VM

В директории **packer** создаем новые шаблоны **db.json** и **app.json** на основе шаблона **ubuntu16.json** и убираем все не нужное
```css
$ cp ../packer/ubuntu16.json ../packer/db.json
$ cp ../packer/ubuntu16.json ../packer/app.json
```

Финальное содержимое шаблона **db.json**
```css
{
    "builders": [
        {
            "type": "yandex",
            "service_account_key_file": "{{user `service_account_key_file_path`}}",
            "folder_id": "{{user `folder_id`}}",
            "source_image_family": "{{user `source_image_family`}}",
            "image_name": "reddit-base-db-{{timestamp}}",
            "image_family": "reddit-base",
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
            "script": "scripts/install_mongodb.sh",
            "execute_command": "sudo {{.Path}}"
        }
    ]
}
```

Финальное содержимое шаблона app.json
```css
{
    "builders": [
        {
            "type": "yandex",
            "service_account_key_file": "{{user `service_account_key_file_path`}}",
            "folder_id": "{{user `folder_id`}}",
            "source_image_family": "{{user `source_image_family`}}",
            "image_name": "reddit-base-app-{{timestamp}}",
            "image_family": "reddit-base",
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
        }
    ]
}
```

Запускаем сборку новых образов для APP и DB 
```css
$ packer build -var-file=variables.json app.json
$ packer build -var-file=variables.json db.json
```

9. Вводим новую переменную для образа APP и DB

В **variables.tf** добавляем 
```css
variable app_disk_image {
  description = "Disk image for reddit app"
  default     = "reddit-app-base"
}
variable db_disk_image {
  description = "Disk image for reddit db"
  default     = "reddit-db-base"
}
```

Получаем id новых образов собранных через packer
```css
$ yc compute image list
```

В **terraform.tfvars** добавляем полученные id образов
```css
app_disk_image           = "***"
db_disk_image            = "***"
```

10. Разделем конфиг **main.tf** на несколько частей

Создадим файл **app.tf** с конфигурацией VM для приложения
```css
$ touch app.tf
```

Содержимое файла **app.tf**
```css
resource "yandex_compute_instance" "app" {
  name = "reddit-app"

  labels = {
    tags = "reddit-app"
  }
  resources {
    cores  = 1
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = var.app_disk_image
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.app-subnet.id
    nat = true
  }

  metadata = {
  ssh-keys = "ubuntu:${file(var.public_key_path)}"
  }
}
```

Создадим файл **db.tf** с конфигурацией VM для приложения
```css
$ touch db.tf
```

Содержимое файла **db.tf**
```css
resource "yandex_compute_instance" "db" {
  name = "reddit-db"
  labels = {
    tags = "reddit-db"
  }

  resources {
    cores  = 1
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = var.db_disk_image
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.app-subnet.id
    nat = true
  }

  metadata = {
  ssh-keys = "ubuntu:${file(var.public_key_path)}"
  }
}
```

11. Создаем файл **vpc.tf**, в который выносим конфигурацию сети и подсети

```css
touch vpc.tf
```

Содержимое файла **vpc.tf**
```css
resource "yandex_vpc_network" "app-network" {
  name = "app-network"
}

resource "yandex_vpc_subnet" "app-subnet" {
  name           = "app-subnet"
  zone           = "ru-central1-a"
  network_id     = "${yandex_vpc_network.app-network.id}"
  v4_cidr_blocks = ["192.168.10.0/24"]
}
```

12. После выноса конфигураций по разнам файлам в **main.tf** остается только определение провайдера
```css
provider "yandex" {
  service_account_key_file = var.service_account_key_file
  cloud_id  = var.cloud_id
  folder_id = var.folder_id
  zone      = var.zone
}
```

13. В outputs.tf добавляем вывод адресов инстансов
```css
output "external_ip_address_app" {
  value = yandex_compute_instance.app.network_interface.0.nat_ip_address
}
output "external_ip_address_db" {
  value = yandex_compute_instance.db.network_interface.0.nat_ip_address
}
```

14. Применяем конфигурацию, проверяем ошибки, при необходимости устраняем
```css
$ terraform apply
``` 

15. После успешного деплоя, заходим на каждый хост по ssh и проверяем факт установки необходимого ПО
После проверки удаляем инстансы
```css
$ terraform destroy
```

## Подготовка конфигурационных файлов для работы с модулями

16. Создаем структуру каталогов для DB
```css
$ mkdir -p modules/db
```

17. Копируем конфигурацию для DB в модули
```css
$ cp db.tf modules/db/main.tf
``` 

18. В файле **modules/db/variables.tf** определим переменные, которые используются в db.tf
```css
variable public_key_path {
  description = "Path to the public key used for ssh access"
}
  variable db_disk_image {
  description = "Disk image for reddit db"
  default = "reddit-db-base"
}
variable subnet_id {
description = "Subnets for modules"
}
```

19. Создаем структуру каталогов для APP
```css
$ mkdir -p modules/app
```

20. Копируем конфигурацию для APP в модули
```css
$ cp app.tf modules/app/main.tf
``` 

21. В файле **modules/app/variables.tf** определим переменные, которые используются в app.tf
```css
variable public_key_path {
  description = "Path to the public key used for ssh access"
}
variable app_disk_image {
  description = "Disk image for reddit app"
  default = "reddit-app-base"
}
variable subnet_id {
description = "Subnets for modules"
}
```

22. Вывод выходных переменных в файлы

Файл **modules/app/outputs.tf**
```css
output "external_ip_address_app" {
  value = yandex_compute_instance.app.network_interface.0.nat_ip_address
}
```

Файл **modules/db/outputs.tf**
```css
output "external_ip_address_db" {
  value = yandex_compute_instance.db.network_interface.0.nat_ip_address
}
```

23. Удаление ненужных файлов в основном каталоге terraform
```css
$ rm db.tf и app.tf vpc.tf
```

24. После удаления **vpc.tf** в файлах **modules/db/main.tf** и **modules/app/main.tf** скорректировал значение subnet_id

Было
```css
  network_interface {
    subnet_id = yandex_vpc_subnet.app-subnet.id
    nat = true
  }
```

Стало
```css
  network_interface {
    subnet_id = var.subnet_id
    nat       = true
  }
```

25. В главный конфигурационный файл **main.tf** добавляем вызов модулей
```css
provider "yandex" {
  service_account_key_file = var.service_account_key_file
  cloud_id  = var.cloud_id
  folder_id = var.folder_id
  zone      = var.zone
}
module "app" {
  source          = "./modules/app"
  public_key_path = var.public_key_path
  app_disk_image  = var.app_disk_image
  subnet_id       = var.subnet_id
}

module "db" {
  source          = "./modules/db"
  public_key_path = var.public_key_path
  db_disk_image   = var.db_disk_image
  subnet_id       = var.subnet_id
}
```

26. В каталоге terraform выхываем загрузку модулей
```css
$ terraform get
```

27. Переопределяем переменную для внешнего ip в файле **outputs.tf**
```css
output "external_ip_address_app" {
  value = module.app.external_ip_address_app
}
output "external_ip_address_db" {
  value = module.db.external_ip_address_db
}
```

28. Проверим и запустим сборку новых инстансов
```css
$ terraform apply
```

29. Проверяем ssh доступ до инстансов

## Создание Stage и Prod окрудений

30. В каталоге terraform создаем подкаталоги stage и prod
```css
$ mkdir terrform/stage
$ mkdir terrform/prod
```

31. Копируем файлы конфигураций в созданные каталоги
```css
$ cp main.tf variables.tf outputs.tf terraform.tfvars stage
$ cp main.tf variables.tf outputs.tf terraform.tfvars prod
```

32. Изменяем путь до модулей в **main.tf** каталога **stage** и **prod**
```css
source          = "../modules/app"
```

33. Проверка правильности настроек каждого окружения и последующим удаление созданных инстансов


## Самостоятельное задание

1. Удалить из каталога terraform файлы **main.tf**, **outputs.tf**, **terraform.tfvars**, **variables.tf**
```css
$ rm main.tf outputs.tf terraform.tfvars variables.tf
```

2. Форматирование конфигурации файлов в каталогах **stage** и **prod**
```css
$ terarform fmt
```

## Задания с ⭐
Настройка хранения стейт файла в remote backends

1. Копируем в основной каталог terraform файлы **main.tf**, **variables.tf** и **terraform.tfvars** для создания bucket
```css
$ cp stage/main.tf main.tf
$ cp stage/variables.tf variables.tf 
$ cp stage/terraform.tfvars terraform.tfvars
```

2. Описываем  переменные необходимые для создания bucket

В файл **variables.tf** добавляем строки
```css
variable access_key {
  description = "Static access key identifier"
}
variable secret_key {
  description = "Secret access key value"
}
variable bucket {
  description = "Bucket name"
}
```

Выполняем команду для получения значений access_key, secret_key 
```css
$ yc iam access-key create --service-account-name terraform
```

Полученные значения и имя создаваемого бакета записываем в файл **terraform.tfvars**
```css
access_key               = "***"
secret_key               = "***"
bucket                   = "dberezikov-bucket"
```

3. Корректируем файл **main.tf** описывая в нем конфигурацию создаваемого бакета
```css
provider "yandex" {
  service_account_key_file = var.service_account_key_file
  cloud_id                 = var.cloud_id
  folder_id                = var.folder_id
  zone                     = var.zone
}
resource "yandex_storage_bucket" "dberezikov-otus-bucket" {
  access_key    = var.access_key
  secret_key    = var.secret_key
  bucket        = var.bucket
#  force_destroy = true
}
```

4. Проверяем корректность конфигурации и создаем бакет
```css
$ terraform plan
$ terraform apply
```

5. В каждой директории **stage** и **prod** создаем файл **backend.tf**

Конфигурационный файл не поддерживает переменные, пришлось указать значения параметров в явном виде

Содержимое файла 
```css
terraform {
  backend "s3" {
    endpoint   = "storage.yandexcloud.net"
    bucket     = "dberezikov-bucket"
    key        = "stage/terraform.tfstate"   ## значение "prod/terraform.tfstate" для каталога prod
    region     = "ru-central1"
    access_key = "***"
    secret_key = "***"

    skip_region_validation      = true
    skip_credentials_validation = true
  }
}
```

6. После сохранения файла необходимо выполнить команду в каталогах **stage** и **prod**
```css
$ terraform init
```

7. При одновременном запуске деплоя инстансов из сред stage и prod возникает ошибка, т.к. название инстансов не уникальны для каждой среды, введем переменные

Добавляем в **module/app/variables.tf**
```css
variable app_instance_name {
  description = "Name of APP instance"
  default     = "reddit-app"
}
```
Добавляем в **module/db/variables.tf**
```css
variable db_instance_name {
  description = "Name of DB instance"
  default     = "reddit-db"
}
```

В **modules/app/main.tf** корректируем имя инстанса
```css
resource "yandex_compute_instance" "app" {
  name = var.app_instance_name
  labels = {
    tags = var.app_instance_name
  }
```

В **modules/db/main.tf** корректируем имя инстанса
```css
resource "yandex_compute_instance" "db" {
  name = var.db_instance_name
  labels = {
    tags = var.db_instance_name
  }
```

В файл **variables.tf** каждой среды добавляем
```css
variable app_instance_name {
  description = "Name of APP instance"
}
variable db_instance_name {
  description = "Name of DB instance"
}
```

В **terraform.tfvars** каждой среды добавляем 
```css
app_instance_name        = "reddir-app-prod" # "reddir-app-stage" для stage среды 
db_instance_name         = "reddir-db-prod"  # "reddir-db-stage"  для stage среды
```

В **main.tf** в модули добавляем строки с переменными для имен инстансов
```css
module "app" {
...
 app_instance_name = var.app_instance_name
}
module "db" {
...
 db_instance_name  = var.db_instance_name
}
```

8. Удаляем файлы **terraform.tfstate** в каждой среде

9. Запукаем проверку на ошибки и сборку инстансов
```css
$ terraform apply
```

10. Проверяем созданные инстансы

## Задания с ⭐

До конца реализовать задание неудалось.
Были добавленые провиженеры в модули, сборка и установка проходит, но не разобрался как реализовать подключение от приложения к БД по внутреннему ip. Пока, что бы не тормозить выполнение других ДЗ, задачу осталяю, позже вернусь, что бы доделать.
