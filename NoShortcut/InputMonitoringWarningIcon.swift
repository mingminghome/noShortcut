import SwiftUI

struct InputMonitoringWarningIcon: View {
    var body: some View {
        Image(systemName: "exclamationmark.triangle.fill")
            .font(.caption)
            .foregroundStyle(.orange)
            .help(AppPermissions.permissionsRequiredMessage)
    }
}