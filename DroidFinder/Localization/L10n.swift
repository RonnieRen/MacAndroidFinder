import Foundation

// MARK: - L10n
//
// Bilingual (English / Simplified Chinese) static string table. The active
// language is derived from `Locale.preferredLanguages` at call time.

enum L10n {
    static var currentLanguage: AppLanguage {
        let code = Locale.preferredLanguages.first?.lowercased() ?? "en"
        if code.hasPrefix("zh") {
            return .chineseSimplified
        }
        return .english
    }

    static func text(_ english: String, _ chineseSimplified: String) -> String {
        switch currentLanguage {
        case .english:
            return english
        case .chineseSimplified:
            return chineseSimplified
        }
    }

    // MARK: - Status / errors

    static func ready() -> String { text("Ready", "准备就绪") }
    static func adbNotFound() -> String { text("adb not found. Please install Android Platform Tools first.", "未找到 adb。请先安装 Android Platform Tools。") }
    static func parseDirectoryFailed() -> String { text("Failed to parse Android directory listing.", "解析 Android 文件列表失败。") }
    static func downloadFileFailed() -> String { text("File download failed.", "文件下载失败。") }
    static func uploadFileFailed() -> String { text("File upload failed.", "文件上传失败。") }
    static func adbExecuteFailed() -> String { text("adb command failed.", "adb 执行失败。") }
    static func adbTimedOut() -> String { text("adb command timed out.", "adb 命令执行超时。") }
    static func downloadingPercent(_ name: String, _ percent: Int) -> String { text("Downloading \(name)… \(percent)%", "正在下载 \(name)… \(percent)%") }
    static func waiting() -> String { text("Pending", "等待中") }
    static func uploading() -> String { text("Uploading", "上传中") }
    static func completed() -> String { text("Completed", "已完成") }
    static func failed() -> String { text("Failed", "失败") }
    static func uploadDone() -> String { text("Upload completed", "上传完成") }
    static func uploaded(file: String) -> String { text("Uploaded: \(file)", "已上传：\(file)") }
    static func uploadFailed(file: String) -> String { text("Upload failed: \(file)", "上传失败：\(file)") }
    static func loadedItems(_ count: Int) -> String { text("Loaded \(count) item(s)", "已加载 \(count) 项") }
    static func directoryReadFailed() -> String { text("Failed to read directory", "目录读取失败") }
    static func chooseDownloadDirectory() -> String { text("Choose download folder", "选择下载目录") }
    static func downloadedFile(_ name: String) -> String { text("Downloaded: \(name)", "已下载：\(name)") }
    static func downloadedDirectory(_ name: String) -> String { text("Downloaded folder: \(name)", "已下载目录：\(name)") }
    static func downloadFailed() -> String { text("Download failed", "下载失败") }
    static func downloadDirectoryFailed() -> String { text("Folder download failed", "目录下载失败") }
    static func uploadTo(_ remoteDirectory: String) -> String { text("Upload to \(remoteDirectory)", "上传到 \(remoteDirectory)") }
    static func noDevice(_ bridgeInfo: String) -> String { text("No available device (\(bridgeInfo)). Please connect your phone and enable USB debugging.", "没有可用设备（\(bridgeInfo)）。请连接手机并开启 USB 调试。") }
    static func unableToReadDevice() -> String { text("Unable to read devices.", "无法读取设备。") }
    static func adbPath(_ path: String?) -> String {
        text("adb: \(path ?? "not found")", "adb: \(path ?? "未找到")")
    }

    // MARK: - Toolbar / navigation

    static func refreshDevices() -> String { text("Refresh Devices", "刷新设备") }
    static func parentDirectory() -> String { text("Up", "上一级") }
    static func uploadFiles() -> String { text("Upload", "上传文件") }
    static func uploadHere() -> String { text("Upload Here", "上传到当前目录") }
    static func openDirectory() -> String { text("Open Folder", "进入目录") }
    static func downloadFile() -> String { text("Download File", "下载文件") }
    static func downloadDirectory() -> String { text("Download Folder", "下载目录") }
    static func deviceLabel() -> String { text("Device", "设备") }
    static func directoryTree() -> String { text("Directory Tree", "目录树") }
    static func folder() -> String { text("Folder", "文件夹") }
    static func file() -> String { text("File", "文件") }
    static func emptyDirectory() -> String { text("Current directory is empty", "当前目录为空") }
    static func dropToUpload(_ path: String) -> String { text("Drop to upload to: \(path)", "松开即可上传到：\(path)") }
    static func uploadQueue() -> String { text("Upload Queue", "上传队列") }
    static func clearFinished() -> String { text("Clear Finished", "清理已完成") }
    static func close() -> String { text("Close", "关闭") }
    static func loadingErrorTitle() -> String { text("Error", "错误") }
    static func ok() -> String { text("OK", "确定") }
    static func unknownError() -> String { text("Unknown error", "未知错误") }
    static func statusUploading() -> String { text("Uploading…", "上传中…") }
    static func phoneRoot() -> String { text("Phone", "手机") }
    static func cameraRoot() -> String { text("Camera", "相机") }

    // MARK: - Wireless

    static func wirelessConnect() -> String { text("Wireless Connect", "无线连接") }
    static func wirelessConnectTitle() -> String { text("Connect Android Over Wi-Fi", "通过 Wi-Fi 连接 Android") }
    static func usbQuickConnect() -> String { text("USB Quick Connect", "USB 快速连接") }
    static func usbQuickConnectHint() -> String { text("Connect with USB once and then switch to Wi-Fi automatically.", "先通过 USB 连接一次，再自动切换到 Wi-Fi。") }
    static func connectUsingUSB() -> String { text("Connect via USB Device", "使用 USB 设备连接") }
    static func noUSBDeviceSelected() -> String { text("Select a USB-connected device first.", "请先选择一个 USB 连接的设备。") }
    static func nearbyDevices() -> String { text("Nearby Devices", "附近设备") }
    static func discover() -> String { text("Discover", "发现设备") }
    static func noNearbyDevices() -> String { text("No nearby wireless devices found.", "未发现附近无线设备。") }
    static func pairWithCode() -> String { text("Pair with Code", "使用配对码") }
    static func pairEndpoint() -> String { text("Pair Endpoint (IP:PORT)", "配对端点（IP:端口）") }
    static func pairCode() -> String { text("Pair Code", "配对码") }
    static func connectEndpoint() -> String { text("Connect Endpoint (IP:PORT)", "连接端点（IP:端口）") }
    static func pairAndConnect() -> String { text("Pair and Connect", "配对并连接") }
    static func manualConnect() -> String { text("Manual Connect", "手动连接") }
    static func endpoint() -> String { text("Endpoint (IP:PORT)", "端点（IP:端口）") }
    static func connect() -> String { text("Connect", "连接") }
    static func disconnectAll() -> String { text("Disconnect All", "断开全部连接") }
    static func disconnect() -> String { text("Disconnect", "断开连接") }
    static func discoveringWireless() -> String { text("Discovering wireless devices…", "正在发现无线设备…") }
    static func discoveredWirelessCount(_ count: Int) -> String { text("Found \(count) wireless device(s).", "发现 \(count) 个无线设备。") }
    static func connectedEndpoint(_ endpoint: String) -> String { text("Connected: \(endpoint)", "已连接：\(endpoint)") }
    static func pairedEndpoint(_ endpoint: String) -> String { text("Paired: \(endpoint)", "已配对：\(endpoint)") }
    static func disconnectedEndpoint(_ endpoint: String) -> String { text("Disconnected: \(endpoint)", "已断开：\(endpoint)") }
    static func disconnectedAll() -> String { text("Disconnected all wireless devices.", "已断开所有无线设备连接。") }
    static func invalidEndpoint() -> String { text("Please enter endpoint as IP:PORT.", "请输入 IP:端口 格式的端点。") }
    static func invalidPairInput() -> String { text("Please enter pair endpoint, pair code, and connect endpoint.", "请输入配对端点、配对码和连接端点。") }
    static func wifiConnectFromUSBFailedIP() -> String { text("Failed to get phone Wi-Fi IP from USB device.", "无法从 USB 设备获取手机 Wi-Fi IP。") }

    // MARK: - QR pairing

    static func qrPairTitle() -> String { text("Pair by QR Code", "扫码配对") }
    static func qrPairHint() -> String { text("On the phone: Developer options → Wireless debugging → Pair device with QR code.", "手机上：开发者选项 → 无线调试 → 使用二维码配对设备。") }
    static func qrPairStart() -> String { text("Show QR Code", "生成二维码") }
    static func qrWaitingForScan() -> String { text("Waiting for phone to scan…", "等待手机扫码…") }
    static func qrPairing() -> String { text("Pairing…", "正在配对…") }
    static func qrConnecting() -> String { text("Connecting…", "正在连接…") }
    static func qrPairSucceeded(_ endpoint: String) -> String { text("Paired and connected: \(endpoint)", "已配对并连接：\(endpoint)") }
    static func qrPairTimeout() -> String { text("Timed out waiting for the phone to scan.", "等待手机扫码超时。") }
    static func qrConnectEndpointNotFound() -> String { text("Paired, but no connect endpoint was found.", "已配对，但未发现连接端点。") }
    static func retry() -> String { text("Try Again", "重试") }

    // MARK: - Redesign 2026-06 (toolbar / sidebar / table / preview / connect)

    static func searchThisFolder() -> String { text("Search this folder", "搜索当前文件夹") }
    static func sendToPhone() -> String { text("Send to Phone", "传到手机") }
    static func saveToMac() -> String { text("Save to Mac", "保存到 Mac") }
    static func share() -> String { text("Share", "分享") }
    static func listViewLabel() -> String { text("List view", "列表视图") }
    static func gridViewLabel() -> String { text("Grid view", "网格视图") }
    static func quickAccess() -> String { text("Quick Access", "快捷访问") }
    static func qaScreenshots() -> String { text("Screenshots", "截图") }
    static func qaCamera() -> String { text("Camera", "相机") }
    static func qaDownloads() -> String { text("Downloads", "下载") }
    static func qaWeChat() -> String { text("WeChat Files", "微信文件") }
    static func deviceDirectory() -> String { text("Device", "设备目录") }
    static func deviceStorage() -> String { text("Device Storage", "设备存储") }
    static func nameColumn() -> String { text("Name", "名称") }
    static func sizeColumn() -> String { text("Size", "大小") }
    static func modifiedColumn() -> String { text("Modified", "修改时间") }
    static func itemsCount(_ n: Int) -> String { text("\(n) items", "\(n) 个项目") }
    static func selectedSummary(_ n: Int, _ size: String?) -> String {
        if let size { return text("\(n) selected (\(size))", "已选 \(n) 项（\(size)）") }
        return text("\(n) selected", "已选 \(n) 项")
    }
    static func freeSpace(_ s: String) -> String { text("\(s) free", "剩余 \(s)") }
    static func typeLabel() -> String { text("Type", "类型") }
    static func dimensionsLabel() -> String { text("Dimensions", "尺寸") }
    static func sizeLabel() -> String { text("Size", "大小") }
    static func modifiedLabel() -> String { text("Modified", "修改时间") }
    static func imageType(_ ext: String) -> String { text("\(ext) image", "\(ext) 图像") }
    static func fileTypeDesc(_ ext: String) -> String { text("\(ext) file", "\(ext) 文件") }
    static func notConnected() -> String { text("No Device Connected", "未连接设备") }
    static func connectTitle() -> String { text("Connect Your Android Device", "连接你的 Android 设备") }
    static func connectSub() -> String { text("Use a USB cable or wireless pairing — both support two-way transfers.", "用数据线或无线配对，两种方式都支持双向传文件") }
    static func usbCardTitle() -> String { text("USB Cable", "USB 数据线") }
    static func usbCardBody() -> String { text("Connect the phone with a cable and allow USB debugging on the phone. Fastest and ready instantly.", "用数据线连接手机与 Mac，在手机上允许 USB 调试授权。连接后立即可用，速度最快。") }
    static func wirelessCardTitle() -> String { text("Wireless Pairing", "无线配对") }
    static func wirelessCardBody() -> String { text("On the same Wi-Fi: Developer options → Wireless debugging → Pair device with QR code, then scan the code below.", "手机连接同一 Wi-Fi，打开 开发者选项 → 无线调试 → 使用二维码配对设备，扫描下方二维码。") }
    static func searchingDevices() -> String { text("Searching for devices… previously connected devices reconnect automatically.", "正在搜索设备… 已连接过的设备会自动重新连接") }
    static func advancedWireless() -> String { text("Advanced…", "高级选项…") }
    static func emptySearchResult() -> String { text("No matches in this folder.", "当前文件夹没有匹配项。") }
    static func shareFailed() -> String { text("Could not prepare the file for sharing.", "无法准备要分享的文件。") }
    static func downloadedItemsCount(_ n: Int) -> String { text("Downloaded \(n) item(s).", "已下载 \(n) 项。") }
    static func transferCancelled() -> String { text("Transfer cancelled.", "传输已取消。") }
    static func transfersTitle() -> String { text("Transfers", "传输队列") }
    static func transferHeadSummary(_ running: Int, _ waiting: Int, _ done: Int) -> String {
        text("\(running) active · \(waiting) waiting · \(done) done", "\(running) 进行中 · \(waiting) 等待 · \(done) 已完成")
    }
    static func queuedLabel() -> String { text("Queued", "排队中") }
    static func cancelledLabel() -> String { text("Cancelled", "已取消") }
    static func saveDest(_ dest: String) -> String { text("to \(dest)", "保存到 \(dest)") }
    static func sendDest(_ dest: String) -> String { text("to \(dest)", "传到 \(dest)") }
    static func savedDest(_ dest: String) -> String { text("saved to \(dest)", "已保存到 \(dest)") }
    static func sentDest(_ dest: String) -> String { text("sent to \(dest)", "已传到 \(dest)") }
    static func transferringSummary(_ n: Int) -> String { text("Transferring \(n) item(s)", "正在传输 \(n) 项") }
    static func saveSelectedToMac(_ n: Int) -> String { text("Save \(n) Selected to Mac", "保存已选 \(n) 项到 Mac") }
    static func deleteSelectedItems(_ n: Int) -> String { text("Delete \(n) Selected", "删除已选 \(n) 项") }
    static func quickAccessNotFound(_ name: String) -> String { text("\"\(name)\" folder not found on this device.", "此设备上未找到「\(name)」目录。") }

    // MARK: - Wi-Fi pair dialog (06)

    static func wifiDialogTitle() -> String { text("Connect Over Wi-Fi", "通过 Wi-Fi 连接") }
    static func wifiDialogSub() -> String { text("Phone and Mac must be on the same Wi-Fi network.", "手机与 Mac 需要在同一个 Wi-Fi 网络") }
    static func usbQuickEnableTitle() -> String { text("Enable via USB", "USB 快速启用") }
    static func recommendedBadge() -> String { text("Recommended", "推荐") }
    static func usbQuickEnableDesc() -> String { text("Connect with a cable once — wireless is enabled for this phone automatically, no cable needed afterwards.", "用数据线连接一次，自动为这台手机开启无线连接，以后无需再插线") }
    static func usbConnectedReady() -> String { text("Connected via USB · ready to enable", "已通过 USB 连接 · 可立即启用") }
    static func enableWireless() -> String { text("Enable Wireless", "启用无线连接") }
    static func noUSBDeviceRow() -> String { text("No USB device detected", "未检测到 USB 设备") }
    static func alreadyWireless() -> String { text("This device is already wireless", "当前设备已是无线连接") }
    static func nearbyDesc() -> String { text("Automatically finds devices on this network with wireless debugging on.", "自动搜索同一网络中已开启无线调试的设备") }
    static func scanningLabel() -> String { text("Scanning…", "正在搜索…") }
    static func codePairTitle() -> String { text("Pair with Code", "配对码配对") }
    static func codePairDesc() -> String { text("Enter what the phone shows under \"Pair device with pairing code\".", "输入手机「使用配对码配对」弹窗中显示的信息") }
    static func pairCodePlaceholder() -> String { text("6-digit code", "六位配对码") }
    static func pairEndpointPlaceholder() -> String { text("IP : PORT", "IP : 端口") }
    static func dialogFootHelp() -> String { text("Devices are remembered and reconnect automatically on the same network.", "连接后会自动记住设备，下次在同一网络自动重连") }
    static func connectHelp() -> String { text("Connection Help", "连接帮助") }
    static func connectEndpointNotFound() -> String { text("Paired, but no connect endpoint was found on that host.", "已配对，但未在该主机上发现连接端口。") }
    static func preparingShare(_ name: String) -> String { text("Preparing to share \(name)…", "正在准备分享 \(name)…") }

    // MARK: - Delete / edit

    static func deleteItem() -> String { text("Delete", "删除") }
    static func deleteFile() -> String { text("Delete File", "删除文件") }
    static func deleteFolder() -> String { text("Delete Folder", "删除文件夹") }
    static func deleteConfirmTitle() -> String { text("Confirm Delete", "确认删除") }
    static func deleteConfirmMessage(_ name: String) -> String { text("Delete \"\(name)\" permanently?", "确定永久删除 “\(name)” 吗？") }
    static func deleteConfirmMessageFolder(_ name: String) -> String { text("Delete folder \"\(name)\" and all its contents permanently?", "确定永久删除文件夹 “\(name)” 及其全部内容吗？") }
    static func cancel() -> String { text("Cancel", "取消") }
    static func deletedFile(_ name: String) -> String { text("Deleted file: \(name)", "已删除文件：\(name)") }
    static func deletedFolder(_ name: String) -> String { text("Deleted folder: \(name)", "已删除文件夹：\(name)") }
    static func deleteFailed() -> String { text("Delete failed", "删除失败") }
    static func deleteRootNotAllowed() -> String { text("Deleting root path is not allowed.", "不允许删除根目录。") }
    static func openedFile(_ name: String) -> String { text("Opened: \(name)", "已打开：\(name)") }
    static func openFile() -> String { text("Open", "打开") }
    static func editMode() -> String { text("Edit", "编辑") }
    static func done() -> String { text("Done", "完成") }
    static func deleteSelected() -> String { text("Delete Selected", "删除已选") }
    static func selectedCount(_ count: Int) -> String { text("\(count) selected", "已选 \(count) 项") }
    static func deleteSelectedConfirmMessage(_ count: Int) -> String {
        text("Delete \(count) selected item(s) permanently?", "确定永久删除已选的 \(count) 项吗？")
    }
    static func deletedItemsCount(_ count: Int) -> String { text("Deleted \(count) item(s)", "已删除 \(count) 项") }
}
