import Vapor

func routes(_ app: Application) throws {
    app.get { req async in
        "It works!"
    }

    app.get("hello") { req async -> String in
        "Hello, world!"
    }

    app.on(.POST, "convert", body: .collect(maxSize: "200mb")) { req in
        let base64Array = req.body
        print(base64Array)
        return ""
    }
}
