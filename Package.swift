import PackageDescription

let package = Package(
    name: "ModMove",
    targets: [
        Target(name: "ModMove", dependencies: [.Target(name: "Login")]),
        Target(name: "Login")
    ]
)
