import Foundation

/// Utility for validating and sanitizing file prefixes
public enum FilePrefixValidator {

    /// Characters that are not allowed in file names on macOS/Unix
    public static let invalidFileNameCharacters = CharacterSet(charactersIn: "/:\\*?\"<>|")

    /// Maximum allowed length for file prefix
    public static let maxPrefixLength = 50

    /// Default prefix to use when the provided one is invalid or empty
    public static let defaultPrefix = "Screenshot"

    /// Sanitizes a file prefix by removing invalid characters
    /// - Parameter prefix: The raw prefix input from the user
    /// - Returns: A sanitized prefix safe for use in file names
    public static func sanitize(_ prefix: String) -> String {
        // Remove invalid characters
        var sanitized = prefix.components(separatedBy: invalidFileNameCharacters).joined()

        // Trim whitespace from start and end
        sanitized = sanitized.trimmingCharacters(in: .whitespaces)

        // Replace multiple spaces with single space
        while sanitized.contains("  ") {
            sanitized = sanitized.replacingOccurrences(of: "  ", with: " ")
        }

        // Limit length to prevent overly long filenames
        if sanitized.count > maxPrefixLength {
            sanitized = String(sanitized.prefix(maxPrefixLength))
        }

        // If empty after sanitization, return default
        if sanitized.isEmpty {
            return defaultPrefix
        }

        return sanitized
    }

    /// Validates if a file prefix is valid
    /// - Parameter prefix: The prefix to validate
    /// - Returns: True if the prefix is valid, false otherwise
    public static func isValid(_ prefix: String) -> Bool {
        guard !prefix.isEmpty else { return false }
        guard prefix.count <= maxPrefixLength else { return false }
        guard prefix.rangeOfCharacter(from: invalidFileNameCharacters) == nil else { return false }
        // Check for leading/trailing whitespace
        guard prefix == prefix.trimmingCharacters(in: .whitespaces) else { return false }
        // Check for multiple consecutive spaces
        guard !prefix.contains("  ") else { return false }
        return true
    }

    /// Returns a list of validation errors for the given prefix
    /// - Parameter prefix: The prefix to validate
    /// - Returns: An array of error messages, empty if valid
    public static func validationErrors(for prefix: String) -> [String] {
        var errors: [String] = []

        if prefix.isEmpty {
            errors.append("Prefix cannot be empty")
        }

        if prefix.count > maxPrefixLength {
            errors.append("Prefix exceeds maximum length of \(maxPrefixLength) characters")
        }

        if prefix.rangeOfCharacter(from: invalidFileNameCharacters) != nil {
            errors.append("Prefix contains invalid characters (/ \\ : * ? \" < > |)")
        }

        if prefix != prefix.trimmingCharacters(in: .whitespaces) {
            errors.append("Prefix cannot have leading or trailing whitespace")
        }

        if prefix.contains("  ") {
            errors.append("Prefix cannot contain multiple consecutive spaces")
        }

        return errors
    }
}
