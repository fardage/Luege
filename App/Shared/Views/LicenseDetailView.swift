import SwiftUI

struct LicenseDetailView: View {
    let license: OpenSourceLicense

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(license.licenseType)
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    Text(license.description)
                        .font(.subheadline)

                    if let sourceURL = license.sourceURL {
                        Link(destination: URL(string: sourceURL)!) {
                            Label("View Source Code", systemImage: "arrow.up.right.square")
                        }
                        .font(.subheadline)
                    }
                }
                .padding(.bottom, 8)

                Divider()

                Text(license.licenseText)
                    .font(.system(.body, design: .monospaced))
                    #if os(iOS)
                    .textSelection(.enabled)
                    #endif
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(license.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

#Preview {
    NavigationStack {
        LicenseDetailView(license: OpenSourceLicenses.amsmb2)
    }
}
