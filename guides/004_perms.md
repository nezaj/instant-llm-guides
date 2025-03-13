# InstantDB Permissions Guide

This guide explains how to use InstantDB's Rule Language to secure your application data and implement proper access controls.

## Core Concepts

InstantDB's permission system is based on a declarative rule language that lets you define who can see, create, update, and delete data. This rule language is:

- **Expressive**: Based on CEL (Common Expression Language)
- **Flexible**: Allows referencing relations and user properties
- **Code-First**: Can be defined in code or through the dashboard

## Setting Up Permissions

### Code-Based Approach

The recommended way to manage permissions is by defining them in code:

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

To set up permissions using code:

1. Generate an `instant.perms.ts` file:
   ```bash
   npx instant-cli@latest init
   ```

2. Edit the file with your permission rules

3. Push your changes to production:
   ```bash
   npx instant-cli@latest push perms
   ```

### Dashboard Approach

You can also manage permissions through the InstantDB dashboard:

1. Navigate to your app in the dashboard
2. Open the permissions editor
3. Define your rules using JSON format

## Basic Permission Rules

### Rule Structure

Each namespace can have rules for four operations:

- **view**: Controls who can read data (used during queries)
- **create**: Controls who can create new entities
- **update**: Controls who can modify existing entities
- **delete**: Controls who can remove entities

### Default Permissions

By default, all permissions are set to `true` (unrestricted access). If a rule is not explicitly defined, it defaults to allowing the operation.

```javascript
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

```javascript
// Same as above, with defaults taking effect
{
  "todos": {
    "allow": {
      "view": "true"
    }
  }
}
```

Or even:

```javascript
// Empty rules = all permissions allowed
{}
```

❌ **Common mistake**: Not setting any restrictions in production
```javascript
// ❌ Bad: No restrictions in a production app
{}
```

## Restricting Access

### Authentication-Based Rules

Limit operations to authenticated users:

```javascript
// ✅ Good: Require authentication for all operations
{
  "todos": {
    "allow": {
      "view": "auth.id != null",
      "create": "auth.id != null",
      "update": "auth.id != null",
      "delete": "auth.id != null"
    }
  }
}
```

### Ownership-Based Rules

Restrict operations to the creator of the data:

```javascript
// ✅ Good: Only allow owners to modify their data
{
  "todos": {
    "allow": {
      "view": "auth.id != null",                    // Anyone logged in can view
      "create": "auth.id != null",                  // Anyone logged in can create
      "update": "auth.id != null && auth.id == data.creatorId", // Only owner can update
      "delete": "auth.id != null && auth.id == data.creatorId"  // Only owner can delete
    }
  }
}
```

## Setting Default Permissions

You can set default rules at different levels:

### Namespace Default

Set default rules for all operations within a namespace:

```javascript
// ✅ Good: Deny all permissions by default, then explicitly allow some
{
  "todos": {
    "allow": {
      "$default": "false",       // Default deny all operations
      "view": "auth.id != null"  // But allow viewing for authenticated users
    }
  }
}
```

### Global Default

Set default rules for all namespaces:

```javascript
// ✅ Good: Secure by default with specific exceptions
{
  "$default": {
    "allow": {
      "view": "false",    // Default deny viewing for all namespaces
      "create": "false",  // Default deny creation for all namespaces
      "update": "false",  // Default deny updates for all namespaces
      "delete": "false"   // Default deny deletion for all namespaces
    }
  },
  "publicPosts": {
    "allow": {
      "view": "true"      // Allow viewing public posts for everyone
    }
  }
}
```

### Ultimate Default

The most restrictive configuration:

```javascript
// Denies all permissions unless explicitly allowed
// Doing this will block new namespaces from being viewed or modified
// unless you set permissions for them, for production this can be good
// but for development it can be annoying
{
  "$default": {
    "allow": {
      "$default": "false"  // Default deny all operations on all namespaces
    }
  }
}
```

If 

## Advanced Permission Features

### Using Bind for Reusable Logic

The `bind` feature lets you create aliases for complex permission rules:

```javascript
// ✅ Good: Using bind for reusable permission logic
{
  "todos": {
    "allow": {
      "create": "isOwner || isAdmin",
      "update": "isOwner || isAdmin",
      "delete": "isOwner || isAdmin"
    },
    "bind": [
      "isOwner", "auth.id != null && auth.id == data.creatorId",
      "isAdmin", "auth.email in ['admin@example.com', 'support@example.com']"
    ]
  }
}
```

This makes your permission rules more readable and maintainable.

### Referencing Related Data

Use `ref` to check permissions based on related entities:

```javascript
// ✅ Good: Permission based on related data
{
  "comments": {
    "allow": {
      "update": "auth.id in data.ref('post.author.id')"  // Allow post authors to update comments
    }
  }
}
```

### Checking Auth User Relations

You can also reference the authenticated user's relations:

```javascript
// ✅ Good: Checking user roles
{
  "adminActions": {
    "allow": {
      "create": "'admin' in auth.ref('$user.role.type')"  // Allow admins only
    }
  }
}
```

### Comparing Old and New Data

For update operations, you can compare the existing (`data`) and updated (`newData`) values:

```javascript
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

## Special Permission: Attrs

The `attrs` permission controls the ability to create new attribute types on the fly:

```javascript
// ✅ Good: Prevent schema expansion in production
{
  "attrs": {
    "allow": {
      "create": "false"  // Prevent creating new attribute types
    }
  }
}
```

This is particularly important in production to lock down your schema.

## Common Pitfalls and Mistakes

### ❌ Missing `$user` prefix with `auth.ref`

```javascript
// Incorrect - auth.ref must use the $user prefix
"delete": "'admin' in auth.ref('roles.name')"

// Correct
"delete": "'admin' in auth.ref('$user.roles.name')"
```

### ❌ Using complex expressions directly in `ref`

```javascript
// Incorrect - ref arguments must be string literals
"view": "auth.id in data.ref(someVariable + '.members.id')"

// Correct - ref arguments should be string literals
"view": "auth.id in data.ref('team.members.id')"
```

### ❌ Not using collection operators properly

```javascript
// Incorrect - cannot use == with a list
"view": "data.ref('admins.id') == auth.id"

// Correct
"view": "auth.id in data.ref('admins.id')"
```

### ❌ Using wrong comparison types

```javascript
// Incorrect - comparing string to number without conversion
"view": "data.count == '5'"

// Correct
"view": "data.count == 5" 
```

### Security Patterns

#### Public Read, Authenticated Write

```javascript
// ✅ Good: Public read, authenticated write
{
  "posts": {
    "allow": {
      "view": "true",                  // Anyone can view
      "create": "auth.id != null",     // Only authenticated users can create
      "update": "auth.id == data.authorId", // Only author can update
      "delete": "auth.id == data.authorId"  // Only author can delete
    }
  }
}
```

#### Team-Based Access

```javascript
// ✅ Good: Team-based access control
{
  "projects": {
    "allow": {
      "view": "auth.id in data.ref('team.members.id')", // Team members can view
      "update": "auth.id in data.ref('team.admins.id')" // Team admins can update
    }
  }
}
```

#### Role-Based Access

```javascript
// ✅ Good: Role-based access control
{
  "systemSettings": {
    "allow": {
      "view": "auth.ref('$user.role.level') >= 1",  // Basic role can view
      "update": "auth.ref('$user.role.level') >= 3" // High-level role can update
    }
  }
}
```

## Common Permission Examples

### Blog Platform

```javascript
// ✅ Good: Blog platform permissions in instant.perms.ts
import type { InstantRules } from '@instantdb/react';

{
  "posts": {
    "allow": {
      "view": "true || data.isPublished || auth.id == data.authorId", // Public can see published posts, author can see drafts
      "create": "auth.id != null",                                    // Logged-in users can create
      "update": "auth.id == data.authorId",                           // Author can update
      "delete": "auth.id == data.authorId || isAdmin"                 // Author or admin can delete
    },
    "bind": [
      "isAdmin", "auth.ref('$user.role') == 'admin'"
    ]
  },
  "comments": {
    "allow": {
      "view": "true",                        // Everyone can see comments
      "create": "auth.id != null",           // Logged-in users can comment
      "update": "auth.id == data.authorId",  // Author can edit their comment
      "delete": "auth.id == data.authorId || auth.id == data.ref('post.authorId') || isAdmin" // Comment author, post author, or admin can delete
    }
  }
} satisfies InstantRules;

export default rules;
```

### Todo App

```javascript
// ✅ Good: Todo app permissions in instant.perms.ts
import type { InstantRules } from '@instantdb/react';

const rules = {
  "todos": {
    "allow": {
      "view": "auth.id == data.ownerId || auth.id in data.ref('sharedWith.id')", // Owner or shared-with can view
      "create": "auth.id != null",                                               // Any logged-in user can create
      "update": "auth.id == data.ownerId || (auth.id in data.ref('sharedWith.id') && !newData.hasOwnProperty('ownerId'))", // Owner can do anything, shared users can't change ownership
      "delete": "auth.id == data.ownerId"                                        // Only owner can delete
    }
  },
  "lists": {
    "allow": {
      "view": "auth.id == data.ownerId || auth.id in data.ref('collaborators.id')", // Owner or collaborator can view
      "create": "auth.id != null",                                                 // Any logged-in user can create
      "update": "auth.id == data.ownerId",                                         // Only owner can update
      "delete": "auth.id == data.ownerId"                                          // Only owner can delete
    }
  }
} satisfies InstantRules;

export default rules;
```
