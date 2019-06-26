import Foundation
import UIKit
import PromiseKit

enum DetailCellType {
    case name
    case identifier
    case amount
    case precision
    case ticker
    case issuer
}

extension DetailCellType: CaseIterable {}

class AssetDetailTableViewController: UITableViewController, UITextViewDelegate {

    var tag: String!
    var asset: AssetInfo?
    var satoshi: UInt64?

    private var assetDetailCellTypes = DetailCellType.allCases
    private var isReadOnly = true
    private var assetTableCell: AssetTableCell?
    private var keyboardDismissGesture: UIGestureRecognizer?

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.sectionHeaderHeight = UITableView.automaticDimension
        tableView.estimatedSectionHeaderHeight = 85
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 75
        tableView.tableFooterView = UIView()
        title = NSLocalizedString("id_asset_details", comment: "")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    @objc func dismissModal() {
        self.dismiss(animated: true, completion: nil)
    }

    @objc func keyboardWillShow(notification: NSNotification) {
        if keyboardDismissGesture == nil {
            keyboardDismissGesture = UITapGestureRecognizer(target: self, action: #selector(KeyboardViewController.dismissKeyboard))
            view.addGestureRecognizer(keyboardDismissGesture!)
        }
    }

    @objc func keyboardWillHide(notification: NSNotification) {
        if keyboardDismissGesture != nil {
            view.removeGestureRecognizer(keyboardDismissGesture!)
            keyboardDismissGesture = nil
        }
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return UITableView.automaticDimension
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if let header = tableView.dequeueReusableCell(withIdentifier: "AssetDetailHeaderCell") as? AssetDetailHeaderCell {
            header.saveButton.isHidden = true
            header.dismissButton.addTarget(self, action: #selector(dismissModal), for: .touchUpInside)
            return header
        }
        return UIView()
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return assetDetailCellTypes.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let cell = tableView.dequeueReusableCell(withIdentifier: "AssetDetailTableCell") as? AssetDetailTableCell {
            let cellType = assetDetailCellTypes[indexPath.row]
            switch cellType {
            case .name:
                cell.titleLabel.text = NSLocalizedString("id_asset_name", comment: "")
                cell.detailLabel.text = asset?.name ?? NSLocalizedString("id_no_registered_name_for_this", comment: "")
            case .identifier:
                cell.titleLabel.text = NSLocalizedString("id_asset_id", comment: "")
                cell.detailLabel.text = tag
            case .amount:
                cell.titleLabel.text = NSLocalizedString("id_total_balance", comment: "")
                let assetInfo = asset ?? AssetInfo(assetId: tag, name: tag, precision: 0, ticker: "")
                let balance = Balance.convert(details: ["satoshi": satoshi ?? 0, "asset_info": assetInfo.encode()!])
                cell.detailLabel.text = balance.get(tag: tag).0
            case .precision:
                cell.titleLabel.text = NSLocalizedString("id_precision", comment: "")
                cell.detailLabel.text = String(asset?.precision ?? 0)
            case .ticker:
                cell.titleLabel.text = NSLocalizedString("id_ticker", comment: "")
                cell.detailLabel.text = asset?.ticker ?? NSLocalizedString("id_no_registered_ticker_for_this", comment: "")
            case .issuer:
                cell.titleLabel.text = NSLocalizedString("id_issuer", comment: "")
                cell.detailLabel.text = asset?.entity?.domain ?? NSLocalizedString("id_unknown", comment: "")
            }
            return cell
        }
        return UITableViewCell()
    }

    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
}