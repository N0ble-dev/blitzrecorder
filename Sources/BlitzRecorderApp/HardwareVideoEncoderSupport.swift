import CoreMedia
import Foundation
import VideoToolbox

struct HardwareVideoEncoderProbeRequest {
    let width: Int
    let height: Int
    let codecType: CMVideoCodecType
}

struct HardwareVideoEncoderStatus: Equatable {
    let isAvailable: Bool
    let isUsingHardware: Bool
    let status: OSStatus
}

enum HardwareVideoEncoderSupport {
    static func probe(_ request: HardwareVideoEncoderProbeRequest) -> HardwareVideoEncoderStatus {
        var session: VTCompressionSession?
        let specification = [
            kVTVideoEncoderSpecification_RequireHardwareAcceleratedVideoEncoder as String: true
        ] as CFDictionary
        let status = VTCompressionSessionCreate(
            allocator: kCFAllocatorDefault,
            width: Int32(request.width),
            height: Int32(request.height),
            codecType: request.codecType,
            encoderSpecification: specification,
            imageBufferAttributes: nil,
            compressedDataAllocator: nil,
            outputCallback: nil,
            refcon: nil,
            compressionSessionOut: &session
        )
        guard status == noErr, let session else {
            return HardwareVideoEncoderStatus(
                isAvailable: false,
                isUsingHardware: false,
                status: status
            )
        }
        defer {
            VTCompressionSessionInvalidate(session)
        }

        var property: CFTypeRef?
        let propertyStatus = withUnsafeMutablePointer(to: &property) { pointer in
            VTSessionCopyProperty(
                session,
                key: kVTCompressionPropertyKey_UsingHardwareAcceleratedVideoEncoder,
                allocator: kCFAllocatorDefault,
                valueOut: UnsafeMutableRawPointer(pointer)
            )
        }
        let usesHardware = propertyStatus == noErr
            && (property as? NSNumber)?.boolValue == true
        return HardwareVideoEncoderStatus(
            isAvailable: true,
            isUsingHardware: usesHardware,
            status: propertyStatus
        )
    }
}
