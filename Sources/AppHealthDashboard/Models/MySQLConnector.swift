import Foundation
import MySQLNIO
import NIOCore
import NIOPosix

public struct MySQLConnector {
    
    public struct ConnectionResult {
        public let success: Bool
        public let message: String
    }
    
    /// Tests connection to the MySQL database with the provided settings.
    public static func testConnection(
        host: String,
        port: Int,
        username: String,
        password: String,
        database: String
    ) async -> ConnectionResult {
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer {
            eventLoopGroup.shutdownGracefully { _ in }
        }
        
        let eventLoop = eventLoopGroup.next()
        
        do {
            let socketAddress = try SocketAddress.makeAddressResolvingHost(host, port: port)
            
            // Connect to MySQL
            let conn = try await MySQLConnection.connect(
                to: socketAddress,
                username: username,
                database: database,
                password: password,
                on: eventLoop
            ).get()
            
            // Execute SELECT 1; to verify queries can be executed
            let rows = try await conn.query("SELECT 1 as one").get()
            
            // Close the connection
            try await conn.close().get()
            
            if let firstRow = rows.first, let val = firstRow.column("one")?.int, val == 1 {
                return ConnectionResult(success: true, message: "Successfully connected and verified query execution.")
            } else {
                return ConnectionResult(success: false, message: "Connected, but verification query (SELECT 1) failed or returned unexpected results.")
            }
            
        } catch {
            return ConnectionResult(success: false, message: "Connection failed: \(error.localizedDescription)")
        }
    }
}
