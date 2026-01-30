import Foundation

/// Static collection of all open source licenses used in the app
enum OpenSourceLicenses {
    static let all: [OpenSourceLicense] = [
        vlcKit,
        amsmb2
    ]

    static let vlcKit = OpenSourceLicense(
        name: "VLCKit",
        version: "3.6.0",
        description: "Cross-platform multimedia framework providing video playback capabilities for formats not natively supported by AVPlayer.",
        licenseType: "LGPL 2.1",
        licenseText: """
        VLCKit is licensed under the GNU Lesser General Public License version 2.1 (LGPL 2.1).

        This means you are free to use this library in your application, provided that:

        1. You include a copy of the LGPL 2.1 license
        2. You provide attribution to the VLCKit project
        3. You provide access to the VLCKit source code
        4. Any modifications to VLCKit itself must be released under LGPL 2.1

        The full license text is available at:
        https://www.gnu.org/licenses/old-licenses/lgpl-2.1.html

        VLCKit source code is available at the Source URL below.
        """,
        sourceURL: "https://code.videolan.org/videolan/VLCKit"
    )

    static let amsmb2 = OpenSourceLicense(
        name: "AMSMB2",
        version: "3.0.0",
        description: "Swift framework for connecting to SMB2/3 shares, enabling network file browsing and streaming.",
        licenseType: "MIT",
        licenseText: """
        MIT License

        Copyright (c) 2018 Amir Abbas Mousavian

        Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

        The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

        THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
        """,
        sourceURL: "https://github.com/amosavian/AMSMB2"
    )
}
