# VCode: 3

#!/system/bin/sh
MODDIR="/data/adb/modules/zapret"
CLI="$MODDIR/system/bin/zapretfin"
LOG="$MODDIR/logs_zapret.log"

if pgrep nfqws > /dev/null; then
    $CLI --stop >/dev/null 2>&1
    echo "ВЫКЛ"
    cmd notification post -t "Zapret" "status" "ВЫКЛ" >/dev/null 2>&1
else
    $CLI --zap >/dev/null 2>&1
    sleep 1
    if pgrep nfqws > /dev/null; then
        STRAT=$(cat "$MODDIR/strategy.txt" 2>/dev/null | tr -d '\r')
        echo "ВКЛ (№$STRAT)"
        cmd notification post -t "Zapret" "status" "РАБОТАЕТ" >/dev/null 2>&1
    else
        echo "ОШИБКА:"
        tail -n 1 "$LOG" | cut -c 1-50
        cmd notification post -t "Zapret" "status" "ERROR" >/dev/null 2>&1
    fi
fi

MODULE_DIR="/data/adb/modules/zapret"
MODULE_PROP="$MODULE_DIR/ru.prop"
HOSTS_FILE="$MODULE_DIR/system/etc/hosts"
SYSTEM_HOSTS="/system/etc/hosts"
LOG_FILE="$MODULE_DIR/logs_ru_ai.txt"
TMP_DIR="/data/local/tmp/unlocker_update"

GITHUB_MODULE_PROP="https://raw.githubusercontent.com/F1NDLE/RU_AI_UNLOCKER/refs/heads/main/module.prop"
GITHUB_HOSTS="https://raw.githubusercontent.com/F1NDLE/RU_AI_UNLOCKER/refs/heads/main/system/etc/hosts"

TMP_MODULE_PROP="$TMP_DIR/module.prop"
TMP_HOSTS="$TMP_DIR/hosts"

log() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $1" >> "$LOG_FILE"
}

ui_print() {
    echo "$1"
    log "$1"
}

log_error() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] ERROR: $1" >> "$LOG_FILE"
    echo "ERROR: $1"
}

init_logs() {
    mkdir -p "$MODULE_DIR"
    if [ ! -f "$LOG_FILE" ]; then
        touch "$LOG_FILE"
        chmod 644 "$LOG_FILE"
        log "Инициализация лог-файла"
    fi
    log "Запуск action.sh"
    log "Пользователь: $(whoami)"
    log "Время запуска: $(date)"
}

download_file() {
    local url="$1"
    local output="$2"
    
    ui_print "Загружаем: $url"
    log "Начало загрузки: $url -> $output"
    
    if command -v wget >/dev/null 2>&1; then
        wget -O "$output" "$url" 2>> "$LOG_FILE"
    elif command -v curl >/dev/null 2>&1; then
        curl -L -o "$output" "$url" 2>> "$LOG_FILE"
    else
        busybox wget -O "$output" "$url" 2>> "$LOG_FILE"
    fi
    
    local result=$?
    if [ $result -eq 0 ]; then
        local file_size=$(stat -c%s "$output" 2>/dev/null || echo "unknown")
        ui_print "Успешно загружено: $file_size байт"
        log "Файл успешно загружен: $file_size байт, код: $result"
    else
        ui_print "Ошибка загрузки, код: $result"
        log_error "Ошибка загрузки $url, код: $result"
    fi
    
    return $result
}

get_prop_value() {
    local file="$1"
    local key="$2"
    grep "^$key=" "$file" 2>/dev/null | cut -d'=' -f2
}

main() {
    init_logs
    ui_print "Проверяем обновления..."
    
    if [ "$(whoami)" != "root" ]; then
        log_error "Отсутствуют root права!"
        exit 1
    fi
    
    mkdir -p "$TMP_DIR"
    log "Создана временная директория: $TMP_DIR"
    
    if ! download_file "$GITHUB_MODULE_PROP" "$TMP_MODULE_PROP"; then
        log_error "Не удалось подключиться к GitHub"
        rm -rf "$TMP_DIR"
        exit 1
    fi
    
    local current_code=$(get_prop_value "$MODULE_PROP" "versionCode")
    local remote_code=$(get_prop_value "$TMP_MODULE_PROP" "versionCode")
    
    if [ -z "$current_code" ] || [ -z "$remote_code" ]; then
        log_error "Не удалось прочитать версии"
        rm -rf "$TMP_DIR"
        exit 1
    fi
    
    ui_print "Текущая версия: $current_code"
    ui_print "Доступная версия: $remote_code"
    
    if [ "$remote_code" -gt "$current_code" ]; then
        ui_print "Найдено обновление. Скачиваем hosts..."
        
        if download_file "$GITHUB_HOSTS" "$TMP_HOSTS"; then
            if [ ! -s "$TMP_HOSTS" ]; then
                log_error "Скачанный файл hosts пуст!"
            else
                mkdir -p "$(dirname "$HOSTS_FILE")"
                cp -f "$TMP_HOSTS" "$HOSTS_FILE"
                chmod 644 "$HOSTS_FILE"
                log "Hosts файл скопирован в модуль"
                
                cp -f "$HOSTS_FILE" "$SYSTEM_HOSTS"
                chmod 644 "$SYSTEM_HOSTS"
                log "Hosts файл применен к системе"
                
                cp -f "$TMP_MODULE_PROP" "$MODULE_PROP"
                log "Module.prop обновлен"
                
                ui_print "Hosts успешно обновлен"
                ui_print "Версия обновлена до $remote_code"
            fi
        else
            log_error "Не удалось загрузить hosts"
            if [ -f "$HOSTS_FILE" ]; then
                ui_print "Использую текущий hosts"
                cp -f "$HOSTS_FILE" "$SYSTEM_HOSTS"
                chmod 644 "$SYSTEM_HOSTS"
            else
                log_error "Отсутствует hosts файл"
            fi
        fi
    else
        ui_print "У вас актуальная версия"
        if [ -f "$HOSTS_FILE" ]; then
            cp -f "$HOSTS_FILE" "$SYSTEM_HOSTS"
            chmod 644 "$SYSTEM_HOSTS"
        else
            log_error "Отсутствует hosts файл"
        fi
    fi
    
    rm -rf "$TMP_DIR"
    ui_print "Готово!"
    log "Завершение action.sh"
}

main