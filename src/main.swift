// BatteryGuard: menu bar app that installs the battery-guard service and shows its state.
import AppKit
import IOKit.ps

let installDir = "/usr/local/battery-guard"
let smcPath = installDir + "/smcctl"
let hotFlag = "/var/run/battery-guard.hot"
let confPath = installDir + "/thresholds"
let resDir = Bundle.main.resourcePath ?? ""
// Hash of the service files bundled in the app (see build.sh), not the app version:
// the service is reinstalled only when those files change. nil in a bundle without it.
let serviceVersion = (try? String(contentsOfFile: resDir + "/version", encoding: .utf8))?
    .trimmingCharacters(in: .whitespacesAndNewlines)

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
            + " with prompt \(lit(L(.prompt))) with administrator privileges"
        var err: NSDictionary?
        NSAppleScript(source: src)?.executeAndReturnError(&err)
        guard let e = err else { return nil }
        if (e[NSAppleScript.errorNumber] as? Int) == -128 { return nil }
        return e[NSAppleScript.errorMessage] as? String ?? L(.unknownError)
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

// Same keys, defaults and validation as battery-guard.sh, so the menu shows what the service uses.
struct Thresholds {
    var limit = 80, hot = 40, cool = 35

    static func read() -> Thresholds {
        var t = Thresholds()
        guard let text = try? String(contentsOfFile: confPath, encoding: .utf8) else { return t }
        func val(_ key: String, _ lo: Int, _ hi: Int, _ def: Int) -> Int {
            for line in text.split(separator: "\n") {
                let kv = line.split(separator: "=", omittingEmptySubsequences: false)  // like awk -F=: field 2
                guard kv.count >= 2, kv[0] == key else { continue }
                let s = kv[1].filter { !$0.isWhitespace }
                guard (1...3).contains(s.count), s.allSatisfy({ $0.isASCII && $0.isNumber }), let v = Int(s) else { return def }
                return (lo...hi).contains(v) ? v : def
            }
            return def
        }
        t.limit = val("LIMIT", 50, 100, 80)
        t.hot = val("HOT", 30, 60, 40)
        t.cool = val("COOL", 25, 59, 35)
        if t.cool >= t.hot { t.cool = t.hot - 5 }
        return t
    }

    // The directory is root-owned, so no temp file + rename: overwrite in place with a
    // fixed-width text, so the service never reads an empty or truncated file.
    func write() -> Bool {
        let text = String(format: "LIMIT=%03d\nHOT=%03d\nCOOL=%03d\n", limit, hot, cool)
        guard let fh = FileHandle(forWritingAtPath: confPath) else { return false }
        defer { fh.closeFile() }
        let data = Data(text.utf8)
        fh.write(data)
        fh.truncateFile(atOffset: UInt64(data.count))
        return true
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
        case .none: return L(.modeNone)
        case .percent: return L(.modePercent)
        case .temp: return L(.modeTemp)
        case .time: return L(.modeTime)
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
        // A newly launched copy (e.g. an updated app) replaces the one already running.
        if let id = Bundle.main.bundleIdentifier {
            for other in NSRunningApplication.runningApplications(withBundleIdentifier: id)
            where other.processIdentifier != getpid() { other.terminate() }
        }
        menu.delegate = self
        item.menu = menu
        refresh()
        Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in self.refresh() }
        DispatchQueue.main.async { self.offerInstall() }
    }

    // On first launch, or when the bundled service files differ from the installed ones.
    func offerInstall() {
        let installed = Service.installedVersion
        guard let bundled = serviceVersion, installed != bundled else { return }
        guard Service.supported else {
            _ = alert(L(.unsupportedTitle), L(.unsupportedText), [L(.ok)])
            NSApp.terminate(nil)
            return
        }
        let title = installed == nil ? L(.installTitle) : L(.updateTitle)
        let r = alert(title, L(.installText), [L(.installButton), L(.later)])
        if r == .alertFirstButtonReturn { installService() }
    }

    @objc func installService() {
        if let e = Service.runPrivileged("install") { _ = alert(L(.installFailed), e, [L(.ok)]) }
        refresh()
    }

    @objc func uninstallService() {
        let r = alert(L(.uninstallTitle), L(.uninstallText), [L(.uninstallButton), L(.cancel)])
        guard r == .alertFirstButtonReturn else { return }
        if let e = Service.runPrivileged("uninstall") { _ = alert(L(.uninstallFailed), e, [L(.ok)]) }
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
        let chargeText = L(.charge) + ": " + (s.percent.map { "\($0)%" } ?? L(.noData))
        let tempText = L(.batteryTemp) + ": " + (s.temp.map { "\($0)°C" } ?? L(.noData))
        var tip = [chargeText, tempText]
        if !s.serviceRunning { tip.append(L(.tipNotRunning)) } else if s.hot { tip.append(L(.tipPaused)) }
        item.button?.toolTip = tip.joined(separator: "\n")
        switch mode {
        case .none: item.button?.title = ""
        case .percent: item.button?.title = s.percent.map { " \($0)%" } ?? ""
        case .temp: item.button?.title = s.temp.map { " \($0)°" } ?? ""
        case .time:
            if s.onAC { item.button?.title = "" }
            else { item.button?.title = lastMinutes.map { " \($0 / 60):" + String(format: "%02d", $0 % 60) } ?? " -:--" }
        }

        let power: String
        if !s.onAC { power = L(.onBattery) }
        else if s.charging { power = L(.acCharging) }
        else { power = L(.acNotCharging) }

        menu.removeAllItems()
        guard Service.installedVersion != nil else {
            menu.addItem(infoItem(L(.service) + ": " + L(.notInstalled)))
            let inst = NSMenuItem(title: L(.installService), action: #selector(installService), keyEquivalent: "")
            inst.target = self
            menu.addItem(inst)
            menu.addItem(.separator())
            menu.addItem(languageMenu())
            menu.addItem(NSMenuItem(title: L(.quit), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
            return
        }
        var lines = [
            L(.service) + ": " + (s.serviceRunning ? L(.running) : L(.notRunning)),
            L(.mode) + ": " + (s.hot ? L(.modeHeat) : L(.modeNormal)),
            "",
            chargeText + ", " + power,
            tempText,
            L(.controllerLimit) + ": " + (s.limit.map { "\($0)%" } ?? L(.noData)),
        ]
        if !s.onAC {
            lines.append(L(.runtime) + ": " + (lastMinutes.map { L(.hoursMinutes, $0 / 60, $0 % 60) } ?? L(.estimating)))
        }
        for line in lines {
            if line.isEmpty { menu.addItem(.separator()); continue }
            menu.addItem(infoItem(line))
        }

        menu.addItem(.separator())
        menu.addItem(submenu(L(.chargeLimit) + ": \(t.limit)%", [70, 75, 80, 85, 90, 95, 100], t.limit, "%", tag: 0) { _ in true })
        menu.addItem(submenu(L(.pauseAbove) + ": \(t.hot)°C", [35, 38, 40, 42, 45], t.hot, "°C", tag: 1) { $0 > t.cool })
        menu.addItem(submenu(L(.resumeBelow) + ": \(t.cool)°C", [30, 32, 35, 38, 40], t.cool, "°C", tag: 2) { $0 < t.hot })

        let show = NSMenuItem(title: L(.showNext), action: nil, keyEquivalent: "")
        show.submenu = NSMenu()
        for m in TitleMode.allCases {
            let mi = NSMenuItem(title: m.label, action: #selector(pickMode(_:)), keyEquivalent: "")
            mi.target = self
            mi.representedObject = m.rawValue
            mi.state = m == mode ? .on : .off
            show.submenu?.addItem(mi)
        }
        menu.addItem(show)
        menu.addItem(languageMenu())

        menu.addItem(.separator())
        for (title, sel) in [(L(.reinstall), #selector(installService)), (L(.removeService), #selector(uninstallService))] {
            let mi = NSMenuItem(title: title, action: sel, keyEquivalent: "")
            mi.target = self
            menu.addItem(mi)
        }
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: L(.quit), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
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
            a.messageText = L(.saveFailed)
            a.informativeText = L(.saveFailedText, confPath)
            a.runModal()
        }
        refresh()
    }

    // "Language" is kept in the title so a user who picked an unfamiliar language can find the way back.
    func languageMenu() -> NSMenuItem {
        let parent = NSMenuItem(title: L(.language) + (Lang.current == .en ? "" : " (Language)"), action: nil, keyEquivalent: "")
        parent.submenu = NSMenu()
        let options: [(String, String?)] = [(L(.systemLanguage), nil)] + Lang.allCases.map { ($0.nativeName, $0.rawValue) }
        for (i, (title, code)) in options.enumerated() {
            let mi = NSMenuItem(title: title, action: #selector(pickLanguage(_:)), keyEquivalent: "")
            mi.target = self
            mi.representedObject = code
            mi.state = Lang.chosen?.rawValue == code ? .on : .off
            parent.submenu?.addItem(mi)
            if i == 0 { parent.submenu?.addItem(.separator()) }
        }
        return parent
    }

    @objc func pickLanguage(_ sender: NSMenuItem) {
        Lang.chosen = (sender.representedObject as? String).flatMap(Lang.init(rawValue:))
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
