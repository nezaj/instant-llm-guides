# InstaML: InstantDB Transaction API Guide

InstaML is InstantDB's mutation language for creating, updating, and managing your data. It uses a Firebase-inspired syntax that is intuitive and powerful.

> **Important Note:** In InstantDB, `$users` is a special system table. We don't directly update attributes on this table - we typically only create links and unlinks to it. The examples in this guide use `profiles`, `projects`, and `todos` as the main tables.

## Core Concepts

- **Transactions**: Groups of operations that execute atomically
- **Transaction Chunks**: Individual operations within a transaction
- **Proxy Syntax**: The `db.tx` object that creates transaction chunks

## Basic Structure

Every transaction follows this pattern:
```javascript
db.transact(db.tx.NAMESPACE[ENTITY_ID].ACTION(DATA));
```

Where:
- `NAMESPACE` is your collection (like "todos" or "users")
- `ENTITY_ID` is the unique ID of an entity
- `ACTION` is the operation (update, merge, delete, link, unlink)
- `DATA` is the information needed for the action

## Creating Entities

### Creating New Entities

Use `update` (not `create`) to create new entities:

```javascript
// ✅ Good: Create a new todo with a random ID
const todoId = id();
db.transact(db.tx.todos[todoId].update({
  text: "Buy groceries",
  done: false,
  createdAt: Date.now()
}));

// ✅ Good: Create a new entity with a generated ID inline
db.transact(db.tx.todos[id()].update({
  text: "Walk the dog",
  done: false
}));
```

❌ **Common mistake**: Using a non-existent `create` method
```javascript
// ❌ Bad: This will throw an error!
db.transact(db.tx.todos[id()].create({ text: "Buy groceries" }));
```

### Storing Different Data Types

You can store various data types in your entities:

```javascript
// ✅ Good: Store different types of data
db.transact(db.tx.todos[id()].update({
  text: "Complex todo",          // String
  priority: 1,                   // Number
  completed: false,              // Boolean
  tags: ["work", "important"],   // Array
  metadata: {                    // Object
    assignee: "user-123",
    dueDate: "2025-01-15"
  }
}));
```

## Updating Entities

### Basic Updates

Update existing entities with new values:

```javascript
// ✅ Good: Update a specific field
db.transact(db.tx.todos[todoId].update({ done: true }));

// ✅ Good: When linking to $users, use the special $users namespace
// This is an example of how to connect a todo to the current authenticated user
db.transact(db.tx.todos[todoId].link({ $users: auth.userId }));
```

This will only change the specified field(s), leaving other fields untouched.

### Deep Merging Objects

Use `merge` for updating nested objects without overwriting unspecified fields:

```javascript
// ✅ Good: Update nested values without losing other data
db.transact(db.tx.profiles[userId].merge({
  preferences: {
    theme: "dark"
  }
}));
```

❌ **Common mistake**: Using `update` for nested objects
```javascript
// ❌ Bad: This will overwrite the entire preferences object
db.transact(db.tx.profiles[userId].update({
  preferences: { theme: "dark" }  // Any other preferences will be lost
}));
```

### Removing Object Keys

Remove keys from nested objects by setting them to `null`:

```javascript
// ✅ Good: Remove a nested key
db.transact(db.tx.profiles[userId].merge({
  preferences: {
    notifications: null  // This will remove the notifications key
  }
}));
```

## Deleting Entities

Delete entities completely:

```javascript
// ✅ Good: Delete a specific entity
db.transact(db.tx.todos[todoId].delete());
```

Delete multiple entities:

```javascript
// ✅ Good: Delete multiple entities
db.transact([
  db.tx.todos[todoId1].delete(),
  db.tx.todos[todoId2].delete(),
  db.tx.todos[todoId3].delete()
]);
```

Delete all entities that match a condition:

```javascript
// ✅ Good: Delete all completed todos
const { data } = db.useQuery({ todos: {} });
const completedTodos = data.todos.filter(todo => todo.done);

db.transact(
  completedTodos.map(todo => db.tx.todos[todo.id].delete())
);
```

## Creating Relationships

### Linking Entities

Create relationships between entities:

```javascript
// ✅ Good: Link a todo to a project
db.transact(db.tx.projects[projectId].link({ todos: todoId }));
```

Link multiple entities at once:

```javascript
// ✅ Good: Link multiple todos to a project
db.transact(db.tx.projects[projectId].link({
  todos: [todoId1, todoId2, todoId3]
}));
```

### Linking in Both Directions

Links are bidirectional - you can query from either side:

```javascript
// These do the same thing:
db.transact(db.tx.projects[projectId].link({ todos: todoId }));
db.transact(db.tx.todos[todoId].link({ projects: projectId }));
```

### Removing Links

Remove relationships with `unlink`:

```javascript
// ✅ Good: Unlink a todo from a project
db.transact(db.tx.projects[projectId].unlink({ todos: todoId }));

// Unlink multiple todos at once
db.transact(db.tx.projects[projectId].unlink({
  todos: [todoId1, todoId2, todoId3]
}));
```

## Advanced Features

### Looking Up by Unique Attributes

Use `lookup` to reference entities by unique fields instead of IDs:

```javascript
// ✅ Good: Update a profile by email
import { lookup } from '@instantdb/react';

db.transact(
  db.tx.profiles[lookup('email', 'user@example.com')].update({
    name: 'Updated Name'
  })
);
```

❌ **Common mistake**: Using lookup on non-unique fields
```javascript
// ❌ Bad: Using lookup on a non-unique field may update the wrong entity
db.transact(
  db.tx.profiles[lookup('role', 'admin')].update({
    isSuperAdmin: true
  })
);
```

### Lookups in Relationships

Use `lookup` on both sides of a relationship:

```javascript
// ✅ Good: Link entities using lookups
db.transact(
  db.tx.profiles[lookup('email', 'user@example.com')].link({
    projects: lookup('name', 'Project Alpha')
  })
);
```

### Combining Multiple Operations

Chain operations together:

```javascript
// ✅ Good: Update and link in one transaction
db.transact(
  db.tx.todos[id()]
    .update({ text: "New todo", done: false })
    .link({ projects: projectId })
);
```

Group multiple operations in one transaction:

```javascript
// ✅ Good: Multiple operations in one atomic transaction
db.transact([
  db.tx.todos[todoId].update({ done: true }),
  db.tx.projects[projectId].update({ completedCount: 10 }),
  db.tx.stats[statsId].merge({ lastCompletedTodo: todoId })
]);
```

## Performance Optimization

### Batching Large Transactions

Break large operations into batches:

```javascript
// ✅ Good: Batch large operations
const batchSize = 100;
const createManyTodos = async (count) => {
  for (let i = 0; i < count; i += batchSize) {
    const batch = [];
    
    // Create up to batchSize transactions
    for (let j = 0; j < batchSize && i + j < count; j++) {
      batch.push(
        db.tx.todos[id()].update({
          text: `Todo ${i + j}`,
          done: false
        })
      );
    }
    
    // Execute this batch
    await db.transact(batch);
  }
};

// Create 1000 todos in batches
createManyTodos(1000);
```

## Common Patterns

### Create-or-Update Pattern

Easily implement upsert functionality:

```javascript
// ✅ Good: Create if doesn't exist, update if it does
db.transact(
  db.tx.profiles[lookup('email', 'user@example.com')].update({
    lastLoginAt: Date.now()
  })
);
```

### Toggle Boolean Flag

Efficiently toggle boolean values:

```javascript
// ✅ Good: Toggle a todo's completion status
const toggleTodo = (todo) => {
  db.transact(
    db.tx.todos[todo.id].update({ done: !todo.done })
  );
};
```

### Dependent Transactions

Wait for one transaction to complete before starting another:

```javascript
// ✅ Good: Sequential dependent transactions
const createProjectAndTasks = async (projectData) => {
  // First create the project
  const result = await db.transact(
    db.tx.projects[id()].update(projectData)
  );
  
  // Then create tasks linked to the project
  const projectId = result.ids.projects[0]; // Get ID from the result
  await db.transact(
    db.tx.tasks[id()].update({
      title: "Initial planning",
      projectId,
      createdAt: Date.now()
    })
  );
};
```

## Debugging Tips

1. **Transaction Results**: Transactions return information about created entities

```javascript
const result = await db.transact(db.tx.todos[id()].update({ text: "Debug me" }));
console.log(result.ids); // See the IDs of created entities
```

2. **Error Handling**: Wrap transactions in try/catch

```javascript
try {
  await db.transact(/* ... */);
} catch (error) {
  console.error("Transaction failed:", error);
  // Handle the error appropriately
}
```

## Best Practices

1. **Use `merge` for nested objects** to avoid overwriting unspecified fields
2. **Keep transactions small and focused** for better performance
3. **Batch large operations** to avoid timeouts
4. **Use `lookup` with caution** on fields that are truly unique
5. **Remember that all operations in a transaction are atomic** - they all succeed or all fail
6. **Treat `$users` as a special system table** - only link/unlink to it, don't update it directly

## Comparison with SQL

| SQL Operation | InstantDB Equivalent |
|---------------|----------------------|
| `INSERT INTO todos (text, done) VALUES ('Buy milk', false)` | `db.transact(db.tx.todos[id()].update({ text: 'Buy milk', done: false }))` |
| `UPDATE todos SET done = true WHERE id = '123'` | `db.transact(db.tx.todos['123'].update({ done: true }))` |
| `DELETE FROM todos WHERE id = '123'` | `db.transact(db.tx.todos['123'].delete())` |
| Complex JOIN operation | `db.transact(db.tx.projects[projectId].link({ todos: todoId }))` |

InstantDB's transaction API significantly simplifies these operations compared to SQL, especially for relationships.
