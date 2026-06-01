# MuxPod coding conventions

## Naming conventions

| Target | Rule | Example |
|------|------|-----|
| Components | PascalCase | `TerminalView.tsx` |
| hooks | camelCase + `use` prefix | `useTerminal.ts` |
| stores | camelCase + `Store` suffix | `connectionStore.ts` |
| services | camelCase | `client.ts` |
| Type definitions | PascalCase | `TmuxSession` |
| Constants | SCREAMING_SNAKE_CASE | `DEFAULT_PORT` |

## State management

### Zustand Store
- Global state lives in `src/stores/`
- Things that need persistence: `persist` middleware + AsyncStorage
- Sensitive data: `expo-secure-store`

```typescript
// Example: src/stores/connectionStore.ts
export const useConnectionStore = create<ConnectionStore>()(
  persist(
    (set, get) => ({ ... }),
    {
      name: 'muxpod-connections',
      storage: createJSONStorage(() => AsyncStorage),
      partialize: (state) => ({ connections: state.connections }),
    }
  )
);
```

## SSH/tmux operations

### SSH client
- Use the `SSHClient` class in `src/services/ssh/client.ts`
- Connection management is coordinated with `connectionStore`

### tmux commands
- Use the `TmuxCommands` class in `src/services/tmux/commands.ts`
- Always use the `escape()` method for shell escaping (injection prevention)

```typescript
// Correct
await tmux.sendKeys(sessionName, windowIndex, paneIndex, keys);

// Bad (building commands directly is forbidden)
await ssh.exec(`tmux send-keys -t ${sessionName} ${keys}`);
```

## Terminal display

- ANSI escape-sequence handling: `src/services/ansi/parser.ts`
- Character-width calculation (Japanese-aware): `src/services/terminal/charWidth.ts`
- Polling interval: 100 ms (inside the `useTerminal` hook)

## TypeScript

### Type definitions
- Shared types live in `src/types/`
- Component-specific Props are defined in the same file

### Strict mode
- Keep `strict: true`
- Avoid `any` as a rule (when unavoidable, comment it with `// eslint-disable-next-line`)

## Component design

### File structure
```typescript
// 1. imports
import { ... } from 'react';
import { ... } from '@/components/ui';

// 2. types
interface Props { ... }

// 3. component
export function MyComponent({ ... }: Props) {
  // hooks
  // handlers
  // render
}
```

### Hooks
- Custom hooks live in `src/hooks/`
- Each hook focuses on a single responsibility
