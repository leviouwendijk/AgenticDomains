import Macros
import Schema

@JSONSchema
public struct LintSwiftPackageForbiddenTargetDependency:
    Sendable,
    Codable,
    Hashable
{
    public let sourceTarget: String
    public let dependencyName: String
    public let dependencyPackage: String?

    public init(
        sourceTarget: String,
        dependencyName: String,
        dependencyPackage: String? = nil
    ) {
        self.sourceTarget = sourceTarget
        self.dependencyName = dependencyName
        self.dependencyPackage = dependencyPackage
    }
}


@JSONSchema
public enum SwiftPackageRuleLintSubject:
    Sendable,
    Codable,
    Hashable
{
    case package(
        identity: String,
        name: String
    )
    case declared_package_dependency(
        identity: String?,
        location: String?
    )
    case product(String)
    case target(String)
    case target_dependency(
        target: String,
        dependency: String,
        package: String?
    )
}

@JSONSchema
public struct SwiftPackageRuleLintDiagnostic:
    Sendable,
    Codable,
    Hashable
{
    public let ruleID: String
    public let severity: String
    public let message: String
    public let subject: SwiftPackageRuleLintSubject

    public init(
        ruleID: String,
        severity: String,
        message: String,
        subject: SwiftPackageRuleLintSubject
    ) {
        self.ruleID = ruleID
        self.severity = severity
        self.message = message
        self.subject = subject
    }
}

