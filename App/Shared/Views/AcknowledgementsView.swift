import SwiftUI

struct AcknowledgementsView: View {
    var body: some View {
        List(OpenSourceLicenses.all) { license in
            NavigationLink(destination: LicenseDetailView(license: license)) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(license.name)
                            .font(.headline)
                        Spacer()
                        Text(license.licenseType)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(license.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Acknowledgements")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

#Preview {
    NavigationStack {
        AcknowledgementsView()
    }
}
