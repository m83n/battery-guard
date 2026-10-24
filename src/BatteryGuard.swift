// BatteryGuard: menu bar app that installs the battery-guard service and shows its state.
import AppKit
import IOKit.ps

let installDir = "/usr/local/battery-guard"
let smcPath = installDir + "/smcctl"
let hotFlag = "/var/run/battery-guard.hot"
let confPath = installDir + "/thresholds"
let resDir = Bundle.main.resourcePath ?? ""
let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"

func run(_ path: String, _ args: [String]) -> (Int32, String) {
    let p = Process()
    let pipe = Pipe()
    p.executableURL = URL(fileURLWithPath: path)
    p.arguments = args
    p.standardOutput = pipe
    p.standardError = FileHandle.nullDevice
    guard (try? p.run()) != nil else { return (-1, "") }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    p.waitUntilExit()
    return (p.terminationStatus, String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines))
}

// Installs/removes the root service via install-helper.sh from the app bundle.
enum Service {
    static var installedVersion: String? {
        (try? String(contentsOfFile: installDir + "/version", encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // Reading an SMC key needs no root; Macs without BCLM are not supported.
    static var supported: Bool { run(resDir + "/smcctl", ["BCLM"]).0 == 0 }

    // Returns nil on success or if the user cancelled the password prompt, else an error text.
    static func runPrivileged(_ action: String) -> String? {
        func lit(_ s: String) -> String {
            "\"" + s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
        }
        let src = "do shell script \"/bin/bash \" & quoted form of \(lit(resDir + "/install-helper.sh"))"
            + " & \" \(action) \" & quoted form of \(lit(resDir)) & \" \" & quoted form of \(lit(NSUserName()))"
            + " with prompt \"BatteryGuard: управление службой контроля заряда.\" with administrator privileges"
        var err: NSDictionary?
        NSAppleScript(source: src)?.executeAndReturnError(&err)
        guard let e = err else { return nil }
        if (e[NSAppleScript.errorNumber] as? Int) == -128 { return nil }
        return e[NSAppleScript.errorMessage] as? String ?? "неизвестная ошибка"
    }
}

func alert(_ title: String, _ text: String, _ buttons: [String]) -> NSApplication.ModalResponse {
    NSApp.activate(ignoringOtherApps: true)
    let a = NSAlert()
    a.messageText = title
    a.informativeText = text
    buttons.forEach { a.addButton(withTitle: $0) }
    return a.runModal()
}

// Same keys and defaults as battery-guard.sh.
struct Thresholds {
    var limit = 80, hot = 40, cool = 35

    static func read() -> Thresholds {
        var t = Thresholds()
        guard let text = try? String(contentsOfFile: confPath, encoding: .utf8) else { return t }
        for line in text.split(separator: "\n") {
            let kv = line.split(separator: "=").map { $0.trimmingCharacters(in: .whitespaces) }
            guard kv.count == 2, let v = Int(kv[1]) else { continue }
            switch kv[0] {
            case "LIMIT": t.limit = v
            case "HOT": t.hot = v
            case "COOL": t.cool = v
            default: break
            }
        }
        return t
    }

    func write() -> Bool {
        let text = "LIMIT=\(limit)\nHOT=\(hot)\nCOOL=\(cool)\n"
        return (try? text.write(toFile: confPath, atomically: false, encoding: .utf8)) != nil
    }
}

struct Status {
    var serviceRunning = false
    var limit: Int?
    var hot = false
    var temp: Int?
    var percent: Int?
    var onAC = false
    var charging = false
    var minutesLeft: Int?

    static func read() -> Status {
        var s = Status()
        s.serviceRunning = run("/bin/launchctl", ["print", "system/local.batteryguard.daemon"]).0 == 0
        let (rc, hex) = run(smcPath, ["BCLM"])
        if rc == 0 { s.limit = Int(hex, radix: 16) }
        s.hot = FileManager.default.fileExists(atPath: hotFlag)

        let battery = IOServiceGetMatchingService(mach_port_t(MACH_PORT_NULL), IOServiceMatching("AppleSmartBattery"))
        if battery != 0 {
            if let t = IORegistryEntryCreateCFProperty(battery, "Temperature" as CFString, nil, 0)?.takeRetainedValue() as? Int {
                s.temp = t / 100
            }
            // Gauge's averaged estimate; 65535 means "not available" (e.g. on AC).
            if let m = IORegistryEntryCreateCFProperty(battery, "AvgTimeToEmpty" as CFString, nil, 0)?.takeRetainedValue() as? Int,
               m > 0, m < 65535 {
                s.minutesLeft = m
            }
            IOObjectRelease(battery)
        }

        let info = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let list = IOPSCopyPowerSourcesList(info).takeRetainedValue() as [CFTypeRef]
        for src in list {
            guard let d = IOPSGetPowerSourceDescription(info, src)?.takeUnretainedValue() as? [String: Any] else { continue }
            s.percent = d[kIOPSCurrentCapacityKey] as? Int
            s.charging = d[kIOPSIsChargingKey] as? Bool ?? false
            s.onAC = (d[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue
            if s.minutesLeft == nil, let m = d[kIOPSTimeToEmptyKey] as? Int, m > 0 { s.minutesLeft = m }
        }
        if s.onAC { s.minutesLeft = nil }
        return s
    }
}

// Battery icon whose fill is proportional to charge; green bolt while charging, plug on AC without charging.
// Colored (not template): fill red below 10%, yellow below 20%; outline matches the menu bar.
// Outline is slightly muted (0.9 / 0.1) to blend with system menu bar icons.
func batteryIcon(percent: Int, charging: Bool, plugged: Bool, dark: Bool) -> NSImage {
    let fg = NSColor(white: dark ? 0.9 : 0.1, alpha: 1)
    let img = NSImage(size: NSSize(width: 26, height: 13), flipped: false) { _ in
        fg.set()
        let body = NSRect(x: 0.5, y: 0.5, width: 22, height: 12)
        let outline = NSBezierPath(roundedRect: body, xRadius: 3.5, yRadius: 3.5)
        outline.lineWidth = 1
        outline.stroke()
        NSBezierPath(roundedRect: NSRect(x: 23.5, y: 4, width: 2, height: 5), xRadius: 1, yRadius: 1).fill()
        let inner = body.insetBy(dx: 2, dy: 2)
        let w = (inner.width * CGFloat(min(max(percent, 0), 100)) / 100).rounded()
        let fillRect = NSRect(x: inner.minX, y: inner.minY, width: max(w, 2), height: inner.height)
        if w > 0 {
            if percent < 10 { NSColor.systemRed.set() } else if percent < 20 { NSColor.systemYellow.set() }
            NSBezierPath(roundedRect: fillRect, xRadius: 1.5, yRadius: 1.5).fill()
        }
        // 6x9 glyph centered on the body, with a transparent halo cut out around it.
        let ox = body.midX - 3, oy = body.midY - 4.5
        let glyph = NSBezierPath()
        if charging {
            for (i, p) in [(3.8, 9.0), (0.0, 4.1), (2.6, 4.1), (2.1, 0.0), (6.0, 4.9), (3.4, 4.9)].enumerated() {
                let pt = NSPoint(x: ox + p.0, y: oy + p.1)
                if i == 0 { glyph.move(to: pt) } else { glyph.line(to: pt) }
            }
            glyph.close()
        } else if plugged {
            glyph.append(NSBezierPath(rect: NSRect(x: ox + 1.2, y: oy + 6.5, width: 1.2, height: 2.5)))      // prongs
            glyph.append(NSBezierPath(rect: NSRect(x: ox + 3.6, y: oy + 6.5, width: 1.2, height: 2.5)))
            glyph.append(NSBezierPath(roundedRect: NSRect(x: ox, y: oy + 2.5, width: 6, height: 4), xRadius: 1.5, yRadius: 1.5))
            glyph.append(NSBezierPath(rect: NSRect(x: ox + 2.4, y: oy, width: 1.2, height: 2.5)))            // cord
        }
        if !glyph.isEmpty {
            if charging {  // plug always contrasts with what is under it, so only the bolt needs a halo
                NSGraphicsContext.current?.compositingOperation = .destinationOut
                glyph.lineWidth = 1.5
                glyph.lineJoinStyle = .round
                glyph.stroke()
                glyph.fill()
                NSGraphicsContext.current?.compositingOperation = .sourceOver
            }
            (charging ? NSColor.systemGreen : fg).set()
            glyph.fill()
            // Plug over the fill is drawn in the inverse color: black on a dark menu bar, white on a light one.
            if !charging && w > 0 {
                NSGraphicsContext.saveGraphicsState()
                NSBezierPath(rect: fillRect).addClip()
                (dark ? NSColor.black : NSColor.white).set()
                glyph.fill()
                NSGraphicsContext.restoreGraphicsState()
            }
        }
        return true
    }
    return img
}

// Disabled (informational) menu line drawn in normal text color instead of system gray.
func infoItem(_ text: String) -> NSMenuItem {
    let mi = NSMenuItem(title: text, action: nil, keyEquivalent: "")
    mi.attributedTitle = NSAttributedString(string: text, attributes: [
        .foregroundColor: NSColor.labelColor,
        .font: NSFont.menuFont(ofSize: 0),
    ])
    return mi
}

enum TitleMode: String, CaseIterable {
    case none, percent, temp, time
    var label: String {
        switch self {
        case .none: return "Только значок"
        case .percent: return "Заряд, %"
        case .temp: return "Температура"
        case .time: return "Время работы от батареи"
        }
    }
}

class App: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let menu = NSMenu()
    var lastMinutes: Int?  // last known estimate on battery, kept while macOS recalculates
    var mode: TitleMode {
        get { TitleMode(rawValue: UserDefaults.standard.string(forKey: "titleMode") ?? "") ?? .percent }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "titleMode") }
    }

    func applicationDidFinishLaunching(_ n: Notification) {
        if let id = Bundle.main.bundleIdentifier, NSRunningApplication.runningApplications(withBundleIdentifier: id).count > 1 {
            NSApp.terminate(nil)
            return
        }
        menu.delegate = self
        item.menu = menu
        refresh()
        Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in self.refresh() }
        DispatchQueue.main.async { self.offerInstall() }
    }

    // On first launch or after an app update: install or update the service.
    func offerInstall() {
        let installed = Service.installedVersion
        if installed == appVersion { return }
        guard Service.supported else {
            _ = alert("Этот Mac не поддерживается",
                      "В контроллере питания нет ключа BCLM, через который BatteryGuard ограничивает заряд. "
                      + "Приложение рассчитано на MacBook на процессорах Intel.", ["Закрыть"])
            NSApp.terminate(nil)
            return
        }
        let title = installed == nil ? "Установить службу BatteryGuard?" : "Обновить службу BatteryGuard до версии \(appVersion)?"
        let r = alert(title, "Служба раз в минуту проверяет заряд и температуру батареи и управляет зарядкой "
                      + "через контроллер питания. Для установки нужен пароль администратора.", ["Установить", "Позже"])
        if r == .alertFirstButtonReturn { installService() }
    }

    @objc func installService() {
        if let e = Service.runPrivileged("install") { _ = alert("Не удалось установить службу", e, ["OK"]) }
        refresh()
    }

    @objc func uninstallService() {
        let r = alert("Удалить службу BatteryGuard?",
                      "Лимит заряда вернется к 100%, защита от нагрева отключится. Само приложение можно затем удалить из папки Программы.",
                      ["Удалить", "Отмена"])
        guard r == .alertFirstButtonReturn else { return }
        if let e = Service.runPrivileged("uninstall") { _ = alert("Не удалось удалить службу", e, ["OK"]) }
        refresh()
    }

    func menuWillOpen(_ m: NSMenu) { refresh() }

    func refresh() {
        let s = Status.read()
        let t = Thresholds.read()

        if s.onAC { lastMinutes = nil } else if let m = s.minutesLeft { lastMinutes = m }

        if !s.serviceRunning {
            item.button?.image = NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: "battery-guard")
        } else if s.hot {
            item.button?.image = NSImage(systemSymbolName: "thermometer", accessibilityDescription: "battery-guard")
        } else {
            let dark = item.button?.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            item.button?.image = batteryIcon(percent: s.percent ?? 0, charging: s.charging, plugged: s.onAC, dark: dark)
        }
        item.button?.imagePosition = .imageLeft
        switch mode {
        case .none: item.button?.title = ""
        case .percent: item.button?.title = s.percent.map { " \($0)%" } ?? ""
        case .temp: item.button?.title = s.temp.map { " \($0)°" } ?? ""
        case .time:
            if s.onAC { item.button?.title = "" }
            else { item.button?.title = lastMinutes.map { " \($0 / 60):" + String(format: "%02d", $0 % 60) } ?? " -:--" }
        }

        let power: String
        if !s.onAC { power = "работа от батареи" }
        else if s.charging { power = "от сети, идет зарядка" }
        else { power = "от сети, зарядка остановлена" }

        menu.removeAllItems()
        guard Service.installedVersion != nil else {
            menu.addItem(infoItem("Служба: не установлена"))
            let inst = NSMenuItem(title: "Установить службу", action: #selector(installService), keyEquivalent: "")
            inst.target = self
            menu.addItem(inst)
            menu.addItem(.separator())
            menu.addItem(NSMenuItem(title: "Закрыть", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
            return
        }
        var lines = [
            "Служба: " + (s.serviceRunning ? "работает" : "не запущена"),
            "Режим: " + (s.hot ? "пауза из-за нагрева" : "обычный"),
            "",
            "Заряд: " + (s.percent.map { "\($0)%" } ?? "нет данных") + ", " + power,
            "Температура батареи: " + (s.temp.map { "\($0)°C" } ?? "нет данных"),
            "Лимит в контроллере: " + (s.limit.map { "\($0)%" } ?? "нет данных"),
        ]
        if !s.onAC {
            lines.append("Работы от батареи: " + (lastMinutes.map { "\($0 / 60) ч \($0 % 60) мин" } ?? "оценивается"))
        }
        for line in lines {
            if line.isEmpty { menu.addItem(.separator()); continue }
            menu.addItem(infoItem(line))
        }

        menu.addItem(.separator())
        menu.addItem(submenu("Лимит заряда: \(t.limit)%", [70, 75, 80, 85, 90, 95, 100], t.limit, "%", tag: 0) { _ in true })
        menu.addItem(submenu("Пауза при нагреве от: \(t.hot)°C", [35, 38, 40, 42, 45], t.hot, "°C", tag: 1) { $0 > t.cool })
        menu.addItem(submenu("Возобновить ниже: \(t.cool)°C", [30, 32, 35, 38, 40], t.cool, "°C", tag: 2) { $0 < t.hot })

        let show = NSMenuItem(title: "Показывать рядом со значком", action: nil, keyEquivalent: "")
        show.submenu = NSMenu()
        for m in TitleMode.allCases {
            let mi = NSMenuItem(title: m.label, action: #selector(pickMode(_:)), keyEquivalent: "")
            mi.target = self
            mi.representedObject = m.rawValue
            mi.state = m == mode ? .on : .off
            show.submenu?.addItem(mi)
        }
        menu.addItem(show)

        menu.addItem(.separator())
        for (title, sel) in [("Переустановить службу", #selector(installService)), ("Удалить службу", #selector(uninstallService))] {
            let mi = NSMenuItem(title: title, action: sel, keyEquivalent: "")
            mi.target = self
            menu.addItem(mi)
        }
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Закрыть", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    // tag: 0 limit, 1 hot, 2 cool. Values failing `allowed` are shown disabled.
    func submenu(_ title: String, _ values: [Int], _ current: Int, _ unit: String, tag: Int, allowed: (Int) -> Bool) -> NSMenuItem {
        let parent = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        parent.submenu = NSMenu()
        parent.submenu?.autoenablesItems = false
        for v in values {
            let mi = NSMenuItem(title: "\(v)\(unit)", action: #selector(pickThreshold(_:)), keyEquivalent: "")
            mi.target = self
            mi.tag = tag * 1000 + v
            mi.state = v == current ? .on : .off
            mi.isEnabled = allowed(v)
            parent.submenu?.addItem(mi)
        }
        return parent
    }

    @objc func pickThreshold(_ sender: NSMenuItem) {
        var t = Thresholds.read()
        let v = sender.tag % 1000
        switch sender.tag / 1000 {
        case 0: t.limit = v
        case 1: t.hot = v
        default: t.cool = v
        }
        if !t.write() {
            let a = NSAlert()
            a.messageText = "Не удалось сохранить пороги"
            a.informativeText = "Нет доступа к файлу \(confPath). Переустановите службу через меню BatteryGuard."
            a.runModal()
        }
        refresh()
    }

    @objc func pickMode(_ sender: NSMenuItem) {
        mode = TitleMode(rawValue: sender.representedObject as? String ?? "") ?? .percent
        refresh()
    }
}

let app = NSApplication.shared
let delegate = App()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
