import FanCore

/// Owns its own SMC connection; the actor keeps the ~270 reads off the main thread without a manual queue.
actor SensorsBackend {
    private var reader: AllSensorsReader?

    func read() -> [SensorValue] {
        if reader == nil, let smc = try? SMC() { reader = AllSensorsReader(smc: smc) }
        return reader?.read() ?? []
    }
}
