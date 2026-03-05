import Foundation
import Metal
import os

// MARK: - HardwareCapabilities

public struct HardwareCapabilities: Sendable {
    public let isAppleSilicon: Bool
    public let hasNeuralEngine: Bool
    public let gpuMemoryBytes: UInt64
    public let processorCount: Int
    public let metalSupported: Bool

    // MARK: - Detection

    public static func detect() -> HardwareCapabilities {
        let logger = Logger(subsystem: "com.snapforge", category: "HardwareCapabilities")

        #if arch(arm64)
        let isAppleSilicon = true
        #else
        let isAppleSilicon = false
        #endif

        let device = MTLCreateSystemDefaultDevice()
        let metalSupported = device != nil

        let hasNeuralEngine: Bool
        let gpuMemoryBytes: UInt64

        if let device {
            // Apple7 family (A14 / M1 and later) guarantees ANE availability
            hasNeuralEngine = device.supportsFamily(.apple7)
            gpuMemoryBytes = device.recommendedMaxWorkingSetSize
        } else {
            hasNeuralEngine = false
            gpuMemoryBytes = 0
        }

        let processorCount = ProcessInfo.processInfo.processorCount

        let caps = HardwareCapabilities(
            isAppleSilicon: isAppleSilicon,
            hasNeuralEngine: hasNeuralEngine,
            gpuMemoryBytes: gpuMemoryBytes,
            processorCount: processorCount,
            metalSupported: metalSupported
        )

        logger.info("""
            Hardware detected — \
            appleSilicon: \(caps.isAppleSilicon), \
            neuralEngine: \(caps.hasNeuralEngine), \
            gpuMemory: \(caps.gpuMemoryBytes / 1_048_576) MB, \
            processors: \(caps.processorCount), \
            metal: \(caps.metalSupported)
            """)

        return caps
    }

    // MARK: - Init

    public init(
        isAppleSilicon: Bool,
        hasNeuralEngine: Bool,
        gpuMemoryBytes: UInt64,
        processorCount: Int,
        metalSupported: Bool
    ) {
        self.isAppleSilicon = isAppleSilicon
        self.hasNeuralEngine = hasNeuralEngine
        self.gpuMemoryBytes = gpuMemoryBytes
        self.processorCount = processorCount
        self.metalSupported = metalSupported
    }
}
