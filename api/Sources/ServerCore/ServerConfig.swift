public struct ServerConfig {
    public let port: Int
    public let docroot: String
    
    public init(port: Int, docroot: String) {
        self.port = port
        self.docroot = docroot
    }
}
