public enum Shell {
    @discardableResult
    public static func run(_ args: String...) -> Int32 {
        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = args
        task.launch()
        task.waitUntilExit()
        return task.terminationStatus
    }
}