protocol AudioSource {
    func start() throws -> AsyncStream<[Float]>
    func stop()
}
