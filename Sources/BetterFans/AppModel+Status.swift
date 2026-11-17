import SwiftUI
import FanCore

extension AppModel {
    /// What the status pill says, decided in one place from helper state, profile and temperature.
    var status: (text: String, icon: String, tint: Color, detail: String?) {
        if !helperReachable {
            return ("Helper detenido", "bolt.slash.fill", .secondary, "macOS controla los ventiladores. Instala el helper con scripts/install-helper.sh.")
        }
        if let err = helperStatus?.lastError {
            return ("Error", "exclamationmark.triangle.fill", .red, err)
        }
        if helperStatus?.controlling == true {
            if let t = temperature, t >= FanController.hardLimitC {
                return ("Límite térmico", "flame.fill", .red, "≥ \(Int(FanController.hardLimitC)) °C: ventiladores al máximo.")
            }
            return (selected.isCurve ? "Curva activa" : "Velocidad fija", "fanblades.fill", .green, nil)
        }
        return ("Control de Apple", "apple.logo", .secondary, nil)
    }
}
