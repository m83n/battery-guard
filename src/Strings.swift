// UI translations. Order of each row follows Lang.allCases; build.sh checks every row (tests/check_strings.swift).
import Foundation

enum Lang: String, CaseIterable {
    case ru, en, es, pt, fr, de, it, tr, uk, zh, ja, ko

    var nativeName: String {
        switch self {
        case .ru: return "Русский"
        case .en: return "English"
        case .es: return "Español"
        case .pt: return "Português"
        case .fr: return "Français"
        case .de: return "Deutsch"
        case .it: return "Italiano"
        case .tr: return "Türkçe"
        case .uk: return "Українська"
        case .zh: return "中文（简体）"
        case .ja: return "日本語"
        case .ko: return "한국어"
        }
    }

    // nil in settings means "follow the system language"; unsupported system languages fall back to English.
    static var chosen: Lang? {
        get { UserDefaults.standard.string(forKey: "language").flatMap(Lang.init(rawValue:)) }
        set { UserDefaults.standard.set(newValue?.rawValue, forKey: "language"); cached = nil }
    }

    private static var cached: Lang?
    static var current: Lang {
        if let c = cached { return c }
        let l = chosen ?? Locale.preferredLanguages.lazy.compactMap(fromSystem).first ?? .en
        cached = l
        return l
    }

    // Only Simplified Chinese is translated, so Traditional (zh-Hant, zh-TW, zh-HK) is not matched.
    private static func fromSystem(_ id: String) -> Lang? {
        if id.hasPrefix("zh"), id.contains("Hant") || id.contains("TW") || id.contains("HK") || id.contains("MO") { return nil }
        return Lang(rawValue: String(id.prefix(2)))
    }
}

enum K: String, CaseIterable {
    case prompt, unknownError
    case modeNone, modePercent, modeTemp, modeTime
    case unsupportedTitle, unsupportedText
    case installTitle, updateTitle, installText, installButton, later, installFailed
    case uninstallTitle, uninstallText, uninstallButton, cancel, uninstallFailed
    case charge, batteryTemp, noData, tipNotRunning, tipPaused
    case onBattery, acCharging, acNotCharging
    case service, notInstalled, installService, quit, running, notRunning
    case mode, modeHeat, modeNormal, controllerLimit, runtime, hoursMinutes, estimating
    case chargeLimit, pauseAbove, resumeBelow, showNext, reinstall, removeService
    case saveFailed, saveFailedText, language, systemLanguage, ok
}

//          ru, en, es, pt, fr, de, it, tr, uk, zh, ja, ko
let T: [K: [String]] = [
    .prompt: [
        "BatteryGuard: управление службой контроля заряда.",
        "BatteryGuard: managing the charge control service.",
        "BatteryGuard: gestión del servicio de control de carga.",
        "BatteryGuard: gerenciamento do serviço de controle de carga.",
        "BatteryGuard : gestion du service de contrôle de la charge.",
        "BatteryGuard: Verwaltung des Ladesteuerungsdienstes.",
        "BatteryGuard: gestione del servizio di controllo della carica.",
        "BatteryGuard: şarj denetimi hizmetinin yönetimi.",
        "BatteryGuard: керування службою контролю заряду.",
        "BatteryGuard：管理充电控制服务。",
        "BatteryGuard：充電制御サービスの管理。",
        "BatteryGuard: 충전 제어 서비스 관리.",
    ],
    .unknownError: [
        "неизвестная ошибка", "unknown error", "error desconocido", "erro desconhecido", "erreur inconnue",
        "unbekannter Fehler", "errore sconosciuto", "bilinmeyen hata", "невідома помилка", "未知错误", "不明なエラー", "알 수 없는 오류",
    ],
    .modeNone: [
        "Только значок", "Icon only", "Solo el icono", "Somente o ícone", "Icône seule",
        "Nur Symbol", "Solo icona", "Yalnızca simge", "Лише значок", "仅图标", "アイコンのみ", "아이콘만",
    ],
    .modePercent: [
        "Заряд, %", "Charge, %", "Carga, %", "Carga, %", "Charge, %",
        "Ladung, %", "Carica, %", "Şarj, %", "Заряд, %", "电量, %", "充電量, %", "충전량, %",
    ],
    .modeTemp: [
        "Температура", "Temperature", "Temperatura", "Temperatura", "Température",
        "Temperatur", "Temperatura", "Sıcaklık", "Температура", "温度", "温度", "온도",
    ],
    .modeTime: [
        "Время работы от батареи", "Time on battery", "Tiempo con batería", "Tempo na bateria", "Autonomie restante",
        "Akkulaufzeit", "Autonomia residua", "Pil ile kalan süre", "Час роботи від батареї", "电池续航时间", "バッテリー駆動時間", "배터리 사용 시간",
    ],
    .unsupportedTitle: [
        "Этот Mac не поддерживается", "This Mac is not supported", "Este Mac no es compatible", "Este Mac não é compatível",
        "Ce Mac n'est pas pris en charge", "Dieser Mac wird nicht unterstützt", "Questo Mac non è supportato",
        "Bu Mac desteklenmiyor", "Цей Mac не підтримується", "不支持此 Mac", "この Mac はサポートされていません", "이 Mac은 지원되지 않습니다",
    ],
    .unsupportedText: [
        "В контроллере питания нет ключа BCLM, через который BatteryGuard ограничивает заряд. Приложение рассчитано на MacBook на процессорах Intel.",
        "The power controller has no BCLM key, which BatteryGuard uses to limit the charge. The app is made for Intel MacBooks.",
        "El controlador de energía no tiene la clave BCLM, que BatteryGuard usa para limitar la carga. La app está pensada para MacBook con procesador Intel.",
        "O controlador de energia não tem a chave BCLM, que o BatteryGuard usa para limitar a carga. O app é feito para MacBooks com processador Intel.",
        "Le contrôleur d'alimentation n'a pas de clé BCLM, utilisée par BatteryGuard pour limiter la charge. L'app est conçue pour les MacBook à processeur Intel.",
        "Der Energiecontroller hat keinen BCLM-Schlüssel, über den BatteryGuard die Ladung begrenzt. Die App ist für MacBooks mit Intel-Prozessor gedacht.",
        "Il controller di alimentazione non ha la chiave BCLM, usata da BatteryGuard per limitare la carica. L'app è pensata per MacBook con processore Intel.",
        "Güç denetleyicisinde BatteryGuard'ın şarjı sınırlamak için kullandığı BCLM anahtarı yok. Uygulama Intel işlemcili MacBook'lar içindir.",
        "У контролері живлення немає ключа BCLM, через який BatteryGuard обмежує заряд. Застосунок розрахований на MacBook із процесорами Intel.",
        "电源控制器中没有 BatteryGuard 用于限制充电的 BCLM 键。本应用适用于 Intel 处理器的 MacBook。",
        "電源コントローラに、BatteryGuard が充電制限に使う BCLM キーがありません。このアプリは Intel プロセッサ搭載の MacBook 用です。",
        "전원 컨트롤러에 BatteryGuard가 충전을 제한하는 데 쓰는 BCLM 키가 없습니다. 이 앱은 Intel 프로세서 MacBook용입니다.",
    ],
    .installTitle: [
        "Установить службу BatteryGuard?", "Install the BatteryGuard service?", "¿Instalar el servicio de BatteryGuard?",
        "Instalar o serviço do BatteryGuard?", "Installer le service BatteryGuard ?", "BatteryGuard-Dienst installieren?",
        "Installare il servizio BatteryGuard?", "BatteryGuard hizmeti yüklensin mi?", "Встановити службу BatteryGuard?",
        "安装 BatteryGuard 服务？", "BatteryGuard サービスをインストールしますか?", "BatteryGuard 서비스를 설치할까요?",
    ],
    .updateTitle: [
        "Обновить службу BatteryGuard?", "Update the BatteryGuard service?", "¿Actualizar el servicio de BatteryGuard?",
        "Atualizar o serviço do BatteryGuard?", "Mettre à jour le service BatteryGuard ?", "BatteryGuard-Dienst aktualisieren?",
        "Aggiornare il servizio BatteryGuard?", "BatteryGuard hizmeti güncellensin mi?", "Оновити службу BatteryGuard?",
        "更新 BatteryGuard 服务？", "BatteryGuard サービスをアップデートしますか?", "BatteryGuard 서비스를 업데이트할까요?",
    ],
    .installText: [
        "Служба раз в минуту проверяет заряд и температуру батареи и управляет зарядкой через контроллер питания. Для установки нужен пароль администратора.",
        "Once a minute the service checks battery charge and temperature and controls charging through the power controller. Installing requires an administrator password.",
        "Una vez por minuto el servicio comprueba la carga y la temperatura de la batería y controla la carga mediante el controlador de energía. Se necesita la contraseña de administrador.",
        "Uma vez por minuto o serviço verifica a carga e a temperatura da bateria e controla o carregamento pelo controlador de energia. É necessária a senha de administrador.",
        "Toutes les minutes, le service vérifie la charge et la température de la batterie et pilote la charge via le contrôleur d'alimentation. Le mot de passe administrateur est requis.",
        "Der Dienst prüft jede Minute Ladung und Temperatur des Akkus und steuert das Laden über den Energiecontroller. Für die Installation ist das Administratorpasswort nötig.",
        "Ogni minuto il servizio controlla carica e temperatura della batteria e gestisce la ricarica tramite il controller di alimentazione. Serve la password di amministratore.",
        "Hizmet her dakika pilin şarjını ve sıcaklığını denetler ve şarjı güç denetleyicisi üzerinden yönetir. Yükleme için yönetici parolası gerekir.",
        "Служба щохвилини перевіряє заряд і температуру батареї та керує заряджанням через контролер живлення. Для встановлення потрібен пароль адміністратора.",
        "该服务每分钟检查一次电池电量和温度，并通过电源控制器管理充电。安装需要管理员密码。",
        "サービスは 1 分ごとにバッテリーの充電量と温度を確認し、電源コントローラで充電を制御します。インストールには管理者パスワードが必要です。",
        "서비스는 1분마다 배터리 충전량과 온도를 확인하고 전원 컨트롤러로 충전을 제어합니다. 설치하려면 관리자 암호가 필요합니다.",
    ],
    .installButton: [
        "Установить", "Install", "Instalar", "Instalar", "Installer", "Installieren", "Installa", "Yükle", "Встановити", "安装", "インストール", "설치",
    ],
    .later: [
        "Позже", "Later", "Más tarde", "Mais tarde", "Plus tard", "Später", "Più tardi", "Sonra", "Пізніше", "稍后", "後で", "나중에",
    ],
    .installFailed: [
        "Не удалось установить службу", "Could not install the service", "No se pudo instalar el servicio", "Não foi possível instalar o serviço",
        "Impossible d'installer le service", "Dienst konnte nicht installiert werden", "Impossibile installare il servizio",
        "Hizmet yüklenemedi", "Не вдалося встановити службу", "无法安装服务", "サービスをインストールできませんでした", "서비스를 설치할 수 없습니다",
    ],
    .uninstallTitle: [
        "Удалить службу BatteryGuard?", "Remove the BatteryGuard service?", "¿Eliminar el servicio de BatteryGuard?",
        "Remover o serviço do BatteryGuard?", "Supprimer le service BatteryGuard ?", "BatteryGuard-Dienst entfernen?",
        "Rimuovere il servizio BatteryGuard?", "BatteryGuard hizmeti kaldırılsın mı?", "Видалити службу BatteryGuard?",
        "移除 BatteryGuard 服务？", "BatteryGuard サービスを削除しますか?", "BatteryGuard 서비스를 제거할까요?",
    ],
    .uninstallText: [
        "Лимит заряда вернется к 100%, защита от нагрева отключится. Само приложение можно затем удалить из папки Программы.",
        "The charge limit returns to 100% and heat protection turns off. You can then delete the app from the Applications folder.",
        "El límite de carga volverá al 100% y la protección térmica se desactivará. Después puede borrar la app de la carpeta Aplicaciones.",
        "O limite de carga voltará a 100% e a proteção contra calor será desligada. Depois você pode apagar o app da pasta Aplicativos.",
        "La limite de charge revient à 100% et la protection thermique est désactivée. Vous pourrez ensuite supprimer l'app du dossier Applications.",
        "Das Ladelimit wird wieder 100%, der Hitzeschutz wird ausgeschaltet. Danach können Sie die App aus dem Ordner Programme löschen.",
        "Il limite di carica torna al 100% e la protezione dal calore si disattiva. Poi puoi eliminare l'app dalla cartella Applicazioni.",
        "Şarj sınırı %100'e döner ve ısı koruması kapanır. Ardından uygulamayı Uygulamalar klasöründen silebilirsiniz.",
        "Ліміт заряду повернеться до 100%, захист від нагрівання вимкнеться. Потім застосунок можна видалити з папки Програми.",
        "充电上限将恢复为 100%，过热保护将关闭。之后可以从应用程序文件夹中删除本应用。",
        "充電上限は 100% に戻り、高温保護はオフになります。その後、アプリケーションフォルダからアプリを削除できます。",
        "충전 한도가 100%로 돌아가고 과열 보호가 꺼집니다. 그런 다음 응용 프로그램 폴더에서 앱을 삭제할 수 있습니다.",
    ],
    .uninstallButton: [
        "Удалить", "Remove", "Eliminar", "Remover", "Supprimer", "Entfernen", "Rimuovi", "Kaldır", "Видалити", "移除", "削除", "제거",
    ],
    .cancel: [
        "Отмена", "Cancel", "Cancelar", "Cancelar", "Annuler", "Abbrechen", "Annulla", "Vazgeç", "Скасувати", "取消", "キャンセル", "취소",
    ],
    .uninstallFailed: [
        "Не удалось удалить службу", "Could not remove the service", "No se pudo eliminar el servicio", "Não foi possível remover o serviço",
        "Impossible de supprimer le service", "Dienst konnte nicht entfernt werden", "Impossibile rimuovere il servizio",
        "Hizmet kaldırılamadı", "Не вдалося видалити службу", "无法移除服务", "サービスを削除できませんでした", "서비스를 제거할 수 없습니다",
    ],
    .charge: [
        "Заряд", "Charge", "Carga", "Carga", "Charge", "Ladung", "Carica", "Şarj", "Заряд", "电量", "充電量", "충전량",
    ],
    .batteryTemp: [
        "Температура батареи", "Battery temperature", "Temperatura de la batería", "Temperatura da bateria", "Température de la batterie",
        "Akkutemperatur", "Temperatura batteria", "Pil sıcaklığı", "Температура батареї", "电池温度", "バッテリー温度", "배터리 온도",
    ],
    .noData: [
        "нет данных", "no data", "sin datos", "sem dados", "pas de données", "keine Daten", "nessun dato", "veri yok", "немає даних", "无数据", "データなし", "데이터 없음",
    ],
    .tipNotRunning: [
        "Служба не запущена", "Service is not running", "El servicio no está en ejecución", "O serviço não está em execução",
        "Le service n'est pas lancé", "Dienst läuft nicht", "Il servizio non è in esecuzione", "Hizmet çalışmıyor",
        "Служба не запущена", "服务未运行", "サービスは停止しています", "서비스가 실행되고 있지 않습니다",
    ],
    .tipPaused: [
        "Зарядка на паузе из-за нагрева", "Charging paused: battery is hot", "Carga en pausa por temperatura", "Carregamento pausado por calor",
        "Charge en pause : batterie chaude", "Laden pausiert: Akku zu warm", "Ricarica in pausa per calore", "Isınma nedeniyle şarj duraklatıldı",
        "Заряджання на паузі через нагрівання", "因过热暂停充电", "高温のため充電を一時停止中", "과열로 충전 일시 중지됨",
    ],
    .onBattery: [
        "работа от батареи", "on battery", "con batería", "na bateria", "sur batterie", "Akkubetrieb", "a batteria", "pil ile çalışıyor",
        "робота від батареї", "使用电池供电", "バッテリー駆動", "배터리 사용 중",
    ],
    .acCharging: [
        "от сети, идет зарядка", "on power adapter, charging", "conectado, cargando", "na tomada, carregando", "sur secteur, en charge",
        "am Netzteil, lädt", "alimentazione, in carica", "adaptöre bağlı, şarj oluyor", "від мережі, заряджається",
        "已接电源，正在充电", "電源接続、充電中", "전원 연결됨, 충전 중",
    ],
    .acNotCharging: [
        "от сети, зарядка остановлена", "on power adapter, not charging", "conectado, sin cargar", "na tomada, sem carregar",
        "sur secteur, pas en charge", "am Netzteil, lädt nicht", "alimentazione, non in carica", "adaptöre bağlı, şarj olmuyor",
        "від мережі, заряджання зупинено", "已接电源，未充电", "電源接続、充電停止中", "전원 연결됨, 충전 안 함",
    ],
    .service: [
        "Служба", "Service", "Servicio", "Serviço", "Service", "Dienst", "Servizio", "Hizmet", "Служба", "服务", "サービス", "서비스",
    ],
    .notInstalled: [
        "не установлена", "not installed", "no instalado", "não instalado", "non installé", "nicht installiert", "non installato",
        "yüklü değil", "не встановлена", "未安装", "未インストール", "설치되지 않음",
    ],
    .installService: [
        "Установить службу", "Install service", "Instalar servicio", "Instalar serviço", "Installer le service", "Dienst installieren",
        "Installa servizio", "Hizmeti yükle", "Встановити службу", "安装服务", "サービスをインストール", "서비스 설치",
    ],
    .quit: [
        "Закрыть", "Quit", "Salir", "Sair", "Quitter", "Beenden", "Esci", "Çık", "Закрити", "退出", "終了", "종료",
    ],
    .running: [
        "работает", "running", "en ejecución", "em execução", "actif", "läuft", "attivo", "çalışıyor", "працює", "运行中", "実行中", "실행 중",
    ],
    .notRunning: [
        "не запущена", "not running", "detenido", "parado", "arrêté", "gestoppt", "fermo", "çalışmıyor", "не запущена", "未运行", "停止中", "중지됨",
    ],
    .mode: [
        "Режим", "Mode", "Modo", "Modo", "Mode", "Modus", "Modalità", "Mod", "Режим", "模式", "モード", "모드",
    ],
    .modeHeat: [
        "пауза из-за нагрева", "paused, battery is hot", "pausa por temperatura", "pausa por calor", "pause, batterie chaude",
        "Pause, Akku zu warm", "pausa per calore", "ısınma nedeniyle duraklatıldı", "пауза через нагрівання", "因过热暂停", "高温のため一時停止", "과열로 일시 중지",
    ],
    .modeNormal: [
        "обычный", "normal", "normal", "normal", "normal", "normal", "normale", "normal", "звичайний", "正常", "通常", "일반",
    ],
    .controllerLimit: [
        "Лимит в контроллере", "Controller limit", "Límite en el controlador", "Limite no controlador", "Limite du contrôleur",
        "Limit im Controller", "Limite nel controller", "Denetleyici sınırı", "Ліміт у контролері", "控制器上限", "コントローラの上限", "컨트롤러 한도",
    ],
    .runtime: [
        "Работы от батареи", "Battery time left", "Tiempo restante", "Tempo restante", "Autonomie restante", "Restlaufzeit",
        "Autonomia residua", "Kalan pil süresi", "Роботи від батареї", "剩余续航", "バッテリー残り時間", "남은 배터리 시간",
    ],
    .hoursMinutes: [
        "%ld ч %ld мин", "%ld h %ld min", "%ld h %ld min", "%ld h %ld min", "%ld h %ld min", "%ld Std. %ld Min.", "%ld h %ld min", "%ld sa %ld dk",
        "%ld год %ld хв", "%ld 小时 %ld 分钟", "%ld 時間 %ld 分", "%ld시간 %ld분",
    ],
    .estimating: [
        "оценивается", "estimating", "calculando", "calculando", "estimation en cours", "wird berechnet", "in calcolo", "hesaplanıyor",
        "оцінюється", "正在估算", "計算中", "계산 중",
    ],
    .chargeLimit: [
        "Лимит заряда", "Charge limit", "Límite de carga", "Limite de carga", "Limite de charge", "Ladelimit", "Limite di carica",
        "Şarj sınırı", "Ліміт заряду", "充电上限", "充電上限", "충전 한도",
    ],
    .pauseAbove: [
        "Пауза при нагреве от", "Pause when hotter than", "Pausar por encima de", "Pausar acima de", "Pause au-dessus de",
        "Pause ab", "Pausa sopra", "Şu sıcaklıkta duraklat", "Пауза при нагріванні від", "高于此温度暂停", "一時停止する温度", "일시 중지 온도",
    ],
    .resumeBelow: [
        "Возобновить ниже", "Resume below", "Reanudar por debajo de", "Retomar abaixo de", "Reprendre en dessous de",
        "Fortsetzen unter", "Riprendi sotto", "Şunun altında sürdür", "Відновити нижче", "低于此温度恢复", "再開する温度", "재개 온도",
    ],
    .showNext: [
        "Показывать рядом со значком", "Show next to icon", "Mostrar junto al icono", "Mostrar ao lado do ícone", "Afficher à côté de l'icône",
        "Neben dem Symbol anzeigen", "Mostra accanto all'icona", "Simgenin yanında göster", "Показувати поруч зі значком",
        "在图标旁显示", "アイコンの横に表示", "아이콘 옆에 표시",
    ],
    .reinstall: [
        "Переустановить службу", "Reinstall service", "Reinstalar servicio", "Reinstalar serviço", "Réinstaller le service",
        "Dienst neu installieren", "Reinstalla servizio", "Hizmeti yeniden yükle", "Перевстановити службу", "重新安装服务", "サービスを再インストール", "서비스 다시 설치",
    ],
    .removeService: [
        "Удалить службу", "Remove service", "Eliminar servicio", "Remover serviço", "Supprimer le service", "Dienst entfernen",
        "Rimuovi servizio", "Hizmeti kaldır", "Видалити службу", "移除服务", "サービスを削除", "서비스 제거",
    ],
    .saveFailed: [
        "Не удалось сохранить пороги", "Could not save thresholds", "No se pudieron guardar los umbrales", "Não foi possível salvar os limites",
        "Impossible d'enregistrer les seuils", "Schwellenwerte konnten nicht gespeichert werden", "Impossibile salvare le soglie",
        "Eşikler kaydedilemedi", "Не вдалося зберегти пороги", "无法保存阈值", "しきい値を保存できませんでした", "임계값을 저장할 수 없습니다",
    ],
    .saveFailedText: [
        "Нет доступа к файлу %@. Переустановите службу через меню BatteryGuard.",
        "No access to %@. Reinstall the service from the BatteryGuard menu.",
        "Sin acceso a %@. Reinstale el servicio desde el menú de BatteryGuard.",
        "Sem acesso a %@. Reinstale o serviço pelo menu do BatteryGuard.",
        "Pas d'accès à %@. Réinstallez le service depuis le menu BatteryGuard.",
        "Kein Zugriff auf %@. Installieren Sie den Dienst über das BatteryGuard-Menü neu.",
        "Nessun accesso a %@. Reinstalla il servizio dal menu di BatteryGuard.",
        "%@ dosyasına erişilemiyor. Hizmeti BatteryGuard menüsünden yeniden yükleyin.",
        "Немає доступу до %@. Перевстановіть службу через меню BatteryGuard.",
        "无法访问 %@。请通过 BatteryGuard 菜单重新安装服务。",
        "%@ にアクセスできません。BatteryGuard メニューからサービスを再インストールしてください。",
        "%@에 접근할 수 없습니다. BatteryGuard 메뉴에서 서비스를 다시 설치하세요.",
    ],
    .language: [
        "Язык", "Language", "Idioma", "Idioma", "Langue", "Sprache", "Lingua", "Dil", "Мова", "语言", "言語", "언어",
    ],
    .ok: [
        "OK", "OK", "Aceptar", "OK", "OK", "OK", "OK", "Tamam", "OK", "好", "OK", "확인",
    ],
    .systemLanguage: [
        "Системный", "System", "Del sistema", "Do sistema", "Système", "System", "Di sistema", "Sistem", "Системна", "跟随系统", "システム", "시스템",
    ],
]

func L(_ key: K) -> String {
    let row = T[key] ?? []
    let i = Lang.allCases.firstIndex(of: Lang.current) ?? 1
    return i < row.count ? row[i] : (row.count > 1 ? row[1] : key.rawValue)
}

func L(_ key: K, _ args: CVarArg...) -> String { String(format: L(key), arguments: args) }
