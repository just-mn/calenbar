import Foundation

/// Centralised localization. Language is detected once at launch from system preferences.
/// Supports English, Russian, and Simplified Chinese.
enum Str {

    private static let lang: String = {
        let preferred = Locale.preferredLanguages.first ?? "en"
        if preferred.lowercased().hasPrefix("zh") { return "zh" }
        if preferred.lowercased().hasPrefix("ru") { return "ru" }
        return "en"
    }()

    private static func pick(en: String, ru: String, zh: String) -> String {
        switch lang {
        case "ru": return ru
        case "zh": return zh
        default:   return en
        }
    }

    // MARK: - Common menu items

    static let settingsMenuItem = pick(en: "Settings…",      ru: "Настройки…",      zh: "设置…")
    static let quit             = pick(en: "Quit",           ru: "Выйти",           zh: "退出")

    // MARK: - Event menu

    static let dismissNotification   = pick(en: "Dismiss Notification",  ru: "Закрыть уведомление", zh: "关闭通知")
    static let openInCalendar        = pick(en: "Open in Calendar →",    ru: "Открыть в Календаре →", zh: "在日历中打开 →")
    static let defaultEventTitle     = pick(en: "Event",                 ru: "Событие",             zh: "事件")

    static func startsIn(_ countdown: String) -> String {
        pick(en: "Starts in \(countdown)",
             ru: "Начинается через \(countdown)",
             zh: "距开始还有 \(countdown)")
    }

    static func runningEndsIn(_ countdown: String) -> String {
        pick(en: "Running · Ends in \(countdown)",
             ru: "Идёт · До конца: \(countdown)",
             zh: "进行中 · 剩余：\(countdown)")
    }

    static let eventEnded = pick(en: "Ended", ru: "Завершилось", zh: "已结束")

    // MARK: - Reminder menu

    static let defaultReminderTitle = pick(en: "Reminder",              ru: "Напоминание",          zh: "提醒事项")
    static let snoozeMenu           = pick(en: "Snooze",                ru: "Отложить",             zh: "稍后提醒")
    static let markDone             = pick(en: "✓ Done",                ru: "✓ Выполнено",          zh: "✓ 完成")
    static let openInReminders      = pick(en: "Open in Reminders →",   ru: "Открыть в Напоминаниях →", zh: "在提醒事项中打开 →")
    static let noDueDate            = pick(en: "No due date",           ru: "Срок не указан",       zh: "未设截止日期")

    static func overdueBy(_ elapsed: String, time: String) -> String {
        pick(en: "Overdue by \(elapsed) · \(time)",
             ru: "Просрочено на \(elapsed) · \(time)",
             zh: "已过期 \(elapsed) · \(time)")
    }

    static func dueToday(_ time: String) -> String {
        pick(en: "Due: today \(time)",
             ru: "Срок: сегодня \(time)",
             zh: "截止：今天 \(time)")
    }

    static func dueDate(_ dateStr: String) -> String {
        pick(en: "Due: \(dateStr)",
             ru: "Срок: \(dateStr)",
             zh: "截止：\(dateStr)")
    }

    static func reminderCount(_ n: Int) -> String {
        pick(en: "\(n) reminders",
             ru: "\(n) напом.",
             zh: "\(n) 提醒")
    }

    // MARK: - Snooze labels

    static func snoozeLabel(minutes: Int) -> String {
        switch minutes {
        case 1:
            return pick(en: "1 minute",  ru: "1 минута",  zh: "1 分钟")
        case 2...59:
            return pick(en: "\(minutes) minutes", ru: "\(minutes) минут", zh: "\(minutes) 分钟")
        case 60:
            return pick(en: "1 hour",    ru: "1 час",     zh: "1 小时")
        case 120:
            return pick(en: "2 hours",   ru: "2 часа",    zh: "2 小时")
        default:
            if minutes % 60 == 0 {
                let h = minutes / 60
                return pick(en: "\(h) hours", ru: "\(h) часов", zh: "\(h) 小时")
            }
            return pick(en: "\(minutes) min", ru: "\(minutes) мин", zh: "\(minutes) 分钟")
        }
    }

    // MARK: - Settings tabs

    static let tabGeneral     = pick(en: "General",     ru: "Основные",      zh: "通用")
    static let tabAppearance  = pick(en: "Appearance",  ru: "Вид",           zh: "外观")
    static let tabCalendars   = pick(en: "Calendars",   ru: "Календари",     zh: "日历")
    static let tabReminders   = pick(en: "Reminders",   ru: "Напоминания",   zh: "提醒事项")
    static let tabSnooze      = pick(en: "Snooze",      ru: "Откладывание",  zh: "稍后提醒")
    static let settingsTitle  = pick(en: "CalendarBar Settings", ru: "Настройки CalendarBar", zh: "CalendarBar 设置")

    // MARK: - Settings — General

    static let flashEnabled       = pick(en: "Flash icon",                 ru: "Мигание иконки",                  zh: "闪烁图标")
    static let flashDuration      = pick(en: "Duration:",                  ru: "Длительность:",                   zh: "时长：")
    static let flashSpeed         = pick(en: "Speed:",                     ru: "Скорость:",                       zh: "速度：")
    static let flashSpeedFast     = pick(en: "Fast",                       ru: "Быстро",                          zh: "快")
    static let flashSpeedMedium   = pick(en: "Medium",                     ru: "Средне",                          zh: "中")
    static let flashSpeedSlow     = pick(en: "Slow",                       ru: "Медленно",                        zh: "慢")
    static let soundEnabled       = pick(en: "Sound notification",         ru: "Звуковое уведомление",            zh: "声音通知")
    static let soundLabel         = pick(en: "Sound:",                     ru: "Звук:",                           zh: "声音：")
    static let soundTest          = pick(en: "▶ Test",                     ru: "▶ Тест",                          zh: "▶ 测试")
    static let showNoAlarmEvents  = pick(en: "Show events without reminders (while in progress)",
                                         ru: "Показывать события без напоминаний (во время события)",
                                         zh: "显示无提醒的事件（进行中）")
    static let launchAtLogin      = pick(en: "Launch at login",            ru: "Запускать при входе",             zh: "登录时启动")
    static let sectionFlash       = pick(en: "Flash",                      ru: "Мигание",                         zh: "闪烁")
    static let sectionSound       = pick(en: "Sound",                      ru: "Звук",                            zh: "声音")
    static let sectionEvents      = pick(en: "Events",                     ru: "События",                         zh: "事件")
    static let sectionLaunch      = pick(en: "Launch",                     ru: "Запуск",                          zh: "启动")

    // MARK: - Settings — Appearance

    static let displayModeSection = pick(en: "Display Mode",               ru: "Режим отображения",               zh: "显示模式")
    static let colorUpcoming      = pick(en: "Color — Upcoming events",    ru: "Цвет — предстоящие события",      zh: "颜色 — 即将发生的事件")
    static let colorOverdue       = pick(en: "Color — Overdue reminders",  ru: "Цвет — просроченные напоминания", zh: "颜色 — 过期提醒")
    static let colorText          = pick(en: "Text:",                      ru: "Текст:",                          zh: "文字：")
    static let colorBg            = pick(en: "Background:",                ru: "Фон:",                            zh: "背景：")
    static let colorExample       = pick(en: "Example",                    ru: "Пример",                          zh: "示例")
    static let displayAutoNote    = pick(en: "Compact when both event and reminder are visible.",
                                         ru: "Компактный когда одновременно видны событие и напоминание.",
                                         zh: "当事件和提醒同时显示时使用紧凑模式。")
    static let displayInfoNote    = pick(en: "Always shows name and timer.",
                                         ru: "Всегда показывает название и таймер.",
                                         zh: "始终显示名称和计时器。")
    static let displayCompactNote = pick(en: "Icon only; details in menu.",
                                         ru: "Только иконка, подробности в меню.",
                                         zh: "仅显示图标，详情在菜单中查看。")
    static let previewLabel       = pick(en: "Preview:",        ru: "Превью:",         zh: "预览：")
    static let exampleEventName   = pick(en: "Meeting",        ru: "Встреча",         zh: "会议")

    // MARK: - Settings — Calendars / Reminders

    static let calendarsTrack     = pick(en: "Track events from:",                   ru: "Отслеживать события из:",                      zh: "跟踪以下日历的事件：")
    static let calendarsHint      = pick(en: "Leave all unchecked to track every calendar.",
                                         ru: "Оставьте всё снятым, чтобы отслеживать все календари.",
                                         zh: "全部不选则跟踪所有日历。")
    static let remindersTrack     = pick(en: "Track reminders from:",                ru: "Отслеживать напоминания из:",                  zh: "跟踪以下列表的提醒事项：")
    static let remindersHint      = pick(en: "Leave all unchecked to track every list.",
                                         ru: "Оставьте всё снятым, чтобы отслеживать все списки.",
                                         zh: "全部不选则跟踪所有列表。")
    static let noCalendarsMsg     = pick(en: "No calendars available.\nCheck access in System Settings → Privacy.",
                                         ru: "Нет доступных календарей.\nПроверьте доступ в Системных настройках → Конфиденциальность.",
                                         zh: "没有可用的日历。\n请在系统设置 → 隐私中检查访问权限。")
    static let noRemindersMsg     = pick(en: "No reminder lists available.\nCheck access in System Settings → Privacy.",
                                         ru: "Нет доступных списков напоминаний.\nПроверьте доступ в Системных настройках → Конфиденциальность.",
                                         zh: "没有可用的提醒列表。\n请在系统设置 → 隐私中检查访问权限。")

    // MARK: - Settings — Snooze

    static let snoozeSectionTitle = pick(en: "Snooze Options",               ru: "Варианты откладывания",               zh: "稍后提醒选项")
    static let snoozeHint         = pick(en: "Values in minutes. Shown in reminder menu.",
                                         ru: "Значения в минутах. Отображаются в меню напоминания.",
                                         zh: "以分钟为单位。显示在提醒菜单中。")
    static let snoozeAddPlaceholder = pick(en: "Minutes",                    ru: "Минуты",                              zh: "分钟")
    static let snoozeAdd          = pick(en: "Add",                          ru: "Добавить",                            zh: "添加")
    static let snoozeErrorNotNum  = pick(en: "Enter a number > 0",           ru: "Введите число > 0",                   zh: "请输入大于 0 的数字")

    // MARK: - Onboarding

    static let permissionManualHint = pick(
        en: "If the permission dialog didn't appear, you may need to enable access manually.",
        ru: "Если диалог разрешения не появился, включите доступ вручную в Системных настройках.",
        zh: "如果权限对话框未出现，您可能需要在系统设置中手动启用访问权限。"
    )
    static let openSystemSettings = pick(en: "Open System Settings",
                                         ru: "Открыть Системные настройки",
                                         zh: "打开系统设置")

    static let onboardingSubtitle = pick(en: "Your events and reminders — always at hand in the menu bar.\n\nFlashing icon and sound will notify you when it's time to act.",
                                         ru: "Ваши события и напоминания — всегда под рукой в строке меню.\n\nМигание иконки и звук дадут знать, когда пора действовать.",
                                         zh: "您的日历事件和提醒 — 随时显示在菜单栏中。\n\n图标闪烁和声音将在需要时提醒您。")
    static let back               = pick(en: "Back",                         ru: "Назад",                               zh: "返回")
    static let next               = pick(en: "Next",                         ru: "Далее",                               zh: "下一步")
    static let done               = pick(en: "Done",                         ru: "Готово",                              zh: "完成")
    static let accessGranted      = pick(en: "Access granted",               ru: "Доступ разрешён",                     zh: "已授权")
    static let allowAccess        = pick(en: "Allow Access",                 ru: "Разрешить доступ",                    zh: "允许访问")
    static let calendarPermTitle  = pick(en: "Calendar Access",              ru: "Доступ к Календарю",                  zh: "访问日历")
    static let calendarPermDesc   = pick(en: "CalendarBar needs access to Calendar to track your events and their reminders.",
                                         ru: "CalendarBar нужен доступ к Календарю, чтобы видеть ваши события и их напоминания.",
                                         zh: "CalendarBar 需要访问日历以跟踪您的事件和提醒。")
    static let reminderPermTitle  = pick(en: "Reminders Access",             ru: "Доступ к Напоминаниям",               zh: "访问提醒事项")
    static let reminderPermDesc   = pick(en: "CalendarBar needs access to Reminders to display your tasks in the menu bar.",
                                         ru: "CalendarBar нужен доступ к Напоминаниям, чтобы показывать задачи прямо в строке меню.",
                                         zh: "CalendarBar 需要访问提醒事项以在菜单栏中显示您的任务。")
    static let pickCalendarsTitle = pick(en: "Select Calendars",             ru: "Выберите календари",                  zh: "选择日历")
    static let pickCalendarsHint  = pick(en: "Leave all unchecked to track every calendar.",
                                         ru: "Если ничего не выбрать — будут отслеживаться все.",
                                         zh: "全部不选则跟踪所有日历。")
    static let alertStyleTitle    = pick(en: "Notification Style",           ru: "Стиль уведомлений",                   zh: "通知样式")
    static let alertColorsNote    = pick(en: "Customize colors in Settings → Appearance",
                                         ru: "Настроить цвета можно в Настройках → Вид",
                                         zh: "可在设置 → 外观中自定义颜色")
    static let previewStepTitle   = pick(en: "Here's how it looks",          ru: "Вот как это выглядит",                zh: "效果预览")
    static let previewStepSubtitle = pick(en: "This is how the icon appears in your menu bar.",
                                          ru: "Так иконка будет появляться в строке меню.",
                                          zh: "图标将以此方式显示在菜单栏中。")
    static let playSoundButton    = pick(en: "▶ Play sound",                 ru: "▶ Воспроизвести звук",                zh: "▶ 播放声音")
    static let changeInSettings   = pick(en: "All of this can be changed in Settings",
                                         ru: "Всё это можно изменить в Настройках",
                                         zh: "这些都可以在设置中更改")

    // MARK: - Event time range

    static func durationMinutes(_ n: Int) -> String {
        pick(en: "\(n) min", ru: "\(n) мин", zh: "\(n) 分钟")
    }

    // MARK: - Test mode scenarios (used by TestModeManager)

    static let testScenarioUpcoming   = pick(en: "Event in 10 minutes",          ru: "Событие через 10 минут",          zh: "10 分钟后的事件")
    static let testScenarioInProgress = pick(en: "Event in progress",            ru: "Событие идёт сейчас",             zh: "进行中的事件")
    static let testScenarioOverlap    = pick(en: "Two overlapping events",       ru: "Два пересекающихся события",      zh: "两个重叠事件")
    static let testScenarioReminder   = pick(en: "One overdue reminder",         ru: "Одно просроченное напоминание",   zh: "一个过期提醒")
    static let testScenarioMultiRem   = pick(en: "Three reminders",              ru: "Три напоминания",                 zh: "三个提醒")
    static let testScenarioEverything = pick(en: "Event + reminder",             ru: "Событие + напоминание",           zh: "事件 + 提醒")

    // MARK: - Demo event/reminder titles for onboarding

    static let demoEventTeamCall     = pick(en: "Team Call",                     ru: "Созвон с командой",               zh: "团队会议")
    static let demoEventDesignSync   = pick(en: "Design Sync",                   ru: "Синк с дизайнерами",              zh: "设计同步会议")
    static let demoEventDailyStandup = pick(en: "Daily Standup",                 ru: "Daily standup",                   zh: "每日站会")
    static let demoEventOneOnOne     = pick(en: "1-on-1 with Manager",           ru: "1-on-1 с менеджером",             zh: "1对1 管理层会议")
    static let demoEventClientMeeting = pick(en: "Client Meeting",               ru: "Встреча с клиентом",              zh: "客户会议")
    
    static let demoReminderCallBank  = pick(en: "Call the Bank",                 ru: "Позвонить в банк",                zh: "给银行打电话")
    static let demoReminderPayBill   = pick(en: "Pay the Bill",                  ru: "Оплатить счёт",                   zh: "支付账单")
    static let demoReminderBuyGroceries = pick(en: "Buy Groceries",              ru: "Купить продукты",                 zh: "购买杂货")
    static let demoReminderWriteReport = pick(en: "Write Report",                ru: "Написать отчёт",                  zh: "编写报告")
    static let demoReminderPreparePresentation = pick(en: "Prepare Presentation", ru: "Подготовить презентацию",       zh: "准备演示文稿")

    // MARK: - Onboarding welcome / new steps

    static let welcomeTitle    = pick(en: "Welcome to CalenBar",     ru: "Добро пожаловать в CalenBar", zh: "欢迎使用 CalenBar")
    static let soundToggleShort = pick(en: "Sound",                     ru: "Звук",                            zh: "声音")
    static let skip            = pick(en: "Skip",                       ru: "Пропустить",                      zh: "跳过")

    static let inProgressTitle  = pick(en: "Events in Progress",        ru: "Текущие события",                 zh: "进行中的事件")
    static let inProgressDesc   = pick(en: "Show events that are currently happening — even if they have no reminder set.",
                                       ru: "Показывать события, которые идут прямо сейчас — даже без напоминания.",
                                       zh: "显示正在进行的事件，即使没有设置提醒。")
    static let inProgressToggle = pick(en: "Show in-progress events without reminders",
                                       ru: "Показывать текущие события без напоминаний",
                                       zh: "显示无提醒的进行中事件")

    static let demoEventTitle   = pick(en: "Try It: Dismiss an Event",  ru: "Попробуйте: уберите событие",     zh: "试一试：关闭事件")
    static let demoEventDesc    = pick(en: "An event alert just appeared in your menu bar. Click it and tap \"Dismiss Notification\".",
                                       ru: "Алерт события появился в строке меню. Нажмите на него и выберите «Закрыть уведомление».",
                                       zh: "事件提醒已出现在菜单栏。点击它选择「关闭通知」。")
    static let demoEventHint    = pick(en: "Dismissing only hides the notification — the event stays in Calendar.",
                                       ru: "Уведомление скроется, но событие останется в Календаре.",
                                       zh: "关闭只隐藏通知，事件仍保留在日历中。")
    static let demoEventDone    = pick(en: "Done! The notification is dismissed.",
                                       ru: "Готово! Уведомление скрыто.",
                                       zh: "完成！通知已关闭。")

    static let demoReminderTitle = pick(en: "Try It: Act on a Reminder", ru: "Попробуйте: обработайте напоминание", zh: "试一试：处理提醒")
    static let demoReminderDesc  = pick(en: "A reminder just appeared. Click it and choose Snooze or Mark Done.",
                                        ru: "Напоминание появилось в строке меню. Нажмите на него и выберите «Отложить» или «Выполнено».",
                                        zh: "提醒已出现。点击它选择「稍后提醒」或「完成」。")
    static let demoReminderHint  = pick(en: "Unlike events, reminders can't be dismissed — you must snooze or complete them.",
                                        ru: "В отличие от событий, напоминания нельзя просто закрыть — нужно отложить или выполнить.",
                                        zh: "与事件不同，提醒必须推迟或完成，不能直接关闭。")
    static let demoReminderDone  = pick(en: "Done! Great job.",          ru: "Готово! Отлично.",                zh: "完成！做得好。")
    static let demoReminderSkip  = pick(en: "Reminders access not granted — this demo is skipped.",
                                        ru: "Доступ к Напоминаниям не разрешён — демо пропущено.",
                                        zh: "未授予提醒访问权限，跳过此演示。")

    static let allDoneTitle      = pick(en: "You're All Set!",           ru: "Всё готово!",                    zh: "一切就绪！")
    static let allDoneDesc       = pick(en: "CalendarBar will keep your events and reminders visible right in the menu bar.",
                                        ru: "CalendarBar будет показывать события и напоминания прямо в строке меню.",
                                        zh: "CalendarBar 将在菜单栏中持续显示您的事件和提醒。")

    // MARK: - Flash duration options

    static let flashForever = pick(en: "Always",     ru: "Постоянно",    zh: "持续")
    static let flash30sec   = pick(en: "30 seconds", ru: "30 секунд",    zh: "30 秒")
    static let flash1min    = pick(en: "1 minute",   ru: "1 минута",     zh: "1 分钟")
    static let flash2min    = pick(en: "2 minutes",  ru: "2 минуты",     zh: "2 分钟")
    static let flash5min    = pick(en: "5 minutes",  ru: "5 минут",      zh: "5 分钟")

    // MARK: - Display mode names

    static let modeAutomatic   = pick(en: "Automatic",   ru: "Автоматический",  zh: "自动")
    static let modeInformative = pick(en: "Informative", ru: "Информативный",   zh: "详细")
    static let modeCompact     = pick(en: "Compact",     ru: "Компактный",      zh: "紧凑")

    // MARK: - Color preset names

    static let colorOrange = pick(en: "Orange",       ru: "Оранжевый",   zh: "橙色")
    static let colorRed    = pick(en: "Red",          ru: "Красный",     zh: "红色")
    static let colorBlue   = pick(en: "Blue",         ru: "Синий",       zh: "蓝色")
    static let colorGreen  = pick(en: "Green",        ru: "Зелёный",     zh: "绿色")
    static let colorPink   = pick(en: "Pink",         ru: "Розовый",     zh: "粉色")
    static let colorCustom = pick(en: "Custom",       ru: "Свой цвет",   zh: "自定义")

    // MARK: - Bug Report / About

    static let tabAbout         = pick(en: "About",             ru: "О программе",        zh: "关于")
    static let aboutDescription = pick(en: "CalendarBar keeps your Calendar events and Reminders always visible in the macOS menu bar.",
                                       ru: "CalendarBar держит события из Календаря и Напоминания всегда на виду в строке меню macOS.",
                                       zh: "CalendarBar 在 macOS 菜单栏中持续显示您的日历事件和提醒。")
    static let reportBug        = pick(en: "Report a Bug",      ru: "Сообщить об ошибке", zh: "报告错误")
    static let viewOnGitHub     = pick(en: "View on GitHub",    ru: "Открыть на GitHub",  zh: "在 GitHub 上查看")
    static let bugReportTitle   = pick(en: "Report a Bug",      ru: "Отправить баг-репорт", zh: "报告错误")
    static let bugReportDesc    = pick(en: "This will collect system information and recent logs (without sensitive data like event titles) and open GitHub to create an issue.",
                                       ru: "Будет собрана информация о системе и последние логи (без чувствительных данных вроде названий событий), затем откроется GitHub для создания issue.",
                                       zh: "这将收集系统信息和最近的日志（不包含事件标题等敏感数据），并打开 GitHub 创建问题报告。")
    static let generating       = pick(en: "Generating…",       ru: "Создание…",          zh: "生成中…")
    static let bugReportSuccess = pick(en: "Bug report generated. Opening GitHub…",
                                       ru: "Баг-репорт создан. Открываю GitHub…",
                                       zh: "错误报告已生成。正在打开 GitHub…")
    static let bugReportError   = pick(en: "Error generating report",
                                       ru: "Ошибка при создании репорта",
                                       zh: "生成报告时出错")
    static let close            = pick(en: "Close",             ru: "Закрыть",            zh: "关闭")
    static let cancel           = pick(en: "Cancel",            ru: "Отмена",             zh: "取消")
    static let generate         = pick(en: "Generate Report",   ru: "Создать репорт",     zh: "生成报告")
}
