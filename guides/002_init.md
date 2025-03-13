# InstantDB Basic Initialization

The first step to using Instant in your app is to call `init`. Here is a simple
example at the root of your app.

```javascript
import { init } from '@instantdb/react';

const db = init({ appId: process.env.INSTANT_APP_ID! });

function App() {
  return <Main />;
}
```

## Typesafety

If you're using typescript, `init` accepts a `schema` argument. Adding a schema provides auto-completion and typesafety for your queries and transactions.
This can be useful for ensuring that your queries and transactions are correct

```typescript
import { init } from '@instantdb/react';
import schema from '../instant.schema';

const db = init({ appId: process.env.INSTANT_APP_ID, schema });
```

## Flexible Initialization

Instant maintains a single connection regardless of where or how many times you
call `init` with the same app ID. This means you can safely call `init` multiple
times without worrying about creating multiple connections or
performance overhead. However we do recommend the pattern of exporting a
reference from a utility file like so:

```javascript
// lib/db.js
import { init } from '@instantdb/react';
import schema from '../instant.schema';

export const db = init({
  appId: process.env.INSTANT_APP_ID!,
  schema
});
```

