Instant comes with support for auth. We currently offer [magic codes](/docs/auth/magic-codes), [Google OAuth](/docs/auth/google-oauth), [Sign In with Apple](/docs/auth/apple), and [Clerk](/docs/auth/clerk). If you want to build your own flow, you can use the [Admin SDK](/docs/backend#custom-auth).

# Magic Codes

Instant supports a "magic-code" flow for auth. Users provide their email, we send
them a login code on your behalf, and they authenticate with your app. Here's
how you can do it with react.

## Full Magic Code Example

Open up your `app/page.tsx` file, and replace the entirety of it with the following code:

```javascript
"use client";

import React, { useState } from "react";
import { init, User } from "@instantdb/react";

// Instant app
const db = init({ appId: process.env.INSTANT_APP_ID! });

function App() {
  const { isLoading, user, error } = db.useAuth();

  if (isLoading) {
    return;
  }

  if (error) {
    return <div className="p-4 text-red-500">Uh oh! {error.message}</div>;
  }

  if (user) {
    // The user is logged in! Let's load the `Main`
    return <Main user={user} />;
  }
  // The use isn't logged in yet. Let's show them the `Login` component
  return <Login />;
}

function Main({ user }: { user: User }) {
  return (
    <div className="p-4 space-y-4">
      <h1 className="text-2xl font-bold">Hello {user.email}!</h1>
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

Go to `localhost:3000`, aand huzzah 🎉 You've got auth.

---

**Let's dig deeper.**

We created a `Login` component to handle our auth flow. Of note is `auth.sendMagicCode`
and `auth.signInWithMagicCode`.

On successful validation, Instant's backend will return a user object with a refresh token.
The client SDK will then restart the websocket connection with Instant's sync layer and provide the refresh token.

When doing `useQuery` or `transact`, the refresh token will be used to hydrate `auth`
on the backend during permission checks.

On the client, `useAuth` will set `isLoading` to `false` and populate `user` -- huzzah!

## useAuth

```javascript
function App() {
  const { isLoading, user, error } = db.useAuth();
  if (isLoading) {
    return;
  }
  if (error) {
    return <div className="p-4 text-red-500">Uh oh! {error.message}</div>;
  }
  if (user) {
    return <Main />;
  }
  return <Login />;
}
```

Use `useAuth` to fetch the current user. Here we guard against loading
our `Main` component until a user is logged in

## Send a Magic Code

```javascript
db.auth.sendMagicCode({ email }).catch((err) => {
  alert('Uh oh :' + err.body?.message);
  onSendEmail('');
});
```

Use `auth.sendMagicCode` to generate a magic code on instant's backend and email it to the user.

## Sign in with Magic Code

```javascript
db.auth.signInWithMagicCode({ email: sentEmail, code }).catch((err) => {
  inputEl.value = '';
  alert('Uh oh :' + err.body?.message);
});
```

You can then use `auth.signInWithMagicCode` to authenticate the user with the magic code they provided.

## Sign out

```javascript
db.auth.signOut();
```

Use `auth.signOut` from the client to invalidate the user's refresh token and
sign them out.You can also use the admin SDK to sign out the user

## Get auth

```javascript
const user = await db.getAuth();
console.log('logged in as', user.email);
```

For scenarios where you want to know the current auth state without subscribing
to changes, you can use `getAuth`.

# Google OAuth

Instant supports logging in your users with their Google account.
We support flows for Web and React Native. Follow the steps below to get started.

**Step 1: Configure OAuth consent screen**
Go to the [Google Console](https://console.cloud.google.com/apis/credentials).

Click "CONFIGURE CONSENT SCREEN." If you already have a consent screen, you can skip to the next step.

Select "External" and click "CREATE".

Add your app's name, a support email, and developer contact information. Click "Save and continue".

No need to add scopes or test users. Click "Save and continue" for the next
screens. Until you reach the "Summary" screen, click "Back to dashboard".

**Step 2: Create an OAuth client for Google**
From Google Console, click "+ CREATE CREDENTIALS"

Select "OAuth client ID"

Select "Web application" as the application type.

Add `https://api.instantdb.com/runtime/oauth/callback` as an Authorized redirect URI.

If you're testing from localhost, **add both `http://localhost`** and `http://localhost:3000` to "Authorized JavaScript origins", replacing `3000` with the port you use.
For production, add your website's domain.

**Step 3: Register your OAuth client with Instant**

Go to the Instant dashboard and select the `Auth` tab for your app.

Register a Google client and enter the client id and client secret from the OAuth client that you created.

**Step 4: Register your website with Instant**

In the `Auth` tab, add the url of the websites where you are using Instant to the Redirect Origins.
If you're testing from localhost, add `http://localhost:3000`, replacing `3000` with the port you use.
For production, add your website's domain.

**Step 5: Add login to your app**

The next sections will show you how to use your configured OAuth client with Instant.

## Native button for Web

You can use [Google's Sign in Button](https://developers.google.com/identity/gsi/web/guides/overview) with Instant. You'll use `db.auth.SignInWithIdToken` to authenticate your user.
The benefit of using Google's button is that you can display your app's name in the consent screen.

First, make sure that your website is in the list of "Authorized JavaScript origins" for your Google client on the [Google console](https://console.cloud.google.com/apis/credentials).

If you're using React, the easiest way to include the signin button is through the [`@react-oauth/google` package](https://github.com/MomenSherif/react-oauth).

```shell
npm install @react-oauth/google
```

Include the button and use `db.auth.signInWithIdToken` to complete sign in.
Here's a full example

```javascript
'use client';

import React, { useState } from 'react';
import { init } from '@instantdb/react';
import { GoogleOAuthProvider, GoogleLogin } from '@react-oauth/google';

const db = init({ appId: process.env.INSTANT_APP_ID! });

// e.g. 89602129-cuf0j.apps.googleusercontent.com
const GOOGLE_CLIENT_ID = 'REPLACE_ME';

// Use the google client name in the Instant dashboard auth tab
const GOOGLE_CLIENT_NAME = 'REPLACE_ME';

function App() {
  const { isLoading, user, error } = db.useAuth();
  if (isLoading) {
    return <div>Loading...</div>;
  }
  if (error) {
    return <div>Uh oh! {error.message}</div>;
  }
  if (user) {
    return <h1>Hello {user.email}!</h1>;
  }

  return <Login />;
}

function Login() {
  const [nonce] = useState(crypto.randomUUID());

  return (
    <GoogleOAuthProvider clientId={GOOGLE_CLIENT_ID}>
      <GoogleLogin
        nonce={nonce}
        onError={() => alert('Login failed')}
        onSuccess={({ credential }) => {
          db.auth
            .signInWithIdToken({
              clientName: GOOGLE_CLIENT_NAME,
              idToken: credential,
              // Make sure this is the same nonce you passed as a prop
              // to the GoogleLogin button
              nonce,
            })
            .catch((err) => {
              alert('Uh oh: ' + err.body?.message);
            });
        }}
      />
    </GoogleOAuthProvider>
  );
}
```

If you're not using React or prefer to embed the button yourself, refer to [Google's docs on how to create the button and load their client library](https://developers.google.com/identity/gsi/web/guides/overview). When creating your button, make sure to set the `data-ux_mode="popup"`. Your `data-callback` function should look like:

```javascript
async function handleSignInWithGoogle(response) {
  await db.auth.signInWithIdToken({
    // Use the google client name in the Instant dashboard auth tab
    clientName: 'REPLACE_ME',
    idToken: response.credential,
    // make sure this is the same nonce you set in data-nonce
    nonce: 'REPLACE_ME',
  });
}
```

## Redirect flow for Web

If you don't want to use the google styled buttons, you can use the redirect flow instead.

Simply create an authorization URL via `db.auth.createAuthorizationURL` and then use the url to create a link. Here's a full example:

```javascript
'use client';

import React, { useState } from 'react';
import { init } from '@instantdb/react';

const db = init({ appId: process.env.INSTANT_APP_ID! });

const url = db.auth.createAuthorizationURL({
  // Use the google client name in the Instant dashboard auth tab
  clientName: 'REPLACE_ME',
  redirectURL: window.location.href,
});

function App() {
  const { isLoading, user, error } = db.useAuth();
  if (isLoading) {
    return <div>Loading...</div>;
  }
  if (error) {
    return <div>Uh oh! {error.message}</div>;
  }
  if (user) {
    return <h1>Hello {user.email}!</h1>;
  }

  return <Login />;
}

function Login() {
  return <a href={url}>Log in with Google</a>;
}
```

When your users clicks on the link, they'll be redirected to Google to start the OAuth flow and then back to your site. Instant will automatically log them in to your app when they are redirected.

## Webview flow on React Native

Instant comes with support for Expo's AuthSession library. If you haven't already, follow the AuthSession [installation instructions from the Expo docs](https://docs.expo.dev/versions/latest/sdk/auth-session/).

Next, add the following dependencies:

```shell
npx expo install expo-auth-session expo-crypto
```

Update your app.json with your scheme:

```json
{
  "expo": {
    "scheme": "mycoolredirect"
  }
}
```

From the Auth tab on the Instant dashboard, add a redirect origin of type "App scheme". For development with expo add `exp://` and your scheme, e.g. `mycoolredirect://`.

Now you're ready to add a login button to your expo app. Here's a full example

```javascript
import { View, Text, Button, StyleSheet } from 'react-native';
import { init } from '@instantdb/react-native';
import {
  makeRedirectUri,
  useAuthRequest,
  useAutoDiscovery,
} from 'expo-auth-session';

const db = init({ appId: process.env.INSTANT_APP_ID! });

function App() {
  const { isLoading, user, error } = db.useAuth();

  let content;
  if (isLoading) {
    content = <Text>Loading...</Text>;
  } else if (error) {
    content = <Text>Uh oh! {error.message}</Text>;
  } else if (user) {
    content = <Text>Hello {user.email}!</Text>;
  } else {
    content = <Login />;
  }

  return <View style={styles.container}>{content}</View>;
}

function Login() {
  const discovery = useAutoDiscovery(db.auth.issuerURI());
  const [request, _response, promptAsync] = useAuthRequest(
    {
      // The unique name you gave the OAuth client when you
      // registered it on the Instant dashboard
      clientId: 'YOUR_INSTANT_AUTH_CLIENT_NAME',
      redirectUri: makeRedirectUri(),
    },
    discovery,
  );

  return (
    <Button
      title="Log in"
      disabled={!request}
      onPress={async () => {
        try {
          const res = await promptAsync();
          if (res.type === 'error') {
            alert(res.error || 'Something went wrong');
          }
          if (res.type === 'success') {
            await db.auth
              .exchangeOAuthCode({
                code: res.params.code,
                codeVerifier: request.codeVerifier,
              })
              .catch((e) => alert(e.body?.message || 'Something went wrong'));
          } else {
          }
        } catch (e) {
          console.error(e);
        }
      }}
    ></Button>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
});
```

# Apple OAuth

Instant supports Sign In with Apple on the Web and in native applications.

## Step 1: Create App ID

- Navigate to [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/identifiers/list)
- Select _Identifiers_
- Click _+_
- _Register a new identifier_ → Select _App IDs_
- _Select a type_ → Select _App_
- _Capabilities_ → _Sign In with Apple_ → Check
- Fill in _Bundle ID_ and _Description_
- Click _Register_

## Step 2: Create Services ID

- Navigate to [Services IDs](https://developer.apple.com/account/resources/identifiers/list/serviceId)
- Click _+_
- _Register a new identifier_ → Select _Services IDs_
- Fill in _Description_ and _Identifier_. You’ll need this _Identifier_ later
- Click _Register_

## Step 3: Configure Services ID (Web Popup flow)

- Select newly created Services ID
- Enable _Sign In with Apple_
- Click _Configure_
- Select _Primary App ID_ from Step 1
- To _Domains_, add your app domain (e.g. `myapp.com`)
- To _Return URLs_, add URL of your app where authentication happens (e.g. `https://myapp.com/signin`)
- Click _Continue_ → _Save_

## Step 3: Configure Services ID (Web Redirect flow)

- Select newly created Services ID
- Enable _Sign In with Apple_
- Click _Configure_
- Select _Primary App ID_ from Step 1
- To _Domains_, add `api.instantdb.com`
- To _Return URLs_, add `https://api.instantdb.com/runtime/oauth/callback`
- Click _Continue_ → _Save_

## Step 3.5: Generate Private Key (Web Redirect flow only)

- Navigate to [Keys](https://developer.apple.com/account/resources/authkeys/list)
- Click _+_
- Fill in _Name_ and _Description_
- Check _Sign in with Apple_
- Configure → select _App ID_ from Step 1
- _Continue_ → _Register_
- Download key file

## Step 3: Configure Services ID (React Native flow)

This step is not needed for Expo.
{% /conditional %}

## Step 4: Register your OAuth client with Instant

- Go to the Instant dashboard and select _Auth_ tab.
- Select _Add Apple Client_
- Select unique _clientName_ (`apple` by default, will be used in `db.auth` calls)
- Fill in _Services ID_ from Step 2
- Fill in _Team ID_ from [Membership details](https://developer.apple.com/account#MembershipDetailsCard)
- Fill in _Key ID_ from Step 3.5
- Fill in _Private Key_ by copying file content from Step 3.5
- Click `Add Apple Client`

## Step 4.5: Whitelist your domain in Instant (Web Redirect flow only)

- In Instant Dashboard, Click _Redirect Origins_ → _Add an origin_
- Add your app’s domain (e.g. `myapp.com`)

## Step 5: Add Sign In code to your app (Web Popup flow)

Add Apple Sign In library to your app:

```
https://appleid.cdn-apple.com/appleauth/static/jsapi/appleid/1/en_US/appleid.auth.js
```

Initialize with `Services ID` from Step 2:

```javascript
AppleID.auth.init({
  clientId: '<Services ID>',
  scope: 'name email',
  redirectURI: window.location.href,
});
```

Implement `signInPopup` using `clientName` from Step 4:

```javascript
async function signInPopup() {
  let nonce = crypto.randomUUID();

  // authenticate with Apple
  let resp = await AppleID.auth.signIn({
    nonce: nonce,
    usePopup: true,
  });

  // authenticate with Instant
  await db.auth.signInWithIdToken({
    clientName: '<clientName>',
    idToken: resp.authorization.id_token,
    nonce: nonce,
  });
}
```

Add Sign In button:

```javascript
<button onClick={signInPopup}>Sign In with Apple</button>
```

## Step 5: Add Sign In code to your app (Web Popup flow)

Create Sign In link using `clientName` from Step 4:

```
const authUrl = db.auth.createAuthorizationURL({
  clientName: '<clientName>',
  redirectURL: window.location.href,
});
```

Add a link uses `authUrl`:

```
<a href={ authUrl }>Sign In with Apple</a>
```

That’s it!

## Step 5: Add Sign In code to your app (React Native flow)

Instant comes with support for [Expo AppleAuthentication library](https://docs.expo.dev/versions/latest/sdk/apple-authentication/).

Add dependency:

```shell
npx expo install expo-apple-authentication
```

Update `app.json` by adding:

```json
{
  "expo": {
    "ios": {
      "usesAppleSignIn": true
    }
  }
}
```

Go to Instant dashboard → Auth tab → Redirect Origins → Add an origin.

Add `exp://` for development with Expo.

Authenticate with Apple and then pass identityToken to Instant along with `clientName` from Step 4:

```javascript
const [nonce] = useState('' + Math.random());
try {
  // sign in with Apple
  const credential = await AppleAuthentication.signInAsync({
    requestedScopes: [
      AppleAuthentication.AppleAuthenticationScope.FULL_NAME,
      AppleAuthentication.AppleAuthenticationScope.EMAIL,
    ],
    nonce: nonce,
  });

  // pass identityToken to Instant
  db.auth
    .signInWithIdToken({
      clientName: '<clientName>',
      idToken: credential.identityToken,
      nonce: nonce,
    })
    .catch((err) => {
      console.log('Error', err.body?.message, err);
    });
} catch (e) {
  if (e.code === 'ERR_REQUEST_CANCELED') {
    // handle that the user canceled the sign-in flow
  } else {
    // handle other errors
  }
}
```

Sign out code:

```javascript
<Button
  title="Sign Out"
  onPress={async () => {
    await db.auth.signOut();
  }}
/>
```

Full example:

```javascript
import React, { useState } from 'react';
import { Button, View, Text, StyleSheet } from 'react-native';
import { init, tx } from '@instantdb/react-native';
import * as AppleAuthentication from 'expo-apple-authentication';

const db = init({ appId: process.env.INSTANT_APP_ID! });

export default function App() {
  const { isLoading, user, error } = db.useAuth();
  if (isLoading) {
    return (
      <View style={styles.container}>
        <Text>Loading...</Text>
      </View>
    );
  }
  if (error) {
    return (
      <View style={styles.container}>
        <Text>Uh oh! {error.message}</Text>
      </View>
    );
  }
  if (user) {
    return (
      <View style={styles.container}>
        <Text>Hello {user.email}!</Text>
        <Button
          title="Sign Out"
          onPress={async () => {
            await db.auth.signOut();
          }}
        />
      </View>
    );
  }
  return <Login />;
}

function Login() {
  const [nonce] = useState('' + Math.random());
  return (
    <View style={styles.container}>
      <AppleAuthentication.AppleAuthenticationButton
        buttonType={AppleAuthentication.AppleAuthenticationButtonType.SIGN_IN}
        buttonStyle={AppleAuthentication.AppleAuthenticationButtonStyle.BLACK}
        cornerRadius={5}
        style={styles.button}
        onPress={async () => {
          try {
            const credential = await AppleAuthentication.signInAsync({
              requestedScopes: [
                AppleAuthentication.AppleAuthenticationScope.FULL_NAME,
                AppleAuthentication.AppleAuthenticationScope.EMAIL,
              ],
              nonce: nonce,
            });
            // signed in
            db.auth
              .signInWithIdToken({
                clientName: 'apple',
                idToken: credential.identityToken,
                nonce: nonce,
              })
              .catch((err) => {
                console.log('Error', err.body?.message, err);
              });
          } catch (e) {
            if (e.code === 'ERR_REQUEST_CANCELED') {
              // handle that the user canceled the sign-in flow
            } else {
              // handle other errors
            }
          }
        }}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  button: {
    width: 200,
    height: 44,
  },
});
```

# Clerk Auth

Instant supports delegating auth to Clerk.

## Setup

**Step 1: Configure Clerk**

Go to your Clerk dashboard, navigate to [`Sessions`](https://dashboard.clerk.com/last-active?path=sessions), then click the `Edit` button in the `Customize session token` section.

Add the email claim to your session token:

```json {% showCopy=true %}
{
  "email": "{{user.primary_email_address}}"
}
```

You can have additional claims as long as the `email` claim is set to `{{user.primary_email_address}}`.

![Clerk token form](/img/docs/clerk-token-form.png)

**Step 2: Get your Clerk Publishable key**

On the Clerk dashboard, navigate to [`API keys`](https://dashboard.clerk.com/last-active?path=api-keys), then copy the `Publishable key`. It should start with `pk_`.

**Step 3: Register your Clerk Publishable key with your instant app**

Go to the Instant dashboard, navigate to the `Auth` tab and add a new clerk app with the publishable key you copied.

## Usage

Use Clerk's `getToken` helper to get a session JWT for your signed-in user. Then call Instant's `db.auth.signInWithIdToken` with the JWT and the client name you set on the Instant dashboard.

When you call `db.auth.signInWithIdToken`, Instant will verify that the JWT was signed by your Clerk app. If verified, Instant use the email in the JWT's claims to lookup your user or create a new one and create a long-lived session. Be sure to call Instant's `db.auth.signOut` when you want to sign the user out.

Here is a full example using clerk's next.js library:

```javascript
'use client';

import {
  useAuth,
  ClerkProvider,
  SignInButton,
  SignedIn,
  SignedOut,
} from '@clerk/nextjs';
import { init } from '@instantdb/react';
import { useEffect } from 'react';

// Instant app
const db = init({ appId: process.env.INSTANT_APP_ID! });

// Use the clerk client name you set in the Instant dashboard auth tab
const CLERK_CLIENT_NAME = 'REPLACE_ME';

function ClerkSignedInComponent() {
  const { getToken, signOut } = useAuth();

  const signInToInstantWithClerkToken = async () => {
    // getToken gets the jwt from Clerk for your signed in user.
    const idToken = await getToken();

    if (!idToken) {
      // No jwt, can't sign in to instant
      return;
    }

    // Create a long-lived session with Instant for your clerk user
    // It will look up the user by email or create a new user with
    // the email address in the session token.
    db.auth.signInWithIdToken({
      clientName: CLERK_CLIENT_NAME,
      idToken: idToken,
    });
  };

  useEffect(() => {
    signInToInstantWithClerkToken();
  }, []);

  const { isLoading, user, error } = db.useAuth();

  if (isLoading) {
    return <div>Loading...</div>;
  }
  if (error) {
    return <div>Error signing in to Instant! {error.message}</div>;
  }
  if (user) {
    return (
      <div>
        <p>Signed in with Instant through Clerk!</p>{' '}
        <button
          onClick={() => {
            // First sign out of Instant to clear the Instant session.
            db.auth.signOut().then(() => {
              // Then sign out of Clerk to clear the Clerk session.
              signOut();
            });
          }}
        >
          Sign out
        </button>
      </div>
    );
  }
  return (
    <div>
      <button onClick={signInToInstantWithClerkToken}>
        Sign in to Instant
      </button>
    </div>
  );
}

function App() {
  return (
    <ClerkProvider>
      <SignedOut>
        <SignInButton />
      </SignedOut>
      <SignedIn>
        <ClerkSignedInComponent />
      </SignedIn>
    </ClerkProvider>
  );
}

export default App;
```


