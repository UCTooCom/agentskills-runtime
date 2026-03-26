import std.env
import fountain.orm.*
import fountain.orm.macros.*

@QueryMappersGenerator[uctoo_entity]
public class EntityPO {
    @ORMField[true 'id']
    private var id: Int64 = 0
    @ORMField['name']
    private var name: String = ''
    @ORMField['code']
    private var code: String = ''
    @ORMField['type']
    private var type: String = ''
    @ORMField['description']
    private var description: String = ''
    @ORMField['created_at']
    private var createdAt: ?DateTime = None<DateTime>
    @ORMField['updated_at']
    private var updatedAt: ?DateTime = None<DateTime>
    @ORMField['deleted_at']
    private var deletedAt: ?DateTime = None<DateTime>
    
    public func getId(): Int64 {
        return id
    }
    
    public func getName(): String {
        return name
    }
    
    public func setName(name: String) {
        this.name = name
    }
    
    public func getCode(): String {
        return code
    }
    
    public func setCode(code: String) {
        this.code = code
    }
    
    public func getType(): String {
        return type
    }
    
    public func setType(type: String) {
        this.type = type
    }
    
    public func getDescription(): String {
        return description
    }
    
    public func setDescription(description: String) {
        this.description = description
    }
}

@DAO
public interface EntityDAO <: RootDAO {
    func getEntityById(id: Int64): Option<EntityPO> {
        executor.FROM<EntityPO>().WHERE{'id = ${arg(id)}'}.single<EntityPO>()
    }
    
    func getEntities(): List<EntityPO> {
        executor.FROM<EntityPO>().list<EntityPO>()
    }
    
    func createEntity(name: String, code: String, type: String, description: String): Int64 {
        executor.setSql('''
            insert into uctoo_entity(
                        name,
                        code,
                        type,
                        description)
                 values(${arg(name)}, 
                        ${arg(code)},
                        ${arg(type)},
                        ${arg(description)})
            returning id'''
        ).insert
    }
}

func initORM() {
    let url = env.getVariable('DATABASE_URL') ?? 'postgresql://postgres:uctoo123@127.0.0.1:5432/uctoo'
    ORM.register("opengauss", url, [])
    println("ORM initialized successfully")
}

func testORM() {
    println("=== Testing ORM in agentskills-runtime ===")
    
    try {
        // Test database connection
        let result = executor().setSql("SELECT 1").query()
        if result.next() {
            let value = result.get<Int32>(1)
            println("Connection test passed: {value}")
        }
        result.close()
        
        // Test get all entities
        println("\nTest: Get all entities")
        let entities = executor().getEntities()
        println("Total entities: {entities.size}")
        for (entity in entities) {
            println("Entity: ID={entity.getId()}, Name={entity.getName()}, Code={entity.getCode()}")
        }
        
        // Test create entity
        println("\nTest: Create a new entity")
        let newEntityId = executor().createEntity("Test Agent Entity", "AGENT_TEST", "agent", "This is a test entity from agentskills-runtime")
        println("Created new entity with ID: {newEntityId}")
        
        // Test get entity by id
        println("\nTest: Get the newly created entity")
        let newEntity = executor().getEntityById(newEntityId)
        match newEntity {
            case Some(entity) => println("Found entity: ID={entity.getId()}, Name={entity.getName()}, Code={entity.getCode()}")
            case None => println("Entity not found")
        }
        
        println("\n=== ORM test in agentskills-runtime completed successfully ===")
    } catch (e: Exception) {
        println("Error: {e.message}")
        e.printStackTrace()
    }
}

main() {
    println("=== Starting ORM test in agentskills-runtime ===")
    
    // Initialize ORM
    initORM()
    
    // Test ORM operations
    testORM()
    
    println("=== ORM test finished ===")
}