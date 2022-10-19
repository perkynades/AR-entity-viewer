import Kitura

public class Server {
    let router: Router
    let config: ServerConfig
    
    public init(_ config: ServerConfig) {
        self.config = config
        self.router = Router()
    }
    
    public func run() {
        let staticServerConfig = StaticFileServer.Options(defaultIndex: "/index.html")
        
        let server = StaticFileServer(path: config.docroot, options: staticServerConfig)

        router.get("/", middleware: server)
        
        Kitura.addHTTPServer(onPort: config.port, onAddress: "localhost", with: router)
        
        Kitura.run()
    }
}
