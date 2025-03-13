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

### How It Works

1. User enters their email address
2. InstantDB sends a one-time verification code to the email
3. User enters the code
4. InstantDB verifies the code and authenticates the user

### Implementation Steps

#### Step 1: Set Up Basic Structure

Create a component that handles the authentication flow:

```jsx
function App() {
  const { isLoading, user, error } = db.useAuth();

  if (isLoading) return <div>Loading...</div>;
  if (error) return <div>Authentication error: {error.message}</div>;
  if (user) return <AuthenticatedContent user={user} />;
  return <Login />;
}
```

#### Step 2: Implement Email Collection

```jsx
function Login() {
  const [sentEmail, setSentEmail] = useState("");

  return (
    <div>
      {!sentEmail ? (
        <EmailForm onSendEmail={setSentEmail} />
      ) : (
        <CodeForm email={sentEmail} />
      )}
    </div>
  );
}

function EmailForm({ onSendEmail }) {
  const [email, setEmail] = useState("");
  const [isSending, setIsSending] = useState(false);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setIsSending(true);
    
    try {
      await db.auth.sendMagicCode({ email });
      onSendEmail(email);
    } catch (error) {
      alert("Error sending code: " + error.message);
    } finally {
      setIsSending(false);
    }
  };

  return (
    <form onSubmit={handleSubmit}>
      <h2>Sign In</h2>
      <input
        type="email"
        value={email}
        onChange={(e) => setEmail(e.target.value)}
        placeholder="Enter your email"
        required
      />
      <button type="submit" disabled={isSending}>
        {isSending ? "Sending..." : "Send Verification Code"}
      </button>
    </form>
  );
}
```

#### Step 3: Implement Code Verification

```jsx
function CodeForm({ email }) {
  const [code, setCode] = useState("");
  const [isVerifying, setIsVerifying] = useState(false);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setIsVerifying(true);
    
    try {
      await db.auth.signInWithMagicCode({ email, code });
    } catch (error) {
      alert("Invalid code: " + error.message);
      setCode("");
    } finally {
      setIsVerifying(false);
    }
  };

  return (
    <form onSubmit={handleSubmit}>
      <h2>Enter Verification Code</h2>
      <p>We sent a code to {email}</p>
      <input
        type="text"
        value={code}
        onChange={(e) => setCode(e.target.value)}
        placeholder="Enter your code"
        required
      />
      <button type="submit" disabled={isVerifying}>
        {isVerifying ? "Verifying..." : "Verify Code"}
      </button>
    </form>
  );
}
```

#### Step 4: Implement Sign Out

```jsx
function AuthenticatedContent({ user }) {
  const handleSignOut = async () => {
    await db.auth.signOut();
  };

  return (
    <div>
      <h1>Welcome, {user.email}!</h1>
      <button onClick={handleSignOut}>Sign Out</button>
    </div>
  );
}
```

### Best Practices for Magic Code Auth

1. **Clear Error Handling** - Provide helpful error messages when code sending or verification fails
2. **Loading States** - Show loading indicators during async operations
3. **Resend Functionality** - Allow users to request a new code if needed

## Google OAuth Authentication

Google OAuth allows users to sign in with their Google accounts.

### Configuration Steps

#### Step 1: Set Up Google OAuth Credentials

1. Go to the [Google Cloud Console](https://console.cloud.google.com/apis/credentials)
2. Create a new OAuth client ID
3. Set the application type to "Web application"
4. Add `https://api.instantdb.com/runtime/oauth/callback` as an authorized redirect URI
5. Add your application domains to the authorized JavaScript origins
6. Save the client ID and client secret

#### Step 2: Register with InstantDB

1. Go to the InstantDB dashboard's Auth tab
2. Add your Google client credentials
3. Add your application's domain to the Redirect Origins

### Implementation Options

#### Option 1: Using Google's Sign-In Button

```jsx
import { GoogleOAuthProvider, GoogleLogin } from '@react-oauth/google';

function Login() {
  const [nonce] = useState(crypto.randomUUID());

  const handleSuccess = async (credentialResponse) => {
    try {
      await db.auth.signInWithIdToken({
        clientName: "YOUR_GOOGLE_CLIENT_NAME", // From InstantDB dashboard
        idToken: credentialResponse.credential,
        nonce: nonce,
      });
    } catch (error) {
      console.error("Authentication failed:", error);
    }
  };

  return (
    <GoogleOAuthProvider clientId="YOUR_GOOGLE_CLIENT_ID">
      <GoogleLogin
        nonce={nonce}
        onSuccess={handleSuccess}
        onError={() => console.error("Login failed")}
      />
    </GoogleOAuthProvider>
  );
}
```

#### Option 2: Using Redirect Flow

```jsx
function Login() {
  // Create authorization URL for Google OAuth
  const authUrl = db.auth.createAuthorizationURL({
    clientName: "YOUR_GOOGLE_CLIENT_NAME", // From InstantDB dashboard
    redirectURL: window.location.href,
  });

  return (
    <div>
      <h2>Sign In</h2>
      <a href={authUrl} className="google-signin-button">
        Sign in with Google
      </a>
    </div>
  );
}
```

### React Native Implementation

For React Native applications, you'll use a different approach with Expo's AuthSession:

```jsx
import { makeRedirectUri, useAuthRequest, useAutoDiscovery } from 'expo-auth-session';

function Login() {
  const discovery = useAutoDiscovery(db.auth.issuerURI());
  const [request, response, promptAsync] = useAuthRequest(
    {
      clientId: "YOUR_INSTANT_AUTH_CLIENT_NAME",
      redirectUri: makeRedirectUri(),
    },
    discovery
  );

  useEffect(() => {
    if (response?.type === 'success') {
      const { code } = response.params;
      
      db.auth.exchangeOAuthCode({
        code,
        codeVerifier: request.codeVerifier,
      }).catch(error => {
        console.error("Auth error:", error);
      });
    }
  }, [response]);

  return (
    <Button
      title="Sign in with Google"
      disabled={!request}
      onPress={() => promptAsync()}
    />
  );
}
```

## Apple Sign In

Apple Sign In allows users to authenticate with their Apple ID.

### Configuration Steps

#### Step 1: Set Up Apple Developer Account

1. Create an App ID in your Apple Developer account
2. Enable the Sign In with Apple capability
3. Create a Services ID and configure Sign In with Apple
4. For redirect flow, add `api.instantdb.com` to the domains
5. For redirect flow, add `https://api.instantdb.com/runtime/oauth/callback` to return URLs
6. For redirect flow, generate a private key

#### Step 2: Register with InstantDB

1. Go to the InstantDB dashboard's Auth tab
2. Add your Apple client with the necessary credentials:
   - Services ID
   - Team ID
   - Key ID
   - Private Key

### Web Implementation

#### Popup Flow

```jsx
function Login() {
  const handleSignIn = async () => {
    const nonce = crypto.randomUUID();
    
    try {
      // Initialize Apple Sign In
      AppleID.auth.init({
        clientId: 'YOUR_SERVICES_ID', // From Apple Developer Account
        scope: 'name email',
        redirectURI: window.location.href,
      });
      
      // Sign in with Apple
      const response = await AppleID.auth.signIn({
        nonce: nonce,
        usePopup: true,
      });
      
      // Sign in with InstantDB
      await db.auth.signInWithIdToken({
        clientName: 'YOUR_APPLE_CLIENT_NAME', // From InstantDB dashboard
        idToken: response.authorization.id_token,
        nonce: nonce,
      });
    } catch (error) {
      console.error("Authentication failed:", error);
    }
  };

  return (
    <button onClick={handleSignIn}>
      Sign in with Apple
    </button>
  );
}
```

#### Redirect Flow

```jsx
function Login() {
  const authUrl = db.auth.createAuthorizationURL({
    clientName: 'YOUR_APPLE_CLIENT_NAME', // From InstantDB dashboard
    redirectURL: window.location.href,
  });

  return (
    <a href={authUrl}>
      Sign in with Apple
    </a>
  );
}
```

### React Native Implementation

```jsx
import * as AppleAuthentication from 'expo-apple-authentication';

function Login() {
  const handleSignIn = async () => {
    const nonce = crypto.randomUUID();
    
    try {
      const credential = await AppleAuthentication.signInAsync({
        requestedScopes: [
          AppleAuthentication.AppleAuthenticationScope.FULL_NAME,
          AppleAuthentication.AppleAuthenticationScope.EMAIL,
        ],
        nonce: nonce,
      });
      
      await db.auth.signInWithIdToken({
        clientName: 'YOUR_APPLE_CLIENT_NAME', // From InstantDB dashboard
        idToken: credential.identityToken,
        nonce: nonce,
      });
    } catch (error) {
      if (error.code === 'ERR_REQUEST_CANCELED') {
        // User canceled the sign-in flow
      } else {
        console.error("Authentication failed:", error);
      }
    }
  };

  return (
    <AppleAuthentication.AppleAuthenticationButton
      buttonType={AppleAuthentication.AppleAuthenticationButtonType.SIGN_IN}
      buttonStyle={AppleAuthentication.AppleAuthenticationButtonStyle.BLACK}
      cornerRadius={5}
      style={{ width: 200, height: 44 }}
      onPress={handleSignIn}
    />
  );
}
```

## Clerk Integration

If you're already using Clerk for authentication, you can integrate it with InstantDB.

### Configuration Steps

#### Step 1: Configure Clerk

1. In your Clerk dashboard, go to the Sessions tab
2. Edit the "Customize session token" section
3. Add the email claim: `{"email": "{{user.primary_email_address}}"}`
4. Save your changes

#### Step 2: Register with InstantDB

1. Copy your Clerk Publishable Key from the Clerk dashboard
2. Go to the InstantDB dashboard's Auth tab
3. Add a new Clerk client with your publishable key

### Implementation

```jsx
import { useAuth, ClerkProvider, SignInButton, SignedIn, SignedOut } from '@clerk/nextjs';
import { useEffect } from 'react';

function ClerkIntegration() {
  const { getToken, signOut: clerkSignOut } = useAuth();
  const { isLoading, user, error } = db.useAuth();

  // Sign in to InstantDB using Clerk token
  const signInWithClerk = async () => {
    const idToken = await getToken();
    
    if (!idToken) return;
    
    try {
      await db.auth.signInWithIdToken({
        clientName: 'YOUR_CLERK_CLIENT_NAME', // From InstantDB dashboard
        idToken: idToken,
      });
    } catch (error) {
      console.error("InstantDB authentication failed:", error);
    }
  };

  // Sign in automatically when component mounts
  useEffect(() => {
    signInWithClerk();
  }, []);

  // Combined sign out function
  const handleSignOut = async () => {
    // First sign out of InstantDB
    await db.auth.signOut();
    // Then sign out of Clerk
    clerkSignOut();
  };

  if (isLoading) return <div>Loading...</div>;
  if (error) return <div>Error: {error.message}</div>;
  if (user) {
    return (
      <div>
        <h1>Welcome, {user.email}!</h1>
        <button onClick={handleSignOut}>Sign Out</button>
      </div>
    );
  }
  
  return (
    <button onClick={signInWithClerk}>
      Sign in to InstantDB with Clerk
    </button>
  );
}

function App() {
  return (
    <ClerkProvider publishableKey="YOUR_CLERK_PUBLISHABLE_KEY">
      <SignedOut>
        <SignInButton />
      </SignedOut>
      <SignedIn>
        <ClerkIntegration />
      </SignedIn>
    </ClerkProvider>
  );
}
```

## Custom Authentication

For advanced use cases, you can build custom authentication flows using the InstantDB Admin SDK.

### Server-Side Implementation

```javascript
// Server-side code (e.g., in a Next.js API route)
import { init } from '@instantdb/admin';

const db = init({
  appId: process.env.INSTANT_APP_ID,
  adminToken: process.env.INSTANT_ADMIN_TOKEN,
});

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }
  
  const { email, password } = req.body;
  
  // Custom authentication logic
  const isValid = await validateCredentials(email, password);
  
  if (!isValid) {
    return res.status(401).json({ error: 'Invalid credentials' });
  }
  
  try {
    // Generate InstantDB token
    const token = await db.auth.createToken(email);
    
    // Return token to client
    res.status(200).json({ token });
  } catch (error) {
    res.status(500).json({ error: 'Authentication failed' });
  }
}

// Custom validation function
async function validateCredentials(email, password) {
  // Implement your custom validation logic
  // e.g., check against your database
  return true; // Return true if valid
}
```

### Client-Side Implementation

```jsx
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
      
      // Use the token to sign in with InstantDB
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

## Authentication Best Practices

Default to Magic Code Authentication - For most applications, magic code (email verification) authentication should the default choice because:

* It's simple to implement
* It eliminates password management concerns
* It provides good security with minimal user friction
* It works reliably across platforms

Use OAuth or custom authentication when explicitly prompted or when it is required

❌ **Common mistake**: Using password-based authentication in client-side code

InstantDB does not provide built-in username/password authentication. If you need traditional password-based authentication, you must implement it as a custom auth flow using the Admin SDK.

## Complete Example: Multi-Provider Auth

Here's a comprehensive example that combines multiple authentication methods:

```jsx
import { useState } from 'react';
import { GoogleOAuthProvider, GoogleLogin } from '@react-oauth/google';
import { init } from '@instantdb/react';

const db = init({ appId: process.env.NEXT_PUBLIC_INSTANT_APP_ID });

function App() {
  const { isLoading, user, error } = db.useAuth();

  if (isLoading) return <div>Loading...</div>;
  if (error) return <div>Error: {error.message}</div>;
  if (user) return <AuthenticatedContent user={user} />;
  return <Login />;
}

function AuthenticatedContent({ user }) {
  const handleSignOut = async () => {
    await db.auth.signOut();
  };

  return (
    <div>
      <h1>Welcome, {user.email}!</h1>
      <button onClick={handleSignOut}>Sign Out</button>
    </div>
  );
}

function Login() {
  const [authMethod, setAuthMethod] = useState(null);
  const [sentEmail, setSentEmail] = useState("");
  const [nonce] = useState(crypto.randomUUID());

  // Google OAuth
  const googleAuthUrl = db.auth.createAuthorizationURL({
    clientName: "YOUR_GOOGLE_CLIENT_NAME",
    redirectURL: window.location.href,
  });

  // Apple Sign In
  const appleAuthUrl = db.auth.createAuthorizationURL({
    clientName: "YOUR_APPLE_CLIENT_NAME",
    redirectURL: window.location.href,
  });

  // Handle Google sign in with button
  const handleGoogleSuccess = async (credentialResponse) => {
    try {
      await db.auth.signInWithIdToken({
        clientName: "YOUR_GOOGLE_CLIENT_NAME",
        idToken: credentialResponse.credential,
        nonce: nonce,
      });
    } catch (error) {
      console.error("Google authentication failed:", error);
    }
  };

  // Render different auth forms based on selected method
  if (authMethod === "magic-code") {
    if (sentEmail) {
      return <MagicCodeForm email={sentEmail} />;
    }
    return <EmailForm onSendEmail={setSentEmail} onBack={() => setAuthMethod(null)} />;
  }

  // Auth method selection screen
  return (
    <div>
      <h2>Sign In</h2>
      
      <div className="auth-options">
        <button onClick={() => setAuthMethod("magic-code")}>
          Continue with Email
        </button>
        
        <a href={googleAuthUrl} className="google-button">
          Continue with Google
        </a>
        
        <GoogleOAuthProvider clientId="YOUR_GOOGLE_CLIENT_ID">
          <GoogleLogin
            nonce={nonce}
            onSuccess={handleGoogleSuccess}
            onError={() => console.error("Login failed")}
          />
        </GoogleOAuthProvider>
        
        <a href={appleAuthUrl} className="apple-button">
          Continue with Apple
        </a>
      </div>
    </div>
  );
}

function EmailForm({ onSendEmail, onBack }) {
  const [email, setEmail] = useState("");
  const [isSending, setIsSending] = useState(false);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setIsSending(true);
    
    try {
      await db.auth.sendMagicCode({ email });
      onSendEmail(email);
    } catch (error) {
      alert("Error sending code: " + error.message);
    } finally {
      setIsSending(false);
    }
  };

  return (
    <form onSubmit={handleSubmit}>
      <h2>Sign In with Email</h2>
      <input
        type="email"
        value={email}
        onChange={(e) => setEmail(e.target.value)}
        placeholder="Enter your email"
        required
      />
      <button type="submit" disabled={isSending}>
        {isSending ? "Sending..." : "Send Verification Code"}
      </button>
      <button type="button" onClick={onBack}>
        Back
      </button>
    </form>
  );
}

function MagicCodeForm({ email }) {
  const [code, setCode] = useState("");
  const [isVerifying, setIsVerifying] = useState(false);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setIsVerifying(true);
    
    try {
      await db.auth.signInWithMagicCode({ email, code });
    } catch (error) {
      alert("Invalid code: " + error.message);
      setCode("");
    } finally {
      setIsVerifying(false);
    }
  };

  return (
    <form onSubmit={handleSubmit}>
      <h2>Enter Verification Code</h2>
      <p>We sent a code to {email}</p>
      <input
        type="text"
        value={code}
        onChange={(e) => setCode(e.target.value)}
        placeholder="Enter your code"
        required
      />
      <button type="submit" disabled={isVerifying}>
        {isVerifying ? "Verifying..." : "Verify Code"}
      </button>
    </form>
  );
}

export default App;
```

## Conclusion

InstantDB provides flexible authentication options to suit different application needs. Whether you prefer passwordless magic codes, social sign-in with Google or Apple, or want to integrate with existing auth providers like Clerk, InstantDB has you covered.

For most applications, the magic code authentication offers a good balance of security and user experience. For applications that require stronger security or integration with existing systems, consider using OAuth providers or building custom authentication flows.

By following the patterns and best practices in this guide, you can implement secure, user-friendly authentication in your InstantDB applications.
