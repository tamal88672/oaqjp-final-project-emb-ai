// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SecretAdmirer",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "SecretAdmirer", targets: ["SecretAdmirer"]),
    ],
    targets: [
        .target(
            name: "SecretAdmirer",
            path: "."
        ),
    ]
)
