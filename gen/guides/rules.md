# What is InstantDB

InstantDB is a backend as a service (Baas) that provides optimistic updates,
multiplayer, and offline support for web and mobile applications. It's like
Firebase but it also has support for relations.

Although the product is called InstantDB it is usually just referenced as
Instant. When talking about InstantDB you should just say Instant.

# How to use Instant in projects

Instant offers client side javascript packages for vanilla JS, react,
and react native. Instant also offers a javascript admin SDK that can be used on
the backend.

If you want to use Instant with react you should only use `@instantdb/react`. For react-native you should
only use `@instantdb/react-native`. For the admin SDK you should only use
`@instantdb/admin`. For other client-side frameworks like Svelte or vanilla js
you should only use `@instantdb/core`

You cannot use Instant on the backend outside of the admin SDK at the moment.

# Common mistakes 

Below are some common mistakes when working with Instant

## Common mistakes with schema

❌ **Common mistake**: Reusing the same label for different links
```
// ❌ Bad: Conflicting labels
const _schema = i.schema({
  links: {
    postAuthor: {
      forward: { on: 'posts', has: 'one', label: 'author' },
      reverse: { on: 'profiles', has: 'many', label: 'posts' }, // Creates 'posts' attr
    },
    postEditor: {
      forward: { on: 'posts', has: 'one', label: 'editor' },
      reverse: { on: 'profiles', has: 'many', label: 'posts' }, // Conflicts!
    },
  },
});
```

✅ **Correction**: Use unique labels for each relationship
```
// ✅ Good: Unique labels for each relationship
const _schema = i.schema({
  links: {
    postAuthor: {
      forward: { on: 'posts', has: 'one', label: 'author' },
      reverse: { on: 'profiles', has: 'many', label: 'authoredPosts' }, // Unique
    },
    postEditor: {
      forward: { on: 'posts', has: 'one', label: 'editor' },
      reverse: { on: 'profiles', has: 'many', label: 'editedPosts' }, // Unique
    },
  },
});
```

❌ **Common mistake**: Linking from a system namespace
```
// ❌ Bad: System namespace in forward direction
profileUser: {
  forward: { on: '$users', has: 'one', label: 'profile' },
  reverse: { on: 'profiles', has: 'one', label: '$user' },
},
```

✅ **Correction**: Always link to system namespaces in the reverse direction
```
// ✅ Good: System namespace in reverse direction
profileUser: {
  forward: { on: 'profiles', has: 'one', label: '$user' },
  reverse: { on: '$users', has: 'one', label: 'profile' },
},
```

## Common mistakes with permissions

Sometimes you want to express permissions based an an attribute in a linked entity. For those instance you can use `data.ref`

❌ **Common mistake**: Not using `data.ref` to reference linked data
```
// ❌ Bad: This will throw an error!
{
  "comments": {
    "allow": {
      "update": "auth.id in data.post.author.id
    }
  }
}
```

```
// ✅ Good: Permission based on linked data
{
  "comments": {
    "allow": {
      "update": "auth.id in data.ref('post.author.id')"  // Allow post authors to update comments
    }
  }
}
```

When using `data.ref` the last part of the string is the attribute you want to access. If you do not specify an attribute an error will occur.

❌ **Common mistake**: Not specifying an attribute when using data.ref
```
// ❌ Bad: No attribute specified. This will throw an error!
"view": "auth.id in data.ref('author')"
```

✅ **Correction**: Specify the attribute you want to access
```
// ✅ Good: Correctly using data.ref to reference a linked attribute
"view": "auth.id in data.ref('author.id')"
```

`data.ref` will *ALWAYS* return a CEL list of linked entities. So we must use the `in` operator to check if a value exists in that list.

❌ **Common mistake**: Using `==` to check if a value exists in a list
```
// ❌ Bad: data.ref returns a list! This will throw an error!
"view": "data.ref('admins.id') == auth.id"
```

✅ **Correction**: Use `in` to check if a value exists in a list
```
✅ Good: Checking if a user is in a list of admins
"view": "auth.id in data.ref('admins.id')"
```

Even if you are referencing a one-to-one relationship, `data.ref` will still return a CEL list. You must extract the first element from the list to compare it properly.

❌ **Common mistake**: Using `==` to check if a value matches in a one-to-one relationship
```
// ❌ Bad: data.ref always returns a CEL list. This will throw an error!
"view": "auth.id == data.ref('owner.id')"
```

✅ **Correction**: Extract the first element from the list when using `==`
```
// ✅ Good: Extracting the first element from a one-to-one relationship
"view": "auth.id == data.ref('owner.id')[0]"
```

Be careful when checking whether there are no linked entities. Here are a few correct ways to do this:

❌ **Common mistake**: Incorrectly checking for an empty list
```
// ❌ Bad: `data.ref` returns a CEL list so checking against null will throw an error!
"view": "data.ref('owner.id') != null"

// ❌ Bad: `data.ref` is a CEL list and does not support `length`
"view": "data.ref('owner.id').length > 0"

// ❌ Bad: You must specify an attribute when using `data.ref`
"view": "data.ref('owner') != []"
```

✅ **Correction**: Correct ways to check for an empty list
```
// ✅ Good: Extracting the first element from a CEL list to check if it's empty
"view": "data.ref('owner.id')[0] != null"

// ✅ Good: Checking if the list is empty
"view": "data.ref('owner.id') != []"

// ✅ Good: Check the size of the list
"view": "size(data.ref('owner.id')) > 0"
```

Use `auth.ref` to reference the authenticated user's linked data. This behaves similar to `data.ref` but you *MUST* use the `$user` prefix when referencing auth data:

❌ **Common mistake**: Missing `$user` prefix with `auth.ref`
```
// ❌ Bad: This will throw an error!
{
  "adminActions": {
    "allow": {
      "create": "'admin' in auth.ref('role.type')"
    }
  }
}
```

✅ **Correction**: Use `$user` prefix with `auth.ref`
```
// ✅ Good: Checking user roles
{
  "adminActions": {
    "allow": {
      "create": "'admin' in auth.ref('$user.role.type')"  // Allow admins only
    }
  }
}
```

`auth.ref` returns a CEL list, so use `[0]` to extract the first element when needed.

❌ **Common mistake**: Using `==` to check if auth.ref matches a value
```
// ❌ Bad: auth.ref returns a list! This will throw an error!
"create": "auth.ref('$user.role.type') == 'admin'"
```

✅ **Correction**: Extract the first element from `auth.ref`
```
// ✅ Good: Extracting the first element from auth.ref
"create": "auth.ref('$user.role.type')[0] == 'admin'"
```

For update operations, you can compare the existing (`data`) and updated (`newData`) values.

One difference between `data.ref` and `newData.ref` is that `newData.ref` does not exist. You can only use `newData` to reference the updated attributes directly.

❌ **Common mistake**: `newData.ref` does not exist.
```
// ❌ Bad: This will throw an error!
// This will throw an error because newData.ref does not exist
{
  "posts": {
    "allow": {
      "update": "auth.id == data.authorId && newData.ref('isPublished') == data.ref('isPublished')"
    }
  }
}
```

❌ **Common mistake**: ref arguments must be string literals
```
// ❌ Bad: This will throw an error!
"view": "auth.id in data.ref(someVariable + '.members.id')"
```

✅ **Correction**: Only string literals are allowed
```
// ✅ Good: Using string literals for ref arguments
"view": "auth.id in data.ref('team.members.id')"
```

## Common mistakes with transactions

Always use `update` method to create new entities:

❌ **Common mistake**: Using a non-existent `create` method
```
// ❌ Bad: `create` does not exist, use `update` instead!
db.transact(db.tx.todos[id()].create({ text: "Buy groceries" }));
```

✅ **Correction**: Use `update` to create new entities
```
// ✅ Good: Always use `update` to create new entities
db.transact(db.tx.todos[id()].update({
  text: "Properly generated ID todo"
}));
```

Use `merge` for updating nested objects without overwriting unspecified fields:

❌ **Common mistake**: Using `update` for nested objects
```typescript
// ❌ Bad: This will overwrite the entire preferences object
db.transact(db.tx.profiles[userId].update({
  preferences: { theme: "dark" }  // Any other preferences will be lost
}));
```

✅ **Correction**: Use `merge` to update nested objects
```
// ✅ Good: Update nested values without losing other data
db.transact(db.tx.profiles[userId].merge({
  preferences: {
    theme: "dark"
  }
}));
```

You can use `merge` to remove keys from nested objects by setting the key to `null`:

❌ **Common mistake**: Calling `update` instead of `merge` for removing keys
```
// ❌ Bad: Calling `update` will overwrite the entire preferences object
db.transact(db.tx.profiles[userId].update({
  preferences: {
    notifications: null
  }
}));
```

✅ **Correction**: Use `merge` to remove keys from nested objects
```
// ✅ Good: Remove a nested key
db.transact(db.tx.profiles[userId].merge({
  preferences: {
    notifications: null  // This will remove the notifications key
  }
}));
```

Large transactions can lead to timeouts. To avoid this, break them into smaller batches:

❌ **Common mistake**: Not batching large transactions leads to timeouts
```typescript
import { id } from '@instantdb/react';

const txs = [];
for (let i = 0; i < 1000; i++) {
  txs.push(
    db.tx.todos[id()].update({
      text: `Todo ${i}`,
      done: false
    })
  );
}

// ❌ Bad: This will likely lead to a timeout!
await db.transact(txs);
```

❌ **Common mistake**: Creating too many transactions will also lead to timeouts
```typescript
import { id } from '@instantdb/react';

// ❌ Bad: This fire 1000 transactions at once and will lead to multiple
timeouts!
for (let i = 0; i < 1000; i++) {
  db.transact(
    db.tx.todos[id()].update({
      text: `Todo ${i}`,
      done: false
    })
  );
}

await db.transact(txs);
```



✅ **Correction**: Batch large transactions into smaller ones
```
// ✅ Good: Batch large operations
import { id } from '@instantdb/react';

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

## Common mistakes with queries

Nest namespaces to fetch associated entities:

❌ **Common mistake**: Not nesting namespaces will fetch unrelated entities
```
// ❌ Bad: This will fetch all todos and all goals instead of todos associated with their goals
const query = { goals: {}, todos: {} };
```

✅ **Correction**: Nest namespaces to fetch associated entities
```
// ✅ Good: Fetch goals and their associated todos
const query = { goals: { todos: {} };
```

Use `where` operator to filter entities:

❌ **Common mistake**: Placing `where` at the wrong level
```typescript
// ❌ Bad: Filter must be inside $
const query = {
  goals: {
    where: { id: 'goal-1' },
  },
};
```

✅ **Correction**: Place `where` inside the `$` operator
```typescript
// ✅ Good: Fetch a specific goal by ID
const query = {
  goals: {
    $: {
      where: {
        id: 'goal-1',
      },
    },
  },
};
```

`where` operators support filtering entities based on associated values

❌ **Common mistake**: Incorrect syntax for filtering on associated values
```
// ❌ Bad: This will return an error!
const query = {
  goals: {
    $: {
      where: {
        todos: { title: 'Go running' }, // Wrong: use dot notation instead
      },
    },
  },
};
```

✅ **Correction**: Use dot notation to filter on associated values
```
// ✅ Good: Find goals that have todos with a specific title
const query = {
  goals: {
    $: {
      where: {
        'todos.title': 'Go running',
      },
    },
    todos: {},
  },
};
```

Use `or` inside of `where` to filter associated based on any criteria.

❌ **Common mistake**: Incorrect synax for `or` and `and`
```typescript
// ❌ Bad: This will return an error!
const query = {
  todos: {
    $: {
      where: {
        or: { priority: 'high', dueDate: { $lt: tomorrow } }, // Wrong: 'or' takes an array
      },
    },
  },
};
```

✅ **Correction**: Use an array for `or` and `and` operators
```typescript
// ✅ Good: Find todos that are either high priority OR due soon
const query = {
  todos: {
    $: {
      where: {
        or: [
          { priority: 'high' },
          { dueDate: { $lt: tomorrow } },
        ],
      },
    },
  },
};
```

Using `$gt`, `$lt`, `$gte`, or `$lte` is supported on indexed attributes with checked types:

❌ **Common mistake**: Using comparison on non-indexed attributes
```typescript
// ❌ Bad: Attribute must be indexed for comparison operators
const query = {
  todos: {
    $: {
      where: {
        nonIndexedAttr: { $gt: 5 }, // Will fail if attr isn't indexed
      },
    },
  },
};
```

✅ **Correction**: Use comparison operators on indexed attributes
```typescript
// ✅ Good: Find todos that take more than 2 hours
const query = {
  todos: {
    $: {
      where: {
        timeEstimate: { $gt: 2 },
      },
    },
  },
};

// Available operators: $gt, $lt, $gte, $lte
```

Use `limit` and/or `offset` for simple pagination:

❌ **Common mistake**: Using limit in nested namespaces
```typescript
// ❌ Bad: Limit only works on top-level namespaces. This will return an error!
const query = {
  goals: {
    todos: {
      $: { limit: 5 }, // This won't work
    },
  },
};
```

✅ **Correction**: Use limit on top-level namespaces
```typescript
// ✅ Good: Get first 10 todos
const query = {
  todos: {
    $: { 
      limit: 10 
    },
  },
};

// ✅ Good: Get next 10 todos
const query = {
  todos: {
    $: { 
      limit: 10,
      offset: 10 
    },
  },
};
```

Use the `order` operator to sort results

❌ **Common mistake**: Using `orderBy` instead of `order`
```typescript
// ❌ Bad: `orderBy` is not a valid operator. This will return an error!
const query = {
  todos: {
    $: {
      orderBy: {
        serverCreatedAt: 'desc',
      },
    },
  },
};
```

✅ **Correction**: Use `order` to sort results
```typescript
// ✅ Good: Sort by creation time in descending order
const query = {
  todos: {
    $: {
      order: {
        serverCreatedAt: 'desc',
      },
    },
  },
};
```

❌ **Common mistake**: Ordering non-indexed fields
```typescript
// ❌ Bad: Field must be indexed for ordering
const query = {
  todos: {
    $: {
      order: {
        nonIndexedField: 'desc', // Will fail if field isn't indexed
      },
    },
  },
};
```

## Common mistakes with admin SDK

Use `db.query` in the admin SDK instead of `db.useQuery`. It is an async API without loading states. We wrap queries in try catch blocks to handle errors. Unlike the client SDK, queries in the admin SDK bypass permission checks

❌ **Common mistake**: Using `db.useQuery` in the admin SDK
```javascript
// ❌ Bad: Don't use useQuery on the server
const { data, isLoading, error } = db.useQuery({ todos: {} }); // Wrong approach!
```

✅ **Correction**: Use `db.query` in the admin SDK
```javascript
// ✅ Good: Server-side querying
const fetchTodos = async () => {
  try {
    const data = await db.query({ todos: {} });
    const { todos } = data;
    console.log(`Found ${todos.length} todos`);
    return todos;
  } catch (error) {
    console.error('Error fetching todos:', error);
    throw error;
  }
};
```

## Common mistakes with $users

Since the `$users` namespace is read-only and can't be modified directly, it's recommended to create a `profiles` namespace for storing additional user information.

❌ **Common mistake**: Adding properties to `$users` directly
```typescript
// ❌ Bad: Directly updating $users will throw an error!
db.transact(db.tx.$users[userId].update({ nickname: "Alice" }));
```

✅ **Correction**: Add properties to a linked profile instead
```
// ✅ Good: Update linked profile instead
db.transact(db.tx.profiles[profileId].update({ displayName: "Alice" }));
```

`$users` is a system namespace so we ensure to create links in the reverse direction.

❌ **Common mistake**: Placing `$users` in the forward direction
```typescript
// ❌ Bad: $users must be in the reverse direction
userProfiles: {
  forward: { on: '$users', has: 'one', label: 'profile' },
  reverse: { on: 'profiles', has: 'one', label: '$user' },
},
```

✅ **Correction**: Always link `$users` in the reverse direction
```
// ✅ Good: Create link between profiles and $users
userProfiles: {
  forward: { on: 'profiles', has: 'one', label: '$user' },
  reverse: { on: '$users', has: 'one', label: 'profile' },
},
```

The default permissions only allow users to view their own data. We recommend keeping it this way for security reasons. Instead of viewing all users, you can view all profiles

❌ **Common mistake**: Directly querying $users
```typescript
// ❌ Bad: This will likely only return the current user
db.useQuery({ $users: {} });
```


✅ **Correction**: Directly query the profiles namespace
```typescript
// ✅ Good: View all profiles
db.useQuery({ profiles: {} });
```

## Common mistakes with auth

InstantDB does not provide built-in username/password authentication. 

❌ **Common mistake**: Using password-based authentication in client-side code

✅ **Correction**: Use Instant's magic code or OAuth flows instead in client-side code


If you need traditional password-based authentication, you must implement it as a custom auth flow using the Admin SDK.
# InstantDB Initialization Guide

This guide explains how to initialize an InstantDB project in your application, including how to obtain your app ID using the Instant CLI.

## Getting Your App ID

Before initializing InstantDB in your application, you need to obtain an app ID. The recommended way to do this is using the Instant CLI:

```bash
npx instant-cli@latest init
```

This command will:
1. Guide you through picking an Instant app
2. Generate two essential files:
   - `instant.schema.ts` - defines your application's data model
   - `instant.perms.ts` - defines your permission rules
3. Set up your app ID, which you'll need for initialization

After running the init command, your app ID will be available for use in your environment variables.

## Environment Variables for App ID

The Instant CLI supports multiple environment variable names for storing your app ID:

- `INSTANT_APP_ID` - default for all applications
- `NEXT_PUBLIC_INSTANT_APP_ID` - for Next.js apps
- `PUBLIC_INSTANT_APP_ID` - for Svelte apps
- `VITE_INSTANT_APP_ID` - for Vite apps
- `NUXT_PUBLIC_INSTANT_APP_ID` - for Nuxt apps
- `EXPO_PUBLIC_INSTANT_APP_ID` - for Expo apps

Choose the appropriate variable name based on your framework.

## Initializing InstantDB in Your Application

Once you have your app ID, you can initialize InstantDB in your application. Here's a basic example:

```javascript
import { init } from '@instantdb/react';

const db = init({ appId: process.env.INSTANT_APP_ID });

function App() {
  return <Main />;
}
```

### Adding TypeScript Support

For TypeScript applications, add the schema argument to enable auto-completion and type safety:

```typescript
import { init } from '@instantdb/react';
import schema from './instant.schema';

const db = init({ 
  appId: process.env.INSTANT_APP_ID,
  schema 
});
```

The `schema` file is automatically generated by the CLI during the init process.

### Recommended Pattern: Central DB Instance

While Instant maintains a single connection regardless of how many times you call `init` with the same app ID, it's recommended to create a central DB instance:

```typescript
// lib/db.ts
import { init } from '@instantdb/react';
import schema from '../instant.schema';

export const db = init({
  appId: process.env.INSTANT_APP_ID,
  schema
});
```

This pattern allows you to import the same DB instance throughout your application.

## Updating Your Schema and Permissions

After initial setup, you can modify your data model and permissions:

1. Edit `instant.schema.ts` to update your data model
2. Edit `instant.perms.ts` to update your permission rules
3. Push changes to production:

```bash
# Push schema changes
npx instant-cli@latest push schema

# Push permission changes
npx instant-cli@latest push perms
```

# InstantDB Schema Modeling Guide

This guide explains how to effectively model your data using InstantDB's schema system. InstantDB provides a simple yet powerful way to define your data structure using code.

> **Important Note:** Namespaces that start with `$` (like `$users`) are reserved for system use. The `$users` namespace is special and managed by InstantDB's authentication system.

## Core Concepts

InstantDB's schema consists of three main building blocks:
- **Namespaces**: Collections of entities (similar to tables or collections)
- **Attributes**: Properties/fields of entities with defined types
- **Links**: Relationships between entities in different namespaces
- **Rooms**: Ephemeral namespaces for sharing non-persistent data like cursors

## Setting Up Your Schema

### Creating a Schema File

First, create a `instant.schema.ts` file in your project:

```typescript
// instant.schema.ts
import { i } from '@instantdb/react';

const _schema = i.schema({
  entities: {
    // Define your namespaces here
  },
  links: {
    // Define relationships between namespaces here
  },
  rooms: {
    // Define ephemeral namespaces here (optional)
  },
});

// This helps TypeScript provide better intellisense
type _AppSchema = typeof _schema;
interface AppSchema extends _AppSchema {}
const schema: AppSchema = _schema;

export type { AppSchema };
export default schema;
```

## Defining Namespaces

Namespaces are collections of similar entities. They're equivalent to tables in relational databases.

```typescript
// ✅ Good: Defining namespaces
const _schema = i.schema({
  entities: {
    profiles: i.entity({
      // Attributes defined here
    }),
    posts: i.entity({
      // Attributes defined here
    }),
    comments: i.entity({
      // Attributes defined here
    }),
  },
});
```

❌ **Common mistake**: Creating namespaces that start with `$`
```typescript
// ❌ Bad: Don't create custom namespaces starting with $
const _schema = i.schema({
  entities: {
    $customNamespace: i.entity({
      // This is not allowed!
    }),
  },
});
```

### Namespace Restrictions

- Must be alphanumeric (can include underscores)
- Cannot contain spaces
- Must be unique
- Names starting with `$` are reserved for system namespaces

## Defining Attributes

Attributes are properties of entities within a namespace. They're similar to columns in a relational database.

```typescript
// ✅ Good: Defining attributes with types
const _schema = i.schema({
  entities: {
    posts: i.entity({
      title: i.string(),
      body: i.string(),
      viewCount: i.number(),
      isPublished: i.boolean(),
      publishedAt: i.date(),
      metadata: i.json(),
    }),
  },
});
```

### Available Attribute Types

| Type | Description | Example |
|------|-------------|---------|
| `i.string()` | Text values | `title: i.string()` |
| `i.number()` | Numeric values | `viewCount: i.number()` |
| `i.boolean()` | True/false values | `isPublished: i.boolean()` |
| `i.date()` | Date and time values | `publishedAt: i.date()` |
| `i.json()` | Complex nested objects | `metadata: i.json()` |
| `i.any()` | Untyped values | `miscData: i.any()` |

The `i.date()` type accepts:
- Numeric timestamps (milliseconds)
- ISO 8601 strings (e.g., result of `JSON.stringify(new Date())`)

## Adding Constraints and Performance Optimizations

### Unique Constraints

Unique attributes:
- Are automatically indexed for fast lookups
- Will reject new entities that would violate uniqueness

```typescript
// ✅ Good: Adding a unique constraint
const _schema = i.schema({
  entities: {
    posts: i.entity({
      slug: i.string().unique(), // No two posts can have the same slug
      title: i.string(),
    }),
  },
});
```

### Indexing for Performance

Add indexes to attributes you'll frequently search or filter by:

```typescript
// ✅ Good: Indexing attributes for faster queries
const _schema = i.schema({
  entities: {
    posts: i.entity({
      publishedAt: i.date().indexed(), // Makes date-based filtering faster
      category: i.string().indexed(),  // Makes category filtering faster
    }),
  },
});
```

❌ **Common mistake**: Not indexing frequently queried fields
```typescript
// ❌ Bad: Not indexing a field you'll query often
const _schema = i.schema({
  entities: {
    posts: i.entity({
      category: i.string(), // Not indexed, but frequently used in queries
    }),
  },
});

// Without an index, this query gets slower as your data grows
const query = { posts: { $: { where: { category: 'news' } } } };
```

## Defining Relationships with Links

Links connect entities from different namespaces.

```typescript
// ✅ Good: Defining a link between posts and profiles
const _schema = i.schema({
  entities: {
    // ... namespaces defined here
  },
  links: {
    postAuthor: {
      forward: { on: 'posts', has: 'one', label: 'author' },
      reverse: { on: 'profiles', has: 'many', label: 'authoredPosts' },
    },
  },
});
```

This creates:
- `posts.author` → links to one profile
- `profiles.authoredPosts` → links to many posts

### Link Relationship Types

InstantDB supports four relationship types:

1. **One-to-One**: Each entity in namespace A links to exactly one entity in namespace B, and vice versa

```typescript
// ✅ Good: One-to-one relationship
profileUser: {
  forward: { on: 'profiles', has: 'one', label: '$user', onDelete: 'cascade'  },
  reverse: { on: '$users', has: 'one', label: 'profile', onDelete: 'cascade' },
},
```

2. **One-to-Many**: Each entity in namespace A links to many entities in namespace B, but each entity in B links to only one entity in A

```typescript
// ✅ Good: One-to-many relationship
postAuthor: {
  forward: { on: 'posts', has: 'one', label: 'author' },
  reverse: { on: 'profiles', has: 'many', label: 'authoredPosts' },
},
```

3. **Many-to-One**: The reverse of one-to-many (just swap the directions)

```typescript
// ✅ Good: Many-to-one relationship
postAuthor: {
  forward: { on: 'profiles', has: 'many', label: 'authoredPosts' },
  reverse: { on: 'posts', has: 'one', label: 'author' },
},
```

4. **Many-to-Many**: Each entity in namespace A can link to many entities in namespace B, and vice versa

```typescript
// ✅ Good: Many-to-many relationship
postsTags: {
  forward: { on: 'posts', has: 'many', label: 'tags' },
  reverse: { on: 'tags', has: 'many', label: 'posts' },
},
```

### Link Naming Rules

- Link names must be unique
- Must be alphanumeric (can include underscores)
- Cannot contain spaces
- You can link entities to themselves
- You can link the same entities multiple times (with different link names)

❌ **Common mistake**: Reusing the same label for different links
```typescript
// ❌ Bad: Conflicting labels
const _schema = i.schema({
  links: {
    postAuthor: {
      forward: { on: 'posts', has: 'one', label: 'author' },
      reverse: { on: 'profiles', has: 'many', label: 'posts' }, // Creates 'posts' attr
    },
    postEditor: {
      forward: { on: 'posts', has: 'one', label: 'editor' },
      reverse: { on: 'profiles', has: 'many', label: 'posts' }, // Conflicts!
    },
  },
});
```

✅ **Correction**: Use unique labels for each relationship
```typescript
// ✅ Good: Unique labels for each relationship
const _schema = i.schema({
  links: {
    postAuthor: {
      forward: { on: 'posts', has: 'one', label: 'author' },
      reverse: { on: 'profiles', has: 'many', label: 'authoredPosts' }, // Unique
    },
    postEditor: {
      forward: { on: 'posts', has: 'one', label: 'editor' },
      reverse: { on: 'profiles', has: 'many', label: 'editedPosts' }, // Unique
    },
  },
});
```

### Linking between System Namespaces

When linking to system namespaces like `$users`:

❌ **Common mistake**: Linking from a system namespace
```typescript
// ❌ Bad: System namespace in forward direction
profileUser: {
  forward: { on: '$users', has: 'one', label: 'profile' },
  reverse: { on: 'profiles', has: 'one', label: '$user' },
},
```

✅ **Correction**: Always link to system namespaces in the reverse direction
```typescript
// ✅ Good: System namespace in reverse direction
profileUser: {
  forward: { on: 'profiles', has: 'one', label: '$user' },
  reverse: { on: '$users', has: 'one', label: 'profile' },
},
```

### Cascade Delete

You can configure links to automatically delete dependent entities:

```typescript
// ✅ Good: Setting up cascade delete
const _schema = i.schema({
  links: {
    postAuthor: {
      forward: { on: 'posts', has: 'one', label: 'author', onDelete: 'cascade' },
      reverse: { on: 'profiles', has: 'many', label: 'authoredPosts' },
    },
  },
});
```

With this configuration, deleting a profile will also delete all posts authored by that profile.

## Complete Schema Example

Here's a complete schema for a blog application:

```typescript
// instant.schema.ts
import { i } from '@instantdb/react';

const _schema = i.schema({
  entities: {
    $users: i.entity({
      email: i.string().unique().indexed(),
    }),
    profiles: i.entity({
      nickname: i.string().unique(),
      bio: i.string(),
      createdAt: i.date().indexed(),
    }),
    posts: i.entity({
      title: i.string(),
      slug: i.string().unique().indexed(),
      body: i.string(),
      isPublished: i.boolean().indexed(),
      publishedAt: i.date().indexed(),
    }),
    comments: i.entity({
      body: i.string(),
      createdAt: i.date().indexed(),
    }),
    tags: i.entity({
      name: i.string().unique().indexed(),
    }),
  },
  links: {
    // Deleting a $user will delete their associated profile
    // Also deleting a profile will delete the underlying $user
    profileUser: {
      forward: { on: 'profiles', has: 'one', label: '$user', onDelete: 'cascade' },
      reverse: { on: '$users', has: 'one', label: 'profile', onDelete: 'cascade' },
    },
    postAuthor: {
      // Deleting an author will delete all their associated posts
      // However deleting an authoredPost will not the associated profile
      forward: { on: 'posts', has: 'one', label: 'author', onDelete: 'cascade' },
      reverse: { on: 'profiles', has: 'many', label: 'authoredPosts' },
    },
    commentPost: {
      forward: { on: 'comments', has: 'one', label: 'post', onDelete: 'cascade' },
      reverse: { on: 'posts', has: 'many', label: 'comments' },
    },
    commentAuthor: {
      forward: { on: 'comments', has: 'one', label: 'author', onDelete: 'cascade' },
      reverse: { on: 'profiles', has: 'many', label: 'authoredComments' },
    },
    postsTags: {
      // Deleting posts or tags have no cascading effects
      forward: { on: 'posts', has: 'many', label: 'tags' },
      reverse: { on: 'tags', has: 'many', label: 'posts' },
    },
  },
});

// TypeScript helpers
type _AppSchema = typeof _schema;
interface AppSchema extends _AppSchema {}
const schema: AppSchema = _schema;

export type { AppSchema };
export default schema;
```

## Publishing Your Schema

After defining your schema, **MUST** publish it for it to take effect:

```bash
npx instant-cli@latest push
```

## TypeScript Integration

Leverage utility types for type-safe entities and relationships:

```typescript
// app/page.tsx
import { InstaQLEntity } from '@instantdb/react';
import { AppSchema } from '../instant.schema';

// Type-safe entity from your schema
type Post = InstaQLEntity<AppSchema, 'posts'>;

// Type-safe entity with related data
type PostWithAuthor = InstaQLEntity<AppSchema, 'posts', { author: {} }>;

// Now you can use these types in your components
function PostEditor({ post }: { post: Post }) {
  // TypeScript knows all the properties of the post
  return <h1>{post.title}</h1>;
}
```

## Schema Modifications

You **CANNOT** rename or delete attributes in the CLI. Instead inform users to:

1. Go to the [InstantDB Dashboard](https://instantdb.com/dash)
2. Navigate to "Explorer"
3. Select the namespace you want to modify
4. Click "Edit Schema"
5. Select the attribute you want to modify
6. Use the modal to rename, delete, or change indexing

## Best Practices

1. **Index wisely**: Add indexes to attributes you'll frequently query or filter by
2. **Use unique constraints**: For attributes that should be unique (usernames, slugs, etc.)
3. **Label links clearly**: Use descriptive names for link labels
4. **Consider cascade deletions**: Set `onDelete: 'cascade'` for dependent relationships
5. **Use Utility Types**: Leverage InstantDB's TypeScript integration for better autocomplete and error checking

# InstantDB Permissions Guide

This guide explains how to use InstantDB's Rule Language to secure your application data and implement proper access controls.

## Core Concepts

InstantDB's permission language is built on top of [Google's Common Expression Language
(CEL)](https://github.com/google/cel-spec/blob/master/doc/langdef.md) and allows you to define rules for viewing, creating, updating, and
deleting data.

At a high level, rules define permissions for four operations on a namespace

- **view**: Controls who can read data (used during queries)
- **create**: Controls who can create new entities
- **update**: Controls who can modify existing entities
- **delete**: Controls who can remove entities

## Rules Strucutre

Rules are defined in the `instant.perms.ts` file and follow a specific structure. Below is the JSON schema for the rules:

```typscript
export const rulesSchema = {
  type: 'object',
  patternProperties: {
    '^[$a-zA-Z0-9_\\-]+$': {
      type: 'object',
      properties: {
        allow: {
          type: 'object',
          properties: {
            create: { type: 'string' },
            update: { type: 'string' },
            delete: { type: 'string' },
            view: { type: 'string' },
            $default: { type: 'string' },
          },
          additionalProperties: false,
        },
        bind: {
          type: 'array',
          // Use a combination of "items" and "additionalItems" for validation
          items: { type: 'string' },
          minItems: 2,
        },
      },
      additionalProperties: false,
    },
  },
  additionalProperties: false,
};
```

## Setting Up Permissions

To set up permissions:

1. Generate an `instant.perms.ts` file at the project root:
   ```bash
   npx instant-cli@latest init
   ```

2. Edit the file with your permission rules. Here is an example for a personal
   todo app:

```typescript
// ✅ Good: Define permissions in instant.perms.ts
import type { InstantRules } from '@instantdb/react';

const rules = {
  todos: {
    allow: {
      view: 'auth.id != null',          // Only authenticated users can view
      create: 'isOwner',                // Only owner can create
      update: 'isOwner',                // Only owner can update
      delete: 'isOwner',                // Only owner can delete
    },
    bind: ['isOwner', 'auth.id != null && auth.id == data.creatorId'],
  },
} satisfies InstantRules;

export default rules;
```

3. Push your changes to production:
   ```bash
   npx instant-cli@latest push perms
   ```

## Default Permission Behavior

By default, all permissions are set to `true` (unrestricted access). If a rule is not explicitly defined, it defaults to allowing the operation.

```
// ✅ Good: Explicitly defining all permissions
{
  "todos": {
    "allow": {
      "view": "true",
      "create": "true",
      "update": "true",
      "delete": "true"
    }
  }
}
```

This is equivalent to:

```
{
  "todos": {
    "allow": {
      "view": "true"
      // create, update, delete default to true
    }
  }
}
```

And also equivalent to:

```
// Empty rules = all permissions allowed
{}
```

## Using `$default` in a namespaces

You can explicitly set default rules for all operations within a namespace with
the `$default` keyword:

```
// Deny all permissions by default, then explicitly allow some
{
  "todos": {
    "allow": {
      "$default": "false",       // Default deny all operations
      "view": "auth.id != null"  // But allow viewing for authenticated users
    }
  }
}
```

## Using `auth` and `data` in rules

The `auth` object represents the authenticated user and `data` represents the
current entity being accessed. You can use these objects to create dynamic
rules:

```
// ✅ Good: Using auth and data in rules
{
  "todos": {
    "allow": {
      "view": "auth.id != null",                                // Only authenticated users can view
      "create": "auth.id != null",                              // Only authenticated users can create
      "update": "auth.id != null && auth.id == data.ownerId",   // Only the owner can update
      "delete": "auth.id != null && auth.id == data.ownerId"    // Only the owner can delete
    }
  }
}
```

## Use `bind` for reusable logic

The `bind` feature lets you create aliases and reusable logic for your rules.

Bind is an array of strings where each pair of strings defines a name and its
corresponding expression. You can then reference these names in both `allow` and
in other bind expressions.

Combining bind with `$default` can make writing permission rules much easier:

```
// ✅ Good: Use bind to succinctly define permissions
{
  "todos": {
    "allow": {
      "view": "isLoggedIn",
      "$default": "isOwner || isAdmin", // You can even use `bind` with `$default`
    },
    "bind": [
      "isLoggedIn", "auth.id != null",
      "isOwner", "isLoggedIn && auth.id == data.ownerId",
      "isAdmin", "isLoggedIn && auth.email in ['admin@example.com', 'support@example.com']"
    ]
  }
}
```

## Use `data.ref` for linked data

Sometimes you want to express permissions based an an attribute in a linked entity. For those instance you can use `data.ref`

```
// ✅ Good: Permission based on linked data
{
  "comments": {
    "allow": {
      "update": "auth.id in data.ref('post.author.id')"  // Allow post authors to update comments
    }
  }
}
```

❌ **Common mistake**: Not using `data.ref` to reference linked data
```
// ❌ Bad: This will throw an error!
{
  "comments": {
    "allow": {
      "update": "auth.id in data.post.author.id
    }
  }
}

```

When using `data.ref` the last part of the string is the attribute you want to
access. If you do not specify an attribute an error will occur.

```
// ✅ Good: Correctly using data.ref to reference a linked attribute
"view": "auth.id in data.ref('author.id')"
```

❌ **Common mistake**: Not specifying an attribute when using data.ref
```
// ❌ Bad: No attribute specified. This will throw an error!
"view": "auth.id in data.ref('author')"
```

`data.ref` will *ALWAYS* return a CEL list of linked entities. So we must use the
`in` operator to check if a value exists in that list.

```
✅ Good: Checking if a user is in a list of admins
"view": "auth.id in data.ref('admins.id')"
```

❌ **Common mistake**: Using `==` to check if a value exists in a list
```
// ❌ Bad: data.ref returns a list! This will throw an error!
"view": "data.ref('admins.id') == auth.id"
```

Even if you are referencing a one-to-one relationship, `data.ref` will still return a CEL list. You must extract the first element from the list to compare it properly.

```
// ✅ Good: Extracting the first element from a one-to-one relationship
"view": "auth.id == data.ref('owner.id')[0]"
```

❌ **Common mistake**: Using `==` to check if a value matches in a one-to-one relationship
```
// ❌ Bad: data.ref always returns a CEL list. This will throw an error!
"view": "auth.id == data.ref('owner.id')"
```

Be careful when checking whether there are no linked entities. Here are a few
correct ways to do this:

```
// ✅ Good: Extracting the first element from a CEL list to check if it's empty
"view": "data.ref('owner.id')[0] != null"

// ✅ Good: Checking if the list is empty
"view": "data.ref('owner.id') != []"

// ✅ Good: Check the size of the list
"view": "size(data.ref('owner.id')) > 0"
```

❌ **Common mistake**: Incorrectly checking for an empty list
```
// ❌ Bad: `data.ref` returns a CEL list so checking against null will throw an error!
"view": "data.ref('owner.id') != null"

// ❌ Bad: `data.ref` is a CEL list and does not support `length`
"view": "data.ref('owner.id').length > 0"

// ❌ Bad: You must specify an attribute when using `data.ref`
"view": "data.ref('owner') != []"
```

## Using `auth.ref` for data linked to the current user

Use `auth.ref` to reference the authenticated user's linked data. This behaves
similar to `data.ref` but you *MUST* use the `$user` prefix when referencing auth data:

```
// ✅ Good: Checking user roles
{
  "adminActions": {
    "allow": {
      "create": "'admin' in auth.ref('$user.role.type')"  // Allow admins only
    }
  }
}
```

❌ **Common mistake**: Missing `$user` prefix with `auth.ref`
```
// ❌ Bad: This will throw an error!
{
  "adminActions": {
    "allow": {
      "create": "'admin' in auth.ref('role.type')"
    }
  }
}
```

`auth.ref` returns a CEL list, so use `[0]` to extract the first element when needed.

```
// ✅ Good: Extracting the first element from auth.ref
"create": "auth.ref('$user.role.type')[0] == 'admin'"
```

❌ **Common mistake**: Using `==` to check if auth.ref matches a value
```
// ❌ Bad: auth.ref returns a list! This will throw an error!
"create": "auth.ref('$user.role.type') == 'admin'"
```

## Using `newData` to compare old and new data

For update operations, you can compare the existing (`data`) and updated (`newData`) values:

```
// ✅ Good: Conditionally allowing updates based on changes
{
  "posts": {
    "allow": {
      "update": "auth.id == data.authorId && newData.isPublished == data.isPublished"
      // Authors can update their posts, but can't change the published status
    }
  }
}
```

One difference between `data.ref` and `newData.ref` is that `newData.ref` does not exist. You can only use `newData` to reference the updated attributes directly.

❌ **Common mistake**: `newData.ref` does not exist.
```
// ❌ Bad: This will throw an error!
// This will throw an error because newData.ref does not exist
{
  "posts": {
    "allow": {
      "update": "auth.id == data.authorId && newData.ref('isPublished') == data.ref('isPublished')"
    }
  }
}
```

## Use `ruleParams` for non-auth based permissions

Use `ruleParams` to implement non-auth based permissions like "only people who know my document id can access it"

```typescript
// app/page.tsx
// ✅ Good: Pass along an object containing docId to `useQuery` or `transact` via `ruleParams`
const docId = new URLSearchParams(window.location.search).get("docId")

const query = {
  docs: {},
};
const { data } = db.useQuery(query, {
  ruleParams: { docId }, // Pass the id to ruleParams!
});

// and/or in your transactions:

db.transact(
  db.tx.docs[docId].ruleParams({ docId }).update({ title: 'eat' }),
);
```

```
// instant.perms.ts
// ✅ Good: And then use ruleParams in your permission rules
{
  "documents": {
    "allow": {
      "view": "data.id == ruleParams.docId",
      "update": "data.id == ruleParams.docId",
      "delete": "data.id == ruleParams.docId"
    }
  }
}
```

### `ruleParams` with linked data

You can check `ruleParams` against linked data too

```
// ✅ Good: We can view all comments for a doc if we know the doc id
{
  "comment": {
    "view": "ruleParams.docId in data.ref('doc.id')"
  }
}
```

### `ruleParams` with a list of values

You use a list as the value for a key to `ruleParams` and it will be treated
like a CEL list in permissions

```typescript
// app/page.tsx
// ✅ Good: Pass a list of docIds
db.useQuery({ docs: {} }, { docIds: [id1, id2, ...] })

// instant.perms.ts
{
  "docs": {
    "view": "data.id in ruleParams.docIds"
  }
}
```

## Common Mistakes

Below are some more common mistakes to avoid when writing permission rules:

❌ **Common mistake**: ref arguments must be string literals
```
// ❌ Bad: This will throw an error!
"view": "auth.id in data.ref(someVariable + '.members.id')"
```

✅ **Correction**: Only string literals are allowed
```
"view": "auth.id in data.ref('team.members.id')"
```

## Permission Examples

Below are some permission examples for different types of applications:

### Blog Platform

```typescript
// ✅ Good: Blog platform permissions in instant.perms.ts
import type { InstantRules } from '@instantdb/react';

{
  "posts": {
    "allow": {
      "view": "data.isPublished || isAuthor",                        // Public can see published posts, author can see drafts
      "create": "auth.id != null && isAuthor",                       // Authors can create posts
      "update": "isAuthor || isAdmin",                               // Author or admin can update
      "delete": "isAuthor || isAdmin"                                // Author or admin can delete
    },
    "bind": [
      "isAuthor", "auth.id == data.authorId",
      "isAdmin", "auth.ref('$user.role')[0] == 'admin'"
    ]
  },
  "comments": {
    "allow": {
      "view": "true",
      "create": "isCommentAuthor",
      "update": "isCommentAuthor",
      "delete": "isCommentAuthor || isPostAuthor || isAdmin"
    },
    "bind": [
      "isLoggedIn", "auth.id != null",
      "isPostAuthor", "isLoggedIn && auth.id == data.ref('post.authorId')",
      "isCommentAuthor", "isLoggedIn && auth.id == data.authorId",
      "isAdmin", "auth.ref('$user.role')[0] == 'admin'"
    ]
  }
} satisfies InstantRules;

export default rules;
```

### Todo App

```typescript
// ✅ Good: Todo app permissions in instant.perms.ts
import type { InstantRules } from '@instantdb/react';

const rules = {
  "todos": {
    "allow": {
      "view": "isOwner || isShared",
      "create": "isOwner",
      "update": "isOwner || (isShared && (data.ownerId == newData.ownerId)", // Owner can do anything, shared users can't change ownership
      "delete": "isOwner"
    },
    "bind": [
      "isLoggedIn", "auth.id != null",
      "isShared", "isLoggedIn && auth.id in data.ref('sharedWith.id')",
      "isOwner", "isLoggedIn && auth.id == data.ownerId",
      "isSharedWith", "auth.id in data.ref('sharedWith.id')"
    ]
  },
  "lists": {
    "allow": {
      "$default": "isOwner", // Only owners can create, update, or delete
      "view": "isOwner || isCollaborator" // Owners and collaborators can view
    },
    "bind": [
      "isLoggedIn", "auth.id != null",
      "isOwner", "isLoggedIn && auth.id == data.ownerId",
      "isCollaborator", "isLoggedIn && auth.id in data.ref('collaborators.id')"
    ]
  }
} satisfies InstantRules;

export default rules;
```

# InstaML: InstantDB Transaction API Guide

InstaML is InstantDB's mutation language for creating, updating, and deleting data.

## Core Concepts

- **Transactions**: Groups of operations that execute atomically
- **Transaction Chunks**: Individual operations within a transaction
- **Proxy Syntax**: The `db.tx` object that creates transaction chunks

## Basic Structure

Every transaction follows this pattern:
```typescript
db.transact(db.tx.NAMESPACE[ENTITY_ID].ACTION(DATA));
```

Where:
- `NAMESPACE` is your collection (like "todos" or "users")
- `ENTITY_ID` is the unique ID of an entity. It **MUST** be a valid UUID which can be generated by `id()` or found using `lookup()`.
  `lookup()` to find an existing one.
- `ACTION` is the operation (update, merge, delete, link, unlink)
- `DATA` is the information needed for the action

## Generating valid Entity IDs

Entity IDs must be valid UUIDs. You can generate valid entity IDs using the `id()` or `lookup()` function.

### Generating IDs with `id()`

Use `id()` to generate a new unique ID for an entity:

```typescript
import { id } from '@instantdb/react';

// ✅ Good: Use `id()` to generate a new unique ID
const newTodoId = id();
db.transact(db.tx.todos[newTodoId].update({ text: "New todo" }));

// ✅ Good: You can also inline `id()` directly
db.transact(db.tx.todos[id()].update({ text: "Another todo" }));
```

❌ **Common mistake**: Manually creating non-UUID IDs
```typescript
// ❌ Bad: ids must be valid UUIDs
db.transact(db.tx.todos["todo-" + Math.random().toString(36).substring(2)].update({
  text: "Custom ID todo"
}));
```

### Looking Up by Unique Attributes

Use `lookup` on unique attributes to get or create entity ids. Unique attributes
must be defined in your schema.

```typescript
// instant.schema.ts
import { i } from '@instantdb/react';

const _schema = i.schema({
  entities: {
    $users: i.entity({
      email: i.string().unique().indexed(),
    }),
    profiles: i.entity({
      handle: i.string().unique(),
      role: i.string(),
      bio: i.string(),
    }),
  },
  links: {
    profileUser: {
      forward: { on: 'profiles', has: 'one', label: '$user' },
      reverse: { on: '$users', has: 'one', label: 'profile' },
    },
  },
});

type _AppSchema = typeof _schema;
interface AppSchema extends _AppSchema {}
const schema: AppSchema = _schema;

export type { AppSchema };
export default schema;

// lib/db.ts
import { init } from '@instantdb/react';
import schema from './instant.schema';

export const db = init({
  appId: process.env.INSTANT_APP_ID,
  schema
});

// app/page.tsx
import { lookup } from '@instantdb/react';
import { db } from '../lib/db';

// ✅ Good: Update a profile by looking up a unique attribute
// This will create a new profile if it doesn't exist
// or update the existing one
db.transact(
  db.tx.profiles[lookup('handle', 'nezaj')].update({
    bio: 'I like turtles'
  })
);

```
❌ **Common mistake**: Using lookup on non-unique fields
```typescript
// ... Using same schema as above
// ❌ Bad: Using lookup on a non-unique field will throw an error
db.transact(
  // 'role' is not marked as unique in the schema!
  db.tx.profiles[lookup('role', 'admin')].update({
    bio: 'I like turtles'
  })
);
```

## Creating Entities

### Creating New Entities

Always use `update` method to create new entities:

```typescript
// ✅ Good: Always use `update` to create new entities
db.transact(db.tx.todos[id()].update({
  text: "Properly generated ID todo"
}));
```

❌ **Common mistake**: Using a non-existent `create` method
```typescript
// ❌ Bad: `create` does not exist, use `update` instead!
db.transact(db.tx.todos[id()].create({ text: "Buy groceries" }));
```

❌ **Common mistake**: Calling `update` on `$users` namespace
```typescript
// ❌ Bad: `$users` is a special system table, don't update it directly. You can only link or unlink to it.
db.transact(db.tx.$users[id()].update({
  email: "new-user@instantdb.com"
}));
```

### Storing Different Data Types

You can store various data types in your entities:

```typescript
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

```typescript
// ✅ Good: Update a specific field
// ... Assume todoId is a valid ID of an existing todo
db.transact(db.tx.todos[todoId].update({ done: true }));

// ✅ Good: When linking to $users, use the special $users namespace
// This is an example of how to connect a todo to the current authenticated user
db.transact(db.tx.todos[todoId].link({ $users: auth.userId }));
```

This will only change the specified field(s), leaving other fields untouched.

### Deep Merging Objects

Use `merge` for updating nested objects without overwriting unspecified fields:

```typescript
// ✅ Good: Update nested values without losing other data
db.transact(db.tx.profiles[userId].merge({
  preferences: {
    theme: "dark"
  }
}));
```

❌ **Common mistake**: Using `update` for nested objects
```typescript
// ❌ Bad: This will overwrite the entire preferences object
db.transact(db.tx.profiles[userId].update({
  preferences: { theme: "dark" }  // Any other preferences will be lost
}));
```

### Removing Object Keys

Remove keys from nested objects by setting them to `null`:

```typescript
// ✅ Good: Remove a nested key
db.transact(db.tx.profiles[userId].merge({
  preferences: {
    notifications: null  // This will remove the notifications key
  }
}));
```

❌ **Common mistake**: Calling `update` instead of `merge` for removing keys
```typescript
// ❌ Bad: Calling `update` will overwrite the entire preferences object
db.transact(db.tx.profiles[userId].update({
  preferences: {
    notifications: null
  }
}));
```

## Deleting Entities

Delete entities completely:

```typescript
// ✅ Good: Delete a specific entity
db.transact(db.tx.todos[todoId].delete());
```

Delete multiple entities:

```typescript
// ✅ Good: Delete multiple entities
db.transact([
  db.tx.todos[todoId1].delete(),
  db.tx.todos[todoId2].delete(),
  db.tx.todos[todoId3].delete()
]);
```

Delete all entities that match a condition:

```typescript
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

```typescript
// ✅ Good: Create a new project and todo and link them
import { id } from '@instantdb/react';

const todoId = id();
const projectId = id();
db.transact([
  db.tx.todos[todoId].update({ text: "New todo", done: false }),
  db.tx.projects[projectId].update({ name: "New project" }).link({ todos: todoId
  })
]);
```

Link multiple entities at once:

```typescript
// ✅ Good: Link multiple todos to a project
//... Assume projectId, todoId1, todoId2, todoId3 are already created
db.transact(db.tx.projects[projectId].link({
  todos: [todoId1, todoId2, todoId3]
}));
```

### Linking in Both Directions

Links are bidirectional - you can query from either side:

```typescript
// These do the same thing:
db.transact(db.tx.projects[projectId].link({ todos: todoId }));
db.transact(db.tx.todos[todoId].link({ projects: projectId }));
```

### Removing Links

Remove relationships with `unlink`:

```typescript
// ✅ Good: Unlink a todo from a project
db.transact(db.tx.projects[projectId].unlink({ todos: todoId }));

// Unlink multiple todos at once
db.transact(db.tx.projects[projectId].unlink({
  todos: [todoId1, todoId2, todoId3]
}));
```

## Advanced Features

### Lookups in Relationships

You can use `lookup` to link entities by unique attributes:

```typescript
// ✅ Good: Link entities using lookups
db.transact(
  db.tx.profiles[lookup('email', 'user@example.com')].link({
    projects: lookup('name', 'Project Alpha')
  })
);
```

### Combining Multiple Operations

You can combine multiple operations in a single transaction. This is useful for
creating, updating, and linking entities in one atomic operation:

```typescript
// ✅ Good: Update and link in one transaction
db.transact(
  db.tx.todos[id()]
    .update({ text: "New todo", done: false })
    .link({ projects: projectId })
);
```

```typescript
// ✅ Good: Multiple operations in one atomic transaction
db.transact([
  db.tx.todos[todoId].update({ done: true }),
  db.tx.projects[projectId].update({ completedCount: 10 }),
  db.tx.stats[statsId].merge({ lastCompletedTodo: todoId })
]);
```

## Performance Optimization

### Batching Large Transactions

Large transactions can lead to timeouts. To avoid this, break them into smaller batches:

```typescript
// ✅ Good: Batch large operations
import { id } from '@instantdb/react';

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

❌ **Common mistake**: Not batching large transactions leads to timeouts
```typescript
import { id } from '@instantdb/react';

const txs = [];
for (let i = 0; i < 1000; i++) {
  txs.push(
    db.tx.todos[id()].update({
      text: `Todo ${i}`,
      done: false
    })
  );
}

// ❌ Bad: This will likely lead to a timeout!
await db.transact(txs);
```

❌ **Common mistake**: Creating too many transactions will also lead to timeouts
```typescript
import { id } from '@instantdb/react';

// ❌ Bad: This fire 1000 transactions at once and will lead to multiple
timeouts!
for (let i = 0; i < 1000; i++) {
  db.transact(
    db.tx.todos[id()].update({
      text: `Todo ${i}`,
      done: false
    })
  );
}

await db.transact(txs);
```

## Common Patterns

### Create-or-Update Pattern

Use `lookup` to create or update an entity based on its unique attribute:

```typescript
// ✅ Good: Create if doesn't exist, update if it does
db.transact(
  db.tx.profiles[lookup('email', 'user@example.com')].update({
    lastLoginAt: Date.now()
  })
);
```

### Toggle Boolean Flag

Efficiently toggle boolean values:

```typescript
// ✅ Good: Toggle a todo's completion status
const toggleTodo = (todo) => {
  db.transact(
    db.tx.todos[todo.id].update({ done: !todo.done })
  );
};
```

### Dependent Transactions

Wait for one transaction to complete before starting another:

```typescript
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
      createdAt: Date.now()
    }).link({ project: projectId })
  );
};
```

## Error Handling

You can handle transaction errors by wrapping transactions in a try/catch block

```typescript
try {
  await db.transact(/* ... */);
} catch (error) {
  console.error("Transaction failed:", error);
  // Handle the error appropriately
}
```

# InstaQL: InstantDB Query Language Guide

InstaQL is InstantDB's declarative query language. It uses plain JavaScript objects and arrays without requiring a build step.

## Core Concepts

InstaQL uses a simple yet powerful syntax built on JavaScript objects:

- **Namespaces**: Collections of related entities (similar to tables)
- **Queries**: JavaScript objects describing what data you want
- **Associations**: Relationships between entities in different namespaces


Queris have the following structure

```typescript
{
  namespace1: {
    $: { /* operators for this namespace */ },
    linkedNamespace: {
      $: { /* operators for this linked namespace */ },
    },
  },
  namespace2: { /* ... */ },
  namespace3: { /* ... */ },
  // ..etc
}
```


## Basic Queries

Queries have `isLoading` and `error` states. We **MUST** handle these before
rendering results

```typscript
const { isLoading, data, error } = db.useQuery({ todos: {} })
if (isLoading) { return }
if (error) { return (<div>Error: {error.message}</div>); }

return ( <pre>{JSON.stringify(data, null, 2)}</pre> );
```

In the following sections we show how to use filters, joins, paginations.
To keep these examples focused we won't show the `isLoading` and `error` states
but these must be handled in actual code

### Fetching an Entire Namespace

To fetch all entities from a namespace, use an empty object without any
operators.

```typescript
// ✅ Good: Fetch all goals
const query = { goals: {} };
const { data } = db.useQuery(query);

// Result:
// {
//   "goals": [
//     { "id": "goal-1", "title": "Get fit!" },
//     { "id": "goal-2", "title": "Get promoted!" }
//   ]
// }
```

### Fetching Multiple Namespaces

Query multiple namespaces in one go by specifying mulitple namespaces:

```typescript
// ✅ Good: Fetch both goals and todos
const query = { goals: {}, todos: {} };
const { data } = db.useQuery(query);

// Result:
// {
//   "goals": [...],
//   "todos": [...]
// }
```

❌ **Common mistake**: Nesting namespaces incorrectly
```typescript
// ❌ Bad: This will fetch todos associated with goals instead of all goals and
todos
const query = { goals: { todos: {} };
```

## Filtering

### Fetching by ID

Use `where` operator to filter entities:

```typescript
// ✅ Good: Fetch a specific goal by ID
const query = {
  goals: {
    $: {
      where: {
        id: 'goal-1',
      },
    },
  },
};
```

❌ **Common mistake**: Placing filter at wrong level
```typescript
// ❌ Bad: Filter must be inside $
const query = {
  goals: {
    where: { id: 'goal-1' },
  },
};
```

### Multiple Conditions

Use multiple keys in `where` to filter with multiple conditions (AND logic):

```typescript
// ✅ Good: Fetch completed todos with high priority
const query = {
  todos: {
    $: {
      where: {
        completed: true,
        priority: 'high',
      },
    },
  },
};
```

## Associations (JOIN logic)

### Fetching Related Entities

Nest namespaces to fetch linked entities.

```typescript
// ✅ Good: Fetch goals with their related todos
const query = {
  goals: {
    todos: {},
  },
};

// Result:
// {
//   "goals": [
//     {
//       "id": "goal-1",
//       "title": "Get fit!",
//       "todos": [
//         { "id": "todo-1", "title": "Go running" },
//         { "id": "todo-2", "title": "Eat healthy" }
//       ]
//     },
//     ...
//   ]
// }
```

### Inverse Associations

Links are bidirectional and you can query in the reverse direction

```typescript
// ✅ Good: Fetch todos with their related goals
const query = {
  todos: {
    goals: {},
  },
};
```

### Filtering By Associations

`where` operators support filtering entities based on associated values

```typescript
// ✅ Good: Find goals that have todos with a specific title
const query = {
  goals: {
    $: {
      where: {
        'todos.title': 'Go running',
      },
    },
    todos: {},
  },
};
```

❌ **Common mistake**: Incorrect syntax for filtering on associated values
```typescript
// ❌ Bad: This will return an error!
const query = {
  goals: {
    $: {
      where: {
        todos: { title: 'Go running' }, // Wrong: use dot notation instead
      },
    },
  },
};
```

### Filtering Associations

You can use `where` in a nested namespace to filter out associated entities.

```typescript
// ✅ Good: Get goals with only their completed todos
const query = {
  goals: {
    todos: {
      $: {
        where: {
          completed: true,
        },
      },
    },
  },
};
```

## Logical Operators

### AND Operator

Use `and` inside of `where` to filter associations based on multiple criteria

```typescript
// ✅ Good: Find goals with todos that are both high priority AND due soon
const query = {
  goals: {
    $: {
      where: {
        and: [
          { 'todos.priority': 'high' },
          { 'todos.dueDate': { $lt: tomorrow } },
        ],
      },
    },
  },
};
```

### OR Operator

Use `or` inside of `where` to filter associated based on any criteria.

```typescript
// ✅ Good: Find todos that are either high priority OR due soon
const query = {
  todos: {
    $: {
      where: {
        or: [
          { priority: 'high' },
          { dueDate: { $lt: tomorrow } },
        ],
      },
    },
  },
};
```

❌ **Common mistake**: Incorrect synax for `or` and `and`
```typescript
// ❌ Bad: This will return an error!
const query = {
  todos: {
    $: {
      where: {
        or: { priority: 'high', dueDate: { $lt: tomorrow } }, // Wrong: 'or' takes an array
      },
    },
  },
};
```

### Comparison Operators

Using `$gt`, `$lt`, `$gte`, or `$lte` is supported on indexed attributes with checked types:

```typescript
// ✅ Good: Find todos that take more than 2 hours
const query = {
  todos: {
    $: {
      where: {
        timeEstimate: { $gt: 2 },
      },
    },
  },
};

// Available operators: $gt, $lt, $gte, $lte
```

❌ **Common mistake**: Using comparison on non-indexed attributes
```typescript
// ❌ Bad: Attribute must be indexed for comparison operators
const query = {
  todos: {
    $: {
      where: {
        nonIndexedAttr: { $gt: 5 }, // Will fail if attr isn't indexed
      },
    },
  },
};
```

### IN Operator

Use `in` to match any value in a list:

```typescript
// ✅ Good: Find todos with specific priorities
const query = {
  todos: {
    $: {
      where: {
        priority: { $in: ['high', 'critical'] },
      },
    },
  },
};
```

### NOT Operator

Use `not` to match entities where an attribute doesn't equal a value:

```typescript
// ✅ Good: Find todos not assigned to "work" location
const query = {
  todos: {
    $: {
      where: {
        location: { $not: 'work' },
      },
    },
  },
};
```

Note: This includes entities where the attribute is null or undefined.

### NULL Check

Use `$isNull` to match by null or undefined:

```typescript
// ✅ Good: Find todos with no assigned location
const query = {
  todos: {
    $: {
      where: {
        location: { $isNull: true },
      },
    },
  },
};

// ✅ Good: Find todos that have an assigned location
const query = {
  todos: {
    $: {
      where: {
        location: { $isNull: false },
      },
    },
  },
};
```

### String Pattern Matching

Use `$like` and `$ilike` to match on indexed string attributes:

```typescript
// ✅ Good: Find goals that start with "Get"
const query = {
  goals: {
    $: {
      where: {
        title: { $like: 'Get%' }, // Case-sensitive
      },
    },
  },
};

// For case-insensitive matching:
const query = {
  goals: {
    $: {
      where: {
        title: { $ilike: 'get%' }, // Case-insensitive
      },
    },
  },
};
```

Pattern options:
- `'prefix%'` - Starts with "prefix"
- `'%suffix'` - Ends with "suffix"
- `'%substring%'` - Contains "substring"

## Pagination and Ordering

### Limit and Offset

Use `limit` and/or `offset` for simple pagination:

```typescript
// ✅ Good: Get first 10 todos
const query = {
  todos: {
    $: { 
      limit: 10 
    },
  },
};

// ✅ Good: Get next 10 todos
const query = {
  todos: {
    $: { 
      limit: 10,
      offset: 10 
    },
  },
};
```

❌ **Common mistake**: Using limit in nested namespaces
```typescript
// ❌ Bad: Limit only works on top-level namespaces. This will return an error!
const query = {
  goals: {
    todos: {
      $: { limit: 5 }, // This won't work
    },
  },
};
```

### Ordering

Use the `order` operator to sort results

```typescript
// ✅ Good: Get todos sorted by dueDate
const query = {
  todos: {
    $: {
      order: {
        dueDate: 'asc', // or 'desc'
      },
    },
  },
};

// ✅ Good: Sort by creation time in descending order
const query = {
  todos: {
    $: {
      order: {
        serverCreatedAt: 'desc',
      },
    },
  },
};
```

❌ **Common mistake**: Using `orderBy` instead of `order`
```typescript
// ❌ Bad: `orderBy` is not a valid operator. This will return an error!
const query = {
  todos: {
    $: {
      orderBy: {
        serverCreatedAt: 'desc',
      },
    },
  },
};
```


❌ **Common mistake**: Ordering non-indexed fields
```typescript
// ❌ Bad: Field must be indexed for ordering
const query = {
  todos: {
    $: {
      order: {
        nonIndexedField: 'desc', // Will fail if field isn't indexed
      },
    },
  },
};
```

## Field Selection

Use the `fields` operator to select specific fields to optimize performance:

```typescript
// ✅ Good: Only fetch title and status fields
const query = {
  todos: {
    $: {
      fields: ['title', 'status'],
    },
  },
};

// Result will include the selected fields plus 'id' always:
// {
//   "todos": [
//     { "id": "todo-1", "title": "Go running", "status": "completed" },
//     ...
//   ]
// }
```

This works with nested associations too:

```typescript
// ✅ Good: Select different fields at different levels
const query = {
  goals: {
    $: {
      fields: ['title'],
    },
    todos: {
      $: {
        fields: ['status'],
      },
    },
  },
};
```

## Defer queries

You can defer queries until a condition is met. This is useful when you
need to wait for some data to be available before you can run your query. Here's
an example of deferring a fetch for todos until a user is logged in.

```typescript
const { isLoading, user, error } = db.useAuth();

const {
  isLoading: isLoadingTodos,
  error,
  data,
} = db.useQuery(
  user
    ? {
        // The query will run once user is populated
        todos: {
          $: {
            where: {
              userId: user.id,
            },
          },
        },
      }
    : // Otherwise skip the query, which sets `isLoading` to true
      null,
);
```

## Combining Features

You can combine these features to create powerful queries:

```typescript
// ✅ Good: Complex query combining multiple features
const query = {
  goals: {
    $: {
      where: {
        or: [
          { status: 'active' },
          { 'todos.priority': 'high' },
        ],
      },
      limit: 5,
      order: { serverCreatedAt: 'desc' },
      fields: ['title', 'description'],
    },
    todos: {
      $: {
        where: {
          completed: false,
          dueDate: { $lt: nextWeek },
        },
        fields: ['title', 'dueDate'],
      },
    },
  },
};
```

## Best Practices

1. **Index fields in the schema** that you'll filter, sort, or use in comparisons
2. **Use field selection** to minimize data transfer and re-renders
3. **Defer queries** when dependent data isn't ready
4. **Avoid deep nesting** of associations when possible
5. **Be careful with queries** that might return large result sets, use where
   clauses, limits, and pagination to avoid timeouts

## Troubleshooting

Common errors:

1. **"Field must be indexed"**: Add an index to the field from the Explorer or schema
2. **"Invalid operator"**: Check operator syntax and spelling
3. **"Invalid query structure"**: Verify your query structure, especially $ placement

# InstantDB Server-Side Development Guide

This guide explains how to use InstantDB in server-side javascript environments

## Initializing the Admin SDK

For server-side operations, Instant exposes `@instantdb/admin`. This package has similar functionality to the client SDK but is designed specifically for server environments.

First, install the admin SDK:

```bash
npm install @instantdb/admin
```

Now you can use it in your project

```javascript
// ✅ Good: Proper server-side initialization
import { init, id } from '@instantdb/admin';

const db = init({
  appId: process.env.NEXT_PUBLIC_INSTANT_APP_ID,
  adminToken: process.env.INSTANT_APP_ADMIN_TOKEN,
});
```

❌ **Common mistake**: Using client SDK on the server
```javascript
// ❌ Bad: Don't use the React SDK on the server
import { init } from '@instantdb/react'; // Wrong package!

const db = init({
  appId: process.env.INSTANT_APP_ID,
  adminToken: process.env.INSTANT_APP_ADMIN_TOKEN,
});
```

Hardcoding or exposing your app id is fine but make sure to never expose
your admin token.

❌ **Common mistake**: Exposing admin token in client code
```javascript
// ❌ Bad: Never expose your admin token in client code
const db = init({
  appId: 'app-123',
  adminToken: 'admin-token-abc', // Hardcoded token = security risk!
});
```

For better type safety, include your schema:

```javascript
// ✅ Good: Using schema for type safety
import { init, id } from '@instantdb/admin';
import schema from '../instant.schema'; // Your schema file

const db = init({
  appId: process.env.INSTANT_APP_ID,
  adminToken: process.env.INSTANT_APP_ADMIN_TOKEN,
  schema, // Add your schema here
});
```

## Reading Data from the Server

The structure of queries from the admin sdk is identical to the client SDK

```typescript
{
  namespace: {
    $: { /* operators for this namespace */ },
    linkedNamespace: {
      $: { /* operators for this linked namespace */ },
    },
  },
}
```

Use `db.query` in the admin SDK instead of `db.useQuery`. It is an async
API without loading states. We wrap queries in try catch blocks to handle
errors. Unlike the client SDK, queries in the admin SDK bypass permission
checks

```javascript
// ✅ Good: Server-side querying
const fetchTodos = async () => {
  try {
    const data = await db.query({ todos: {} });
    const { todos } = data;
    console.log(`Found ${todos.length} todos`);
    return todos;
  } catch (error) {
    console.error('Error fetching todos:', error);
    throw error;
  }
};
```

❌ **Common mistake**: Using client-side syntax
```javascript
// ❌ Bad: Don't use useQuery on the server
const { data, isLoading, error } = db.useQuery({ todos: {} }); // Wrong approach!
```


## Writing Data from the Server

Use `db.transact` in the admin SDK to create, update, and delete data.
`db.transact` has the same API and behaves the same in the admin and client SDK. 
The only difference is permission checks are bypassed in the admin SDK.

```javascript
// ✅ Good: Server-side transaction
const createTodo = async (title, dueDate) => {
  try {
    const result = await db.transact(
      db.tx.todos[id()].update({
        title,
        dueDate,
        createdAt: new Date().toISOString(),
        completed: false,
      })
    );
    
    console.log('Created todo with transaction ID:', result['tx-id']);
    return result;
  } catch (error) {
    console.error('Error creating todo:', error);
    throw error;
  }
};
```

## Impersonate a User

Ue `db.asUser` to enforce permission checks for queries and transactions. This
is **ONLY** available in the admin SDK. 

```typescript
// ✅ Good: Impersonating a user by email
const userDb = db.asUser({ email: userEmail });

// ✅ Good: Impersonating a user with a token
const userDb = db.asUser({ token: userToken });

// ✅ Good: Operating as a guest
const guestDb = db.asUser({ guest: true });
};
```


## Retrieve a user

Use `db.auth.getUser` to retrieve an app user. This is **ONLY* available in the admin SDk

```typescript
// ✅ Good: Retrieve a user by email
const user = await db.auth.getUser({ email: 'alyssa_p_hacker@instantdb.com' });

// ✅ Good: Retrieve a user by id
const user = await db.auth.getUser({ id: userId });

// ✅ Good: Retrieve a user by refresh_token.
const user = await db.auth.getUser({ refresh_token: userRefreshToken, });
```

## Delete a user

Use `db.auth.deleteUser` to delete an app user. This is **ONLY* available in the admin SDk

```typescript
// ✅ Good: Delete a user by email
const user = await db.auth.deleteUser({ email: 'alyssa_p_hacker@instantdb.com' });

// ✅ Good: Delete a user by id
const user = await db.auth.deleteUser({ id: userId });

// ✅ Good: Delete a user by refresh_token.
const user = await db.auth.deleteUser({ refresh_token: userRefreshToken, });
```

Note, this _only_ deletes the user record and any associated data with cascade on delete.
If there's additional data to delete you need to do an additional transaction.

## Sign Out Users

Use `db.auth.signOut(email: string)` to sign out an app user. This behaves
differently than the client sdk version. It will invalidate all a user's refresh
tokens and sign out a user everywhere.

```javascript
// ✅ Good: Sign out a user from the server
await db.auth.signOut(email);
```

## Creating Authenticated Endpoints

Use `db.auth.verifyToken` on the server to create authenticated endpoints

```javascript
// ✅ Good: Authenticated API endpoint
app.post('/api/protected-resource', async (req, res) => {
  try {
    // Get the token from request headers
    const token = req.headers.authorization?.replace('Bearer ', '');
    
    if (!token) {
      return res.status(401).json({ error: 'Authentication required' });
    }
    
    // Verify the token
    const user = await db.auth.verifyToken(token);
    
    if (!user) {
      return res.status(401).json({ error: 'Invalid or expired token' });
    }
    
    // Token is valid, proceed with the authenticated request
    // The user object contains the user's information
    console.log(`Request from verified user: ${user.email}`);
    
    // Process the authenticated request
    const { data } = await db.asUser({ email: user.email }).query({
      profiles: { $: { where: { '$user.id': user.id } } }
    });
    
    return res.status(200).json({
      message: 'Authentication successful',
      profile: data.profiles[0]
    });
  } catch (error) {
    console.error('Authentication error:', error);
    return res.status(500).json({ error: 'Server error' });
  }
});
```

And on the client pass along the refresh token to the client

```javascript
// ✅ Good: Frontend calling an authenticated endpoint
const callProtectedApi = async () => {
  const { user } = db.useAuth();
  
  if (!user) {
    console.error('User not authenticated');
    return;
  }
  
  try {
    // ✅ Good: Send the user's refresh token to your endpoint
    const response = await fetch('/api/protected-resource', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${user.refresh_token}`
      },
      body: JSON.stringify({ /* request data */ })
    });
    
    const data = await response.json();
    
    if (!response.ok) {
      throw new Error(data.error || 'API request failed');
    }
    
    return data;
  } catch (error) {
    console.error('API call error:', error);
    throw error;
  }
};
```

## Server-Side use cases

Here are some common use cases you can implement with the admin SDK

### Scheduled Jobs

Running periodic tasks with a scheduler (like cron):

```javascript
// ✅ Good: Scheduled cleanup job
const cleanupExpiredItems = async () => {
  const now = new Date().toISOString();
  
  // Find expired items
  const { expiredItems } = await db.query({
    items: {
      $: {
        where: {
          expiryDate: { $lt: now }
        }
      }
    }
  });
  
  // Delete them
  if (expiredItems.length > 0) {
    await db.transact(
      expiredItems.map(item => db.tx.items[item.id].delete())
    );
    console.log(`Cleaned up ${expiredItems.length} expired items`);
  }
};

// Run this with a scheduler
```

### Data Import/Export

```javascript
// ✅ Good: Exporting data without permission checks
const exportUserData = async (userId) => {
  const data = await db.query({
    profiles: {
      $: { where: { id: userId } },
      authoredPosts: {
        comments: {},
        tags: {}
      }
    }
  });
  
  return JSON.stringify(data, null, 2);
};
```

### Custom Authentication Flows

```javascript
// ✅ Good: Custom sign-up flow
const customSignUp = async (email, userData) => {
  // Create a user in your auth system
  const token = await db.auth.createToken(email);

  // Get the user
  const user = await db.auth.getUser({ refresh_token: token });
  
  // Create a profile with additional data
  await db.transact(
    db.tx.profiles[id()]
      .update({
        ...userData,
        createdAt: new Date().toISOString()
      })
      .link({ $users: user.id })
  );
  
  return user;
};
```

## Conclusion

The InstantDB admin SDK enables server-side operations, allowing you to:

- Run background tasks and scheduled jobs
- Implement custom authentication flows
- Perform administrative operations
- Manage user accounts securely

Always follow best practices by:

- Keeping your admin token secure
- Wrapping transactions in try/catch blocks to handle errors

Remember that the admin SDK bypasses permissions by default

# InstantDB Storage Guide

This guide explains how to use InstantDB Storage to easily upload, manage, and serve files in your applications.

## Core Concepts

InstantDB Storage allows you to:

- Upload files (images, videos, documents, etc.)
- Retrieve file metadata and download URLs
- Delete files
- Link files to other entities in your data model
- Secure files with permissions

Files are stored in a special `$files` namespace that automatically updates when files are added, modified, or removed.

## Getting Started

### Setting Up Schema

First, ensure your schema includes the `$files` namespace:

```typescript
// instant.schema.ts
import { i } from "@instantdb/react";

const _schema = i.schema({
  entities: {
    $files: i.entity({
      path: i.string().unique().indexed(),
      url: i.string(),
    }),
    // Your other entities...
  },
  links: {
    // Your links...
  },
});

// TypeScript helpers
type _AppSchema = typeof _schema;
interface AppSchema extends _AppSchema {}
const schema: AppSchema = _schema;

export type { AppSchema };
export default schema;
```

### Setting Up Permissions

Configure permissions to control who can upload, view, and delete files:

```typescript
// instant.perms.ts
import type { InstantRules } from "@instantdb/react";

const rules = {
  "$files": {
    "allow": {
      "view": "auth.id != null",  // Only authenticated users can view
      "create": "auth.id != null", // Only authenticated users can upload
      "delete": "auth.id != null"  // Only authenticated users can delete
    }
  }
} satisfies InstantRules;

export default rules;
```

Note `update` is currently not supported for `$files` so there is no need to
define an `update` rule for `$files`

> **Note:** For development, you can set all permissions to `"true"`, but for production applications, you should implement proper access controls.

## Uploading Files

### Basic File Upload

```typescript
// ✅ Good: Simple file upload
async function uploadFile(file: File) {
  try {
    await db.storage.uploadFile(file.name, file);
    console.log('File uploaded successfully!');
  } catch (error) {
    console.error('Error uploading file:', error);
  }
}
```

### Custom Path and Options

```typescript
// ✅ Good: Upload with custom path and content type
async function uploadProfileImage(userId: string, file: File) {
  try {
    const path = `users/${userId}/profile.jpg`;
    await db.storage.uploadFile(path, file, {
      contentType: 'image/jpeg',
      contentDisposition: 'inline'
    });
    console.log('Profile image uploaded!');
  } catch (error) {
    console.error('Error uploading profile image:', error);
  }
}
```

### React Component for Image Upload

```tsx
// ✅ Good: Image upload component
function ImageUploader() {
  const [selectedFile, setSelectedFile] = useState<File | null>(null);
  const [preview, setPreview] = useState<string | null>(null);
  const [isUploading, setIsUploading] = useState(false);
  
  // Handle file selection
  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      setSelectedFile(file);
      // Create preview URL
      const previewUrl = URL.createObjectURL(file);
      setPreview(previewUrl);
    }
  };
  
  // Upload the file
  const handleUpload = async () => {
    if (!selectedFile) return;
    
    setIsUploading(true);
    try {
      await db.storage.uploadFile(selectedFile.name, selectedFile);
      // Clean up
      setSelectedFile(null);
      if (preview) {
        URL.revokeObjectURL(preview);
        setPreview(null);
      }
    } catch (error) {
      console.error('Upload failed:', error);
    } finally {
      setIsUploading(false);
    }
  };
  
  return (
    <div className="uploader">
      <input 
        type="file" 
        accept="image/*" 
        onChange={handleFileChange}
        disabled={isUploading} 
      />
      
      {preview && (
        <div className="preview">
          <img src={preview} alt="Preview" />
        </div>
      )}
      
      <button 
        onClick={handleUpload} 
        disabled={!selectedFile || isUploading}
      >
        {isUploading ? 'Uploading...' : 'Upload'}
      </button>
    </div>
  );
}
```

❌ Common mistake: Not handling errors or loading states
```tsx
// ❌ Bad: Missing error handling and loading state
function BadUploader() {
  const handleUpload = async (file) => {
    // No try/catch, no loading state
    await db.storage.uploadFile(file.name, file);
  };
}
```

## Retrieving Files

Files are accessed by querying the `$files` namespace:

### Basic Query

```typescript
// ✅ Good: Query all files
function FileList() {
  const { isLoading, error, data } = db.useQuery({
    $files: {}
  });
  
  if (isLoading) return <div>Loading...</div>;
  if (error) return <div>Error: {error.message}</div>;
  
  const { $files } = data;
  
  return (
    <div>
      <h2>Files ({$files.length})</h2>
      <ul>
        {$files.map(file => (
          <li key={file.id}>
            <a href={file.url} target="_blank" rel="noopener noreferrer">
              {file.path}
            </a>
          </li>
        ))}
      </ul>
    </div>
  );
}
```

### Filtered Query

```typescript
// ✅ Good: Query files with filtering and ordering
function UserImages({ userId }: { userId: string }) {
  const { isLoading, error, data } = db.useQuery({
    $files: {
      $: {
        where: {
          path: { $like: `users/${userId}/%` },
        },
        order: { serverCreatedAt: 'desc' }
      }
    }
  });
  
  if (isLoading) return <div>Loading...</div>;
  if (error) return <div>Error: {error.message}</div>;
  
  const { $files } = data;
  
  return (
    <div className="image-grid">
      {$files.map(file => (
        <div key={file.id} className="image-item">
          <img src={file.url} alt={file.path} />
        </div>
      ))}
    </div>
  );
}
```

## Displaying Images

```tsx
// ✅ Good: Image gallery component
function ImageGallery() {
  const { isLoading, error, data } = db.useQuery({
    $files: {
      $: {
        where: {
          path: { $like: '%.jpg' },
        }
      }
    }
  });
  
  if (isLoading) return <div className="loading">Loading...</div>;
  if (error) return <div className="error">Error: {error.message}</div>;
  
  const { $files: images } = data;
  
  if (images.length === 0) {
    return <div className="empty">No images found</div>;
  }
  
  return (
    <div className="gallery">
      {images.map(image => (
        <div key={image.id} className="gallery-item">
          <img 
            src={image.url} 
            alt={image.path} 
            loading="lazy" 
          />
          <div className="image-info">
            <span>{image.path.split('/').pop()}</span>
          </div>
        </div>
      ))}
    </div>
  );
}
```

## Deleting Files

```typescript
// ✅ Good: Delete a file
async function deleteFile(filePath: string) {
  try {
    await db.storage.delete(filePath);
    console.log(`File ${filePath} deleted successfully`);
  } catch (error) {
    console.error(`Failed to delete ${filePath}:`, error);
  }
}

// ✅ Good: Delete file component
function FileItem({ file }) {
  const [isDeleting, setIsDeleting] = useState(false);
  
  const handleDelete = async () => {
    if (confirm(`Are you sure you want to delete ${file.path}?`)) {
      setIsDeleting(true);
      try {
        await db.storage.delete(file.path);
      } catch (error) {
        console.error('Delete failed:', error);
        alert(`Failed to delete: ${error.message}`);
      } finally {
        setIsDeleting(false);
      }
    }
  };
  
  return (
    <div className="file-item">
      <span>{file.path}</span>
      <button 
        onClick={handleDelete} 
        disabled={isDeleting}
        className="delete-btn"
      >
        {isDeleting ? 'Deleting...' : 'Delete'}
      </button>
    </div>
  );
}
```

## Linking Files to Other Entities

Files can be associated with other entities in your data model. This is useful for features like profile pictures, post attachments, etc.

### Schema Setup

First, define the relationship in your schema:

```typescript
// ✅ Good: Schema with file relationships
import { i } from "@instantdb/react";

const _schema = i.schema({
  entities: {
    $files: i.entity({
      path: i.string().unique().indexed(),
      url: i.string(),
    }),
    profiles: i.entity({
      name: i.string(),
      bio: i.string(),
    }),
    posts: i.entity({
      title: i.string(),
      content: i.string(),
    }),
  },
  links: {
    // Profile avatar - one-to-one relationship
    profileAvatar: {
      forward: { on: 'profiles', has: 'one', label: 'avatar' },
      reverse: { on: '$files', has: 'one', label: 'profile' },
    },
    // Post attachments - one-to-many relationship
    postAttachments: {
      forward: { on: 'posts', has: 'many', label: 'attachments' },
      reverse: { on: '$files', has: 'one', label: 'post' },
    },
  },
});
```

> **Important:** Links to `$files` must be defined with `$files` in the **reverse** direction, similar to `$users`.

### Upload and Link

```typescript
// ✅ Good: Upload and link a profile avatar
async function uploadAvatar(profileId: string, file: File) {
  try {
    // 1. Upload the file
    const path = `profiles/${profileId}/avatar.jpg`;
    const { data } = await db.storage.uploadFile(path, file, {
      contentType: 'image/jpeg'
    });
    
    // 2. Link the file to the profile
    await db.transact(
      db.tx.profiles[profileId].link({ avatar: data.id })
    );
    
    console.log('Avatar uploaded and linked successfully');
  } catch (error) {
    console.error('Failed to upload avatar:', error);
  }
}

// ✅ Good: Upload multiple attachments to a post
async function addPostAttachments(postId: string, files: File[]) {
  try {
    // Process each file
    const fileIds = await Promise.all(
      files.map(async (file, index) => {
        const path = `posts/${postId}/attachment-${index}.${file.name.split('.').pop()}`;
        const { data } = await db.storage.uploadFile(path, file);
        return data.id;
      })
    );
    
    // Link all files to the post
    await db.transact(
      db.tx.posts[postId].link({ attachments: fileIds })
    );
    
    console.log(`${fileIds.length} attachments added to post`);
  } catch (error) {
    console.error('Failed to add attachments:', error);
  }
}
```

### Query Linked Files

```typescript
// ✅ Good: Query profiles with their avatars
function ProfileList() {
  const { isLoading, error, data } = db.useQuery({
    profiles: {
      avatar: {},
    }
  });
  
  if (isLoading) return <div>Loading...</div>;
  if (error) return <div>Error: {error.message}</div>;
  
  const { profiles } = data;
  
  return (
    <div className="profiles">
      {profiles.map(profile => (
        <div key={profile.id} className="profile-card">
          {profile.avatar ? (
            <img 
              src={profile.avatar.url} 
              alt={`${profile.name}'s avatar`} 
              className="avatar"
            />
          ) : (
            <div className="avatar-placeholder">No Avatar</div>
          )}
          <h3>{profile.name}</h3>
          <p>{profile.bio}</p>
        </div>
      ))}
    </div>
  );
}

// ✅ Good: Query a post with its attachments
function PostDetails({ postId }: { postId: string }) {
  const { isLoading, error, data } = db.useQuery({
    posts: {
      $: { where: { id: postId } },
      attachments: {},
    }
  });
  
  if (isLoading) return <div>Loading...</div>;
  if (error) return <div>Error: {error.message}</div>;
  
  const post = data.posts[0];
  if (!post) return <div>Post not found</div>;
  
  return (
    <div className="post">
      <h1>{post.title}</h1>
      <div className="content">{post.content}</div>
      
      {post.attachments && post.attachments.length > 0 && (
        <div className="attachments">
          <h2>Attachments ({post.attachments.length})</h2>
          <div className="attachment-list">
            {post.attachments.map(file => (
              <a 
                key={file.id} 
                href={file.url} 
                target="_blank" 
                rel="noopener noreferrer"
                className="attachment-item"
              >
                {file.path.split('/').pop()}
              </a>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
```

## Permissions for File Storage

`data.path.startsWith` is a useful pattern for writing permissions for `$files`

```typescript
// ✅ Good: Users can only access their own files
const rules = {
  "$files": {
    "allow": {
      "view": "isOwner || isAdmin",
      "create": "isOwner",
      "delete": "isOwner || isAdmin"
    },
    "bind": [
      "isOwner", "data.path.startsWith('users/' + auth.id + '/')",
      "isAdmin", "auth.ref('$user.role') == 'admin'"
    ]
  }
} satisfies InstantRules;
```

## Using Storage with React Native

For React Native applications, you'll need to convert files to a format compatible with InstantDB's storage:

```typescript
// ✅ Good: Upload from React Native
import * as FileSystem from 'expo-file-system';
import { init } from '@instantdb/react-native';
import schema from '../instant.schema';

const db = init({ appId: process.env.EXPO_PUBLIC_INSTANT_APP_ID, schema });

async function uploadFromReactNative(localFilePath: string, uploadPath: string) {
  try {
    // Check if file exists
    const fileInfo = await FileSystem.getInfoAsync(localFilePath);
    if (!fileInfo.exists) {
      throw new Error(`File does not exist at: ${localFilePath}`);
    }
    
    // Convert to a File object
    const response = await fetch(fileInfo.uri);
    const blob = await response.blob();
    
    // Determine file type from extension or use a default
    const extension = localFilePath.split('.').pop()?.toLowerCase();
    let contentType = 'application/octet-stream';
    
    // Set appropriate content type based on extension
    if (extension === 'jpg' || extension === 'jpeg') contentType = 'image/jpeg';
    else if (extension === 'png') contentType = 'image/png';
    else if (extension === 'pdf') contentType = 'application/pdf';
    // Add more types as needed
    
    const file = new File([blob], uploadPath.split('/').pop() || 'file', { 
      type: contentType 
    });
    
    // Upload the file
    await db.storage.uploadFile(uploadPath, file, { contentType });
    console.log('File uploaded successfully!');
    return true;
  } catch (error) {
    console.error('Error uploading file:', error);
    return false;
  }
}
```

## Server-Side Storage Operations

For server-side operations, use the Admin SDK:

### Uploading from the Server

```typescript
// ✅ Good: Server-side file upload
import { init } from '@instantdb/admin';
import fs from 'fs';
import path from 'path';
import schema from '../instant.schema';

const db = init({
  appId: process.env.INSTANT_APP_ID!,
  adminToken: process.env.INSTANT_APP_ADMIN_TOKEN!,
  schema,
});

async function uploadFromServer(localFilePath: string, uploadPath: string) {
  try {
    // Read file as buffer
    const buffer = fs.readFileSync(localFilePath);
    
    // Determine content type based on file extension
    const extension = path.extname(localFilePath).toLowerCase();
    let contentType = 'application/octet-stream';
    
    if (extension === '.jpg' || extension === '.jpeg') contentType = 'image/jpeg';
    else if (extension === '.png') contentType = 'image/png';
    else if (extension === '.pdf') contentType = 'application/pdf';
    // Add more types as needed
    
    // Upload the file
    await db.storage.uploadFile(uploadPath, buffer, {
      contentType,
    });
    
    console.log(`File uploaded to ${uploadPath}`);
    return true;
  } catch (error) {
    console.error('Server upload failed:', error);
    return false;
  }
}
```

### Bulk Deleting Files

```typescript
// ✅ Good: Bulk delete server-side
async function bulkDeleteFiles(pathPattern: string) {
  try {
    // Query files matching the pattern
    const { $files } = await db.query({
      $files: {
        $: {
          where: {
            path: { $like: pathPattern + '%' }
          }
        }
      }
    });
    
    // Extract paths
    const pathsToDelete = $files.map(file => file.path);
    
    if (pathsToDelete.length === 0) {
      console.log('No files found matching pattern');
      return 0;
    }
    
    // Delete in bulk
    await db.storage.deleteMany(pathsToDelete);
    console.log(`Deleted ${pathsToDelete.length} files`);
    return pathsToDelete.length;
  } catch (error) {
    console.error('Bulk delete failed:', error);
    throw error;
  }
}
```

## Best Practices

### File Organization

Uploading to the same path will overwrite files. Use organized file patterns to
correctly update user, project, and application-wide assets

```typescript
// ✅ Good: Organized file paths
// For user-specific files
const userFilePath = `users/${userId}/profile-picture.jpg`;

// For project-based files
const projectFilePath = `projects/${projectId}/documents/${documentId}.pdf`;

// For application-wide files
const publicFilePath = `public/logos/company-logo.png`;
```

## Common Errors and Solutions

1. **"Permission denied" when uploading**: Check your permissions rules for the `$files` namespace
2. **File not appearing after upload**: Ensure your query is correct and you're handling the asynchronous nature of uploads

## Complete Example: Image Gallery

Here's a complete example of an image gallery with upload, display, and delete functionality:

```tsx
import React, { useState, useRef } from 'react';
import { init, InstaQLEntity } from '@instantdb/react';
import schema, { AppSchema } from './instant.schema';

// Initialize InstantDB
const db = init({ 
  appId: process.env.NEXT_PUBLIC_INSTANT_APP_ID!,
  schema 
});

type InstantFile = InstaQLEntity<AppSchema, '$files'>;

function ImageGallery() {
  const [uploading, setUploading] = useState(false);
  const [selectedFile, setSelectedFile] = useState<File | null>(null);
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);
  
  // Query all image files
  const { isLoading, error, data } = db.useQuery({
    $files: {
      $: {
        where: {
          path: { 
            $like: '%.jpg' 
          }
        },
        order: { 
          serverCreatedAt: 'desc' 
        }
      }
    }
  });
  
  // Handle file selection
  const handleFileSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      setSelectedFile(file);
      const objectUrl = URL.createObjectURL(file);
      setPreviewUrl(objectUrl);
    }
  };
  
  // Upload the selected file
  const handleUpload = async () => {
    if (!selectedFile) return;
    
    setUploading(true);
    try {
      await db.storage.uploadFile(selectedFile.name, selectedFile, {
        contentType: selectedFile.type
      });
      
      // Reset state
      setSelectedFile(null);
      if (previewUrl) {
        URL.revokeObjectURL(previewUrl);
        setPreviewUrl(null);
      }
      if (fileInputRef.current) {
        fileInputRef.current.value = '';
      }
    } catch (error) {
      console.error('Upload failed:', error);
      alert('Failed to upload image. Please try again.');
    } finally {
      setUploading(false);
    }
  };
  
  // Delete an image
  const handleDelete = async (file: InstantFile) => {
    if (!confirm(`Are you sure you want to delete ${file.path}?`)) {
      return;
    }
    
    try {
      await db.storage.delete(file.path);
    } catch (error) {
      console.error('Delete failed:', error);
      alert('Failed to delete image. Please try again.');
    }
  };
  
  if (isLoading) {
    return <div className="loading">Loading gallery...</div>;
  }
  
  if (error) {
    return <div className="error">Error: {error.message}</div>;
  }
  
  const { $files: images } = data;
  
  return (
    <div className="image-gallery-container">
      <h1>Image Gallery</h1>
      
      {/* Upload Section */}
      <div className="upload-section">
        <input
          type="file"
          ref={fileInputRef}
          accept="image/jpeg,image/png,image/gif"
          onChange={handleFileSelect}
          disabled={uploading}
        />
        
        {previewUrl && (
          <div className="preview">
            <img src={previewUrl} alt="Preview" />
          </div>
        )}
        
        <button
          onClick={handleUpload}
          disabled={!selectedFile || uploading}
          className="upload-button"
        >
          {uploading ? 'Uploading...' : 'Upload Image'}
        </button>
      </div>
      
      {/* Gallery Section */}
      <div className="gallery">
        {images.length === 0 ? (
          <p>No images yet. Upload some!</p>
        ) : (
          <div className="image-grid">
            {images.map(image => (
              <div key={image.id} className="image-item">
                <img src={image.url} alt={image.path} />
                <div className="image-overlay">
                  <span className="image-name">{image.path.split('/').pop()}</span>
                  <button
                    onClick={() => handleDelete(image)}
                    className="delete-button"
                  >
                    Delete
                  </button>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}

export default ImageGallery;
```

## Best Practices

- Make sure permissions are set for uploads to succeed
- Use organized path based permissions
- Validate image sizes and use compression for performance
- Use proper error handling to debug upload errors
- Links to `$files` must be defined with `$files` in the **reverse** direction, similar to `$users`

# InstantDB User Management Guide

This guide explains how to effectively manage users in your InstantDB applications, covering everything from basic user operations to advanced permission patterns.

## Understanding the `$users` Namespace

InstantDB provides a special system namespace called `$users` for managing user accounts. This namespace:

- Is automatically created for every app
- Contains basic user information (email, ID)
- Has special rules and restrictions
- Requires special handling in schemas and transactions

## Default Permissions

By default, the `$users` namespace has restrictive permissions:

```typescript
// Default permissions for $users
{
  $users: {
    allow: {
      view: 'auth.id == data.id',   // Users can only view their own data
      create: 'false',              // Cannot create users directly
      delete: 'false',              // Cannot delete users directly
      update: 'false',              // Cannot update user properties directly
    },
  },
}
```

These permissions ensure:

- Users can only access their own user data
- No direct modifications to the `$users` namespace
- Authentication operations are handled securely

## Extending User Data

Since the `$users` namespace is read-only and can't be modified directly, you'll need to create additional namespaces and link them to users.

❌ **Common mistake**: Using arrays instead of objects
```typescript
// ❌ Bad: Directly updating $users will throw an error!
db.transact(db.tx.$users[userId].update({ nickname: "Alice" }));
```

```
// ✅ Good: Update linked profile instead
db.transact(db.tx.profiles[profileId].update({ displayName: "Alice" }));
```

It's recommended to create a `profiles` namespace for storing additional user
information.

```typescript
// instant.schema.ts
import { i } from '@instantdb/react';

const _schema = i.schema({
  entities: {
    $users: i.entity({
      email: i.string().unique().indexed(),
    }),
    profiles: i.entity({
      displayName: i.string(),
      bio: i.string(),
      avatarUrl: i.string(),
      location: i.string(),
      joinedAt: i.date().indexed(),
    }),
  },
  links: {
    userProfiles: {
      // ✅ Good: Create link between profiles and $users
      forward: { on: 'profiles', has: 'one', label: '$user' },
      reverse: { on: '$users', has: 'one', label: 'profile' },
    },
  },
});
```

❌ **Common mistake**: Placing `$users` in the forward direction
```typescript
// ❌ Bad: $users must be in the reverse direction
userProfiles: {
  forward: { on: '$users', has: 'one', label: 'profile' },
  reverse: { on: 'profiles', has: 'one', label: '$user' },
},
```

```typescript
// lib/db.ts
import { init } from '@instantdb/react';
import schema from '../instant.schema';

export const db = init({
  appId: process.env.NEXT_PUBLIC_INSTANT_APP_ID!,
  schema
});

// app/page.tsx
import { id } from '@instantdb/react';
import { db } from "../lib/db";

// ✅ Good: Create a profile for a new user
async function createUserProfile(user) {
  const profileId = id();
  await db.transact(
    db.tx.profiles[profileId]
      .update({
        displayName: user.email.split('@')[0], // Default name from email
        bio: '',
        joinedAt: new Date().toISOString(),
      })
      .link({ $user: user.id }) // Link to the user
  );
  
  return profileId;
}
```

## Viewing all users

The default permissions only allow users to view their own data. We recommend
keeping it this way for security reasons. Instead of viewing all users, you can
view all profiles

```typescript
// ✅ Good: View all profiles
db.useQuery({ profiles: {} });
```

❌ **Common mistake**: Directly querying $users
```typescript
// ❌ Bad: This will likely only return the current user
db.useQuery({ $users: {} });
```

## User Relationships

You can model various relationships between users and other entities in your application.

```typescript
// ✅ Good: User posts relationship
const _schema = i.schema({
  entities: {
    $users: i.entity({
      email: i.string().unique().indexed(),
    }),
    profiles: i.entity({
      displayName: i.string(),
      bio: i.string(),
      avatarUrl: i.string(),
      location: i.string(),
      joinedAt: i.date().indexed(),
    }),
    posts: i.entity({
      title: i.string(),
      content: i.string(),
      createdAt: i.date().indexed(),
    }),
  },
  links: {
    userProfiles: {
      forward: { on: 'profiles', has: 'one', label: '$user' },
      reverse: { on: '$users', has: 'one', label: 'profile' },
    },
    postAuthor: {
      forward: { on: 'posts', has: 'one', label: 'author' },
      reverse: { on: 'profiles', has: 'many', label: 'posts' },
    },
  },
});
```

Creating a post:

```typescript
// ✅ Good: Create a post linked to current user
function createPost(title, content, currentProfile) {
  const postId = id();
  return db.transact(
    db.tx.posts[postId]
      .update({
        title,
        content,
        createdAt: new Date().toISOString(),
      })
      .link({ author: currentProfile.id })
  );
}
```

By linking `posts` to `profiles`, you can easily retrieve all posts by a user
through their profile.

```typescript
// ✅ Good: Get all posts for a specific user
// ... assuming currentProfile is already defined
db.useQuery({
  currentProfile
    ? profiles: {
        posts: {},
        $: {
          where: {
            id: currentProfile.id
          }
        }
      }
    : null
  }
});
```

## Conclusion

The `$users` namespace is a system generated namespace that lets you manage
users in InstantDb.

Key takeaways:
1. The `$users` namespace is read-only and cannot be modified directly
2. Always use linked entities to store additional user information
3. When creating links, always put `$users` in the reverse direction

# InstantDB Authentication Guide

This guide explains how to implement user authentication in your InstantDB applications. InstantDB offers multiple authentication methods to suit different application needs and user preferences.

## Authentication Options

InstantDB supports several authentication methods:

1. **Magic Code Authentication** - Email-based passwordless login
2. **Google OAuth** - Sign in with Google accounts
3. **Apple Sign In** - Sign in with Apple ID
4. **Clerk Integration** - Delegate auth to Clerk
5. **Custom Authentication** - Build your own auth flow with the Admin SDK

## Core Authentication Concepts

Before diving into specific methods, let's understand the key authentication concepts:

### Auth Lifecycle

1. **User initiates sign-in** - Triggers the auth flow via email, OAuth provider, etc.
2. **Verification** - User proves their identity (entering a code, OAuth consent, etc.)
3. **Token generation** - InstantDB generates a refresh token for the authenticated user
4. **Session establishment** - The token is used to create a persistent session
5. **User access** - The user can now access protected resources

### The `useAuth` Hook

All authentication methods use the `useAuth` hook to access the current auth state:

```javascript
function App() {
  const { isLoading, user, error } = db.useAuth();

  if (isLoading) return <div>Loading...</div>;
  if (error) return <div>Authentication error: {error.message}</div>;
  if (user) return <AuthenticatedApp user={user} />;
  return <UnauthenticatedApp />;
}
```

Now let's explore each authentication method in detail.

## Magic Code Authentication

Magic code authentication provides a passwordless login experience via email verification codes.
This method is user-friendly and secure, as it eliminates the need for passwords. This is the recommended approach for most applications.

❌ **Common mistake**: Using password-based authentication in client-side code

InstantDB does not provide built-in username/password authentication. If you need traditional password-based authentication, you must implement it as a custom auth flow using the Admin SDK.

### How It Works

1. User enters their email address
2. InstantDB sends a one-time verification code to the email
3. User enters the code
4. InstantDB verifies the code and authenticates the user

### Full Example

Here's a complete example of how to implement magic code authentication using
Next.js, React, and the InstantDB React SDK in a client-side application.

```typescript
// instant.schema.ts
import { i } from '@instantdb/react';

const _schema = i.schema({
  entities: {
    $users: i.entity({
      email: i.string().unique().indexed(),
    }),
  },
});

type _AppSchema = typeof _schema;
interface AppSchema extends _AppSchema {}
const schema: AppSchema = _schema;

export type { AppSchema };
export default schema;

// lib/db.ts
import { init } from '@instantdb/react';
import schema from './instant.schema';

export const db = init({
  appId: process.env.NEXT_PUBLIC_INSTANT_APP_ID!,
  schema
});


// app/page.tsx
"use client";

import React, { useState } from "react";
import { User } from "@instantdb/react";
import { db } from "../lib/db";

function App() {
  // ✅ Good: Use the `useAuth` hook to get the current auth state
  const { isLoading, user, error } = db.useAuth();

  // ✅ Good: Handle loading state
  if (isLoading) {
    return;
  }

  // ✅ Good: Handle error state
  if (error) {
    return <div className="p-4 text-red-500">Uh oh! {error.message}</div>;
  }

  // ✅ Good: Show authenticated content if user exists
  if (user) {
    // The user is logged in! Let's load the `Main`
    return <Main user={user} />;
  }
  // The user isn't logged in yet. Let's show them the `Login` component
  return <Login />;
}

function Main({ user }: { user: User }) {
  return (
    <div className="p-4 space-y-4">
      <h1 className="text-2xl font-bold">Hello {user.email}!</h1>
      {/* ✅ Good: Use the `db.auth.signOut()` to sign out a user */}
      <button
        onClick={() => db.auth.signOut()}
        className="px-3 py-1 bg-blue-600 text-white font-bold hover:bg-blue-700"
      >
        Sign out
      </button>
    </div>
  );
}

function Login() {
  const [sentEmail, setSentEmail] = useState("");

  return (
    <div className="flex justify-center items-center min-h-screen">
      <div className="max-w-sm">
        {!sentEmail ? (
          <EmailStep onSendEmail={setSentEmail} />
        ) : (
          <CodeStep sentEmail={sentEmail} />
        )}
      </div>
    </div>
  );
}

function EmailStep({ onSendEmail }: { onSendEmail: (email: string) => void }) {
  const inputRef = React.useRef<HTMLInputElement>(null);
  const handleSubmit = (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    const inputEl = inputRef.current!;
    const email = inputEl.value;
    onSendEmail(email);
    // ✅ Good: Use the `sendMagicCode` method to send the magic code
    db.auth.sendMagicCode({ email }).catch((err) => {
      alert("Uh oh :" + err.body?.message);
      onSendEmail("");
    });
  };
  return (
    <form
      key="email"
      onSubmit={handleSubmit}
      className="flex flex-col space-y-4"
    >
      <h2 className="text-xl font-bold">Let's log you in</h2>
      <p className="text-gray-700">
        Enter your email, and we'll send you a verification code. We'll create
        an account for you too if you don't already have one.
      </p>
      <input
        ref={inputRef}
        type="email"
        className="border border-gray-300 px-3 py-1  w-full"
        placeholder="Enter your email"
        required
        autoFocus
      />
      <button
        type="submit"
        className="px-3 py-1 bg-blue-600 text-white font-bold hover:bg-blue-700 w-full"
      >
        Send Code
      </button>
    </form>
  );
}

function CodeStep({ sentEmail }: { sentEmail: string }) {
  const inputRef = React.useRef<HTMLInputElement>(null);
  const handleSubmit = (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    const inputEl = inputRef.current!;
    const code = inputEl.value;
    // ✅ Good: Use the `signInWithMagicCode` method to sign in with the code
    db.auth.signInWithMagicCode({ email: sentEmail, code }).catch((err) => {
      inputEl.value = "";
      alert("Uh oh :" + err.body?.message);
    });
  };

  return (
    <form
      key="code"
      onSubmit={handleSubmit}
      className="flex flex-col space-y-4"
    >
      <h2 className="text-xl font-bold">Enter your code</h2>
      <p className="text-gray-700">
        We sent an email to <strong>{sentEmail}</strong>. Check your email, and
        paste the code you see.
      </p>
      <input
        ref={inputRef}
        type="text"
        className="border border-gray-300 px-3 py-1  w-full"
        placeholder="123456..."
        required
        autoFocus
      />
      <button
        type="submit"
        className="px-3 py-1 bg-blue-600 text-white font-bold hover:bg-blue-700 w-full"
      >
        Verify Code
      </button>
    </form>
  );
}

export default App;
```

### Best Practices for Magic Code Auth

1. **Clear Error Handling** - Provide helpful error messages when code sending or verification fails
2. **Loading States** - Show loading indicators during async operations
3. **Resend Functionality** - Allow users to request a new code if needed

## Custom Authentication

For advanced use cases, you can build custom authentication flows using the InstantDB Admin SDK.

### Server-Side Implementation

We can use a Next.js API route to handle custom authentication logic. This example demonstrates a simple email/password validation, but you can adapt it to your needs.

```typescript
// pages/api/auth/login.ts
import { init } from '@instantdb/admin';
import { NextApiRequest, NextApiResponse } from 'next';

// Define the type for the request body
interface LoginRequest {
  email: string;
  password: string;
}

const db = init({
  appId: process.env.NEXT_PUBLIC_INSTANT_APP_ID!,
  adminToken: process.env.INSTANT_ADMIN_TOKEN!,
});

export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse
) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }
  
  const { email, password } = req.body as LoginRequest;
  
  // Custom authentication logic
  const isValid = await validateCredentials(email, password);
  
  if (!isValid) {
    return res.status(401).json({ error: 'Invalid credentials' });
  }
  
  try {
    // ✅ Good: Now that we have validated the user, we can create a token
    // and return it to the client
    const token = await db.auth.createToken(email);
    res.status(200).json({ token });
  } catch (error) {
    res.status(500).json({ error: 'Authentication failed' });
  }
}

// Custom validation function
async function validateCredentials(email: string, password: string): Promise<boolean> {
  // Implement your custom validation logic
  // e.g., check against your database
  return true; // Return true if valid
}
```

### Client-Side Implementation

```typescript
// app/page.tsx
"use client";

import React, { useState } from "react";
import { db } from "../lib/db";

function Login() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [isLoading, setIsLoading] = useState(false);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setIsLoading(true);
    
    try {
      // Call your custom authentication endpoint
      const response = await fetch('/api/auth/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password }),
      });
      
      if (!response.ok) {
        throw new Error('Authentication failed');
      }
      
      const { token } = await response.json();
      
      // ✅ Good: User was authenticated successfully, now sign in with the
      token
      await db.auth.signInWithToken(token);
    } catch (error) {
      console.error("Login failed:", error);
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <form onSubmit={handleSubmit}>
      <input
        type="email"
        value={email}
        onChange={(e) => setEmail(e.target.value)}
        placeholder="Email"
        required
      />
      <input
        type="password"
        value={password}
        onChange={(e) => setPassword(e.target.value)}
        placeholder="Password"
        required
      />
      <button type="submit" disabled={isLoading}>
        {isLoading ? "Signing in..." : "Sign In"}
      </button>
    </form>
  );
}
```

## Google OAuth Authentication

To use Google OAuth with Instant use the docs at https://www.instantdb.com/docs/auth/google-oauth

## Apple Sign In

To use Apple Sign In with Instant use the docs at https://www.instantdb.com/docs/auth/apple

## Clerk Integration

To use Clerk with Instant use the docs at https://www.instantdb.com/docs/auth/clerk

## Authentication Best Practices

For most applications, magic code authentication should the default choice.

# InstantDB Presence, Cursors, and Activity Guide

This guide explains how to add real-time ephemeral features like presence, cursors, and live reactions to your InstantDB applications.

## Core Concepts

InstantDB provides three primitives for building ephemeral experiences:

- **Rooms**: Temporary contexts for real-time events. Users in the same room receive updates from each other
- **Presence**: Persistent state shared between peers in a room (auto-cleaned on disconnect)
- **Topics**: Fire-and-forget events for broadcasting without persistence

### When to Use Each

- **Use `transact`**: When you need to persist data to the database (e.g., sending a chat message)
- **Use `presence`**: When you need temporary persistence in a room (e.g., who's currently online)
- **Use `topics`**: When you need to broadcast without persistence (e.g., live emoji reactions)

## Setting Up Rooms

### Basic Room Setup

```typescript
import { init } from '@instantdb/react';

const db = init({ appId: process.env.NEXT_PUBLIC_INSTANT_APP_ID });

// Create a room with type and ID
const room = db.room('chat', 'room-123');

// Or use default room (auto-generated ID)
const defaultRoom = db.room();
```

### Adding TypeScript Support

Define room schemas for type safety:

```typescript
// instant.schema.ts
import { i } from '@instantdb/react';

const _schema = i.schema({
  entities: {
    // ... your entities
  },
  rooms: {
    chat: {
      presence: i.entity({
        name: i.string(),
        status: i.string(),
        cursorX: i.number(),
        cursorY: i.number(),
      }),
      topics: {
        emoji: i.entity({
          emoji: i.string(),
          x: i.number(),
          y: i.number(),
        }),
        typing: i.entity({
          isTyping: i.boolean(),
        }),
      },
    },
  },
});

type _AppSchema = typeof _schema;
interface AppSchema extends _AppSchema {}
const schema: AppSchema = _schema;

export type { AppSchema };
export default schema;
```

## Working with Presence

### Basic Presence - Who's Online

```typescript
// ✅ Good: Show who's online in a room
function OnlineUsers() {
  const room = db.room('chat', 'room-123');
  
  const {
    user: myPresence,
    peers,
    publishPresence,
  } = db.rooms.usePresence(room, {
    initialData: { 
      name: 'Alice',
      status: 'active' 
    }
  });

  // Update presence when status changes
  const updateStatus = (status: string) => {
    publishPresence({ status });
  };

  if (!myPresence) return <div>Loading...</div>;

  return (
    <div>
      <h3>Online Users</h3>
      <div>You: {myPresence.name} ({myPresence.status})</div>
      <ul>
        {Object.entries(peers).map(([peerId, peer]) => (
          <li key={peerId}>
            {peer.name} ({peer.status})
          </li>
        ))}
      </ul>
    </div>
  );
}
```

### Optimized Presence Subscriptions

```typescript
// ✅ Good: Only subscribe to specific presence keys
const { user, peers, publishPresence } = db.rooms.usePresence(room, {
  keys: ['status'], // Only re-render when status changes
});

// ✅ Good: Write-only presence (no re-renders)
const { publishPresence } = db.rooms.usePresence(room, {
  peers: [],
  user: false,
});
```

### Sync Presence Helper

For simple presence syncing:

```typescript
// ✅ Good: Automatically sync user presence
function ChatRoom({ userId, userName }) {
  const room = db.room('chat', 'room-123');
  
  // Sync presence data
  db.rooms.useSyncPresence(room, {
    id: userId,
    name: userName,
  });
  
  // Rest of your component...
}
```

## Working with Topics

### Publishing and Subscribing to Topics

```typescript
// ✅ Good: Live emoji reactions
function EmojiReactions() {
  const room = db.room('chat', 'room-123');
  
  // Get publish function for emoji topic
  const publishEmoji = db.rooms.usePublishTopic(room, 'emoji');
  
  // Subscribe to emoji events from peers
  db.rooms.useTopicEffect(room, 'emoji', ({ emoji, x, y }) => {
    // Display emoji animation at position
    showEmojiAnimation(emoji, x, y);
  });
  
  const sendEmoji = (emoji: string) => {
    const position = { x: Math.random() * 100, y: Math.random() * 100 };
    
    // Show locally
    showEmojiAnimation(emoji, position.x, position.y);
    
    // Broadcast to peers
    publishEmoji({ emoji, ...position });
  };
  
  return (
    <div>
      <button onClick={() => sendEmoji('🎉')}>🎉</button>
      <button onClick={() => sendEmoji('❤️')}>❤️</button>
      <button onClick={() => sendEmoji('👍')}>👍</button>
    </div>
  );
}
```

## Built-in Components (React Only)

### Cursors Component

Add multiplayer cursors with a single component:

```tsx
// ✅ Good: Basic cursor implementation
import { Cursors } from '@instantdb/react';

function CollaborativeCanvas() {
  const room = db.room('canvas', 'canvas-123');
  
  return (
    <Cursors 
      room={room} 
      className="h-full w-full"
      userCursorColor="tomato"
    >
      <div className="canvas-content">
        Move your cursor around!
      </div>
    </Cursors>
  );
}
```

### Custom Cursor Rendering

```tsx
// ✅ Good: Custom cursor component
function CustomCursorCanvas() {
  const room = db.room('canvas', 'canvas-123');
  
  const renderCursor = ({ color, presence }) => (
    <div style={{ color }}>
      <svg width="20" height="20">
        <circle cx="10" cy="10" r="8" fill={color} />
      </svg>
      <span>{presence.name}</span>
    </div>
  );
  
  return (
    <Cursors 
      room={room}
      renderCursor={renderCursor}
      userCursorColor="blue"
    >
      {/* Your content */}
    </Cursors>
  );
}
```

### Multiple Cursor Spaces

```tsx
// ✅ Good: Separate cursor spaces per tab
function TabbedEditor() {
  const room = db.room('editor', 'doc-123');
  const [activeTab, setActiveTab] = useState(0);
  
  return (
    <div>
      {tabs.map((tab, index) => (
        <div key={tab.id} hidden={activeTab !== index}>
          <Cursors 
            room={room} 
            spaceId={`tab-${tab.id}`}
            className="tab-content"
          >
            {tab.content}
          </Cursors>
        </div>
      ))}
    </div>
  );
}
```

### Typing Indicators

```tsx
// ✅ Good: Chat typing indicator
function ChatInput() {
  const room = db.room('chat', 'room-123');
  const [message, setMessage] = useState('');
  
  // Sync user presence
  db.rooms.useSyncPresence(room, { 
    id: userId,
    name: userName 
  });
  
  // Use typing indicator hook
  const typing = db.rooms.useTypingIndicator(room, 'chat');
  
  const handleKeyDown = (e: React.KeyboardEvent<HTMLTextAreaElement>) => {
    // Handle typing indicator
    typing.inputProps.onKeyDown(e);
    
    // Send message on Enter
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      sendMessage(message);
      setMessage('');
    }
  };
  
  return (
    <div>
      <textarea
        value={message}
        onChange={(e) => setMessage(e.target.value)}
        onKeyDown={handleKeyDown}
        onBlur={typing.inputProps.onBlur}
        placeholder="Type a message..."
      />
      <div className="typing-indicator">
        {typing.active.length > 0 && (
          <span>{formatTypingUsers(typing.active)}</span>
        )}
      </div>
    </div>
  );
}

function formatTypingUsers(users) {
  if (users.length === 1) return `${users[0].name} is typing...`;
  if (users.length === 2) return `${users[0].name} and ${users[1].name} are typing...`;
  return `${users[0].name} and ${users.length - 1} others are typing...`;
}
```

## Complete Example: Collaborative Document

```tsx
// ✅ Good: Full collaborative document example
import { useState } from 'react';
import { init, Cursors } from '@instantdb/react';
import schema from './instant.schema';

const db = init({ 
  appId: process.env.NEXT_PUBLIC_INSTANT_APP_ID,
  schema 
});

function CollaborativeDocument({ docId, userId, userName }) {
  const room = db.room('document', docId);
  const [content, setContent] = useState('');
  
  // Sync user presence
  db.rooms.useSyncPresence(room, {
    id: userId,
    name: userName,
    color: getUserColor(userId),
  });
  
  // Get online users
  const { peers } = db.rooms.usePresence(room);
  
  // Setup typing indicator
  const typing = db.rooms.useTypingIndicator(room, 'editor');
  
  // Setup emoji reactions
  const publishReaction = db.rooms.usePublishTopic(room, 'reaction');
  
  db.rooms.useTopicEffect(room, 'reaction', ({ emoji, userName }) => {
    showNotification(`${userName} reacted with ${emoji}`);
  });
  
  return (
    <div className="collaborative-doc">
      {/* Online users */}
      <div className="online-users">
        {Object.values(peers).map(peer => (
          <div 
            key={peer.id} 
            className="user-avatar"
            style={{ backgroundColor: peer.color }}
          >
            {peer.name[0]}
          </div>
        ))}
      </div>
      
      {/* Document with cursors */}
      <Cursors room={room} className="document-area">
        <textarea
          value={content}
          onChange={(e) => setContent(e.target.value)}
          onKeyDown={typing.inputProps.onKeyDown}
          onBlur={typing.inputProps.onBlur}
          className="document-editor"
        />
      </Cursors>
      
      {/* Typing indicator */}
      {typing.active.length > 0 && (
        <div className="typing-status">
          {formatTypingUsers(typing.active)}
        </div>
      )}
      
      {/* Reaction buttons */}
      <div className="reactions">
        {['👍', '❤️', '🎉'].map(emoji => (
          <button 
            key={emoji}
            onClick={() => publishReaction({ emoji, userName })}
          >
            {emoji}
          </button>
        ))}
      </div>
    </div>
  );
}

function getUserColor(userId: string): string {
  const colors = ['#FF6B6B', '#4ECDC4', '#45B7D1', '#FFA07A', '#98D8C8'];
  const index = userId.charCodeAt(0) % colors.length;
  return colors[index];
}
```

## Common Mistakes

❌ **Using presence for persistent data**
```typescript
// ❌ Bad: This data will be lost when user disconnects
publishPresence({ importantData: 'This should be saved!' });
```

✅ **Use transact for persistent data**
```typescript
// ✅ Good: Save important data to database
db.transact(db.tx.userData[id()].update({ importantData: 'Saved!' }));
```

❌ **Not handling loading states**
```typescript
// ❌ Bad: myPresence might be undefined initially
return <div>Hello {myPresence.name}</div>;
```

✅ **Check for presence data**
```typescript
// ✅ Good: Handle loading state
if (!myPresence) return <div>Loading...</div>;
return <div>Hello {myPresence.name}</div>;
```

## Best Practices

1. **Clean up presence**: Presence is automatically cleaned when users disconnect
2. **Use appropriate primitives**: Choose between transact, presence, and topics based on persistence needs
3. **Type your rooms**: Use schema to get TypeScript support for room data
4. **Optimize subscriptions**: Use `keys` parameter to limit presence updates
5. **Handle connection states**: Check for presence data before rendering
