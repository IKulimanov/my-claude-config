# Vue 3 Composition API Reference

## Component Structure

```vue
<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useOrderStore } from '@/stores/order'
import type { Order } from '@/types'

// Props
const props = defineProps<{
  orderId: string
  editable?: boolean
}>()

// Emits
const emit = defineEmits<{
  save: [order: Order]
  cancel: []
}>()

// State
const loading = ref(false)
const error = ref<string | null>(null)

// Store
const orderStore = useOrderStore()

// Computed
const isValid = computed(() => orderStore.currentOrder?.items.length > 0)

// Methods
async function handleSave() {
  loading.value = true
  try {
    const order = await orderStore.save(props.orderId)
    emit('save', order)
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Unknown error'
  } finally {
    loading.value = false
  }
}

// Lifecycle
onMounted(() => {
  orderStore.fetchOrder(props.orderId)
})
</script>

<template>
  <div class="order-form">
    <div v-if="loading">Loading...</div>
    <div v-else-if="error" class="error">{{ error }}</div>
    <template v-else>
      <slot name="header" />
      <OrderItems :items="orderStore.currentOrder?.items ?? []" />
      <button :disabled="!isValid" @click="handleSave">Save</button>
      <button @click="emit('cancel')">Cancel</button>
    </template>
  </div>
</template>

<style scoped>
.order-form { /* component-scoped styles */ }
.error { color: var(--color-error); }
</style>
```

## Composables (Reusable Logic)

Extract reusable stateful logic into composables:

```typescript
// composables/useAsync.ts
import { ref, type Ref } from 'vue'

export function useAsync<T>(fn: () => Promise<T>) {
  const data: Ref<T | null> = ref(null)
  const error = ref<string | null>(null)
  const loading = ref(false)

  async function execute() {
    loading.value = true
    error.value = null
    try {
      data.value = await fn()
    } catch (e) {
      error.value = e instanceof Error ? e.message : 'Unknown error'
    } finally {
      loading.value = false
    }
  }

  return { data, error, loading, execute }
}
```

## Component Design Rules

- One component = one responsibility.
- Props down, events up. Never mutate props.
- Use `v-model` with `defineModel()` for two-way binding.
- Prefer `<script setup>` - more concise, better TypeScript inference.
- Keep templates readable: max 3 levels of nesting, extract sub-components.
- Use named slots for flexible composition.
- Prefer `computed` over `watch` when possible.
- Use `watchEffect` for side effects that depend on reactive sources.
- Use `shallowRef` / `shallowReactive` for large objects that don't need deep reactivity.

## TypeScript Integration

- Always use `lang="ts"` in `<script setup>`.
- Define prop types with generics: `defineProps<{ ... }>()`.
- Define emit types: `defineEmits<{ event: [payload: Type] }>()`.
- Type template refs: `const input = ref<HTMLInputElement | null>(null)`.
- Export shared types from `@/types/` directory.
- Avoid `any` - use `unknown` and narrow with type guards.

## File & Directory Conventions

```
src/
  components/        # Shared/reusable components
    ui/              # Generic UI components (Button, Modal, Input)
    layout/          # Layout components (Header, Sidebar)
  views/             # Page-level components (mapped to routes)
  composables/       # Reusable composition functions (use*.ts)
  stores/            # Pinia stores
  types/             # TypeScript type definitions
  utils/             # Pure utility functions
  router/            # Vue Router configuration
  assets/            # Static assets (images, fonts)
  styles/            # Global styles, variables
```

- Components: `PascalCase.vue` (e.g. `OrderList.vue`)
- Composables: `camelCase.ts` prefixed with `use` (e.g. `useOrder.ts`)
- Stores: `camelCase.ts` (e.g. `order.ts`, used as `useOrderStore`)
- Views: `PascalCase.vue` matching route name (e.g. `OrderDetails.vue`)
