import Foundation

struct ProjectExportPlacementRequest {
    let renderedURL: URL
    let destinationURL: URL
}

enum ProjectExportPlacement {
    static func place(_ request: ProjectExportPlacementRequest) throws -> URL {
        let fileManager = FileManager.default
        let destinationDirectory = request.destinationURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)

        if request.renderedURL.standardizedFileURL == request.destinationURL.standardizedFileURL {
            return request.destinationURL
        }

        let stagedURL = destinationDirectory.appendingPathComponent(
            ".blitzrecorder-export-\(UUID().uuidString).\(request.destinationURL.pathExtension)"
        )
        do {
            try fileManager.copyItem(at: request.renderedURL, to: stagedURL)
            if fileManager.fileExists(atPath: request.destinationURL.path) {
                _ = try fileManager.replaceItemAt(request.destinationURL, withItemAt: stagedURL)
            } else {
                try fileManager.moveItem(at: stagedURL, to: request.destinationURL)
            }
            try? fileManager.removeItem(at: request.renderedURL)
            return request.destinationURL
        } catch {
            try? fileManager.removeItem(at: stagedURL)
            throw error
        }
    }
}
