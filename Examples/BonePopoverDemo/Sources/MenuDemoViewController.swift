import UIKit
import BonePopoverKit

/// 场景 23：从真实按钮展开，底部按钮会触发向上翻转。
final class MenuDemoViewController: UIViewController {
    private let materialControl = UISegmentedControl(items: ["自动", "纯色", "毛玻璃"])
    private let resultLabel = UILabel()
    private weak var currentMenu: BoneMenuView?
    private var isFavorite = true

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "按钮旁菜单"
        navigationItem.largeTitleDisplayMode = .never
        view.backgroundColor = .systemGroupedBackground
        view.accessibilityIdentifier = "menu-screen"

        let introduction = UILabel()
        introduction.text = "点按按钮，操作就在手边展开。\n底部空间不足时，菜单会自动翻到上方。"
        introduction.font = .preferredFont(forTextStyle: .body)
        introduction.textColor = .secondaryLabel
        introduction.numberOfLines = 0
        introduction.adjustsFontForContentSizeCategory = true

        materialControl.selectedSegmentIndex = 0
        materialControl.accessibilityIdentifier = "menu-material"
        materialControl.addAction(UIAction { [weak self] _ in self?.applyMaterial() }, for: .valueChanged)

        let topButton = makeButton("更多操作", symbol: "ellipsis.circle", identifier: "menu-anchor-top") { [weak self] button in
            self?.showMenu(from: button)
        }
        let bottomButton = makeButton("底部按钮", symbol: "ellipsis.circle", identifier: "menu-anchor-bottom") { [weak self] button in
            self?.showMenu(from: button)
        }
        let longButton = makeButton("打开长菜单", symbol: "list.bullet", identifier: "menu-long") { [weak self] button in
            self?.showMenu(from: button, long: true)
        }

        resultLabel.text = "选择一项操作，结果会显示在这里。"
        resultLabel.font = .preferredFont(forTextStyle: .body)
        resultLabel.textColor = .secondaryLabel
        resultLabel.numberOfLines = 0
        resultLabel.textAlignment = .center
        resultLabel.adjustsFontForContentSizeCategory = true
        resultLabel.accessibilityIdentifier = "menu-demo-result"

        let header = UIStackView(arrangedSubviews: [introduction, materialControl])
        header.axis = .vertical
        header.spacing = 20
        for child in [header, topButton, bottomButton, longButton, resultLabel] {
            child.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(child)
        }
        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: safe.topAnchor, constant: 24),
            header.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 24),
            header.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -24),
            topButton.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 24),
            topButton.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 24),
            bottomButton.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -24),
            bottomButton.bottomAnchor.constraint(equalTo: safe.bottomAnchor, constant: -24),
            longButton.centerXAnchor.constraint(equalTo: safe.centerXAnchor),
            longButton.centerYAnchor.constraint(equalTo: safe.centerYAnchor, constant: 40),
            resultLabel.topAnchor.constraint(equalTo: longButton.bottomAnchor, constant: 32),
            resultLabel.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 24),
            resultLabel.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -24)
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        view.accessibilityIdentifier = "menu-screen-ready"
    }

    private func makeButton(_ title: String, symbol: String, identifier: String,
                            action: @escaping (UIButton) -> Void) -> UIButton {
        var configuration = UIButton.Configuration.tinted()
        configuration.title = title
        configuration.image = UIImage(systemName: symbol)
        configuration.imagePadding = 8
        configuration.cornerStyle = .capsule
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 18, bottom: 12, trailing: 18)
        let button = UIButton(configuration: configuration)
        button.accessibilityIdentifier = identifier
        button.addAction(UIAction { [weak button] _ in
            if let button { action(button) }
        }, for: .touchUpInside)
        return button
    }

    private func showMenu(from button: UIButton, long: Bool = false) {
        currentMenu?.dismissPopover(animated: false)
        let menu = BoneMenuView(anchorView: button)
        if long {
            for index in 1...24 {
                menu.addItem(title: "菜单项目 \(index)", icon: UIImage(systemName: "doc.text"),
                             accessibilityIdentifier: "menu-long-\(index)") { [weak self] in
                    self?.resultLabel.text = "已选择：菜单项目 \(index)"
                }
            }
        } else {
            menu.addItem(title: "收藏", icon: UIImage(systemName: "star"),
                         isSelected: isFavorite, inSection: "阅读选项", dismissesPopover: false,
                         accessibilityIdentifier: "menu-favorite") { [weak self, weak menu] in
                guard let self else { return }
                self.isFavorite.toggle()
                menu?.setItemSelected(self.isFavorite, at: IndexPath(row: 0, section: 0))
                self.resultLabel.text = self.isFavorite ? "已收藏" : "已取消收藏"
            }
            menu.addItem(title: "朗读（暂不可用）", icon: UIImage(systemName: "speaker.wave.2"),
                         isEnabled: false, inSection: "阅读选项",
                         accessibilityIdentifier: "menu-disabled") { [weak self] in
                self?.resultLabel.text = "禁用项不应触发"
            }
            menu.addItem(title: "分享", icon: UIImage(systemName: "square.and.arrow.up"),
                         inSection: "项目操作", accessibilityIdentifier: "menu-share") { [weak self] in
                self?.resultLabel.text = "已选择：分享"
            }
            menu.addItem(title: "切换材质", icon: UIImage(systemName: "paintpalette"), style: .highlighted,
                         inSection: "项目操作", dismissesPopover: false,
                         accessibilityIdentifier: "menu-switch-material") { [weak self] in
                guard let self else { return }
                self.materialControl.selectedSegmentIndex = (self.materialControl.selectedSegmentIndex + 1) % 3
                self.applyMaterial()
            }
            menu.addItem(title: "删除", icon: UIImage(systemName: "trash"), style: .destructive,
                         inSection: "项目操作", accessibilityIdentifier: "menu-delete") { [weak self] in
                self?.resultLabel.text = "演示：已删除"
            }
        }
        currentMenu = menu
        applyMaterial()
        menu.baseView.accessibilityIdentifier = "popover-content"
        menu.onDidShow = { [weak menu] in menu?.view.accessibilityIdentifier = "popover-ready" }
        menu.show(from: self)
    }

    private func applyMaterial() {
        guard let menu = currentMenu else { return }
        switch materialControl.selectedSegmentIndex {
        case 1: menu.configuration.appearance.material = .solid
        case 2: menu.configuration.appearance.material = .blur(.systemMaterial)
        default: menu.configuration.appearance.material = .automatic
        }
    }
}
