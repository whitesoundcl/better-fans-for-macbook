import FanCore

/// Reads the SMC off the main thread with its own connection. Unprivileged: reads only.
actor Sampler {
    struct Reading: Sendable {
        var cpu: Double?
        var gpu: Double?
        var ambient: Double?
        var fans: [FanReading]
    }

    private var sensors: SensorReader?

    func read() -> Reading {
        if sensors == nil, let smc = try? SMC() { sensors = SensorReader(smc: smc) }
        let temps = sensors?.hottestCPUAndGPU()
        return Reading(cpu: temps?.cpu, gpu: temps?.gpu, ambient: sensors?.ambient(), fans: sensors?.fans() ?? [])
    }
}
