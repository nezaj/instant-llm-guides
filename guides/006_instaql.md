# InstaQL: InstantDB Query Language Guide

InstaQL is InstantDB's declarative query language. It offers GraphQL-like functionality but using plain JavaScript objects and arrays without requiring a build step.

## Core Concepts

InstaQL uses a simple yet powerful syntax built on JavaScript objects:
- **Namespaces**: Collections of related entities (similar to tables)
- **Queries**: JavaScript objects describing what data you want
- **Associations**: Relationships between entities in different namespaces

## Basic Queries

### Fetching an Entire Namespace

To fetch all entities from a namespace, use an empty object:

```javascript
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

❌ **Common mistake**: Using arrays instead of objects
```javascript
// ❌ Bad: This will not work
const query = { goals: [] };
```

### Fetching Multiple Namespaces

Query multiple namespaces in one go:

```javascript
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
```javascript
// ❌ Bad: This will not fetch both namespaces correctly
const query = { goals: { todos: [] } };
```

## Filtering

### Fetching by ID

Use `where` to filter entities:

```javascript
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
```javascript
// ❌ Bad: Filter must be inside $
const query = {
  goals: {
    where: { id: 'goal-1' },
  },
};
```

### Multiple Conditions

Filter with multiple conditions (AND logic):

```javascript
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

## Associations

### Fetching Related Entities

Get entities and their related entities:

```javascript
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

❌ **Common mistake**: Using arrays for associations
```javascript
// ❌ Bad: Associations must be objects, not arrays
const query = {
  goals: {
    todos: [],
  },
};
```

### Inverse Associations

Query in the reverse direction:

```javascript
// ✅ Good: Fetch todos with their related goals
const query = {
  todos: {
    goals: {},
  },
};
```

### Filtering By Associations

Filter entities based on associated data:

```javascript
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

❌ **Common mistake**: Incorrect association path
```javascript
// ❌ Bad: Incorrect association path
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

Filter the associated entities that are returned:

```javascript
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

## Advanced Filtering

### Logical Operators

#### AND Operator

Combine multiple conditions that must all be true:

```javascript
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

#### OR Operator

Match any of the given conditions:

```javascript
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

❌ **Common mistake**: Mixing operators incorrectly
```javascript
// ❌ Bad: Incorrect nesting of operators
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

For indexed fields with checked types:

```javascript
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

❌ **Common mistake**: Using comparison on non-indexed fields
```javascript
// ❌ Bad: Field must be indexed for comparison operators
const query = {
  todos: {
    $: {
      where: {
        nonIndexedField: { $gt: 5 }, // Will fail if field isn't indexed
      },
    },
  },
};
```

### IN Operator

Match any value in a list:

```javascript
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

Match entities where a field doesn't equal a value:

```javascript
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

Note: This includes entities where the field is null or undefined.

### NULL Check

Filter by null/undefined status:

```javascript
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

For indexed string fields:

```javascript
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

For simple pagination:

```javascript
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

❌ **Common mistake**: Using on nested namespaces
```javascript
// ❌ Bad: Limit only works on top-level namespaces
const query = {
  goals: {
    todos: {
      $: { limit: 5 }, // This won't work
    },
  },
};
```

### Cursor-Based Pagination

For more efficient pagination:

```javascript
// ✅ Good: Get first page
const query = {
  todos: {
    $: { 
      first: 10 
    },
  },
};

// ✅ Good: Get next page using cursor
const query = {
  todos: {
    $: { 
      first: 10,
      after: pageInfo.todos.endCursor 
    },
  },
};

// ✅ Good: Get previous page
const query = {
  todos: {
    $: { 
      last: 10,
      before: pageInfo.todos.startCursor 
    },
  },
};
```

❌ **Common mistake**: Using on nested namespaces
```javascript
// ❌ Bad: Cursor pagination only works on top-level namespaces
const query = {
  goals: {
    todos: {
      $: {
        first: 10,
        after: pageInfo.todos.endCursor,
      },
    },
  },
};
```

### Ordering

Change the sort order (default is by creation time):

```javascript
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

❌ **Common mistake**: Ordering non-indexed fields
```javascript
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

Select specific fields to optimize performance:

```javascript
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

```javascript
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

You can also defer queries until a condition is met. This is useful when you
need to wait for some data to be available before you can run your query. Here's
an example of deferring a fetch for todos until a user is logged in.

```javascript
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

## Query once

Sometimes, you don't want a subscription, and just want to fetch data once. For example, you might want to fetch data before rendering a page or check whether a user name is available.

In these cases, you can use `queryOnce` instead of `useQuery`. `queryOnce` returns a promise that resolves with the data once the query is complete.

Unlike `useQuery`, `queryOnce` will throw an error if the user is offline. This is because `queryOnce` is intended for use cases where you need the most up-to-date data.

```javascript
const query = { todos: {} };
const { data } = await db.queryOnce(query);
// returns the same data as useQuery, but without the isLoading and error fields
```

You can also do pagination with `queryOnce`:

```javascript
const query = {
  todos: {
    $: {
      limit: 10,
      offset: 10,
    },
  },
};

const { data, pageInfo } = await db.queryOnce(query);
// pageInfo behaves the same as with useQuery
```


## Combining Features

You can combine these features to create powerful queries:

```javascript
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

1. **Index fields** that you'll filter, sort, or use in comparisons
2. **Use field selection** to minimize data transfer and re-renders
3. **Defer queries** when dependent data isn't ready
4. **Avoid deep nesting** of associations when possible
5. **Be careful with queries** that might return large result sets

## Troubleshooting

Common errors:

1. **"Field must be indexed"**: Add an index to the field from the Explorer or schema
2. **"Invalid operator"**: Check operator syntax and spelling
3. **"Invalid query structure"**: Verify your query structure, especially $ placement

Remember that the query structure is:
```javascript
{
  namespace: {
    $: { /* options for this namespace */ },
    relatedNamespace: {
      $: { /* options for this related namespace */ },
    },
  },
}
```
