import std.env
import fountain.orm.*
import fountain.orm.macros.*

@QueryMappersGenerator[uctoo_user]
public class UserPO {
    @ORMField[true 'id']
    private var id: Int64 = 0
    @ORMField['username']
    private var username: String = ''
    @ORMField['password']
    private var password: String = ''
    @ORMField['created_at']
    private var createdAt: ?DateTime = None<DateTime>
    @ORMField['updated_at']
    private var updatedAt: ?DateTime = None<DateTime>
    @ORMField['deleted_at']
    private var deletedAt: ?DateTime = None<DateTime>
    
    public func getId(): Int64 {
        return id
    }
    
    public func getUsername(): String {
        return username
    }
    
    public func setUsername(username: String) {
        this.username = username
    }
    
    public func getPassword(): String {
        return password
    }
    
    public func setPassword(password: String) {
        this.password = password
    }
}

@DAO
public interface UserDAO <: RootDAO {
    func getUserById(id: Int64): Option<UserPO> {
        executor.FROM<UserPO>().WHERE{'id = ${arg(id)}'}.single<UserPO>()
    }
    
    func getUsers(): List<UserPO> {
        executor.FROM<UserPO>().list<UserPO>()
    }
    
    func createUser(username: String, password: String): Int64 {
        executor.setSql('''
            insert into uctoo_user(
                        username,
                        password)
                 values(${arg(username)}, 
                        ${arg(password)})
            returning id'''
        ).insert
    }
}

func initORM() {
    let url = env.getVariable('DATABASE_URL') ?? ''
    ORM.register("opengauss", url, [])
    println("ORM initialized successfully")
}

func testDatabaseConnection() {
    println("Testing database connection...")
    
    try {
        // Use ORM to test connection
        let url = env.getVariable('DATABASE_URL') ?? ''
        ORM.register("opengauss", url, [])
        
        // Test simple query using ORM
        let result = executor().setSql("SELECT 1").query()
        
        if result.next() {
            let value = result.get<Int32>(1)
            println("Query test passed: {value}")
        }
        
        result.close()
        println("Database connected successfully")
    } catch (e: Exception) {
        println("Database connection failed: {e.message}")
        e.printStackTrace()
    }
}

func testORMOperations() {
    println("Testing ORM operations...")
    
    try {
        // Get user by id
        let user = executor().getUserById(1)
        match user {
            case Some(u) => println("Found user: {u.getUsername()}")
            case None => println("User not found")
        }
        
        // Get all users
        let users = executor().getUsers()
        println("Total users: {users.size}")
        
        for (user in users) {
            println("User: {user.getUsername()}")
        }
        
    } catch (e: Exception) {
        println("ORM operation failed: {e.message}")
        e.printStackTrace()
    }
}

main() {
    println("=== Database Test ===")
    
    // Initialize ORM
    initORM()
    
    // Test database connection
    testDatabaseConnection()
    
    // Test ORM operations
    testORMOperations()
    
    println("=== Test completed ===")
}