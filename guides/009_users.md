# InstantDB User Management Guide

This guide explains how to effectively manage users in your InstantDB applications, covering everything from basic user operations to advanced permission patterns.

## Understanding the `$users` Namespace

InstantDB provides a special system namespace called `$users` for managing user accounts. This namespace:

- Is automatically created for every app
- Contains basic user information (email, ID)
- Has special rules and restrictions
- Requires special handling in schemas and transactions

## Basic User Operations

### Viewing Users

You can view all users in your application through:

1. The InstantDB dashboard in the Explorer tab
2. Querying the `$users` namespace in your application

```typescript
// ✅ Good: Query current user
function ProfilePage() {
  const { user } = db.useAuth();
  const { isLoading, error, data } = db.useQuery(
    user ? { $users: { $: { where: { id: user.id } } } } : null
  );
  
  if (isLoading) return <div>Loading...</div>;
  if (error) return <div>Error: {error.message}</div>;
  
  const currentUser = data?.$users?.[0];
  
  return (
    <div>
      <h1>Profile</h1>
      <p>Email: {currentUser?.email}</p>
    </div>
  );
}
```

### Default Permissions

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

### Schema Design Pattern

```typescript
// ✅ Good: User data extension pattern
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
      // Link from profiles to $users
      forward: { on: 'profiles', has: 'one', label: '$user' },
      // Link from $users to profiles
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

### Creating User Profiles

```typescript
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

### Updating User Profiles

```typescript
// ✅ Good: Update a user's profile
async function updateProfile(profileId, updates) {
  await db.transact(
    db.tx.profiles[profileId].update(updates)
  );
}
```

## User Relationships

You can model various relationships between users and other entities in your application.

### One-to-Many: User Posts

```typescript
// ✅ Good: User posts relationship
const _schema = i.schema({
  entities: {
    $users: i.entity({
      email: i.string().unique().indexed(),
    }),
    posts: i.entity({
      title: i.string(),
      content: i.string(),
      createdAt: i.date().indexed(),
    }),
  },
  links: {
    postAuthor: {
      forward: { on: 'posts', has: 'one', label: 'author' },
      reverse: { on: '$users', has: 'many', label: 'posts' },
    },
  },
});
```

Creating a post:

```typescript
// ✅ Good: Create a post linked to current user
function createPost(title, content, currentUser) {
  const postId = id();
  return db.transact(
    db.tx.posts[postId]
      .update({
        title,
        content,
        createdAt: new Date().toISOString(),
      })
      .link({ author: currentUser.id })
  );
}
```

### Many-to-Many: User Teams

```typescript
// ✅ Good: User teams relationship
const _schema = i.schema({
  entities: {
    $users: i.entity({
      email: i.string().unique().indexed(),
    }),
    teams: i.entity({
      name: i.string(),
      description: i.string(),
    }),
  },
  links: {
    teamMembers: {
      forward: { on: 'teams', has: 'many', label: 'members' },
      reverse: { on: '$users', has: 'many', label: 'teams' },
    },
  },
});
```

Adding a user to a team:

```typescript
// ✅ Good: Add user to team
function addUserToTeam(teamId, userId) {
  return db.transact(
    db.tx.teams[teamId].link({ members: userId })
  );
}
```

## User Roles and Permissions

A common pattern is to implement role-based access control.

### Setting Up User Roles

```typescript
// ✅ Good: User roles schema
const _schema = i.schema({
  entities: {
    $users: i.entity({
      email: i.string().unique().indexed(),
    }),
    roles: i.entity({
      name: i.string().unique().indexed(),
      permissions: i.json(), // Store permissions as JSON
    }),
  },
  links: {
    userRoles: {
      forward: { on: 'roles', has: 'many', label: 'users' },
      reverse: { on: '$users', has: 'many', label: 'roles' },
    },
  },
});
```

### Assigning Roles to Users

```typescript
// ✅ Good: Assign role to user
async function assignRoleToUser(roleId, userId) {
  await db.transact(
    db.tx.roles[roleId].link({ users: userId })
  );
}
```

### Using Roles in Permissions

```typescript
// ✅ Good: Role-based permissions
const rules = {
  settings: {
    allow: {
      update: "isAdmin",
    },
    bind: [
      "isAdmin",
      "'admin' in auth.ref('$user.roles.name')",
    ],
  },
} satisfies InstantRules;
```

## Advanced Patterns

### User Creation Flow

```typescript
// ✅ Good: Complete user onboarding flow
async function onUserCreated(user) {
  // Create initial profile
  const profileId = id();
  
  // Create initial settings
  const settingsId = id();
  
  // Assign default role
  const defaultRoleId = 'basic-user'; // Assuming this exists
  
  // Execute all in one transaction
  await db.transact([
    // Create profile
    db.tx.profiles[profileId]
      .update({
        displayName: user.email.split('@')[0],
        joinedAt: new Date().toISOString(),
      })
      .link({ $user: user.id }),
    
    // Create settings
    db.tx.userSettings[settingsId]
      .update({
        theme: 'light',
        emailNotifications: true,
      })
      .link({ $user: user.id }),
    
    // Assign role
    db.tx.roles[defaultRoleId].link({ users: user.id }),
  ]);
}
```

### User Activity Tracking

```typescript
// ✅ Good: Track user activity
function trackUserActivity(userId, action, metadata = {}) {
  return db.transact(
    db.tx.userActivities[id()].update({
      userId,
      action,
      timestamp: new Date().toISOString(),
      metadata,
    })
  );
}
```

## Permission Patterns

### Owner-Based Access

Only allow users to access their own data:

```typescript
// ✅ Good: Owner-based permissions
const rules = {
  posts: {
    allow: {
      update: "isOwner",
      delete: "isOwner",
    },
    bind: [
      "isOwner",
      "auth.id in data.ref('author.id')",
    ],
  },
} satisfies InstantRules;
```

### Role-Based Access

Allow access based on user roles:

```typescript
// ✅ Good: Role-based permissions
const rules = {
  posts: {
    allow: {
      update: "isOwner || isAdmin || isModerator",
      delete: "isOwner || isAdmin",
    },
    bind: [
      "isOwner", "auth.id in data.ref('author.id')",
      "isAdmin", "'admin' in auth.ref('$user.roles.name')",
      "isModerator", "'moderator' in auth.ref('$user.roles.name')",
    ],
  },
} satisfies InstantRules;
```

### Team-Based Access

Allow access based on team membership:

```typescript
// ✅ Good: Team-based permissions
const rules = {
  projects: {
    allow: {
      view: "isTeamMember || isAdmin",
      update: "isTeamMember && isProjectManager",
    },
    bind: [
      "isTeamMember", "auth.id in data.ref('team.members.id')",
      "isProjectManager", "'project_manager' in auth.ref('$user.roles.name')",
      "isAdmin", "'admin' in auth.ref('$user.roles.name')",
    ],
  },
} satisfies InstantRules;
```

## Common User Management Patterns

### User Profile Completion

Track profile completion status:

```typescript
// ✅ Good: Check profile completion
function getProfileCompletionStatus(profile) {
  const requiredFields = ['displayName', 'bio', 'avatarUrl', 'location'];
  const completedFields = requiredFields.filter(field => 
    profile[field] && profile[field].trim() !== ''
  );
  
  return {
    completed: completedFields.length === requiredFields.length,
    percentage: Math.round((completedFields.length / requiredFields.length) * 100),
    missingFields: requiredFields.filter(field => 
      !profile[field] || profile[field].trim() === ''
    ),
  };
}
```

### User Last Seen

Track when users were last active:

```typescript
// ✅ Good: Update last seen timestamp
function updateUserLastSeen(userId) {
  // Find or create user presence record
  return db.transact(
    db.tx.userPresence[lookup('userId', userId)].update({
      userId,
      lastSeen: new Date().toISOString(),
      isOnline: true,
    })
  );
}
```

## Best Practices

### 1. Always Use Links Correctly

Remember that `$users` must always be in the reverse direction of links:

```typescript
// ✅ Good: Correct link direction
userSettings: {
  forward: { on: 'settings', has: 'one', label: '$user' },
  reverse: { on: '$users', has: 'one', label: 'settings' },
},
```

### 2. Create Profiles Immediately After User Creation

Ensure users have associated profiles as soon as they sign up:

```typescript
// ✅ Good: Handle user creation
function App() {
  const { isLoading, user, error } = db.useAuth();
  
  // Create profile when user is first created
  useEffect(() => {
    if (user && !user.profile) {
      createUserProfile(user);
    }
  }, [user]);
  
  // Rest of your app
}
```

### 3. Use Named Relationships in Links

Use clear, descriptive names for your links:

```typescript
// ✅ Good: Clear link names
const _schema = i.schema({
  links: {
    postAuthor: { /* ... */ },     // Better than "postUser"
    teamMembers: { /* ... */ },    // Better than "teamUsers"
    projectOwnership: { /* ... */ }, // Better than "projectUser"
  },
});
```

## Troubleshooting

### Common Issues and Solutions

1. **Can't update user properties directly**
   
   You cannot directly modify the `$users` namespace. Instead, create linked entities:
   
   ```typescript
   // ❌ Bad: Directly updating $users
   db.transact(db.tx.$users[userId].update({ nickname: "Alice" }));
   
   // ✅ Good: Update linked profile instead
   db.transact(db.tx.profiles[profileId].update({ displayName: "Alice" }));
   ```

2. **Invalid link direction**
   
   Make sure `$users` is in the reverse direction:
   
   ```typescript
   // ❌ Bad: $users in forward direction
   userProfiles: {
     forward: { on: '$users', has: 'one', label: 'profile' },
     reverse: { on: 'profiles', has: 'one', label: '$user' },
   },
   
   // ✅ Good: $users in reverse direction
   userProfiles: {
     forward: { on: 'profiles', has: 'one', label: '$user' },
     reverse: { on: '$users', has: 'one', label: 'profile' },
   },
   ```

## Complete Example

Here's a comprehensive example illustrating a complete user management implementation:

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
    roles: i.entity({
      name: i.string().unique().indexed(),
      description: i.string(),
    }),
    posts: i.entity({
      title: i.string(),
      content: i.string(),
      createdAt: i.date().indexed(),
    }),
    comments: i.entity({
      content: i.string(),
      createdAt: i.date().indexed(),
    }),
  },
  links: {
    // User profiles
    userProfiles: {
      forward: { on: 'profiles', has: 'one', label: '$user' },
      reverse: { on: '$users', has: 'one', label: 'profile' },
    },
    
    // User roles
    userRoles: {
      forward: { on: 'roles', has: 'many', label: 'users' },
      reverse: { on: '$users', has: 'many', label: 'roles' },
    },
    
    // User posts
    postAuthor: {
      forward: { on: 'posts', has: 'one', label: 'author' },
      reverse: { on: '$users', has: 'many', label: 'posts' },
    },
    
    // Post comments
    postComments: {
      forward: { on: 'posts', has: 'many', label: 'comments' },
      reverse: { on: 'comments', has: 'one', label: 'post' },
    },
    
    // Comment author
    commentAuthor: {
      forward: { on: 'comments', has: 'one', label: 'author' },
      reverse: { on: '$users', has: 'many', label: 'comments' },
    },
  },
});

// Permissions
// instant.perms.ts
import type { InstantRules } from '@instantdb/react';

const rules = {
  $users: {
    allow: {
      view: "auth.id == data.id || isAdmin",
    },
    bind: [
      "isAdmin",
      "'admin' in auth.ref('$user.roles.name')",
    ],
  },
  
  profiles: {
    allow: {
      view: "true",
      update: "auth.id == data.ref('$user.id') || isAdmin",
    },
    bind: [
      "isAdmin",
      "'admin' in auth.ref('$user.roles.name')",
    ],
  },
  
  posts: {
    allow: {
      view: "true",
      create: "auth.id != null",
      update: "auth.id == data.ref('author.id') || isAdmin || isModerator",
      delete: "auth.id == data.ref('author.id') || isAdmin",
    },
    bind: [
      "isAdmin", "'admin' in auth.ref('$user.roles.name')",
      "isModerator", "'moderator' in auth.ref('$user.roles.name')",
    ],
  },
  
  comments: {
    allow: {
      view: "true",
      create: "auth.id != null",
      update: "auth.id == data.ref('author.id') || isAdmin || isModerator",
      delete: "auth.id == data.ref('author.id') || data.ref('post.author.id') == auth.id || isAdmin || isModerator",
    },
    bind: [
      "isAdmin", "'admin' in auth.ref('$user.roles.name')",
      "isModerator", "'moderator' in auth.ref('$user.roles.name')",
    ],
  },
} satisfies InstantRules;

export default rules;
```

## Conclusion

Managing users in InstantDB requires understanding the special nature of the `$users` namespace and properly leveraging links to create relationships. By following these patterns and best practices, you can build robust user management systems that handle authentication, authorization, and user data effectively.

Key takeaways:
1. The `$users` namespace is read-only and cannot be modified directly
2. Always use linked entities to store additional user information
3. When creating links, always put `$users` in the reverse direction
4. Use user references in permission rules to control access

With these guidelines, you can create secure, flexible, and scalable user systems in your InstantDB applications.
