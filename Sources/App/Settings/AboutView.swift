import CPDAcknowledgements
import Shared
import SwiftUI

struct AboutView: View {
    @State private var showVersionAlert = false

    var body: some View {
        List {
            AppleLikeListTopRowHeader(
                image: nil,
                headerImageAlternativeView: AnyView(
                    Image(uiImage: Asset.logo.image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                ),
                title: L10n.About.Logo.appTitle,
                subtitle: HomeAssistantAPI.clientVersionDescription
            )
            .onTapGesture {
                showVersionAlert = true
            }

            Section {
                NavigationLink(destination: AcknowledgementsView().navigationTitle(AcknowledgementsView.title)) {
                    Text(AcknowledgementsView.title)
                }
            }

            Section {
                Link(L10n.About.Website.title, destination: AppConstants.WebURLs.homeAssistant)
                Link(L10n.About.Documentation.title, destination: AppConstants.WebURLs.companionAppDocs)
                Link(L10n.Support.contact, destination: AppConstants.WebURLs.support)
            }
        }
        .navigationTitle(L10n.About.title)
        .alert(isPresented: $showVersionAlert) {
            Alert(
                title: Text(""),
                message: Text(HomeAssistantAPI.clientVersionDescription),
                primaryButton: .default(Text(L10n.copyLabel), action: {
                    UIPasteboard.general.string = HomeAssistantAPI.clientVersionDescription
                }),
                secondaryButton: .cancel(Text(L10n.cancelLabel))
            )
        }
    }
}

struct AcknowledgementsView: UIViewControllerRepresentable {
    static var title: String {
        L10n.About.Acknowledgements.title
    }

    func makeUIViewController(context: Context) -> CPDAcknowledgementsViewController {
        var licenses = [CPDLibrary]()

        for fileName in [
            "Pods-iOS-App-metadata",
            "ManualPodLicenses",
        ] {
            if let file = Bundle.main.url(forResource: fileName, withExtension: "plist"),
               let dictionary = NSDictionary(contentsOf: file),
               let license = dictionary["specs"] as? [[String: Any]] {
                licenses += license.map { CPDLibrary(cocoaPodsMetadataPlistDictionary: $0) }
            }
        }

        licenses.sort(by: { $0.title < $1.title })

        return CPDAcknowledgementsViewController(style: nil, acknowledgements: licenses, contributions: nil)
    }

    func updateUIViewController(_ uiViewController: CPDAcknowledgementsViewController, context: Context) {}
}
