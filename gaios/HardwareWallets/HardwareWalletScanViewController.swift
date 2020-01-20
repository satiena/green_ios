import UIKit
import PromiseKit
import RxSwift
import RxBluetoothKit

class HardwareWalletScanViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var radarImageView: RadarImageView!

    let timeout = RxTimeInterval.seconds(10)
    var peripherals = [ScannedPeripheral]()

    var scanningDispose: Disposable?
    var enstablishDispose: Disposable?

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.dataSource = self
        tableView.delegate = self
        tableView.tableFooterView = UIView()

        let manager = AppDelegate.manager
        if manager.state == .poweredOn {
            scanningDispose = scan()
            return
        }

        // wait bluetooth is ready
        scanningDispose = manager.observeState()
            .do(onNext: { print("do: \($0.rawValue)") })
            .filter { $0 == .poweredOn }
            .take(1)
            .subscribe(onNext: { _ in
                self.scanningDispose = self.scan()
            }, onError: { err in
                self.showAlert(err.localizedDescription)
            })
    }

    func scan() -> Disposable {
        return AppDelegate.manager.scanForPeripherals(withServices: nil)
            .filter { $0.peripheral.name?.contains("Nano") ?? false }
            .subscribe(onNext: { p in
                self.peripherals.removeAll { $0.rssi == p.rssi }
                self.peripherals.append(p)
                self.tableView.reloadData()
            }, onError: { err in
                self.showAlert(err.localizedDescription)
            })
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        radarImageView.startSpinning()
    }

    override func viewWillDisappear(_ animated: Bool) {
        scanningDispose?.dispose()
        AppDelegate.manager.manager.stopScan()
    }
}

extension HardwareWalletScanViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return peripherals.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let cell = tableView.dequeueReusableCell(withIdentifier: "HardwareDeviceCell",
                                                    for: indexPath as IndexPath) as? HardwareDeviceCell {
            let p = peripherals[indexPath.row]
            cell.nameLabel.text = p.advertisementData.localName
            cell.connectionStatusLabel.text = p.peripheral.identifier.uuidString == UserDefaults.standard.string(forKey: "paired_device_uuid") ? "Current selected" : ""
            cell.accessoryType = p.advertisementData.isConnectable ?? false ? .disclosureIndicator : .none
            return cell
        }
        return UITableViewCell()
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let peripheral = peripherals[indexPath.row].peripheral
        scanningDispose?.dispose()
        enstablishDispose?.dispose()
        self.connect(peripheral: peripheral)
    }
}

extension HardwareWalletScanViewController {

    enum DeviceError: Error {
        case dashboard
        case wrong_app
    }

    func network() -> String {
        return getGdkNetwork(getNetwork()).network.lowercased() == "testnet" ? "Bitcoin Test" : "Bitcoin"
    }

    func connect(peripheral: Peripheral) {
       enstablishDispose = peripheral.establishConnection()
            .timeoutIfNoEvent(self.timeout)
            .flatMap { Ledger.shared.open($0) }
            .timeoutIfNoEvent(self.timeout)
            .flatMap { _ in Ledger.shared.application() }
            .flatMap { res -> Observable<Bool> in
                let name = res["name"] as? String
                if name!.contains("OLOS") {
                    // open app from dashboard
                    return Observable<Bool>.error(DeviceError.dashboard)
                } else if name! != self.network() {
                    // change app
                    return Observable<Bool>.error(DeviceError.wrong_app)
                }
                // correct open app
                return Observable.just(true)
            }
            .subscribe(onNext: { _ in
                print("Login on progress")
                self.login()
            }, onError: { err in
                switch err {
                case is BluetoothError:
                    self.showAlert("Connection to unit failed! Move closer to the unit and try again.")
                case RxError.timeout:
                    self.showAlert("Communication with the device timed out. Make sure the unit is powered on, move closer to it, and try again.")
                case DeviceError.dashboard:
                    self.showAlert("Open \(self.network()) app on your Ledger")
                case DeviceError.wrong_app:
                    self.showAlert("Quit current app and open \(self.network()) app on your Ledger")
                default:
                    self.showAlert("Uncaught error: \(err.localizedDescription).")
                }
            }, onCompleted: {}, onDisposed: {})
    }

    func login() {
        let bgq = DispatchQueue.global(qos: .background)
        let session = getGAService().getSession()
        let appDelegate = getAppDelegate()!
        firstly {
            self.startAnimating()
            return Guarantee()
        }.compactMap(on: bgq) {
            try appDelegate.connect()
        }.compactMap(on: bgq) { _ -> TwoFactorCall in
            return try session.registerUser(mnemonic: "", hw_device: ["device": (Ledger.shared.hwDevice as Any) ])
        }.then(on: bgq) { call in
            call.resolve()
        }.compactMap(on: bgq) {_ -> TwoFactorCall in
            try session.login(mnemonic: "", hw_device: ["device": Ledger.shared.hwDevice])
        }.then(on: bgq) { call in
            call.resolve()
        }.ensure {
            self.stopAnimating()
        }.done { _ in
            appDelegate.instantiateViewControllerAsRoot(storyboard: "Wallet", identifier: "TabViewController")
        }.catch { e in
            self.showAlert("error \(e.localizedDescription)")
        }
    }

    func showAlert(_ message: String) {
        let alert = UIAlertController(title: NSLocalizedString("id_warning", comment: ""), message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("id_cancel", comment: ""), style: .cancel))
        self.present(alert, animated: true, completion: nil)
    }
}

extension Observable {
    func timeoutIfNoEvent(_ dueTime: RxTimeInterval) -> Observable<Element> {
        let timeout = Observable
            .never()
            .timeout(dueTime, scheduler: MainScheduler.instance)

        return self.amb(timeout)
    }
}