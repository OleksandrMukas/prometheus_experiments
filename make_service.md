### 1. Щоб запустити моніторінг Prometheus і щоб він працював як сервіс - треба все зробити гарно.

Файл бінарний закидаємо в /usr/local/bin -

| Каталог          | Призначення                                                   | Коли використовувати                                                   |
| ---------------- | ------------------------------------------------------------- | ---------------------------------------------------------------------- |
| `/usr/bin`       | Бінарні файли системи та пакетів з дистрибутива               | Файли, які ставить менеджер пакетів (`dnf`, `yum`, `apt`)              |
| `/usr/local/bin` | Локально встановлені програми вручну, без пакетного менеджера | Те, що ти компілюєш чи скачав з сайту (Prometheus з офіційного tar.gz) |
можна перейти в sudo su -> # щоб писати без sudo

```bash
mv prometheus /usr/local/bin
mkdir /etc/prometheus
mv prometheus.yml /etc/prometheus
mkdir -p /var/lib/prometheus/data
```

Тобто, наші файли тут і `data` плануємо туди:

BIN     -> /usr/local/bin/prometheus
CONF -> /etc/prometheus/prometheus.yml
DATA  -> /var/lib/prometheus/data

Створюємо юзера для запуску сервісу і видаємо права на директорії і BIN файл:

```bash
useradd -rs /bin/false prometheus
chown prometheus:prometheus /usr/local/bin/prometheus
chown -R prometheus:prometheus /etc/prometheus
chown -R prometheus:prometheus /var/lib/prometheus/
```

# Опція `-r`
> 
> - `-r` → **system account** (системний користувач)
> - Що це означає:
>     - Користувач **не призначений для входу в систему**
>     - UID буде **нижчий за 1000** (стандарт для системних користувачів)
>     - Використовується для **сервісів**, наприклад Prometheus, nginx, postgres, etc.
> 
> > ✅ Тобто ми створюємо “службового” користувача, а не людину.
> 
> 
> # Опція `-s /bin/false`
> 
> - `-s` → задає **shell**, який запускається при вході користувача
> - `/bin/false` → спеціальна програма, яка одразу повертає **помилку** і не відкриває shell
> - Наслідок:
>     - Користувач **не може логінитись** в систему через ssh або tty
>     - Він потрібен **тільки для запуску сервісу**
> 
> # `prometheus`
> 
> - Це ім’я нового користувача
> - Тепер в системі є обліковий запис **prometheus**, який використовується для запуску демона Prometheus
> - Він **не має домашньої директорії** (за замовчуванням) і **не може увійти** в систему

chown - owner і група міняється, бо запускатись буде від юзера `prometheus`

### 2. Робимо сервіс 

Усі сервіси розміщаються у директорії : /etc/systemd/system/ 

```bash
vim /etc/systemd/system/prometheus.service
```

```bash
```bash
[Unit]
Description=Prometheus Server
After=network.target

[Service]
User=prometheus
Group=prometheus
Type=simple
Restart=on-failure
ExecStart=/usr/local/bin/prometheus \
  --config.file       /etc/prometheus/prometheus.yml \
  --storage.tsdb.path /var/lib/prometheus/data

[Install]
WantedBy=multi-user.target
```

Зберігаємо :wq 

Зчитаємо новий сервіс через systemd: 

```bash
systemctl daemon-reload
systemctl status prometheus
```

`○ prometheus.service - Prometheus Server`
     `Loaded: loaded (/etc/systemd/system/prometheus.service; disabled; preset: disabled)`
     `Active: inactive (dead)`

Все норм, можна start і enable 

```bash
systemctl enable --now prometheus.service
```

Тепер треба дати SELinux статус 0, щоб він нас не чіпав : 

```bash
setenforce 0
systemctl restart prometheus.service
```

Сервіс стартонув! Проблема була в SELinux. Тепер добавимо і повернемо захист :

```bash
restorecon -v /usr/local/bin/prometheus
restorecon -Rv /etc/prometheus
restorecon -Rv /var/lib/prometheus
setenforce 1
systemctl restart prometheus.service
```

Prometheus успішно стартанув - можна відкривати localhost:9090 і дивитись на web інтерфейс.
