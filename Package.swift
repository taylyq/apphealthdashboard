// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AppHealthDashboard",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/mysql-nio.git", from: "1.0.0")
    ],
    targets: [
        .executableTarget(
            name: "AppHealthDashboard",
            dependencies: [
                .product(name: "MySQLNIO", package: "mysql-nio")
            ],
            path: "Sources/AppHealthDashboard"
        )
    ]
)
