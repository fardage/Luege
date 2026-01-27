import XCTest
import SwiftUI
import SnapshotTesting
#if canImport(UIKit)
import UIKit
#endif

/// Base class for snapshot tests with common setup
class SnapshotTestCase: XCTestCase {

    /// Set to true to record new reference snapshots.
    /// After recording, set back to false and commit the new images.
    var isRecording: Bool {
        get { SnapshotTesting.isRecording }
        set { SnapshotTesting.isRecording = newValue }
    }

    override func setUp() {
        super.setUp()

        // Disable animations for consistent snapshots
        UIView.setAnimationsEnabled(false)

        // Set to true when you need to record new reference images
        // isRecording = true
    }

    override func tearDown() {
        UIView.setAnimationsEnabled(true)
        super.tearDown()
    }

    // MARK: - Platform-Specific Snapshot Helpers

    // MARK: - Platform Name Helper

    private var platformSuffix: String {
        #if os(iOS)
        return "iOS"
        #elseif os(tvOS)
        return "tvOS"
        #else
        return "unknown"
        #endif
    }

    private func snapshotName(_ name: String?) -> String {
        if let name = name {
            return "\(name).\(platformSuffix)"
        }
        return platformSuffix
    }

    #if os(iOS)
    /// Snapshot a SwiftUI view on iPhone
    func assertiPhoneSnapshot<V: View>(
        of view: V,
        colorScheme: ColorScheme = .light,
        named name: String? = nil,
        file: StaticString = #file,
        testName: String = #function,
        line: UInt = #line
    ) {
        let controller = UIHostingController(rootView: view)
        controller.overrideUserInterfaceStyle = colorScheme == .dark ? .dark : .light
        assertSnapshot(
            of: controller,
            as: .image(on: .iPhone13),
            named: snapshotName(name),
            file: file,
            testName: testName,
            line: line
        )
    }

    /// Snapshot a SwiftUI view on iPad
    func assertiPadSnapshot<V: View>(
        of view: V,
        colorScheme: ColorScheme = .light,
        named name: String? = nil,
        file: StaticString = #file,
        testName: String = #function,
        line: UInt = #line
    ) {
        let controller = UIHostingController(rootView: view)
        controller.overrideUserInterfaceStyle = colorScheme == .dark ? .dark : .light
        assertSnapshot(
            of: controller,
            as: .image(on: .iPadPro11),
            named: snapshotName(name),
            file: file,
            testName: testName,
            line: line
        )
    }

    /// Snapshot a small component view with fixed size
    func assertComponentSnapshot<V: View>(
        of view: V,
        size: CGSize = CGSize(width: 400, height: 100),
        colorScheme: ColorScheme = .light,
        named name: String? = nil,
        file: StaticString = #file,
        testName: String = #function,
        line: UInt = #line
    ) {
        let framedView = view
            .frame(width: size.width, height: size.height)
            .background(Color(UIColor.systemBackground))

        let controller = UIHostingController(rootView: framedView)
        controller.view.frame = CGRect(origin: .zero, size: size)
        controller.overrideUserInterfaceStyle = colorScheme == .dark ? .dark : .light
        assertSnapshot(
            of: controller,
            as: .image(size: size),
            named: snapshotName(name),
            file: file,
            testName: testName,
            line: line
        )
    }
    #endif

    #if os(tvOS)
    /// Snapshot a SwiftUI view on Apple TV (1920x1080)
    func assertTVSnapshot<V: View>(
        of view: V,
        colorScheme: ColorScheme = .light,
        named name: String? = nil,
        file: StaticString = #file,
        testName: String = #function,
        line: UInt = #line
    ) {
        let controller = UIHostingController(rootView: view)
        let size = CGSize(width: 1920, height: 1080)
        controller.view.frame = CGRect(origin: .zero, size: size)
        controller.overrideUserInterfaceStyle = colorScheme == .dark ? .dark : .light
        // Set background color explicitly since tvOS doesn't have systemBackground
        controller.view.backgroundColor = colorScheme == .dark ? .black : .white
        assertSnapshot(
            of: controller,
            as: .image(size: size),
            named: snapshotName(name),
            file: file,
            testName: testName,
            line: line
        )
    }

    /// Snapshot a small component view with fixed size on tvOS
    func assertComponentSnapshot<V: View>(
        of view: V,
        size: CGSize = CGSize(width: 800, height: 200),
        colorScheme: ColorScheme = .light,
        named name: String? = nil,
        file: StaticString = #file,
        testName: String = #function,
        line: UInt = #line
    ) {
        // tvOS doesn't have systemBackground, use a dynamic color based on color scheme
        let backgroundColor = colorScheme == .dark ? Color.black : Color.white
        let framedView = view
            .frame(width: size.width, height: size.height)
            .background(backgroundColor)

        let controller = UIHostingController(rootView: framedView)
        controller.view.frame = CGRect(origin: .zero, size: size)
        controller.overrideUserInterfaceStyle = colorScheme == .dark ? .dark : .light
        assertSnapshot(
            of: controller,
            as: .image(size: size),
            named: snapshotName(name),
            file: file,
            testName: testName,
            line: line
        )
    }
    #endif
}

// MARK: - Color Scheme Helpers

extension View {
    /// Apply light mode for testing
    func lightMode() -> some View {
        self.preferredColorScheme(.light)
    }

    /// Apply dark mode for testing
    func darkMode() -> some View {
        self.preferredColorScheme(.dark)
    }
}
