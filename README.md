# antizapret-custom-dns

Точечные DNS-оверрайды для [AntiZapret-VPN](https://github.com/GubernievS/AntiZapret-VPN): закрепить отдельный домен за своим апстрим-резолвером или за фиксированным IP — **не заворачивая его в VPN**.

Ставится поверх стокового AntiZapret через штатный хук `custom-doall.sh`, поэтому переживает обновления. Если используете свой форк AntiZapret — фичу можно вшить прямо в `parse.sh`/`kresd.conf` (см. раздел «Форк» ниже), тогда этот установщик не нужен.

## Зачем

AntiZapret для «не-заблокированных» доменов резолвит их через РФ-резолверы и оставляет на прямом маршруте. Иногда гео-DNS отдаёт для домена IP из подсети, которую тот же аплинк сам же и блокирует (классика — `amp-api.apps.apple.com` → `146.75.119.x`, из-за чего «вечно крутится» App Store). Этот инструмент позволяет:

- **custom-upstream** — резолвить такой домен через свой DNS (например `1.1.1.1`), который отдаёт рабочий IP;
- **custom-bind** — жёстко прибить домен к конкретному рабочему IP.

В обоих случаях домен остаётся на **прямом** маршруте, нагрузки на VPN-туннель нет.

## Установка

Одной командой (от root, как в оригинальном AntiZapret):

```bash
bash <(wget -qO- --no-hsts --inet4-only https://raw.githubusercontent.com/fenekosan/antizapret-dns-overrides/main/install.sh)
```

Или из клона:

```bash
git clone https://github.com/fenekosan/antizapret-dns-overrides
cd antizapret-dns-overrides
sudo ./install.sh
```

Установщик:
1. кладёт `custom-dns.sh` в `/root/antizapret/`;
2. создаёт `config/custom-bind.txt` и `config/custom-upstream.txt` (существующие не трогает);
3. подцепляет вызов в `/root/antizapret/custom-doall.sh`;
4. подключает `custom.lua` в `kresd.conf` (оба инстанса) и перезапускает kresd.

## Использование

Правите конфиги и применяете:

```bash
# /root/antizapret/config/custom-upstream.txt   —  <домен> <резолвер[,резолвер2,...]>
amp-api.apps.apple.com        1.1.1.1,9.9.9.10

# /root/antizapret/config/custom-bind.txt        —  <домен> <IP[,IP2,...]>
xp.apple.com                  17.253.15.147,17.253.15.148
```

```bash
sudo /root/antizapret/custom-dns.sh        # применить сразу
# либо это произойдёт автоматически при следующем /root/antizapret/doall.sh (ежедневный крон)
```

Несколько значений — через запятую или пробел. Домен покрывает себя и все поддомены.

## Как это работает

`custom-dns.sh` собирает `/etc/knot-resolver/custom.lua` из двух конфигов:

| Файл | Действие в kresd | Семантика |
|---|---|---|
| `custom-bind.txt` | `policy.ANSWER` | статический A-ответ (мгновенно, без рекурсии) |
| `custom-upstream.txt` | `policy.FORWARD` | резолв через указанный DNS |

`custom.lua` подключается из `kresd.conf` в обоих инстансах **после** adblock-deny, но **до** маршрутизации AntiZapret. Приоритет:

```
custom-bind  >  custom-upstream  >  маршрутизация AntiZapret (VPN)  >  дефолтный форвард
```

Перезапуск kresd происходит только при реальном изменении. Инъекция в `kresd.conf` идемпотентна и самовосстанавливается: если `kresd.conf` затёрло переустановкой AntiZapret, ближайший прогон вернёт подключение на место.

### Безопасность и валидация
Домены и IP строго валидируются (`^[a-z0-9.-]+$`, октеты 0–255). Некорректные строки пропускаются с пометкой `-- skip ...`, kresd не падает.

### Производительность
Каждая запись — одна `policy.suffix`-проверка в цепочке политик (O(N) на запрос). Для единиц-десятков записей влияние неизмеримо; `bind` даже ускоряет резолв своих доменов. Не для массовых списков — для них есть штатный `include-hosts.txt`/RPZ.

## Удаление

```bash
sudo ./uninstall.sh   # снимает хук, инъекцию и custom.lua; конфиги остаются
```

## Форк вместо установщика

Если ведёте собственный форк AntiZapret, те же два файла можно встроить в пайплайн без хуков: генерация в `parse.sh`, `dofile` в `setup/etc/knot-resolver/kresd.conf`. См. ветку с интеграцией в форке.
