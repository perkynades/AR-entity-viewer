import Foundation
import ArgumentParser
import ServerCore

let defaultDocroot = "docroot"
let defaultPort = 8888

struct MainCLI: ParsableCommand {
    @Option(name: .shortAndLong, help: "TCP Port to listen on (Default: \(defaultPort))")
    var port: Int = defaultPort
    
    @Option(name: .shortAndLong, help: "Filesystem path to search for files.  (Default: \(defaultDocroot)")
    var docroot: String = defaultDocroot
    
    func run() throws {
        let config = ServerConfig(port: port, docroot: docroot)
        let server = Server(config)
        server.run()
    }
}

MainCLI.main()
