# InstantDB Server-Side Development Guide

This guide explains how to use InstantDB in server-side environments for running background tasks, scripts, custom authentication flows, and sensitive application logic that shouldn't run in the browser.

## Getting Started with the Admin SDK

For server-side operations, InstantDB provides a specialized package called `@instantdb/admin`. This package has similar functionality to the client SDK but is designed specifically for secure server environments.

> **Important Security Note:** Never use the client SDK (`@instantdb/react`) on the server, and never expose your admin token in client-side code.

### Installation

First, install the admin SDK:

```bash
npm install @instantdb/admin
```

## Initializing the Admin SDK

### Basic Initialization

```javascript
// ✅ Good: Proper server-side initialization
import { init, id } from '@instantdb/admin';

const db = init({
  appId: process.env.INSTANT_APP_ID,
  adminToken: process.env.INSTANT_APP_ADMIN_TOKEN,
});
```

❌ **Common mistake**: Using client SDK on the server
```javascript
// ❌ Bad: Don't use the React SDK on the server
import { init } from '@instantdb/react'; // Wrong package!

const db = init({
  appId: process.env.INSTANT_APP_ID,
});
```

❌ **Common mistake**: Exposing admin token in client code
```javascript
// ❌ Bad: Never expose your admin token in client code
const db = init({
  appId: 'app-123',
  adminToken: 'admin-token-abc', // Hardcoded token = security risk!
});
```

### With TypeScript Schema

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

Unlike the client SDK which uses reactive hooks, the admin SDK uses simple async functions.

### Basic Querying

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

### Complex Queries

The query syntax is the same as in the client SDK:

```javascript
// ✅ Good: Complex server-side query
const fetchUserData = async (userId) => {
  try {
    const data = await db.query({
      profiles: {
        $: {
          where: { 
            id: userId 
          },
        },
        authoredPosts: {
          comments: {}
        },
      },
    });
    
    return data.profiles[0];
  } catch (error) {
    console.error('Error fetching user data:', error);
    throw error;
  }
};
```

❌ **Common mistake**: Using client-side syntax
```javascript
// ❌ Bad: Don't use useQuery on the server
const { data, isLoading } = db.useQuery({ todos: {} }); // Wrong approach!
```

## Writing Data from the Server

The transaction API is functionally the same as the client SDK but is asynchronous.

### Basic Transactions

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

### Batch Operations

```javascript
// ✅ Good: Batch server-side operations
const importTodos = async (todoItems) => {
  try {
    const transactions = todoItems.map(item => 
      db.tx.todos[id()].update({
        title: item.title,
        completed: item.completed || false,
        createdAt: new Date().toISOString(),
      })
    );
    
    const result = await db.transact(transactions);
    return result;
  } catch (error) {
    console.error('Error importing todos:', error);
    throw error;
  }
};
```

### Handling Large Batches

For very large batch operations, split them into smaller chunks:

```javascript
// ✅ Good: Processing large datasets in chunks
const importLargeDataset = async (items) => {
  const batchSize = 100;
  const results = [];
  
  for (let i = 0; i < items.length; i += batchSize) {
    const batch = items.slice(i, i + batchSize);
    const transactions = batch.map(item => 
      db.tx.todos[id()].update({
        title: item.title,
        // other fields...
      })
    );
    
    try {
      const result = await db.transact(transactions);
      results.push(result);
      console.log(`Processed batch ${i / batchSize + 1}`);
    } catch (error) {
      console.error(`Error processing batch ${i / batchSize + 1}:`, error);
      // Handle error (retry, skip, or throw)
    }
  }
  
  return results;
};
```

## User Authentication and Permission Management

### Impersonating Users

When you need to operate on behalf of a specific user (respecting their permissions):

```javascript
// ✅ Good: Impersonating a user by email
const getUserData = async (userEmail) => {
  const userDb = db.asUser({ email: userEmail });
  return await userDb.query({ todos: {} });
};

// ✅ Good: Impersonating a user with a token
const getUserDataWithToken = async (userToken) => {
  const userDb = db.asUser({ token: userToken });
  return await userDb.query({ todos: {} });
};

// ✅ Good: Operating as a guest
const getPublicData = async () => {
  const guestDb = db.asUser({ guest: true });
  return await guestDb.query({ publicPosts: {} });
};
```

❌ **Common mistake**: Not handling errors when impersonating
```javascript
// ❌ Bad: Missing error handling
const getUserData = async (userEmail) => {
  // If userEmail doesn't exist, this will fail silently
  const userDb = db.asUser({ email: userEmail });
  return await userDb.query({ todos: {} });
};
```

### User Management

You can retrieve user information:

```javascript
// ✅ Good: Retrieving a user by email
const getUserByEmail = async (email) => {
  try {
    const user = await db.auth.getUser({ email });
    return user;
  } catch (error) {
    console.error(`User with email ${email} not found:`, error);
    return null;
  }
};

// ✅ Good: Retrieving a user by ID
const getUserById = async (userId) => {
  try {
    const user = await db.auth.getUser({ id: userId });
    return user;
  } catch (error) {
    console.error(`User with ID ${userId} not found:`, error);
    return null;
  }
};

// ✅ Good: Retrieving a user by refresh token
const getUserByToken = async (refreshToken) => {
  try {
    const user = await db.auth.getUser({ refresh_token: refreshToken });
    return user;
  } catch (error) {
    console.error('Invalid refresh token:', error);
    return null;
  }
};
```

### Deleting Users

You can delete users and their associated data:

```javascript
// ✅ Good: Deleting a user with cleanup
const deleteUserAndData = async (userId) => {
  try {
    // First, fetch user-related data
    const { posts, comments } = await db.query({
      posts: { $: { where: { 'author.$user.id': userId } } },
      comments: { $: { where: { 'author.$user.id': userId } } },
    });
    
    // Delete the related data
    await db.transact([
      ...posts.map(post => db.tx.posts[post.id].delete()),
      ...comments.map(comment => db.tx.comments[comment.id].delete()),
    ]);
    
    // Finally, delete the user
    const deletedUser = await db.auth.deleteUser({ id: userId });
    console.log(`User ${deletedUser.email} successfully deleted`);
    return deletedUser;
  } catch (error) {
    console.error(`Failed to delete user ${userId}:`, error);
    throw error;
  }
};
```

❌ **Common mistake**: Not cleaning up associated data
```javascript
// ❌ Bad: Deleting user without handling their data
const deleteUser = async (userId) => {
  // This will leave orphaned data if cascade delete isn't configured
  return await db.auth.deleteUser({ id: userId });
};
```

## Advanced Authentication Features

### Custom Authentication Flows

With the Admin SDK, you can create fully customized authentication flows. This is a two-part process involving both your backend and frontend.

#### Backend: Creating Authentication Tokens

```javascript
// ✅ Good: Custom authentication endpoint
import express from 'express';
import { init } from '@instantdb/admin';

const app = express();
app.use(express.json());

const db = init({
  appId: process.env.INSTANT_APP_ID,
  adminToken: process.env.INSTANT_APP_ADMIN_TOKEN,
});

app.post('/api/sign-in', async (req, res) => {
  try {
    const { email, password } = req.body;
    
    // Verify credentials against your own database or auth system
    const isValid = await verifyCredentials(email, password);
    
    if (!isValid) {
      return res.status(401).json({ 
        error: 'Invalid credentials' 
      });
    }
    
    // Generate an InstantDB token
    const token = await db.auth.createToken(email);
    
    // Return the token to the client
    return res.status(200).json({ token });
  } catch (error) {
    console.error('Sign-in error:', error);
    return res.status(500).json({
      error: 'Authentication failed'
    });
  }
});
```

> **Note:** If a user with the provided email doesn't exist, `auth.createToken` will automatically create a new user record.

#### Frontend: Using the Token

```javascript
// ✅ Good: Frontend implementation with custom auth
import { useState } from 'react';
import { init } from '@instantdb/react';

const db = init({ 
  appId: process.env.NEXT_PUBLIC_INSTANT_APP_ID 
});

function LoginForm() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState(null);
  
  const handleLogin = async (e) => {
    e.preventDefault();
    setIsLoading(true);
    setError(null);
    
    try {
      // Call your custom authentication endpoint
      const response = await fetch('/api/sign-in', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password }),
      });
      
      const data = await response.json();
      
      if (!response.ok) {
        throw new Error(data.error || 'Authentication failed');
      }
      
      // Use the token to sign in with InstantDB
      await db.auth.signInWithToken(data.token);
      
    } catch (err) {
      setError(err.message);
    } finally {
      setIsLoading(false);
    }
  };
  
  return (
    <form onSubmit={handleLogin}>
      {/* Form fields */}
    </form>
  );
}
```

### Magic Code Authentication

If you want to use your own email provider for magic code authentication:

```javascript
// ✅ Good: Custom magic code endpoint
app.post('/api/send-magic-code', async (req, res) => {
  try {
    const { email } = req.body;
    
    // Generate a magic code through InstantDB
    const { code } = await db.auth.generateMagicCode(email);
    
    // Send the code using your own email service
    await sendEmail({
      to: email,
      subject: 'Your login code',
      body: `Your verification code is: ${code}`
    });
    
    return res.status(200).json({ 
      message: 'Magic code sent successfully' 
    });
  } catch (error) {
    console.error('Error generating magic code:', error);
    return res.status(500).json({ 
      error: 'Failed to send magic code' 
    });
  }
});
```

### Sign Out Users

You can force a user to sign out by invalidating their tokens:

```javascript
// ✅ Good: Sign out a user from the server
const signOutUser = async (email) => {
  try {
    await db.auth.signOut(email);
    console.log(`Successfully signed out ${email}`);
    return true;
  } catch (error) {
    console.error(`Failed to sign out ${email}:`, error);
    return false;
  }
};
```

### Creating Authenticated Endpoints

You can verify user tokens in your custom API endpoints:

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

#### Frontend Implementation

```javascript
// ✅ Good: Frontend calling an authenticated endpoint
const callProtectedApi = async () => {
  const { user } = db.useAuth();
  
  if (!user) {
    console.error('User not authenticated');
    return;
  }
  
  try {
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

## Common Server-Side Patterns

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
// ✅ Good: Exporting data
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
  const user = await db.auth.verifyToken(token);
  
  // Create profile with additional data
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

## Security Considerations

### Environment Variables

Store sensitive credentials in environment variables:

```javascript
// ✅ Good: Using environment variables
const db = init({
  appId: process.env.INSTANT_APP_ID,
  adminToken: process.env.INSTANT_APP_ADMIN_TOKEN,
});
```

### User Input Validation

Always validate user input before making transactions:

```javascript
// ✅ Good: Validating input before using in transactions
const createValidatedItem = async (userInput) => {
  // Validate input
  if (!userInput.title || userInput.title.length < 3) {
    throw new Error('Title must be at least 3 characters');
  }
  
  if (userInput.count && typeof userInput.count !== 'number') {
    throw new Error('Count must be a number');
  }
  
  // Only proceed with valid data
  return await db.transact(
    db.tx.items[id()].update({
      title: userInput.title,
      count: userInput.count || 0,
      createdAt: new Date().toISOString(),
    })
  );
};
```

## Performance Optimization

### Query Optimization

Fetch only what you need:

```javascript
// ✅ Good: Optimized query with field selection
const getEssentialData = async () => {
  return await db.query({
    posts: {
      $: {
        fields: ['title', 'slug', 'publishedAt'],
        limit: 10,
        order: { publishedAt: 'desc' }
      }
    }
  });
};
```

## Complete Example: Background Worker

Here's a complete example of a server-side process that might run as a background worker:

```javascript
import { init, id } from '@instantdb/admin';
import schema from '../instant.schema';

// Initialize the SDK
const db = init({
  appId: process.env.INSTANT_APP_ID,
  adminToken: process.env.INSTANT_APP_ADMIN_TOKEN,
  schema,
});

// Process pending orders
const processPendingOrders = async () => {
  try {
    // Get pending orders
    const { orders } = await db.query({
      orders: {
        $: {
          where: {
            status: 'pending',
            createdAt: { $lt: getTimeAgo(30) } // Orders older than 30 minutes
          }
        },
        customer: {
          profile: {}
        },
        items: {}
      }
    });
    
    console.log(`Processing ${orders.length} pending orders`);
    
    // Process each order
    for (const order of orders) {
      try {
        // Some payment processing logic
        const paymentResult = await processPayment(order);
        
        // Update the order
        await db.transact(
          db.tx.orders[order.id].update({
            status: paymentResult.success ? 'completed' : 'failed',
            processedAt: new Date().toISOString(),
            paymentDetails: {
              transactionId: paymentResult.transactionId,
              amount: paymentResult.amount
            }
          })
        );
        
        // Notify the customer
        if (paymentResult.success) {
          await sendOrderConfirmation(order);
        } else {
          await sendPaymentFailedNotification(order);
        }
        
      } catch (orderError) {
        console.error(`Error processing order ${order.id}:`, orderError);
        
        // Mark as error
        await db.transact(
          db.tx.orders[order.id].update({
            status: 'error',
            error: orderError.message
          })
        );
      }
    }
    
    console.log('Finished processing pending orders');
  } catch (error) {
    console.error('Error in order processing job:', error);
    // Send alert to administrators
    await alertAdmins('Order processing job failed', error);
  }
};

// Helper function
const getTimeAgo = (minutes) => {
  const date = new Date();
  date.setMinutes(date.getMinutes() - minutes);
  return date.toISOString();
};

// Run the job
processPendingOrders();
```

## Conclusion

The InstantDB admin SDK provides powerful capabilities for server-side operations, allowing you to:

- Run background tasks and scheduled jobs
- Implement custom authentication flows
- Process data in batches
- Perform administrative operations
- Manage user accounts securely

Always follow security best practices by:
- Keeping your admin token secure
- Validating all user input
- Using environment variables for sensitive information

Remember that the admin SDK bypasses permissions by default - use `db.asUser()` when you want to respect user permissions.
